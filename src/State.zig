const std = @import("std");

const Timer = std.time.Timer;

const Barrier = @import("Barrier.zig");

const State = @This();

iterations: usize,
duration: ?u64 = null,
thread_id: usize,
threads: usize,
bytes: ?usize = null,
barrier: *Barrier,
alloc: std.mem.Allocator, // TODO: use a tracked allocator so we can report stats
timer: Timer = undefined,

pub fn iter(state: *State) Iterator {
    var it = Iterator{
        .limit = state.iterations,
        .state = state,
    };

    it.start();

    return it;
}

const Iterator = struct {
    // keep iterator to minimum so the compiler has a better chance of putting
    // cur and limit in registers and avoid ld/st to the stack
    cur: usize = 0,
    limit: usize,
    state: *State,

    inline fn start(it: *Iterator) void {
        @setCold(true);
        std.debug.assert(it.cur == 0);
        it.state.timer = Timer.start() catch unreachable;
        it.state.barrier.wait();
    }

    inline fn end(it: *Iterator) void {
        @setCold(true);
        it.state.barrier.wait();
        it.state.duration = it.state.timer.read();
    }

    pub inline fn next(it: *Iterator) ?usize {
        const cur = it.cur;

        if (cur != it.limit) {
            it.cur += 1;
            return cur;
        }

        it.end();
        return null;
    }
};
