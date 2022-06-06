//! Measures the performance of a minimal, empty timing loop. Also demonstrates
//! the use of fixture code before/after the main loop.

const std = @import("std");
const metron = @import("metron");

const State = metron.State;

pub fn main() anyerror!void {
    try metron.run(struct {
        pub const name = "empty";
        pub const args = [_]void{{}};
        pub const min_iter = 100; // useful for attaching gdb and seeing loop

        // On my M1 Mac with -Drelease-fast=true, the inner loop compiles to:
        //
        // loop:
        //    stp x10, x8, [sp, #8] ; doNotOptimize(&i)
        //    add x8, x8, #0x1      ; increment
        //    cmp x9, x8            ; are we done?
        //    b.ne loop             ; branch backwards if not done
        //
        // However... backend optimization is fickle, and seeming unrelated
        // changes can generate different code, often worse. On my machine, I
        // see the per-loop timing ranging from 0.3ns to ~2ns, and so long as
        // your actual work is much longer per iteration, any loop
        // inefficiencies shouldn't matter. But if you're trying to time
        // individual instructions you probably need to inspect carefully and
        // hand-hold the compiler as needed.

        pub fn simple(state: *State, _: void) void {
            var iter = state.iter();
            while (iter.next()) |i| {
                std.mem.doNotOptimizeAway(&i);
            }
        }

        pub fn fixture(state: *State, _: void) !void {
            // We can do expensive setup and teardown before the main loop,
            // with no disruption to results.
            const size = 100 * 1024 * 1024;
            var arr = try state.alloc.alloc(u8, size);
            defer state.alloc.free(arr);

            std.mem.set(u8, arr, 42);

            // loop is timed from creation of iter() to final next()
            var iter = state.iter();
            while (iter.next()) |i| {
                std.mem.doNotOptimizeAway(&i);
            }
        }
    });
}
