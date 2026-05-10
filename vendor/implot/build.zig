const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Define the Zig module
    const lib_mod = b.addModule("root", .{
        .root_source_file = b.path("src/implot.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .link_libcpp = true,
    });

    // Create static library for ImPlot
    const lib = b.addLibrary(.{
        .name = "implot",
        .root_module = lib_mod,
        .linkage = .static,
    });

    // Include paths
    lib_mod.addIncludePath(b.path(".")); // ImPlot headers
    lib_mod.addIncludePath(b.path("../zgui/libs/imgui")); // ImGui headers

    const flags: []const []const u8 = &.{"-std=c++11"};
    lib_mod.addCSourceFile(.{ .file = b.path("implot.cpp"), .flags = flags });
    lib_mod.addCSourceFile(.{ .file = b.path("implot_items.cpp"), .flags = flags });
    lib_mod.addCSourceFile(.{ .file = b.path("implot_demo.cpp"), .flags = flags });
    lib_mod.addCSourceFile(.{ .file = b.path("src/implot_zig.cpp"), .flags = flags });

    // Install the artifact for dependencies
    b.installArtifact(lib);
}
