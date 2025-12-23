// third-party
const std = @import("std");
const c = @cImport({
    @cDefine("NO_FONT_AWESOME", "1");
    @cInclude("rlImGui.h");
});
const rl = @import("raylib");
const z = @import("zgui");
const imnodes = @import("imnodes");

// namespaces
const commons = @import("commons.zig");
const color = @import("color.zig");

// classes
const Agent = @import("agent.zig");
const Contour = @import("contour.zig");

// data objects
const Settings = @import("settings.zig");
const SimData = @import("sim_data.zig");
const AgentData = @import("agent_data.zig");
const NodeEditor = @import("node_editor.zig");

const settings = Settings.init();
var sim_data = SimData.init();
var agent_data = AgentData.init();
var node_editor = NodeEditor.init();

// main
pub fn main() !void {
    rl.initWindow(
        settings.width,
        settings.height,
        "QuickPed",
    );

    defer rl.closeWindow();
    rl.setTargetFPS(settings.fps_cap);

    c.rlImGuiSetup(true);
    defer c.rlImGuiShutdown();

    z.initNoContext(std.heap.c_allocator);
    defer z.deinitNoContext();

    imnodes.createContext();
    defer imnodes.destroyContext();

    // custom font
    const font = z.io.addFontFromFile("fonts/DroidSans.ttf", 20);
    z.io.setDefaultFont(font);
    c.rlImGuiReloadFonts();

    // seeding
    rl.setRandomSeed(123);

    // entities for the simulation
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    var agents = std.ArrayList(Agent).init(allocator);
    var contours = std.ArrayList(Contour).init(allocator);
    defer agents.deinit();
    defer contours.deinit();

    const _c = Contour.init(&[_]rl.Vector2{
        .{ .x = 0, .y = 0 },
        .{ .x = @floatFromInt(settings.sim_width), .y = 0 },
        .{ .x = @floatFromInt(settings.sim_width), .y = @floatFromInt(settings.sim_height) },
        .{ .x = 0, .y = @floatFromInt(settings.sim_height) },
        .{ .x = 500, .y = 208 },
        .{ .x = 30, .y = 730 },
    });

    try contours.append(_c);

    const camera_default = rl.Camera2D{
        .target = .{ .x = 0, .y = 0 },
        .offset = .{ .x = 0, .y = 0 },
        .rotation = 0.0,
        .zoom = 1.0,
    };

    var camera = camera_default;

    var prev_mouse_position = rl.getMousePosition();
    var capture = false;

    const sim_rect: rl.Rectangle = .{
        .x = 0,
        .y = 0,
        .width = @floatFromInt(settings.sim_width),
        .height = @floatFromInt(settings.sim_height),
    };

    // Main loop
    while (!rl.windowShouldClose()) {
        // Draw Raylib
        {
            rl.beginDrawing();
            defer rl.endDrawing();
            rl.clearBackground(color.BLACK);

            {
                rl.beginMode2D(camera);
                defer rl.endMode2D();

                rl.drawRectangleRec(sim_rect, color.arrToColor(sim_data.bg_color));
                rl.drawRectangleLinesEx(sim_rect, 4, color.WHITE);
                renderGrid();

                if (!sim_data.paused) {
                    for (agents.items) |*a| {
                        a.update();
                    }
                }
                for (agents.items) |*a| {
                    a.draw();
                }
                for (contours.items) |*con| {
                    con.draw();
                }

                // Make sure to check that ImGui is not capturing the mouse inputs
                // before checking mouse inputs in Raylib!
                capture = z.io.getWantCaptureMouse();
                if (!capture) {
                    const mouse_position = rl.getMousePosition();
                    defer prev_mouse_position = mouse_position;

                    const zoom_delta = rl.getMouseWheelMove() * 0.01;
                    if (zoom_delta > 0 or (zoom_delta < 0 and camera.zoom > 0.05))
                        camera.zoom += zoom_delta;
                    if (rl.isMouseButtonDown(rl.MouseButton.mouse_button_left)) {
                        const delta_x = mouse_position.x - prev_mouse_position.x;
                        const delta_y = mouse_position.y - prev_mouse_position.y;
                        camera.target = rl.Vector2{
                            .x = camera.target.x - delta_x,
                            .y = camera.target.y - delta_y,
                        };
                    }
                }
            }

            // draw ImGui
            {
                c.rlImGuiBegin();
                defer c.rlImGuiEnd();

                z.setNextWindowPos(.{ .x = @floatFromInt(settings.width - settings.tab_width), .y = 0 });
                z.setNextWindowSize(.{
                    .w = @floatFromInt(settings.tab_width),
                    .h = @floatFromInt(settings.height),
                });

                // draw all options (except node editor)
                {
                    _ = z.begin("Settings", .{});
                    defer z.end();

                    const fps: f32 = @floatFromInt(rl.getFPS());
                    const frametime: f32 = if (fps > 0) 1000.0 / fps else 0.0;
                    z.text("FPS: {d:.1} | {d:.3} ms frame", .{ fps, frametime });
                    sim_data.render(&camera, camera_default);

                    try agent_data.render(&agents, &contours);

                    // draw environment items to render
                    if (z.collapsingHeader("Environment", .{ .default_open = true })) {
                        if (z.button("Spawner", .{})) {
                            std.debug.print("ASDASD", .{});
                        }
                    }
                }

                // draw node editor
                {
                    z.setNextWindowPos(.{ .x = 0, .y = 0 });
                    z.setNextWindowSize(.{
                        .w = @floatFromInt(settings.width),
                        .h = @floatFromInt(settings.height),
                    });

                    node_editor.render();
                }
            }
        }
    }
}

pub fn renderGrid() void {
    const num_blocks: i32 = 40;
    const offset: i32 = settings.sim_height / num_blocks;
    for (0..num_blocks) |i| {
        rl.drawLine(
            0,
            @intCast(i * offset),
            settings.sim_width,
            @intCast(i * offset),
            color.NAVY,
        );
        rl.drawLine(
            @intCast(i * offset),
            0,
            @intCast(i * offset),
            settings.sim_height,
            color.NAVY,
        );
    }
}
