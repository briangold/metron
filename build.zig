const std = @import("std");

const FileSource = std.build.FileSource;

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

const micros = [_]struct {
    name: []const u8,
    path: []const u8,
}{
    .{ .name = "fn", .path = "micros/fn.zig" },
    .{ .name = "mem", .path = "micros/mem.zig" },
};

pub fn build(b: *std.build.Builder) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const tour_step = b.step("tour", "Build a guided tour");

    const metron_mod = b.createModule(.{
        .source_file = .{ .path = "metron.zig" },
    });

    for (tour) |t| {
        const exe = b.addExecutable(.{
            .name = t.name,
            .root_source_file = .{ .path = t.path },
            .target = target,
            .optimize = optimize,
        });
        exe.addModule("metron", metron_mod);
        exe.install();

        tour_step.dependOn(&exe.step);
    }

    const micros_step = b.step("micros", "Build microbenchmarks");

    for (micros) |m| {
        const exe = b.addExecutable(.{
            .name = m.name,
            .root_source_file = .{ .path = m.path },
            .target = target,
            .optimize = optimize,
        });
        exe.addModule("metron", metron_mod);
        exe.install();

        micros_step.dependOn(&exe.step);
    }

    // unit tests for the library itself
    const exe_tests = b.addTest(.{
        .root_source_file = .{ .path = "metron.zig" },
        .target = target,
        .optimize = optimize,
    });

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);
}
