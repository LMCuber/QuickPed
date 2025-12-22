const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    _ = b.addModule("root", .{
        .root_source_file = b.path("src/imnodes.zig"),
    });

    // Create static library for imnodes
    const lib = b.addStaticLibrary(.{
        .name = "imnodes",
        .target = target,
        .optimize = optimize,
    });

    // Include paths
    lib.addIncludePath(b.path(".")); // imnodes headers
    lib.addIncludePath(b.path("../zgui/libs/imgui")); // ImGui headers from zgui

    // Compile the main ImNodes implementation
    lib.addCSourceFile(.{
        .file = b.path("imnodes.cpp"),
        .flags = &[_][]const u8{"-std=c++17"},
    });

    // Compile C ABI wrapper for Zig
    lib.addCSourceFile(.{
        .file = b.path("src/imnodes_zig.cpp"),
        .flags = &[_][]const u8{"-std=c++17"},
    });

    // Link standard C and C++ libraries
    lib.linkLibC();
    lib.linkLibCpp();

    // Make the library available for dependencies
    b.installArtifact(lib);
}
