const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseSafe });

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libcpp = true,
    });
    const exe = b.addExecutable(.{
        .name = "quickped",
        .root_module = exe_mod,
    });

    const raylib_zig = b.dependency("raylib_zig", .{
        .target = target,
        .optimize = optimize,
    });
    const raylib = raylib_zig.module("raylib");
    const raylib_artifact = raylib_zig.artifact("raylib");
    exe_mod.linkLibrary(raylib_artifact);
    exe_mod.addImport("raylib", raylib);

    const zgui = b.dependency("zgui", .{
        .shared = false,
        .with_implot = false,
        .backend = .no_backend,
    });
    exe_mod.addImport("zgui", zgui.module("root"));
    exe_mod.linkLibrary(zgui.artifact("imgui"));
    exe_mod.addIncludePath(b.path("vendor/zgui/libs/imgui"));

    // implot ==============================================================
    const implot = b.dependency("implot", .{});
    exe_mod.addImport("implot", implot.module("root"));
    exe_mod.linkLibrary(implot.artifact("implot"));
    // =====================================================================

    // imnodesez ==============================================================
    const imnodesez = b.dependency("imnodesez", .{});
    exe_mod.addImport("imnodesez", imnodesez.module("root"));
    exe_mod.linkLibrary(imnodesez.artifact("imnodesez"));
    // =====================================================================

    const rlimgui = b.dependency("rlimgui", .{
        .target = target,
        .optimize = optimize,
    });
    exe_mod.addCSourceFile(.{
        .file = rlimgui.path("rlImGui.cpp"),
        .flags = &.{
            "-fno-sanitize=undefined",
            "-std=c++11",
            "-Wno-deprecated-declarations",
            "-DNO_FONT_AWESOME",
        },
    });
    exe_mod.addIncludePath(rlimgui.path("."));

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
