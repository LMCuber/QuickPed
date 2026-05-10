const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib_mod = b.addModule("root", .{
        .root_source_file = b.path("src/imnodesez.zig"),
        .optimize = optimize,
        .target = target,
        .link_libc = true,
        .link_libcpp = true,
    });

    // Create static library for imnodes
    const lib = b.addLibrary(.{
        .name = "imnodesez",
        .root_module = lib_mod,
        .linkage = .static,
    });

    // Include paths
    lib_mod.addIncludePath(b.path(".")); // imnodes headers
    lib_mod.addIncludePath(b.path("../zgui/libs/imgui")); // ImGui headers from zgui

    lib_mod.addCSourceFile(.{
        .file = b.path("ImNodes.cpp"),
        .flags = &[_][]const u8{"-std=c++11"},
    });
    lib_mod.addCSourceFile(.{
        .file = b.path("ImNodesEz.cpp"),
        .flags = &[_][]const u8{"-std=c++11"},
    });

    // Compile C ABI wrapper for Zig
    lib_mod.addCSourceFile(.{
        .file = b.path("src/imnodesez_zig.cpp"),
        .flags = &[_][]const u8{"-std=c++17"},
    });

    // Make the library available for dependencies
    b.installArtifact(lib);
}
