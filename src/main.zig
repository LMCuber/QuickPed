// third-party
const std = @import("std");
const c = @cImport({
    @cDefine("NO_FONT_AWESOME", "1");
    @cInclude("rlImGui.h");
});
const rl = @import("raylib");
const z = @import("zgui");
const implot = @import("implot");
const imnodes = @import("imnodesez");

// namespaces
const commons = @import("commons.zig");
const color = @import("color.zig");
const palette = @import("palette.zig");

// environment
const Environment = @import("environment/Environment.zig");
const entity = @import("environment/entity.zig");
const Agent = @import("Agent.zig");
const Contour = @import("environment/Contour.zig");
const Spawner = @import("environment/Spawner.zig");
const Area = @import("environment/Area.zig");
const Revolver = @import("environment/Revolver.zig");

// data objects
const Settings = @import("Settings.zig");
const SimData = @import("editor/SimData.zig");
const AgentData = @import("editor/AgentData.zig");
const EB = @import("editor/EnvironmentButtons.zig");
const Stats = @import("editor/Stats.zig");
const NodeEditor = @import("nodes/NodeEditor.zig");

const settings = Settings.init();
var sim_data = SimData.init();
var agent_data = AgentData.init();

var ctx: ?*imnodes.ez.Context = null;

const SceneSnapshot = struct {
    version: []const u8,
    entities: []const entity.EntitySnapshot,
    next_id: i32,
    next_contour_id: i32,
    next_spawner_id: i32,
    next_area_id: i32,
};

// main
pub fn main() !void {
    rl.setConfigFlags(.{ .vsync_hint = true });
    rl.initWindow(
        settings.width,
        settings.height,
        "QuickPed",
    );

    defer rl.closeWindow();
    rl.setTargetFPS(rl.getMonitorRefreshRate(0));

    c.rlImGuiSetup(true);
    defer c.rlImGuiShutdown();

    // initialize contexts for the imgui libraries
    z.initNoContext(std.heap.c_allocator);
    defer z.deinitNoContext();

    implot.createContext();
    defer implot.destroyContext();

    ctx = imnodes.ez.createContext().?;
    imnodes.ez.setContext(ctx.?);
    defer imnodes.ez.freeContext(ctx.?);

    // custom font
    const mono_font: bool = false;
    if (mono_font) {
        imnodes.setZoom(imnodes.ez.getState(), 1.4);
    } else {
        const font = z.io.addFontFromFile("fonts/DroidSans.ttf", 20);
        z.io.setDefaultFont(font);
        c.rlImGuiReloadFonts();
    }

    // seeding
    rl.setRandomSeed(123);

    // entities for the simulation
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    var agents = std.ArrayList(Agent).init(allocator);
    defer agents.deinit();

    // environmental objects
    var env: Environment = Environment.init(allocator);
    var current_entity: ?entity.Entity = null;

    // allocated editor objects
    var stats = Stats.init(allocator);
    defer stats.deinit();
    var node_editor = NodeEditor.init(allocator);
    defer node_editor.deinit();

    try loadScene(
        allocator,
        "scene.json",
        &env,
    );

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
        {
            const dt: f32 = rl.getFrameTime();
            rl.beginDrawing();
            defer rl.endDrawing();
            rl.clearBackground(color.black);

            // UPDATING =============================================
            var confirm_current: bool = false;
            {
                // set popup attribute of current entity
                if (current_entity) |ent| {
                    if (ent.kind == .area) {}
                }

                // update all placed entities
                for (env.entities.items) |*ent| {
                    _ = try ent.update(dt, sim_data, settings);
                }

                // update selected entity
                if (current_entity) |*ent| {
                    const action = try ent.update(dt, sim_data, settings);
                    switch (action) {
                        .cancelled, .none => {},
                        .placed => {
                            try env.entities.append(ent.*);
                            const stored_entity_ptr = &env.entities.items[env.entities.items.len - 1];

                            switch (stored_entity_ptr.kind) {
                                .contour => try env.contours.append(&stored_entity_ptr.kind.contour),
                                .spawner => try env.spawners.append(&stored_entity_ptr.kind.spawner),
                                .area => try env.areas.append(&stored_entity_ptr.kind.area),
                                .revolver => try env.revolvers.append(&stored_entity_ptr.kind.revolver),
                            }

                            current_entity = null;
                        },
                        .confirm => confirm_current = true,
                    }
                }

                // update the agents
                if (!sim_data.paused) {
                    for (agents.items) |*agent| {
                        agent.update(&agents, &env, agent_data);
                    }
                    // cleanup to be deleted agents
                    var i: usize = agents.items.len;
                    while (i > 0) {
                        i -= 1;
                        if (agents.items[i].marked) {
                            _ = agents.swapRemove(i);
                        }
                    }
                }

                // Make sure to check that ImGui is not capturing the mouse inputs
                // before checking mouse inputs in Raylib!
                capture = z.io.getWantCaptureMouse();
                capture = z.io.getWantCaptureMouse();
                capture = z.io.getWantCaptureMouse();
            }

            // DRAWING =============================================
            {
                rl.beginMode2D(camera);
                defer rl.endMode2D();

                rl.drawRectangleRec(sim_rect, palette.env.black);
                renderGrid();

                if (!capture) {
                    const mouse_position: rl.Vector2 = rl.getMousePosition();
                    const zoom_delta = rl.getMouseWheelMove() * 0.01;
                    if (zoom_delta > 0 or (zoom_delta < 0 and camera.zoom > 0.05))
                        camera.zoom += zoom_delta;
                    if (rl.isMouseButtonDown(.mouse_button_left)) {
                        const delta_x = mouse_position.x - prev_mouse_position.x;
                        const delta_y = mouse_position.y - prev_mouse_position.y;
                        camera.target = .{
                            .x = camera.target.x - delta_x,
                            .y = camera.target.y - delta_y,
                        };
                    }
                    prev_mouse_position = mouse_position;
                }

                // render all the entities
                for (env.entities.items) |*ent| {
                    ent.draw();
                }

                // render the in-progress selected entity
                if (current_entity) |*ent| {
                    ent.draw();
                }

                // render all pedestrians
                for (agents.items) |*agent| {
                    agent.draw(agent_data);
                }
            }

            // IMGUI
            {
                c.rlImGuiBegin();
                defer c.rlImGuiEnd();

                // draw all options (except node editor)
                {
                    z.setNextWindowPos(.{
                        .x = @floatFromInt(settings.width - settings.tab_width),
                        .y = z.calcTextSize("Node editor", .{})[1] + 5,
                    });
                    z.setNextWindowSize(.{
                        .w = @floatFromInt(settings.tab_width),
                        .h = @floatFromInt(settings.height),
                    });
                    _ = z.begin("Settings", .{});

                    defer z.end();

                    const fps: f32 = @floatFromInt(rl.getFPS());
                    const frametime: f32 = if (fps > 0) 1000.0 / fps else 0.0;
                    z.text("FPS: {d:.1} | {d:.2} ms frame | peds: {}", .{ fps, frametime, agents.items.len });

                    // sim data header
                    sim_data.render(&camera, camera_default);

                    // agent data header
                    try agent_data.render(&agents);

                    // ENVIRONMENTAL BUTTONS --------------------------------------------
                    if (z.collapsingHeader("Environment", .{ .default_open = true })) {
                        const bs: i32 = 50;

                        // contour
                        if (EB.contourButton(bs)) {
                            // free previous entities
                            if (current_entity) |*ent| {
                                ent.deinit(allocator);
                            }
                            current_entity = try entity.Entity.initContour(allocator);
                        }

                        // spawner
                        z.sameLine(.{});
                        if (EB.spawnerButton(bs)) {
                            if (current_entity) |*ent| {
                                ent.deinit(allocator);
                            }
                            current_entity = try entity.Entity.initSpawner(allocator);
                        }

                        // area
                        z.sameLine(.{});
                        if (EB.areaButton(bs)) {
                            if (current_entity) |*ent| {
                                ent.deinit(allocator);
                            }
                            current_entity = try entity.Entity.initArea(allocator);
                        }

                        // revolver button
                        z.sameLine(.{});
                        if (EB.revolverButton(bs)) {
                            if (current_entity) |*ent| {
                                ent.deinit(allocator);
                            }
                            current_entity = try entity.Entity.initRevolver(allocator);
                        }

                        // reset
                        if (EB.resetButton()) {
                            // dealloc and delete existing entities (environmental objects)
                            for (env.entities.items) |*ent| {
                                ent.deinit(allocator);
                            }
                            env.entities.clearRetainingCapacity();
                            env.contours.clearRetainingCapacity();
                            env.spawners.clearRetainingCapacity();
                        }
                        z.newLine();
                    }
                    // ------------------------------------------------------------------

                    // statistics header
                    try stats.render(&agents);

                    // process new popups if placing entity gave .confirm signal
                    if (confirm_current) {
                        z.openPopup("Confirm", .{});
                        confirm_current = false;
                    }

                    // popups
                    if (z.beginPopupModal("Confirm", .{ .flags = .{ .always_auto_resize = true } })) {
                        // render the neede widget buttons
                        if (current_entity) |*ent| {
                            switch (ent.kind) {
                                .area => |*a| a.confirm(),
                                .revolver => |*r| r.confirm(),
                                inline else => {},
                            }
                        }

                        z.newLine();

                        // confirm and cancel
                        if (z.button("cancel", .{})) {
                            z.closeCurrentPopup();
                            current_entity.?.deinit(allocator);
                            current_entity = null;
                        }
                        z.sameLine(.{});
                        if (z.button("confirm", .{})) {
                            z.closeCurrentPopup();
                            try env.entities.append(current_entity.?);

                            if (current_entity) |*ent| {
                                switch (ent.kind) {
                                    .area => |*a| try env.areas.append(a),
                                    .revolver => |*r| try env.revolvers.append(r),
                                    inline else => {},
                                }
                            }
                            current_entity = null;
                        }

                        z.endPopup();
                    }
                }

                // draw node editor
                {
                    z.setNextWindowPos(.{ .x = 0, .y = 0 });
                    z.setNextWindowSize(.{
                        .w = @floatFromInt(settings.width),
                        .h = @floatFromInt(settings.height),
                    });

                    try node_editor.render(&env.entities);
                    try node_editor.graph.processSpawners(&agents);
                }
            }
        }
    }

    // save the scene
    try saveScene(allocator, &env, "scene.json");

    // deinit all entity allocations
    if (current_entity) |*ent| {
        ent.deinit(allocator);
    }
    for (env.entities.items) |*ent| {
        ent.deinit(allocator);
    }
}

pub fn renderGrid() void {
    const num_hor_blocks = @divTrunc(settings.sim_width, sim_data.grid_size);
    const col = palette.env.gray;
    for (0..@as(usize, @intCast(num_hor_blocks))) |i| {
        const i_i32: i32 = @intCast(i);
        const grid_pos = i_i32 * sim_data.grid_size;
        rl.drawLine(
            grid_pos,
            0,
            grid_pos,
            settings.sim_height,
            col,
        );
    }
    const num_ver_blocks = @divExact(settings.sim_height, sim_data.grid_size);
    for (0..@as(usize, @intCast(num_ver_blocks))) |i| {
        const i_i32: i32 = @intCast(i);
        const grid_pos = i_i32 * sim_data.grid_size;
        rl.drawLine(
            0,
            grid_pos,
            settings.sim_width,
            grid_pos,
            col,
        );
    }
}

pub fn saveScene(
    allocator: std.mem.Allocator,
    env: *Environment,
    path: []const u8,
) !void {
    var snaps = std.ArrayList(entity.EntitySnapshot).init(allocator);
    defer snaps.deinit();

    for (env.entities.items) |*ent| {
        try snaps.append(ent.getSnapshot());
    }
    const scene_snap: SceneSnapshot = .{
        .version = "0.1.0",
        .entities = snaps.items,
        .next_id = entity.Entity.next_id,
        .next_contour_id = Contour.next_id,
        .next_spawner_id = Spawner.next_id,
        .next_area_id = Area.next_id,
    };
    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();

    try std.json.stringify(scene_snap, .{
        .whitespace = .indent_2,
    }, buf.writer());
    const file = try std.fs.cwd().createFile(path, .{ .truncate = true });
    defer file.close();
    try file.writeAll(buf.items);
}

//
// HALF-AI CODE
//
pub fn loadScene(
    allocator: std.mem.Allocator,
    path: []const u8,
    env: *Environment,
) !void {
    const json = try commons.readFile(allocator, path);
    defer allocator.free(json);

    // dealloc and delete existing entities (environmental objects)
    for (env.entities.items) |*ent| {
        ent.deinit(allocator);
    }
    env.entities.clearRetainingCapacity();
    env.contours.clearRetainingCapacity();
    env.spawners.clearRetainingCapacity();
    env.areas.clearRetainingCapacity();

    // if there is nothing in the file, return
    if (json.len == 0) {
        return;
    }

    // get parsed scene
    const parsed = try std.json.parseFromSlice(
        SceneSnapshot,
        allocator,
        json,
        .{},
    );
    defer parsed.deinit();
    const scene: SceneSnapshot = parsed.value;

    // get next ids for the EE's
    entity.Entity.next_id = scene.next_id;
    Contour.next_id = scene.next_contour_id;
    Spawner.next_id = scene.next_spawner_id;
    Area.next_id = scene.next_area_id;

    // repopulate entities from saved snapshots
    for (scene.entities) |snap| {
        try env.entities.append(try entity.Entity.fromSnapshot(allocator, snap));

        var entity_ptr: *entity.Entity = &env.entities.items[env.entities.items.len - 1];
        switch (entity_ptr.kind) {
            .contour => |*contour| try env.contours.append(contour),
            .spawner => |*spawner| try env.spawners.append(spawner),
            .area => |*area| try env.areas.append(area),
            .revolver => |*revolver| try env.revolvers.append(revolver),
        }
    }
}
