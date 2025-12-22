// third-party
const std = @import("std");
const c = @cImport({
    @cDefine("NO_FONT_AWESOME", "1");
    @cInclude("rlImGui.h");
});
const rl = @import("raylib");
const z = @import("zgui");

// namespaces
const commons = @import("commons.zig");
const color = @import("color.zig");
const settings = @import("settings.zig");

// classes
const Agent = @import("agent.zig");
const Contour = @import("contour.zig");

// data objects
const SimData = @import("sim_data.zig");
const AgentData = @import("agent_data.zig");

// main
pub fn main() !void {
    var sim_data = SimData.init();
    var agent_data = AgentData.init();

    rl.initWindow(
        settings.tabWidth + settings.width,
        settings.height,
        "Agent Based Model Simulation",
    );
    defer rl.closeWindow();
    rl.setTargetFPS(settings.fps_cap);

    c.rlImGuiSetup(true);
    defer c.rlImGuiShutdown();

    z.initNoContext(std.heap.c_allocator);
    defer z.deinitNoContext();

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
        .{ .x = 100, .y = 100 },
        .{ .x = 200, .y = 500 },
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

    // Main loop
    while (!rl.windowShouldClose()) {
        const rect: rl.Rectangle = .{
            .x = 0,
            .y = 0,
            .width = settings.width,
            .height = settings.height,
        };

        // Draw Raylib
        {
            rl.beginDrawing();
            defer rl.endDrawing();
            rl.clearBackground(color.BLACK);

            {
                rl.beginMode2D(camera);
                defer rl.endMode2D();

                rl.drawRectangle(rect.x, rect.y, rect.width, rect.height, color.arrToColor(sim_data.bg_color));
                rl.drawRectangleLinesEx(rect, 4, color.WHITE);

                for (agents.items) |*a| {
                    a.update();
                }
                for (agents.items) |*a| {
                    a.draw();
                }

                for (contours.items) |*con| {
                    con.update();
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

            rl.drawFPS(12, 12);
            // rl.drawText()

            // Draw ImGui
            {
                c.rlImGuiBegin();
                defer c.rlImGuiEnd();

                // var open = true;
                // z.setNextWindowCollapsed(.{ .collapsed = true, .cond = .first_use_ever });
                // z.showDemoWindow(&open);

                z.setNextWindowPos(.{ .x = @floatFromInt(settings.width), .y = 0 });
                z.setNextWindowSize(.{
                    .w = @floatFromInt(settings.tabWidth),
                    .h = settings.height,
                });

                _ = z.begin("Settings", .{});
                defer z.end();
                sim_data.show_stats(&camera, camera_default);
                try agent_data.show_stats(&agents, &contours);
            }
        }
    }
}
