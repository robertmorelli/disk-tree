const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    // Default to ReleaseFast for better performance with large queries
    // ReleaseFast prioritizes runtime speed over binary size and safety checks
    // This is essential for handling large disk/query datasets efficiently
    const optimize = b.standardOptimizeOption(.{
        .preferred_optimize_mode = .ReleaseFast,
    });

    // Library
    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "disk_stabbing",
        .root_module = b.createModule(.{
            .root_source_file = b.path("disk_stabbing.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(lib);

    // Tests
    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("disk_stabbing.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_tests.step);

    // Benchmark executable
    const bench = b.addExecutable(.{
        .name = "benchmark",
        .root_module = b.createModule(.{
            .root_source_file = b.path("benchmark.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(bench);

    const run_bench = b.addRunArtifact(bench);
    const bench_step = b.step("bench", "Run benchmark");
    bench_step.dependOn(&run_bench.step);

    // Stress tests executable
    const stress = b.addExecutable(.{
        .name = "stress_tests",
        .root_module = b.createModule(.{
            .root_source_file = b.path("stress_tests.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(stress);

    // Correctness tests executable
    const correctness = b.addExecutable(.{
        .name = "correctness_tests",
        .root_module = b.createModule(.{
            .root_source_file = b.path("correctness_tests.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(correctness);

    // Debug test executable
    const debug_test = b.addExecutable(.{
        .name = "debug_test",
        .root_module = b.createModule(.{
            .root_source_file = b.path("debug_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(debug_test);

    // Complexity check executable
    const complexity = b.addExecutable(.{
        .name = "complexity_check_simple",
        .root_module = b.createModule(.{
            .root_source_file = b.path("complexity_check_simple.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(complexity);

    // 100k benchmark executable
    const bench_100k = b.addExecutable(.{
        .name = "benchmark_100k",
        .root_module = b.createModule(.{
            .root_source_file = b.path("benchmark_100k.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(bench_100k);

    const run_bench_100k = b.addRunArtifact(bench_100k);
    const bench_100k_step = b.step("bench100k", "Run 100k circles benchmark");
    bench_100k_step.dependOn(&run_bench_100k.step);
}
