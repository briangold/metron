//! Records additional information about the system where benchmarks are run
const std = @import("std");
const os = std.os;

const Context = @This();

timestamp: i64,

cpu_info: struct {
    num_cpus: usize,
    mhz_per_cpu: usize,
    scaling: enum {
        unknown,
        enabled,
        disabled,
    },
    // TODO: cache info
},

sys_info: struct {
    name: []const u8,
},

pub fn init(alloc: std.mem.Allocator) !Context {
    // TODO: get as many of these from std as we can, otherwise consult
    // Google bench for their method

    var buf = try alloc.alloc(u8, os.HOST_NAME_MAX);

    return Context{
        .timestamp = std.time.timestamp(),
        .cpu_info = .{
            .num_cpus = try std.Thread.getCpuCount(),
            .mhz_per_cpu = 1000,
            .scaling = .unknown,
        },
        .sys_info = .{
            .name = try os.gethostname(@ptrCast(buf[0..])),
        },
    };
}

pub fn deinit(ctx: *Context, alloc: std.mem.Allocator) void {
    // NOTE: we have to match the alloc above - without the @as cast here,
    // alloc.free() will only free the bytes used by the hostname, not the
    // full, original buffer sized to HOST_NAME_MAX
    alloc.free(@as(*const [os.HOST_NAME_MAX]u8, @ptrCast(ctx.sys_info.name)));
}
