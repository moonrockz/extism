//! Builds the Extism kernel and runs its tests.
//!
//! - `zig build` writes `zig-out/bin/kernel.wasm`, a `wasm32-freestanding` module for the CPU
//!   `mvp+mutable_globals+sign_ext`, so that the kernel needs no WASM feature that an engine might lack.
//! - `zig build test` runs the Zig tests of the kernel on the host.

const std = @import("std");

/// The 20 upstream kernel functions, the only exports besides `memory`.
const exports = [_][]const u8{
    "alloc",         "free",          "length",         "length_unsafe", "load_u8",
    "load_u64",      "input_load_u8", "input_load_u64", "store_u8",      "store_u64",
    "input_set",     "output_set",    "input_length",   "input_offset",  "output_length",
    "output_offset", "reset",         "error_set",      "error_get",     "memory_bytes",
};

pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding,
        .cpu_model = .{ .explicit = &std.Target.wasm.cpu.mvp },
        .cpu_features_add = std.Target.wasm.featureSet(&.{ .mutable_globals, .sign_ext }),
    });
    const kernel = b.addExecutable(.{
        .name = "kernel",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/wasm.zig"),
            .target = target,
            .optimize = .ReleaseSmall,
            .strip = true,
            .single_threaded = true,
        }),
    });
    kernel.entry = .disabled;
    kernel.root_module.export_symbol_names = &exports;
    // Sixteen initial pages, as the upstream kernel, so that the bounds checks against the memory size give
    // the same results. The kernel keeps no data and no stack in its memory.
    kernel.initial_memory = 16 * 65536;
    kernel.stack_size = 0;
    b.installArtifact(kernel);

    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/tests.zig"),
            .target = b.graph.host,
        }),
    });
    const run_tests = b.addRunArtifact(tests);
    b.step("test", "Run the kernel tests").dependOn(&run_tests.step);
}
