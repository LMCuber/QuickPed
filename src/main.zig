// third-party
const std = @import("std");
const c = @cImport({
    @cDefine("NO_FONT_AWESOME", "1");
    @cInclude("rlImGui.h");
});
const rl = @import("raylib");
const z = @import("zgui");
// const imnodes = @import("imnodes");
const implot = @import("implot");
const imnodes = @import("imnodesez");

// namespaces
const commons = @import("commons.zig");
const color = @import("color.zig");
const palette = @import("palette.zig");

// environment
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
    rl.initWindow(
        settings.width,
        settings.height,
        "QuickPed",
    );

    defer rl.closeWindow();
    rl.setTargetFPS(settings.fps_cap);

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
    var entities = std.ArrayList(entity.Entity).init(allocator);
    defer entities.deinit();
    try entities.ensureTotalCapacity(100_000);
    var agents = std.ArrayList(Agent).init(allocator);
    defer agents.deinit();

    var current_entity: ?entity.Entity = null;

    // specific entity containers
    var contours = std.ArrayList(*Contour).init(allocator);
    defer contours.deinit();
    var spawners = std.ArrayList(*Spawner).init(allocator);
    defer spawners.deinit();
    var areas = std.ArrayList(*Area).init(allocator);
    defer areas.deinit();
    var revolvers = std.ArrayList(*Revolver).init(allocator);
    defer revolvers.deinit();

    // allocated editor objects
    var stats = Stats.init(allocator);
    defer stats.deinit();

    // node editor
    var node_editor = NodeEditor.init(allocator);
    defer node_editor.deinit();

    try loadScene(
        allocator,
        "scene.json",
        &entities,
        &contours,
        &spawners,
        &areas,
        &revolvers,
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
        // Draw Raylib
        {
            rl.beginDrawing();
            defer rl.endDrawing();
            rl.clearBackground(color.black);

            // set popup attribute of current entity
            if (current_entity) |ent| {
                if (ent.kind == .area) {}
            }

            var confirm_current: bool = false;
            {
                rl.beginMode2D(camera);
                defer rl.endMode2D();

                rl.drawRectangleRec(sim_rect, palette.env.black);
                renderGrid();

                // update selected entity
                if (current_entity) |*ent| {
                    const action = try ent.update(sim_data, settings);
                    switch (action) {
                        .cancelled, .none => {},
                        .placed => {
                            try entities.append(ent.*);
                            const stored_entity_ptr = &entities.items[entities.items.len - 1];

                            switch (stored_entity_ptr.kind) {
                                .contour => try contours.append(&stored_entity_ptr.kind.contour),
                                .spawner => try spawners.append(&stored_entity_ptr.kind.spawner),
                                .area => try areas.append(&stored_entity_ptr.kind.area),
                                .revolver => try revolvers.append(&stored_entity_ptr.kind.revolver),
                            }

                            current_entity = null;
                        },
                        .confirm => confirm_current = true,
                    }
                    if (action == .placed) {} else {
                        ent.draw();
                    }
                }
                // update all placed entities
                for (entities.items) |*ent| {
                    _ = try ent.update(sim_data, settings);
                }

                // update the agents
                if (!sim_data.paused) {
                    for (agents.items) |*agent| {
                        agent.update(&agents, &contours, agent_data);
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

                // render all the entities
                for (entities.items) |*ent| {
                    ent.draw();
                }
                for (agents.items) |*agent| {
                    agent.draw(agent_data);
                }

                // Make sure to check that ImGui is not capturing the mouse inputs
                // before checking mouse inputs in Raylib!
                capture = z.io.getWantCaptureMouse();
                capture = z.io.getWantCaptureMouse();
                capture = z.io.getWantCaptureMouse();
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
            }

            // draw ImGui
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
                            for (entities.items) |*e| {
                                e.deinit(allocator);
                            }
                            entities.clearRetainingCapacity();
                            contours.clearRetainingCapacity();
                            spawners.clearRetainingCapacity();
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
                        if (current_entity) |*ent| {
                            switch (ent.kind) {
                                .area => |*a| a.confirm(),
                                inline else => {},
                            }
                        }
                        z.newLine();
                        if (z.button("confirm", .{})) {
                            z.closeCurrentPopup();
                            try entities.append(current_entity.?);
                            const stored_entity_ptr = &entities.items[entities.items.len - 1];
                            try areas.append(&stored_entity_ptr.kind.area);
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

                    try node_editor.render(&entities);
                    try node_editor.graph.processSpawners(&agents);
                }
            }
        }
    }

    // save the scene
    try saveScene(allocator, entities, "scene.json");

    // deinit all entity allocations
    if (current_entity) |*ent| {
        ent.deinit(allocator);
    }
    for (entities.items) |*ent| {
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
    entities: std.ArrayList(entity.Entity),
    path: []const u8,
) !void {
    var snaps = std.ArrayList(entity.EntitySnapshot).init(allocator);
    defer snaps.deinit();

    for (entities.items) |*ent| {
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

pub fn loadScene(
    allocator: std.mem.Allocator,
    path: []const u8,
    entities: *std.ArrayList(entity.Entity),
    contours: *std.ArrayList(*Contour),
    spawners: *std.ArrayList(*Spawner),
    areas: *std.ArrayList(*Area),
    revolvers: *std.ArrayList(*Revolver),
) !void {
    const json = try commons.readFile(allocator, path);
    defer allocator.free(json);

    // dealloc and delete existing entities (environmental objects)
    for (entities.items) |*e| {
        e.deinit(allocator);
    }
    entities.clearRetainingCapacity();
    contours.clearRetainingCapacity();
    spawners.clearRetainingCapacity();
    areas.clearRetainingCapacity();

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
        try entities.append(try entity.Entity.fromSnapshot(allocator, snap));

        var entity_ptr: *entity.Entity = &entities.items[entities.items.len - 1];
        switch (entity_ptr.kind) {
            .contour => |*contour| try contours.append(contour),
            .spawner => |*spawner| try spawners.append(spawner),
            .area => |*area| try areas.append(area),
            .revolver => |*revolver| try revolvers.append(revolver),
        }
    }
}
