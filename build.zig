const std = @import("std");

const tests = [_]struct {
    name: []const u8,
    path: []const u8,
}{
    .{ .name = "empty", .path = "tests/empty.zig" },
    .{ .name = "fib", .path = "tests/fib.zig" },
    .{ .name = "roots", .path = "tests/roots.zig" },
    .{ .name = "bitset", .path = "tests/bitset.zig" },
    .{ .name = "memcpy", .path = "tests/memcpy.zig" },
    .{ .name = "threads", .path = "tests/threads.zig" },
    .{ .name = "cache", .path = "tests/cache.zig" },
};

const metron_pkg = std.build.Pkg{
    .name = "metron",
    .path = .{ .path = "metron.zig" },
    .dependencies = &[_]std.build.Pkg{},
};

pub fn build(b: *std.build.Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    for (tests) |tc| {
        const exe = b.addExecutable(tc.name, tc.path);
        exe.setTarget(target);
        exe.setBuildMode(mode);
        exe.addPackage(metron_pkg);
        exe.install();
    }

    // unit tests for the library itself
    const exe_tests = b.addTest("metron.zig");
    exe_tests.setTarget(target);
    exe_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);
}
