const std = @import("std");

const tour = [_]struct {
    name: []const u8,
    path: []const u8,
}{
    .{ .name = "empty", .path = "tour/empty.zig" },
    .{ .name = "fib", .path = "tour/fib.zig" },
    .{ .name = "roots", .path = "tour/roots.zig" },
    .{ .name = "bitset", .path = "tour/bitset.zig" },
    .{ .name = "memcpy", .path = "tour/memcpy.zig" },
    .{ .name = "threads", .path = "tour/threads.zig" },
    .{ .name = "cache", .path = "tour/cache.zig" },
};

const metron_pkg = std.build.Pkg{
    .name = "metron",
    .path = .{ .path = "metron.zig" },
    .dependencies = &[_]std.build.Pkg{},
};

pub fn build(b: *std.build.Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const tour_step = b.step("tour", "Build a guided tour");

    for (tour) |t| {
        const exe = b.addExecutable(t.name, t.path);
        exe.setTarget(target);
        exe.setBuildMode(mode);
        exe.addPackage(metron_pkg);

        const install_exe = b.addInstallArtifact(exe);
        tour_step.dependOn(&install_exe.step);
    }

    // unit tests for the library itself
    const exe_tests = b.addTest("metron.zig");
    exe_tests.setTarget(target);
    exe_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);
}
