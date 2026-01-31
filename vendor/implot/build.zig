const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Define the Zig module
    _ = b.addModule("root", .{
        .root_source_file = b.path("src/implot.zig"),
    });

    // Create static library for ImPlot
    const lib = b.addStaticLibrary(.{
        .name = "implot",
        .target = target,
        .optimize = optimize,
    });

    // Include paths
    lib.addIncludePath(b.path(".")); // ImPlot headers
    lib.addIncludePath(b.path("../zgui/libs/imgui")); // ImGui headers

    // Compile all C++ source files
    lib.addCSourceFile(.{
        .file = b.path("implot.cpp"),
        .flags = &[_][]const u8{"-std=c++11"},
    });
    lib.addCSourceFile(.{
        .file = b.path("implot_items.cpp"),
        .flags = &[_][]const u8{"-std=c++11"},
    });
    lib.addCSourceFile(.{
        .file = b.path("implot_demo.cpp"),
        .flags = &[_][]const u8{"-std=c++11"},
    });

    // Compile the C ABI wrapper for Zig
    lib.addCSourceFile(.{
        .file = b.path("src/implot_zig.cpp"),
        .flags = &[_][]const u8{"-std=c++11"},
    });

    // Link standard C and C++ libraries
    lib.linkLibC();
    lib.linkLibCpp();

    // Install the artifact for dependencies
    b.installArtifact(lib);
}
