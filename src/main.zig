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
        .{ .x = settings.width, .y = 0 },
        .{ .x = settings.width, .y = settings.height },
        .{ .x = 0, .y = settings.height },
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
                // rl.drawRectangleLinesEx(rect, 4, color.WHITE);

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

                if (z.beginTable("split", .{ .column = 2 })) {
                    defer z.endTable();

                    _ = z.tableNextColumn();
                    const fps: f32 = @floatFromInt(rl.getFPS());
                    const frametime: f32 = if (fps > 0) 1000.0 / fps else 0.0;
                    z.text("FPS: {d:.1} | {d:.3} ms frame", .{ fps, frametime });
                    sim_data.show_stats(&camera, camera_default);

                    _ = z.tableNextColumn();
                    try agent_data.show_stats(&agents, &contours);
                }

                // imnodes
                imnodes.beginNodeEditor();

                imnodes.beginNode(1);

                imnodes.beginNodeTitleBar();
                z.textUnformatted("Nodetext");
                imnodes.endNodeTitleBar();

                imnodes.beginInputAttribute(2);
                z.text("input", .{});
                imnodes.endInputAttribute();

                imnodes.beginOutputAttribute(3);
                z.indent(.{ .indent_w = 40 });
                z.text("output", .{});
                imnodes.endOutputAttribute();

                imnodes.endNode();

                imnodes.beginNode(2);

                imnodes.beginNodeTitleBar();
                z.textUnformatted("Nodetext");
                imnodes.endNodeTitleBar();

                imnodes.beginInputAttribute(4);
                z.text("input", .{});
                imnodes.endInputAttribute();

                imnodes.beginOutputAttribute(5);
                z.indent(.{ .indent_w = 40 });
                z.text("output", .{});
                imnodes.endOutputAttribute();

                imnodes.endNode();

                imnodes.link(6, 3, 4);

                imnodes.minimap();
                imnodes.endNodeEditor();
            }
        }
    }
}
