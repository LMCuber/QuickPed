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
const Schedule = @import("editor/Schedule.zig");
const EB = @import("editor/EnvironmentButtons.zig");
const Stats = @import("editor/Stats.zig");
const NodeEditor = @import("nodes/NodeEditor.zig");
const Benchmarker = @import("Benchmarker.zig");
const UUID = @import("UUID.zig");

var sim_data = SimData.init();
var agent_data = AgentData.init();

var ctx: ?*imnodes.ez.Context = null;

// main
pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const alloc = init.gpa;

    var file = try std.Io.Dir.cwd().createFile(io, "output.txt", .{});
    defer file.close(io);
    // var writer = file.writer();

    rl.initWindow(1, 1, "QuickPed");
    // initWindow must be called BEFORE Settings.init() so we can get monitor size
    const settings = Settings.init();
    rl.setConfigFlags(.{ .vsync_hint = settings.vsync });
    rl.initWindow(settings.width, settings.height, "QuickPed");
    defer rl.closeWindow();
    if (settings.vsync) {
        rl.setTargetFPS(rl.getMonitorRefreshRate(0));
    }

    // imgui setup + breakdown
    c.rlImGuiSetup(true);
    defer c.rlImGuiShutdown();

    // initialize contexts for the imgui libraries
    try z.initNoContext(alloc);
    defer z.deinitNoContext(alloc);

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

    // environmental objects
    var env: Environment = Environment.init(alloc);
    defer env.deinit(alloc);
    var current_entity: ?entity.Entity = null;
    var selected_entity: ?UUID = null;

    // load saved data
    sim_data = try SimData.loadFromFile(alloc, io, "data/sim_data.json");
    if (sim_data.environment_width == 0) {
        sim_data.environment_width = settings.sim_width;
        sim_data.environment_height = settings.sim_height;
    }
    agent_data = try AgentData.loadFromFile(alloc, io, "data/agent_data.json");
    var schedule = try Schedule.loadFromFile(alloc, io, "data/schedule.json");
    defer schedule.deinit(alloc);

    // stats
    const n_cols = 120;
    const n_rows = 120;
    const grid_buf = try alloc.alloc(f32, n_cols * n_rows);
    defer alloc.free(grid_buf);
    var stats = Stats.init(grid_buf, n_cols, n_rows);
    defer stats.deinit(alloc);

    // node editor
    var node_editor = NodeEditor.init(alloc);
    defer node_editor.deinit(alloc);

    try env.loadScene(alloc, io, "data/scene.json", sim_data, agent_data);
    try node_editor.loadNodes(alloc, io, "data/nodes.json", &env);

    // commons.camera shenanigans
    var prev_mouse_position = commons.mousePos();
    var gui_capturing = false;

    var bench = Benchmarker.init(.empty);
    defer bench.deinit(alloc);

    // Main loop
    while (!rl.windowShouldClose()) {
        {
            const dt: f32 = rl.getFrameTime();
            rl.beginDrawing();
            defer rl.endDrawing();
            rl.clearBackground(palette.env.black);
            const sim_rect: rl.Rectangle = .{
                .x = 0,
                .y = 0,
                .width = @floatFromInt(sim_data.environment_width),
                .height = @floatFromInt(sim_data.environment_height),
            };

            // UPDATE =============================================
            var current_entity_action: entity.Entity.EntityAction = .none;
            {
                if (!sim_data.paused) {
                    // update all placed entities
                    for (env.entities.items()) |*ent| {
                        const action = try ent.update(alloc, dt, agent_data, sim_data, settings);
                        switch (action) {
                            .selected => selected_entity = ent.uuid,
                            else => {},
                        }
                    }
                }

                // update in-progress entity
                if (current_entity) |*ent| {
                    current_entity_action = try ent.update(
                        alloc,
                        dt,
                        agent_data,
                        sim_data,
                        settings,
                    );
                    switch (current_entity_action) {
                        .placed => {
                            try env.createEntity(alloc, ent.*);
                            current_entity = null;
                        },
                        else => {},
                    }
                }

                // rebuild the quadtree
                // const last: f64 = rl.getTime();
                {
                    // try bench.begin();
                    // defer bench.end() catch {};
                    try env.quadtree.rebuild(alloc, &env.agents, sim_rect);
                }

                // update the agents
                var check_count: i32 = 0;
                {
                    // try bench.begin();
                    // defer bench.end() catch {};

                    var scratch_buf: std.ArrayList(rl.Vector2) = .empty;
                    defer scratch_buf.deinit(alloc);

                    if (!sim_data.paused) {
                        for (env.agents.items()) |*agent|
                            try agent.update(
                                alloc,
                                &env,
                                &stats,
                                settings,
                                sim_data,
                                agent_data,
                                n_rows,
                                n_cols,
                                &node_editor.graph.nodes,
                                &check_count,
                                &scratch_buf,
                            );
                        // remove marked entities
                        var i: usize = env.agents.len();
                        while (i > 0) {
                            i -= 1;
                            if (env.agents.getByIndex(i).marked)
                                try env.agents.deleteByIndex(i);
                        }
                    }
                }

                // make sure to check that imgui is not capturing the mouse inputs
                // before checking mouse inputs in raylib!
                gui_capturing = z.io.getWantCaptureMouse();
            }

            // RAYLIB DRAW =============================================
            {
                rl.beginMode2D(commons.camera);
                defer rl.endMode2D();

                rl.drawRectangleRec(sim_rect, palette.env.dark_blue);
                renderGrid();

                if (sim_data.show_quadtree) {
                    env.quadtree.render();
                }

                if (!gui_capturing) {
                    // if pressing ctrl, then zoom. otherwise pan
                    if (rl.isKeyDown(.left_control) or rl.isKeyDown(.right_control)) {
                        const mouse_position: rl.Vector2 = rl.getMousePosition();
                        const zoom_delta = 0.006 * rl.getMouseWheelMove();
                        if (zoom_delta > 0 or (zoom_delta < 0 and commons.camera.zoom > 0.1))
                            commons.camera.zoom += zoom_delta;
                        if (rl.isMouseButtonDown(.left)) {
                            const delta_x = mouse_position.x - prev_mouse_position.x;
                            const delta_y = mouse_position.y - prev_mouse_position.y;
                            commons.camera.target = .{
                                .x = commons.camera.target.x - delta_x,
                                .y = commons.camera.target.y - delta_y,
                            };
                        }
                        prev_mouse_position = mouse_position;
                    } else {
                        const wheel: rl.Vector2 = rl.getMouseWheelMoveV();
                        const m = 8;
                        commons.camera.target = .{
                            .x = commons.camera.target.x - wheel.x * m,
                            .y = commons.camera.target.y - wheel.y * m,
                        };
                    }
                }

                // keypresses
                if (rl.isKeyDown(.left_super) and rl.isKeyPressed(.s)) {
                    std.debug.print("Saved!\n", .{});
                    try save(alloc, io, &env, &node_editor, &schedule);
                }

                // render all the entities
                for (env.entities.items()) |*ent| {
                    ent.draw(
                        sim_data,
                        agent_data,
                        node_editor.active,
                    );
                }

                // render the in-progress selected entity
                if (current_entity) |*ent|
                    ent.draw(sim_data, agent_data, node_editor.active);

                // render all pedestrians
                for (env.agents.items()) |*agent|
                    agent.draw(&env, sim_data, agent_data);

                // render sim data misc. things
                sim_data.render();
            }

            // IMGUI DRAW
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
                        .h = @as(f32, @floatFromInt(settings.height)),
                    });
                    _ = z.begin("Settings", .{});

                    defer z.end();

                    const fps: f32 = @floatFromInt(rl.getFPS());
                    const frametime: f32 = if (fps > 0) 1000.0 / fps else 0.0;
                    try z.text(alloc, "FPS: {d:.1} | {d:.2} ms frame | {s} | peds: {}", .{
                        fps,
                        frametime,
                        if (settings.vsync) ("vsync") else "no vsync",
                        env.agents.items().len,
                    });

                    // sim data header
                    if (rl.isKeyPressed(.space)) sim_data.paused = !sim_data.paused;
                    sim_data.updateUi(&commons.camera, commons.camera_default);

                    // schedule header
                    try schedule.updateUi(alloc);

                    // agent data header
                    try agent_data.updateUi(alloc, &env.agents);

                    // ENVIRONMENTAL BUTTONS --------------------------------------------
                    if (z.collapsingHeader("Environment", .{ .default_open = true })) {
                        const button_size: i32 = 50;
                        const next_id: usize = 0;

                        // todo: this is literally the best (worst) thing of all time
                        inline for (@typeInfo(std.meta.Tag(entity.Entity.Kind)).@"enum".fields, 0..) |field, i| {
                            if (i != 0) z.sameLine(.{});
                            if (try @field(EB, field.name ++ "Button")(alloc, button_size)) {
                                resetCurrentEntity(alloc, &current_entity);
                                current_entity = try entity.Entity.init(
                                    std.meta.stringToEnum(std.meta.Tag(entity.Entity.Kind), field.name).?,
                                    alloc,
                                    next_id,
                                );
                            }
                        }

                        // contour
                        if (try EB.contourButton(alloc, button_size)) {
                            resetCurrentEntity(alloc, &current_entity);
                            current_entity = try entity.Entity.init(.contour, alloc, next_id);
                        }

                        // // spawner
                        z.sameLine(.{});
                        if (try EB.spawnerButton(alloc, button_size)) {
                            resetCurrentEntity(alloc, &current_entity);
                            current_entity = try entity.Entity.init(.spawner, alloc, next_id);
                        }

                        // area
                        z.sameLine(.{});
                        if (try EB.areaButton(alloc, button_size)) {
                            resetCurrentEntity(alloc, &current_entity);
                            current_entity = try entity.Entity.init(.area, alloc, next_id);
                        }

                        // revolver
                        z.sameLine(.{});
                        if (try EB.revolverButton(alloc, button_size)) {
                            resetCurrentEntity(alloc, &current_entity);
                            current_entity = try entity.Entity.init(.revolver, alloc, next_id);
                        }

                        // queue
                        z.sameLine(.{});
                        if (try EB.queueButton(alloc, button_size)) {
                            resetCurrentEntity(alloc, &current_entity);
                            current_entity = try entity.Entity.init(.queue, alloc, next_id);
                        }

                        // portal
                        z.sameLine(.{});
                        if (try EB.portalButton(alloc, button_size)) {
                            resetCurrentEntity(alloc, &current_entity);
                            current_entity = try entity.Entity.init(.portal, alloc, next_id);
                        }

                        // update the selected entity
                        z.newLine();
                        if (selected_entity) |ent_id| {
                            var ent = env.entities.getByUUID(ent_id);
                            try ent.edit(alloc);
                        }
                        z.newLine();
                    }
                    // ------------------------------------------------------------------

                    // statistics header
                    try stats.updateUi(alloc, &env.agents, sim_data.paused);

                    // process new popups if placing entity gave .confirm signal
                    switch (current_entity_action) {
                        .confirm => {
                            z.openPopup("Confirm", .{});
                            current_entity_action = .none;
                        },
                        .confirm_init => {
                            z.openPopup("Confirm creation", .{});
                            current_entity_action = .none;
                        },
                        else => {},
                    }

                    // POPUPS
                    // confirm close popup
                    if (z.beginPopupModal("Confirm", .{ .flags = .{ .always_auto_resize = true } })) {
                        defer z.endPopup();

                        // give focus the first time it appears
                        if (z.isWindowAppearing()) {
                            z.setKeyboardFocusHere(0);
                        }

                        if (current_entity) |*ent| {
                            const node_width: i32 = 130;

                            // ent.name_edit_buf = .{0} ** 256;
                            z.setNextItemWidth(node_width);
                            var name_str: [:0]const u8 = "";
                            if (z.inputText("name", .{ .buf = &ent.name_edit_buf })) {
                                name_str = std.mem.sliceTo(&ent.name_edit_buf, 0);
                                try current_entity.?.setName(alloc, name_str);
                            }

                            name_str = std.mem.sliceTo(&ent.name_edit_buf, 0);

                            // if name already exists, display that
                            var duplicate_name: bool = false;
                            for (env.entities.items()) |inner_ent| {
                                if (std.mem.eql(u8, inner_ent.name, name_str)) {
                                    duplicate_name = true;
                                }
                            }
                            if (duplicate_name) {
                                try z.text(alloc, "duplicate name!", .{});
                            } else {
                                z.newLine();
                            }
                            z.newLine();

                            // render the needed confirm widget buttons
                            try ent.confirm(alloc, sim_data, agent_data);

                            z.newLine();

                            // confirm and cancel
                            if (z.button("cancel", .{})) {
                                z.closeCurrentPopup();
                                ent.deinit(alloc);
                                current_entity = null;
                            }
                            z.sameLine(.{});
                            if (z.button("confirm", .{}) and !duplicate_name) {
                                z.closeCurrentPopup();

                                try env.createEntity(alloc, ent.*);
                                // don't deinit!

                                current_entity = null;
                            }
                        } else unreachable;
                    }

                    // confirm creation popup
                    if (z.beginPopupModal("Confirm creation", .{ .flags = .{ .always_auto_resize = true } })) {
                        defer z.endPopup();
                        if (current_entity) |*ent| {
                            // entity-specific widgets
                            switch (ent.kind) {
                                .area => |*a| a.confirmInit(),
                                else => {},
                            }

                            // closing buttons
                            if (z.button("cancel", .{})) {
                                z.closeCurrentPopup();
                                ent.deinit(alloc);
                                current_entity = null;
                            }
                            z.sameLine(.{});
                            if (z.button("confirm", .{})) {
                                switch (ent.kind) {
                                    .area => |*a| try a.finishConfirm(),
                                    else => unreachable,
                                }
                                z.closeCurrentPopup();
                            }
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

                    try node_editor.render(alloc, settings, &env);
                    if (!sim_data.paused) {
                        try node_editor.update(alloc, &env);
                    }
                }
            }
        }
    }
    // deinit current entity and decrement the increased ID back to the previous since it hasn't been placed in the end
    resetCurrentEntity(alloc, &current_entity);

    // save the simulation data, scene, nodes
    try save(alloc, io, &env, &node_editor, &schedule);

    // dealloc all entities
    for (env.entities.items()) |*ent| {
        ent.deinit(alloc);
    }
}

pub fn save(
    alloc: std.mem.Allocator,
    io: std.Io,
    env: *Environment,
    node_editor: *NodeEditor,
    schedule: *Schedule,
) !void {
    try commons.writeFile(alloc, io, agent_data, "data/agent_data.json");
    try commons.writeFile(alloc, io, sim_data, "data/sim_data.json");
    try env.saveScene(alloc, io, "data/scene.json");
    try node_editor.saveNodes(alloc, io, "data/nodes.json");
    try commons.writeFile(alloc, io, schedule.getSnapshot(), "data/schedule.json");
}

pub fn resetCurrentEntity(alloc: std.mem.Allocator, current_entity: *?entity.Entity) void {
    if (current_entity.*) |*ent| ent.deinit(alloc);
}

pub fn renderGrid() void {
    const num_hor_blocks = @divTrunc(sim_data.environment_width, sim_data.grid_size);
    const col = palette.env.navy;
    for (0..@as(usize, @intCast(num_hor_blocks))) |i| {
        const i_i32: i32 = @intCast(i);
        const grid_pos = i_i32 * sim_data.grid_size;
        rl.drawLine(
            grid_pos,
            0,
            grid_pos,
            sim_data.environment_height,
            col,
        );
    }

    const num_ver_blocks = @divTrunc(sim_data.environment_height, sim_data.grid_size);
    for (0..@as(usize, @intCast(num_ver_blocks))) |i| {
        const i_i32: i32 = @intCast(i);
        const grid_pos = i_i32 * sim_data.grid_size;
        rl.drawLine(
            0,
            grid_pos,
            sim_data.environment_width,
            grid_pos,
            col,
        );
    }
}
