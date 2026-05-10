const std = @import("std");

pub const Backend = enum {
    no_backend,
    glfw_wgpu,
    glfw_opengl3,
    glfw_dx12,
    win32_dx12,
    glfw,
};

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const options = .{
        .backend = b.option(Backend, "backend", "Backend to build (default: no_backend)") orelse .no_backend,
        .shared = b.option(
            bool,
            "shared",
            "Bulid as a shared library",
        ) orelse false,
        .with_implot = b.option(
            bool,
            "with_implot",
            "Build with bundled implot source",
        ) orelse true,
        .with_te = b.option(
            bool,
            "with_te",
            "Build with bundled test engine support",
        ) orelse false,
        .use_wchar32 = b.option(
            bool,
            "use_wchar32",
            "Extended unicode support",
        ) orelse false,
    };

    const options_step = b.addOptions();
    inline for (std.meta.fields(@TypeOf(options))) |field| {
        options_step.addOption(field.type, field.name, @field(options, field.name));
    }

    const options_module = options_step.createModule();

    const lib_mod = b.addModule("root", .{
        .root_source_file = b.path("src/gui.zig"),
        .imports = &.{
            .{ .name = "zgui_options", .module = options_module },
        },
        .link_libc = true,
        .link_libcpp = target.result.abi != .msvc,
        .target = target,
        .optimize = optimize,
    });

    const cflags = &.{ "-fno-sanitize=undefined", "-Wno-elaborated-enum-base" };

    const translate = b.addTranslateC(.{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("src/zgui.cpp"),
    });

    const imgui = if (options.shared) blk: {
        const lib = b.addLibrary(.{
            .name = "imgui",
            .root_module = lib_mod,
            .linkage = .static,
        });

        if (target.result.os.tag == .windows) {
            translate.defineCMacro("IMGUI_API", "__declspec(dllexport)");
            translate.defineCMacro("IMPLOT_API", "__declspec(dllexport)");
            translate.defineCMacro("ZGUI_API", "__declspec(dllexport)");
        }

        if (target.result.os.tag == .macos) {
            lib.linker_allow_shlib_undefined = true;
        }

        break :blk lib;
    } else b.addLibrary(.{
        .name = "imgui",
        .root_module = lib_mod,
        .linkage = .static,
    });

    b.installArtifact(imgui);

    lib_mod.addIncludePath(b.path("libs"));
    lib_mod.addIncludePath(b.path("libs/imgui"));

    lib_mod.addCSourceFile(.{
        .file = b.path("src/zgui.cpp"),
        .flags = cflags,
    });

    lib_mod.addCSourceFiles(.{
        .files = &.{
            "libs/imgui/imgui.cpp",
            "libs/imgui/imgui_widgets.cpp",
            "libs/imgui/imgui_tables.cpp",
            "libs/imgui/imgui_draw.cpp",
            "libs/imgui/imgui_demo.cpp",
        },
        .flags = cflags,
    });
    if (options.with_implot) {
        translate.defineCMacro("ZGUI_IMPLOT", "1");
        lib_mod.addCSourceFiles(.{
            .files = &.{
                "libs/imgui/implot_demo.cpp",
                "libs/imgui/implot.cpp",
                "libs/imgui/implot_items.cpp",
            },
            .flags = cflags,
        });
    } else {
        translate.defineCMacro("ZGUI_IMPLOT", "0");
    }

    if (options.use_wchar32) {
        translate.defineCMacro("IMGUI_USE_WCHAR32", "1");
    }

    if (options.with_te) {
        translate.defineCMacro("ZGUI_TE", "1");

        translate.defineCMacro("IMGUI_ENABLE_TEST_ENGINE", null);
        translate.defineCMacro("IMGUI_TEST_ENGINE_ENABLE_COROUTINE_STDTHREAD_IMPL", "1");

        lib_mod.addIncludePath(b.path("libs/imgui_test_engine/"));

        lib_mod.addCSourceFile(.{ .file = b.path("libs/imgui_test_engine/imgui_capture_tool.cpp"), .flags = cflags });
        lib_mod.addCSourceFile(.{ .file = b.path("libs/imgui_test_engine/imgui_te_context.cpp"), .flags = cflags });
        lib_mod.addCSourceFile(.{ .file = b.path("libs/imgui_test_engine/imgui_te_coroutine.cpp"), .flags = cflags });
        lib_mod.addCSourceFile(.{ .file = b.path("libs/imgui_test_engine/imgui_te_engine.cpp"), .flags = cflags });
        lib_mod.addCSourceFile(.{ .file = b.path("libs/imgui_test_engine/imgui_te_exporters.cpp"), .flags = cflags });
        lib_mod.addCSourceFile(.{ .file = b.path("libs/imgui_test_engine/imgui_te_perftool.cpp"), .flags = cflags });
        lib_mod.addCSourceFile(.{ .file = b.path("libs/imgui_test_engine/imgui_te_ui.cpp"), .flags = cflags });
        lib_mod.addCSourceFile(.{ .file = b.path("libs/imgui_test_engine/imgui_te_utils.cpp"), .flags = cflags });

        // TODO: Workaround because zig on win64 doesn have phtreads
        // TODO: Implement corutine in zig can solve this
        if (target.result.os.tag == .windows) {
            const src: []const []const u8 = &.{
                "libs/winpthreads/src/nanosleep.c",
                "libs/winpthreads/src/cond.c",
                "libs/winpthreads/src/barrier.c",
                "libs/winpthreads/src/misc.c",
                "libs/winpthreads/src/clock.c",
                "libs/winpthreads/src/libgcc/dll_math.c",
                "libs/winpthreads/src/spinlock.c",
                "libs/winpthreads/src/thread.c",
                "libs/winpthreads/src/mutex.c",
                "libs/winpthreads/src/sem.c",
                "libs/winpthreads/src/sched.c",
                "libs/winpthreads/src/ref.c",
                "libs/winpthreads/src/rwlock.c",
            };

            const winpthreads_mod = b.createModule(.{
                .optimize = optimize,
                .target = target,
                .link_libc = true,
            });
            const winpthreads = b.addLibrary(.{
                .name = "winpthreads",
                .root_module = winpthreads_mod,
            });
            winpthreads_mod.sanitize_c = .full;
            if (optimize == .Debug or optimize == .ReleaseSafe)
                winpthreads.bundle_compiler_rt = true
            else
                winpthreads.root_module.strip = true;
            winpthreads_mod.addCSourceFiles(.{
                .files = src,
                .flags = &.{
                    "-Wall",
                    "-Wextra",
                },
            });
            translate.defineCMacro("__USE_MINGW_ANSI_STDIO", "1");
            winpthreads_mod.addIncludePath(b.path("libs/winpthreads/include"));
            winpthreads_mod.addIncludePath(b.path("libs/winpthreads/src"));
            b.installArtifact(winpthreads);
            winpthreads_mod.linkLibrary(winpthreads);
            winpthreads_mod.addSystemIncludePath(b.path("libs/winpthreads/include"));
        }
    } else {
        translate.defineCMacro("ZGUI_TE", "0");
    }

    switch (options.backend) {
        .glfw_wgpu => {
            const zglfw = b.dependency("zglfw", .{});
            const zgpu = b.dependency("zgpu", .{});
            lib_mod.addIncludePath(zglfw.path("libs/glfw/include"));
            lib_mod.addIncludePath(zgpu.path("libs/dawn/include"));
            lib_mod.addCSourceFiles(.{
                .files = &.{
                    "libs/imgui/backends/imgui_impl_glfw.cpp",
                    "libs/imgui/backends/imgui_impl_wgpu.cpp",
                },
                .flags = cflags,
            });
        },
        .glfw_opengl3 => {
            const zglfw = b.dependency("zglfw", .{});
            lib_mod.addIncludePath(zglfw.path("libs/glfw/include"));
            lib_mod.addCSourceFiles(.{
                .files = &.{
                    "libs/imgui/backends/imgui_impl_glfw.cpp",
                    "libs/imgui/backends/imgui_impl_opengl3.cpp",
                },
                .flags = &(cflags.* ++ .{"-DIMGUI_IMPL_OPENGL_LOADER_CUSTOM"}),
            });
        },
        .glfw_dx12 => {
            const zglfw = b.dependency("zglfw", .{});
            lib_mod.addIncludePath(zglfw.path("libs/glfw/include"));
            lib_mod.addCSourceFiles(.{
                .files = &.{
                    "libs/imgui/backends/imgui_impl_glfw.cpp",
                    "libs/imgui/backends/imgui_impl_dx12.cpp",
                },
                .flags = cflags,
            });
            lib_mod.linkSystemLibrary("d3dcompiler_47", .{});
        },
        .win32_dx12 => {
            lib_mod.addCSourceFiles(.{
                .files = &.{
                    "libs/imgui/backends/imgui_impl_win32.cpp",
                    "libs/imgui/backends/imgui_impl_dx12.cpp",
                },
                .flags = cflags,
            });
            lib_mod.linkSystemLibrary("d3dcompiler_47", .{});
            lib_mod.linkSystemLibrary("dwmapi", .{});
            switch (target.result.abi) {
                .msvc => lib_mod.linkSystemLibrary("Gdi32", .{}),
                .gnu => lib_mod.linkSystemLibrary("gdi32", .{}),
                else => {},
            }
        },
        .glfw => {
            const zglfw = b.dependency("zglfw", .{});
            lib_mod.addIncludePath(zglfw.path("libs/glfw/include"));
            lib_mod.addCSourceFiles(.{
                .files = &.{
                    "libs/imgui/backends/imgui_impl_glfw.cpp",
                },
                .flags = cflags,
            });
        },
        .no_backend => {},
    }

    // if (target.result.os.tag == .macos) {
    //     const system_sdk = b.dependency("system_sdk", .{});
    //     imgui.addSystemIncludePath(system_sdk.path("macos12/usr/include"));
    //     imgui.addFrameworkPath(system_sdk.path("macos12/System/Library/Frameworks"));
    // }

    const test_step = b.step("test", "Run zgui tests");

    const tests_mod = b.createModule(.{
        .root_source_file = b.path("src/gui.zig"),
        .target = target,
        .optimize = optimize,
    });

    const tests = b.addTest(.{
        .name = "zgui-tests",
        .root_module = tests_mod,
    });

    b.installArtifact(tests);

    tests_mod.addImport("zgui_options", options_module);
    tests_mod.linkLibrary(imgui);

    test_step.dependOn(&b.addRunArtifact(tests).step);
}
