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

    // environmental objects
    var env: Environment = Environment.init(allocator);
    defer env.deinit();
    var current_entity: ?entity.Entity = null;

    // load saved data
    sim_data = try SimData.loadFromFile(allocator, "data/sim_data.json");
    agent_data = try AgentData.loadFromFile(allocator, "data/agent_data.json");

    // stats
    const n_cols = 100;
    const n_rows = 100;
    const buf = try allocator.alloc(f32, n_cols * n_rows);
    defer allocator.free(buf);
    var stats = Stats.init(allocator, buf, n_cols, n_rows);
    defer stats.deinit();

    // node editor
    var node_editor = NodeEditor.init(allocator);
    defer node_editor.deinit(allocator);

    try env.loadScene(allocator, "data/scene.json");
    try node_editor.loadNodes(allocator, "data/nodes.json", &env);

    // commons.camera shenanigans
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
            rl.clearBackground(palette.env.black);

            // UPDATING =============================================
            var confirm_current: bool = false;
            {
                if (!sim_data.paused) {
                    // update all placed entities
                    for (&env.entities.items) |*eslot| {
                        if (eslot.alive) {
                            _ = try eslot.value.update(
                                allocator,
                                dt,
                                agent_data,
                                sim_data,
                                settings,
                            );
                        }
                    }
                }

                // update selected entity
                if (current_entity) |*ent| {
                    const action = try ent.update(allocator, dt, agent_data, sim_data, settings);
                    switch (action) {
                        .cancelled, .none => {},
                        .placed => {
                            try env.createEntity(ent.*);
                            current_entity = null;
                        },
                        .confirm => confirm_current = true,
                    }
                }

                // update the agents
                if (!sim_data.paused) {
                    for (&env.agents.items, 0..) |*aslot, i| {
                        if (!aslot.alive) continue;
                        try aslot.value.update(
                            allocator,
                            &env,
                            &stats,
                            settings,
                            i,
                            agent_data,
                            n_rows,
                            n_cols,
                            &node_editor.graph.nodes,
                        );
                    }
                    // cleanup to be deleted agents
                    for (&env.agents.items, 0..) |*aslot, i| {
                        if (!aslot.alive) continue;
                        if (aslot.value.marked) {
                            env.agents.deleteItem(i);
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
                rl.beginMode2D(commons.camera);
                defer rl.endMode2D();

                rl.drawRectangleRec(sim_rect, palette.env.dark_blue);
                renderGrid();

                if (!capture) {
                    const mouse_position: rl.Vector2 = rl.getMousePosition();
                    const zoom_delta = rl.getMouseWheelMove() * 0.01;
                    if (zoom_delta > 0 or (zoom_delta < 0 and commons.camera.zoom > 0.05))
                        commons.camera.zoom += zoom_delta;
                    if (rl.isMouseButtonDown(.mouse_button_left)) {
                        const delta_x = mouse_position.x - prev_mouse_position.x;
                        const delta_y = mouse_position.y - prev_mouse_position.y;
                        commons.camera.target = .{
                            .x = commons.camera.target.x - delta_x,
                            .y = commons.camera.target.y - delta_y,
                        };
                    }
                    prev_mouse_position = mouse_position;
                }

                // render all the entities
                for (&env.entities.items) |*eslot| {
                    if (!eslot.alive) continue;
                    eslot.value.draw(agent_data);
                }

                // render the in-progress selected entity
                if (current_entity) |*ent| {
                    ent.draw(agent_data);
                }

                // render all pedestrians
                for (&env.agents.items) |*aslot| {
                    if (!aslot.alive) continue;
                    aslot.value.draw(agent_data);
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
                    z.text("FPS: {d:.1} | {d:.2} ms frame | peds: {}", .{ fps, frametime, env.agents.getLen() });

                    // sim data header
                    sim_data.render(&commons.camera, commons.camera_default);

                    // agent data header
                    try agent_data.render(&env.agents);

                    // ENVIRONMENTAL BUTTONS --------------------------------------------
                    if (z.collapsingHeader("Environment", .{ .default_open = true })) {
                        const button_size: i32 = 50;
                        const next_id: usize = env.entities.getNextIndex();

                        // contour
                        if (EB.contourButton(button_size)) {
                            resetCurrentEntity(allocator, &current_entity);
                            current_entity = try entity.Entity.initContour(allocator, next_id);
                        }

                        // // spawner
                        z.sameLine(.{});
                        if (EB.spawnerButton(button_size)) {
                            resetCurrentEntity(allocator, &current_entity);
                            current_entity = try entity.Entity.initSpawner(allocator, next_id);
                        }

                        // area
                        z.sameLine(.{});
                        if (EB.areaButton(button_size)) {
                            resetCurrentEntity(allocator, &current_entity);
                            current_entity = try entity.Entity.initArea(allocator, next_id);
                        }

                        // revolver
                        z.sameLine(.{});
                        if (EB.revolverButton(button_size)) {
                            resetCurrentEntity(allocator, &current_entity);
                            current_entity = try entity.Entity.initRevolver(allocator, next_id);
                        }

                        // queue
                        z.sameLine(.{});
                        if (EB.queueButton(button_size)) {
                            resetCurrentEntity(allocator, &current_entity);
                            current_entity = try entity.Entity.initQueue(allocator, next_id);
                        }

                        // reset
                        z.separatorText("");

                        // reset
                        if (EB.clearButton()) {
                            env.clearEntities(allocator);
                        }
                        z.newLine();
                    }
                    // ------------------------------------------------------------------

                    // statistics header
                    try stats.render(&env.agents, sim_data.paused);

                    // process new popups if placing entity gave .confirm signal
                    if (confirm_current) {
                        z.openPopup("Confirm", .{});
                        confirm_current = false;
                    }

                    // popups
                    if (z.beginPopupModal("Confirm", .{ .flags = .{ .always_auto_resize = true } })) {
                        // give focus the first time it appears
                        if (z.isWindowAppearing()) {
                            z.setKeyboardFocusHere(0);
                        }

                        if (current_entity) |*ent| {
                            const node_width: i32 = 130;

                            ent.name_edit_buf = .{0} ** 256;
                            z.setNextItemWidth(node_width);
                            var name_str: [:0]const u8 = "";
                            if (z.inputText("name", .{ .buf = &ent.name_edit_buf })) {
                                name_str = std.mem.sliceTo(&ent.name_edit_buf, 0);
                                try current_entity.?.setName(allocator, name_str);
                            }

                            name_str = std.mem.sliceTo(&ent.name_edit_buf, 0);

                            // if name already exists, display that
                            var duplicate_name: bool = false;
                            for (env.entities.items[0..]) |*inner_eslot| {
                                if (!inner_eslot.alive) continue;
                                if (std.mem.eql(u8, inner_eslot.value.name, name_str)) {
                                    duplicate_name = true;
                                }
                            }
                            if (duplicate_name) {
                                z.text("duplicate name!", .{});
                            } else {
                                z.newLine();
                            }
                            z.newLine();

                            // render the needed widget buttons
                            switch (ent.kind) {
                                .area => |*a| a.confirm(),
                                .revolver => |*r| r.confirm(),
                                .queue => |*q| try q.confirm(allocator, agent_data),
                                else => {},
                            }

                            z.newLine();

                            // confirm and cancel
                            if (z.button("cancel", .{})) {
                                z.closeCurrentPopup();
                                ent.deinit(allocator);
                                current_entity = null;
                            }
                            z.sameLine(.{});
                            if (z.button("confirm", .{}) and !duplicate_name) {
                                z.closeCurrentPopup();

                                try env.createEntity(ent.*);
                                // don't deinit!

                                current_entity = null;
                            }

                            z.endPopup();
                        } else unreachable;
                    }
                }

                // draw node editor
                {
                    z.setNextWindowPos(.{ .x = 0, .y = 0 });
                    z.setNextWindowSize(.{
                        .w = @floatFromInt(settings.width),
                        .h = @floatFromInt(settings.height),
                    });

                    try node_editor.render(allocator, &env);
                    if (!sim_data.paused) {
                        try node_editor.update(allocator, &env);
                    }
                }
            }
        }
    }
    // deinit current entity and decrement the increased ID back to the previous since it hasn't been placed in the end
    resetCurrentEntity(allocator, &current_entity);

    // save the simulation data, scene, nodes
    try agent_data.saveToFile(allocator, "data/agent_data.json");
    try sim_data.saveToFile(allocator, "data/sim_data.json");
    try env.saveScene(allocator, "data/scene.json");
    try node_editor.saveNodes(allocator, "data/nodes.json");

    // dealloc all entities
    for (&env.entities.items) |*eslot| {
        if (!eslot.alive) continue;
        eslot.value.deinit(allocator);
    }
}

pub fn resetCurrentEntity(alloc: std.mem.Allocator, current_entity: *?entity.Entity) void {
    if (current_entity.*) |*ent| {
        ent.deinit(alloc);
    }
}

pub fn renderGrid() void {
    const num_hor_blocks = @divTrunc(settings.sim_width, sim_data.grid_size);
    const col = palette.env.light_blue;
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
