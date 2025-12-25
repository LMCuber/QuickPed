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

// environment
const Entity = @import("environment/entity.zig").Entity;
const Agent = @import("agent.zig");
const Contour = @import("environment/contour.zig");
const Spawner = @import("environment/spawner.zig");

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
    defer agents.deinit();
    var entities = std.ArrayList(Entity).init(allocator);
    defer entities.deinit();

    var current_entity: ?*Entity = null;
    var entity_storage: Entity = undefined;

    // specific entities
    var contours = std.ArrayList(Contour).init(allocator);
    defer contours.deinit();
    var spawners = std.ArrayList(Spawner).init(allocator);
    defer spawners.deinit();

    // camera shenanigans
    const camera_default = rl.Camera2D{
        .target = .{ .x = 0, .y = 0 },
        .offset = .{ .x = 0, .y = 0 },
        .rotation = 0.0,
        .zoom = 1.0,
    };
    var camera = camera_default;
    commons.camera = &camera;
    var prev_mouse_position = commons.mousePos();
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
            rl.clearBackground(color.black);

            {
                rl.beginMode2D(camera);
                defer rl.endMode2D();

                rl.drawRectangleRec(sim_rect, color.arrToColor(sim_data.bg_color));
                renderGrid();

                // update and render the agents
                if (!sim_data.paused) {
                    for (agents.items) |*a| {
                        a.update();
                    }
                }
                for (agents.items) |*a| {
                    a.draw();
                }

                // update and render the environmental entities, including the selected one
                if (current_entity) |ce| {
                    ce.update(sim_data);
                    ce.draw();
                }
                for (entities.items) |*ent| {
                    ent.update(sim_data);
                    ent.draw();
                }

                // Make sure to check that ImGui is not capturing the mouse inputs
                // before checking mouse inputs in Raylib!
                capture = z.io.getWantCaptureMouse();
                if (!capture) {
                    const mouse_position = commons.mousePos();
                    defer prev_mouse_position = mouse_position;

                    const zoom_delta = rl.getMouseWheelMove() * 0.01;
                    if (zoom_delta > 0 or (zoom_delta < 0 and camera.zoom > 0.05))
                        camera.zoom += zoom_delta;
                    if (rl.isMouseButtonDown(rl.MouseButton.mouse_button_left)) {
                        const delta_x = mouse_position.x - prev_mouse_position.x;
                        const delta_y = mouse_position.y - prev_mouse_position.y;
                        camera.target = .{
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
                            entity_storage = try Entity.initContour(gpa.allocator());
                            current_entity = &entity_storage;
                        }
                        z.sameLine(.{});
                        if (z.button("Contour", .{})) {
                            std.debug.print("contour!", .{});
                        }

                        // var current_item: i32 = 0;
                        // var buf: [256]u8 = undefined;
                        // for (entities.items) |*ent| {
                        //     switch (ent.*) {
                        //         inline else => |inner| {
                        //             _ = try std.fmt.bufPrint(&buf, "{s}", .{inner.getName()});
                        //         },
                        //     }
                        // }
                        // _ = z.combo("name", .{ .current_item = &current_item, .items_separated_by_zeros = "Contour\x00Spawner" });
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
    const num_blocks = @divTrunc(settings.sim_width, sim_data.grid_size);
    for (0..@as(usize, @intCast(num_blocks))) |i| {
        const i_i32: i32 = @intCast(i);
        const grid_pos = i_i32 * sim_data.grid_size;
        rl.drawLine(
            0,
            grid_pos,
            settings.sim_width,
            grid_pos,
            color.navy,
        );
        rl.drawLine(
            grid_pos,
            0,
            grid_pos,
            settings.sim_height,
            color.navy,
        );
    }
}
