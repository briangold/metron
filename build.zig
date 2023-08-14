const std = @import("std");

const FileSource = std.build.FileSource;

// A "tour" of features in Metron -- see tour/README.md
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

// Selected microbenchmarks
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
        b.installArtifact(exe);
    }

    for (micros) |m| {
        const exe = b.addExecutable(.{
            .name = m.name,
            .root_source_file = .{ .path = m.path },
            .target = target,
            .optimize = optimize,
        });
        exe.addModule("metron", metron_mod);
        b.installArtifact(exe);
    }

    // unit tests for the library itself
    const unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "metron.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
