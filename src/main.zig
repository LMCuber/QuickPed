// third-party
const std = @import("std");
const c = @cImport({
    @cDefine("NO_FONT_AWESOME", "1");
    @cInclude("rlImGui.h");
});
const rl = @import("raylib");
const zgui = @import("zgui");

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

    zgui.initNoContext(std.heap.c_allocator);
    defer zgui.deinitNoContext();

    // custom font
    const font = zgui.io.addFontFromFile("fonts/Cousine-Regular.ttf", 20);
    zgui.io.setDefaultFont(font);
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
        .target = .{ .x = @floatFromInt(-settings.tabWidth()), .y = 0 },
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
            rl.clearBackground(commons.arrToColor(sim_data.bg_color));

            {
                rl.beginMode2D(camera);
                defer rl.endMode2D();

                rl.drawRectangleLinesEx(rect, 4, commons.arrToColor(color.WHITE));

                for (agents.items) |*a| {
                    a.update(&agent_data);
                }
                for (agents.items) |*a| {
                    a.draw(&agent_data);
                }

                // Make sure to check that ImGui is not capturing the mouse inputs
                // before checking mouse inputs in Raylib!
                capture = zgui.io.getWantCaptureMouse();
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

            rl.drawFPS(settings.tabWidth() + 12, 12);

            // Draw ImGui
            {
                c.rlImGuiBegin();
                defer c.rlImGuiEnd();

                // var open = true;
                // zgui.setNextWindowCollapsed(.{ .collapsed = true, .cond = .first_use_ever });
                // zgui.showDemoWindow(&open);

                zgui.setNextWindowPos(.{ .x = 0, .y = 0 });
                zgui.setNextWindowSize(.{
                    .w = @floatFromInt(settings.tabWidth()),
                    .h = settings.height,
                });

                _ = zgui.begin("Settings", .{});
                defer zgui.end();
                if (zgui.collapsingHeader("Simulation", .{ .default_open = true })) {
                    _ = zgui.colorEdit3("bg", .{ .col = @ptrCast(&sim_data.bg_color) });
                    if (zgui.button("Recenter", .{})) {
                        camera = camera_default;
                    }
                }
                if (zgui.collapsingHeader("Agent", .{ .default_open = true })) {
                    zgui.separatorText("Lifetime");
                    // place N agents
                    _ = zgui.sliderInt("count", .{ .v = &agent_data.num_to_place, .min = 2, .max = 50 });
                    if (zgui.button("place", .{})) {
                        try agent.create(
                            &agents,
                            .{ .x = 100, .y = 100 },
                            agent_data.num_to_place,
                        );
                    }
                    zgui.sameLine(.{});
                    if (zgui.button("delete", .{})) {
                        // TODO: delete agents
                    }

                    zgui.separatorText("Properties");
                    _ = zgui.sliderInt("radius", .{ .v = &agent_data.radius, .min = 2, .max = 16 });
                }
            }
        }
    }
}
