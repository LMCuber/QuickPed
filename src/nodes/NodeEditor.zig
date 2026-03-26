const Self = @This();

const z = @import("zgui");
// const imnodes = @import("imnodes");
const rl = @import("raylib");
const std = @import("std");
const node = @import("node.zig");
const Graph = @import("Graph.zig");
const Spawner = @import("../environment/Spawner.zig");
const entity = @import("../environment/entity.zig");
const Area = @import("../environment/Area.zig");
const Queue = @import("../environment/Queue.zig");
const Environment = @import("../environment/Environment.zig");
const Settings = @import("../Settings.zig");
const Agent = @import("../Agent.zig");
const commons = @import("../commons.zig");
const imnodes = @import("imnodesez");

graph: Graph,

active: bool = false,
showing_keybinds: bool = false,

pub fn init(allocator: std.mem.Allocator) Self {
    return .{
        .graph = Graph.init(allocator),
    };
}

pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    self.graph.deinit(allocator);
}

pub fn saveNodes(self: *Self, alloc: std.mem.Allocator, path: []const u8) !void {
    try self.graph.saveNodes(alloc, path);
}

pub fn deleteEntity(self: *Self, ent_id: usize) void {
    self.graph.deleteEntity(ent_id);
}

pub fn loadNodes(self: *Self, alloc: std.mem.Allocator, path: []const u8, env: *Environment) !void {
    try self.graph.loadNodes(alloc, path, env);
}

pub fn update(self: *Self, alloc: std.mem.Allocator, env: *Environment) !void {
    try self.processSpawners(alloc, env);
}

pub fn processSpawners(self: *Self, alloc: std.mem.Allocator, env: *Environment) !void {
    try self.graph.processSpawners(alloc, env);
}

pub fn render(
    self: *Self,
    allocator: std.mem.Allocator,
    settings: Settings,
    env: *Environment,
) !void {
    if (rl.isKeyPressed(.key_space)) {
        self.active = !self.active;
    }

    z.setNextWindowSize(.{
        .w = @floatFromInt(settings.width),
        .h = @floatFromInt(settings.height),
    });

    if (z.begin("Node editor", .{ .flags = .{ .no_scrollbar = true, .no_scroll_with_mouse = true } })) {
        // tutorial
        if (rl.isKeyReleased(.key_i)) {
            self.showing_keybinds = !self.showing_keybinds;
        }
        if (self.showing_keybinds) {
            z.text("[a] to add node", .{});
            z.text("[d] to delete node", .{});
            z.text("[c] to recenter", .{});
            z.text("double click to delete link", .{});
            z.newLine();
            z.text("[i] to hide keybinds", .{});
        } else {
            z.text("[i] to show keybinds", .{});
        }

        imnodes.ez.beginCanvas();
        defer imnodes.ez.endCanvas();

        // user centers the editor
        if (rl.isKeyReleased(.key_c) and !z.isAnyItemHovered()) {
            imnodes.setOffset(imnodes.ez.getState(), .{ .x = 0, .y = 0 });
        }

        // user adds new nodes
        const wants_add: bool = rl.isKeyReleased(.key_a) or rl.isMouseButtonDown(.mouse_button_right);
        if (wants_add and !z.isAnyItemHovered()) {
            z.openPopup("edit", .{});
        }
        if (z.beginPopup("edit", .{})) {
            defer z.endPopup();
            if (z.beginMenu("Add node", true)) {
                defer z.endMenu();

                if (z.menuItem("Spawner", .{ .enabled = commons.existsAnyObject(env, .spawner) })) {
                    try self.graph.addNode(node.Node.initSpawner(
                        env,
                        1_000,
                    ));
                }

                if (z.menuItem("Area", .{ .enabled = commons.existsAnyObject(env, .area) })) {
                    try self.graph.addNode(node.Node.initArea(
                        env,
                        .{ .constant = .{
                            .wait = 1000,
                        } },
                    ));
                }

                if (z.menuItem("Queue", .{ .enabled = commons.existsAnyObject(env, .queue) })) {
                    try self.graph.addNode(node.Node.initQueue(
                        env,
                        .{ .constant = .{
                            .wait = 1000,
                        } },
                    ));
                }

                if (z.menuItem("Queue Fork", .{})) {
                    try self.graph.addNode(node.Node.initQueueFork());
                }

                // fork node
                if (z.menuItem("Fork", .{})) {
                    try self.graph.addNode(node.Node.initFork());
                }

                // sink node
                if (z.menuItem("Sink", .{})) {
                    try self.graph.addNode(node.Node.initSink());
                }

                // less frequently used environmental objects
                if (z.beginMenu("other", true)) {
                    defer z.endMenu();

                    if (z.menuItem("Portal", .{ .enabled = commons.existsAnyObject(env, .portal) })) {
                        try self.graph.addNode(node.Node.initPortal(env));
                    }
                }
            }
        }

        var selected_node_id: ?usize = null;

        // update and draw entire graph using imnodes
        // and save the selected one
        for (&self.graph.nodes.items, 0..) |*nslot, i| {
            if (!nslot.alive) continue;
            const node_state = nslot.value.update();
            if (node_state == .selected) {
                selected_node_id = i;
            }
            nslot.value.draw();
        }

        // user wants to delete the currently selected node
        if (selected_node_id) |node_id| {
            if (rl.isKeyReleased(.key_d)) {
                try self.graph.deleteNode(allocator, node_id);
            }
        }

        // create new conns by passing an empty dummy connections struct to be populated with values
        var new_conn: node.NewConnection = .{};
        const input_node_ptr_ptr: *?*anyopaque = @ptrCast(&new_conn.input_node);
        const output_node_ptr_ptr: *?*anyopaque = @ptrCast(&new_conn.output_node);
        if (imnodes.getNewConnection(
            input_node_ptr_ptr,
            &new_conn.input_slot_title,
            output_node_ptr_ptr,
            &new_conn.output_slot_title,
        )) {
            // scan which node id the ptrs correspond to
            const input_node_id = self.graph.nodes.scan(new_conn.input_node.?).?;
            const output_node_id = self.graph.nodes.scan(new_conn.output_node.?).?;

            // construct the in- and output the slots involved (see composite key)
            const input_slot: node.Slot = try node.Slot.init(
                allocator,
                input_node_id,
                new_conn.input_slot_title,
            );
            const output_slot: node.Slot = try node.Slot.init(
                allocator,
                output_node_id,
                new_conn.output_slot_title,
            );

            // create new connection
            try self.graph.addConnection(output_slot, input_slot);
        }

        // render existing connections
        var i = self.graph.connections.items.len;
        while (i > 0) {
            i -= 1;
            var conn = self.graph.connections.items[i];
            const input_node_ptr: *anyopaque = @ptrCast(self.graph.nodes.get(conn.input_slot.node_id));
            const output_node_ptr: *anyopaque = @ptrCast(self.graph.nodes.get(conn.output_slot.node_id));

            const double_clicked: bool = !imnodes.ez.connection(
                input_node_ptr,
                conn.input_slot.title,
                output_node_ptr,
                conn.output_slot.title,
            );
            if (double_clicked) {
                conn.deinit(allocator);
                _ = self.graph.connections.swapRemove(i);
            }
        }
    }
    z.end();
}
