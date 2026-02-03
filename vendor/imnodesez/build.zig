const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    _ = b.addModule("root", .{
        .root_source_file = b.path("src/imnodesez.zig"),
    });

    // Create static library for imnodes
    const lib = b.addStaticLibrary(.{
        .name = "imnodesez",
        .target = target,
        .optimize = optimize,
    });

    // Include paths
    lib.addIncludePath(b.path(".")); // imnodes headers
    lib.addIncludePath(b.path("../zgui/libs/imgui")); // ImGui headers from zgui

    lib.addCSourceFile(.{
        .file = b.path("ImNodes.cpp"),
        .flags = &[_][]const u8{"-std=c++11"},
    });
    lib.addCSourceFile(.{
        .file = b.path("ImNodesEz.cpp"),
        .flags = &[_][]const u8{"-std=c++11"},
    });

    // Compile C ABI wrapper for Zig
    lib.addCSourceFile(.{
        .file = b.path("src/imnodesez_zig.cpp"),
        .flags = &[_][]const u8{"-std=c++17"},
    });

    // Link standard C and C++ libraries
    lib.linkLibC();
    lib.linkLibCpp();

    // Make the library available for dependencies
    b.installArtifact(lib);
}
