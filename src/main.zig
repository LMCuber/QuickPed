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
const color = @import("color.zig").Color;
const agent = @import("agent.zig");

// classes

// objects
const settings = @import("settings.zig").Settings{};
var sim_data = @import("sim_data.zig").SimData{};
var agent_data = @import("agent_data.zig").AgentData{};

// main
pub fn main() !void {
    rl.initWindow(
        settings.tabWidth() + settings.width,
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
    const font = z.io.addFontFromFile("fonts/Cousine-Regular.ttf", 20);
    z.io.setDefaultFont(font);
    c.rlImGuiReloadFonts();

    // seeding
    rl.setRandomSeed(123);

    // agents
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    var agents = std.ArrayList(agent.Agent).init(allocator);
    defer agents.deinit();

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
        const rect = rl.Rectangle{
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

            // Draw ImGui
            {
                c.rlImGuiBegin();
                defer c.rlImGuiEnd();

                // var open = true;
                // z.setNextWindowCollapsed(.{ .collapsed = true, .cond = .first_use_ever });
                // z.showDemoWindow(&open);

                z.setNextWindowPos(.{ .x = @floatFromInt(settings.width), .y = 0 });
                z.setNextWindowSize(.{
                    .w = @floatFromInt(settings.tabWidth()),
                    .h = settings.height,
                });

                _ = z.begin("Settings", .{});
                defer z.end();
                if (z.collapsingHeader("Simulation", .{ .default_open = true })) {
                    _ = z.colorEdit3("bg", .{ .col = @ptrCast(&sim_data.bg_color) });
                    if (z.button("Recenter", .{})) {
                        camera = camera_default;
                    }
                }
                if (z.collapsingHeader("Agent", .{ .default_open = true })) {
                    z.separatorText("Lifetime");
                    // place N agents
                    _ = z.sliderInt("count", .{ .v = &agent_data.num_to_place, .min = 1, .max = 50 });
                    if (z.button("place", .{})) {
                        try agent.create(
                            &agents,
                            &agent_data,
                            agent_data.num_to_place,
                        );
                    }
                    z.sameLine(.{});
                    if (z.button("delete", .{})) {
                        agent.delete(
                            &agents,
                            agent_data.num_to_place,
                        );
                    }

                    z.separatorText("Properties");
                    _ = z.sliderFloat("speed", .{ .v = &agent_data.speed, .min = 0.1, .max = 5.0 });
                    _ = z.sliderFloat("tau", .{ .v = &agent_data.relaxation, .min = 10, .max = 50 });
                    _ = z.sliderFloat("repuls.", .{ .v = &agent_data.a_ped, .min = 0.01, .max = 0.1 });
                    _ = z.sliderFloat("range", .{ .v = &agent_data.b_ped, .min = 1, .max = 10 });
                    _ = z.sliderInt("radius", .{ .v = &agent_data.radius, .min = 2, .max = 16 });
                    _ = z.checkbox("show vectors", .{ .v = &agent_data.show_vectors });
                }
            }
        }
    }
}
