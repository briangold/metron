const std = @import("std");

const Decl = std.builtin.TypeInfo.Declaration;

const Barrier = @import("Barrier.zig");
const Context = @import("Context.zig");
const Console = @import("Console.zig");
const State = @import("State.zig");
const spec = @import("spec.zig");

pub const Options = struct {
    json_path: ?[]const u8 = null,
};

const Runner = @This();

alloc: std.mem.Allocator,
options: Options,
console: Console,

pub fn init(alloc: std.mem.Allocator, options: Options) Runner {
    return Runner{
        .alloc = alloc,
        .options = options,
        .console = undefined, // will be configured in run()
    };
}

pub fn run(runner: *Runner, comptime Spec: anytype) !void {
    var context = try Context.init(runner.alloc);
    defer context.deinit(runner.alloc);

    runner.console = try Console.init(stdErrWriter(), Spec, context);

    // ensure we have a tuple of benchmarks for simplicity
    const Benchmarks = if (comptime spec.specLength(Spec) == 1) .{Spec} else Spec;

    inline for (Benchmarks) |B| {
        try runner.runOneBenchmark(B);
    }
}

fn Result(comptime B: type) type {
    const Counters = if (@hasDecl(B, "Counters")) B.Counters else struct {};

    return struct {
        ops: usize,
        ns: u64,
        counters: Counters,
    };
}

fn runOneBenchmark(runner: *Runner, comptime B: type) !void {
    const repeat = if (@hasDecl(B, "repeat")) B.repeat else 1;
    if (repeat != 1) @compileError("repetition not yet supported");

    const threads = if (@hasDecl(B, "threads"))
        B.threads
    else
        [_]?usize{null}; // null signals the reporter to not indicate # threads

    const BenchResult = Result(B);
    const ResultList = std.ArrayListUnmanaged(BenchResult);
    const funlist = comptime spec.functions(B);

    inline for (funlist) |def| {
        inline for (B.args) |arg| {
            inline for (threads) |tc| {
                var accum = ResultList{};
                defer accum.deinit(runner.alloc);

                var i: usize = 0;
                while (i < repeat) : (i += 1) {
                    const res = try runner.runOneTestRep(B, def, arg, tc, i);
                    try accum.append(runner.alloc, res);
                }

                try runner.console.report(
                    stdErrWriter(),
                    B,
                    if (funlist.len > 1) def.name else null,
                    arg,
                    tc,
                    accum.items,
                );
            }
        }
    }
}

fn runOneTestRep(
    runner: *Runner,
    comptime B: type,
    comptime def: Decl,
    comptime arg: anytype,
    comptime maybe_threads: ?usize,
    index: usize,
) !Result(B) {
    _ = index; // TODO: needed?

    const max_iter: u64 = 1_000_000_000;
    const threads = maybe_threads orelse 1;

    const min_time: u64 = if (@hasDecl(B, "min_time"))
        B.min_time
    else
        std.time.ns_per_s;

    const min_iter = if (@hasDecl(B, "min_iter")) B.min_iter else 1;

    var n: usize = min_iter;
    var result = while (n < max_iter) {
        const result = try runner.runThreads(B, def, arg, threads, n);

        if (result.ns >= min_time) {
            break result;
        }

        // This algorithm is based on the one in Google Benchmark, but
        // altered to use fixed-point math.

        const prev = n;

        // If we're close, try to predict with some padding (x1.4)
        n = if (result.ns > min_time / 10)
            (min_time * prev * 14 / result.ns / 10)
        else
            prev * 10; // otherwise, just bump by 10
        n = std.math.max(n, prev + 1); // ensure at least +1
        n = std.math.min(n, max_iter); // don't go over max
    } else unreachable;

    return result;
}

fn runThreads(
    runner: *Runner,
    comptime B: type,
    comptime def: Decl,
    comptime arg: anytype,
    comptime threads: usize,
    num_iter: usize,
) !Result(B) {
    const ThreadRunner = struct {
        threads: usize,
        barrier: Barrier,
        alloc: std.mem.Allocator,

        fn entry(
            t_runner: *@This(),
            tid: usize,
            iter: usize,
            result: *Result(B),
        ) void {
            var state = State{
                .iterations = iter,
                .thread_id = tid,
                .threads = t_runner.threads,
                .barrier = &t_runner.barrier,
                .alloc = t_runner.alloc,
            };

            // We don't want inlining here... the compiler can statically
            // compute the result.
            const fun = @field(B, def.name);
            const copt = std.builtin.CallOptions{ .modifier = .never_inline };
            const FunArgs = std.meta.ArgsTuple(@TypeOf(fun));
            const Return = @typeInfo(@TypeOf(fun)).Fn.return_type orelse
                @compileError(def.name ++ " missing return type");

            // Run the user-provided function and panic on any error
            const maybe_err = @call(copt, fun, FunArgs{ &state, arg });
            const res = switch (@typeInfo(Return)) {
                .ErrorUnion => maybe_err catch
                    @panic("Benchmark '" ++ def.name ++ "' hit error"),
                else => maybe_err,
            };

            if (state.duration == null) {
                // The benchmark entry didn't set the state duration, which
                // likely happened if you forgot to iterate over the state
                // iterator. See the tour guide for examples.
                @panic("missing duration - did you forget to iterate?");
            }

            result.* = Result(B){
                .ns = state.duration.?,
                .ops = iter,
                .counters = if (@TypeOf(res) == void) .{} else res,
            };
        }
    };

    var handles = try runner.alloc.alloc(std.Thread, threads - 1);
    defer runner.alloc.free(handles);

    var results = try runner.alloc.alloc(Result(B), threads);
    defer runner.alloc.free(results);

    var t_runner = ThreadRunner{
        .threads = threads,
        .barrier = Barrier{ .num_threads = threads },
        .alloc = runner.alloc,
    };

    // spawn N-1 threads, numbered starting at 1
    for (handles) |*h, i| {
        const tid = i + 1;
        h.* = try std.Thread.spawn(
            .{},
            ThreadRunner.entry,
            .{ &t_runner, tid, num_iter, &results[tid] },
        );
    }

    // run thread '0' in place here
    @call(.{}, ThreadRunner.entry, .{ &t_runner, 0, num_iter, &results[0] });

    // join all the threads that were spawned
    for (handles) |h| h.join();

    var total = Result(B){
        .ns = results[0].ns,
        .ops = 0,
        .counters = .{},
    };

    for (results) |res| {
        total.ops += res.ops;

        const counter_fields = spec.CounterFields(B);
        inline for (counter_fields) |cf| {
            const ctr = @field(res.counters, cf.name);
            @field(total.counters, cf.name).val += ctr.val;
        }
    }

    return total;
}

fn stdErrWriter() std.fs.File.Writer {
    return std.io.getStdErr().writer();
}
