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
const Agent = @import("../Agent.zig");
const imnodes = @import("imnodesez");

active: bool = false,
graph: Graph,

pub fn init(allocator: std.mem.Allocator) Self {
    return .{
        .graph = Graph.init(allocator),
    };
}

pub fn deinit(self: *Self) void {
    self.graph.deinit();
}

pub fn render(
    self: *Self,
    _: std.mem.Allocator,
    entities: *std.ArrayList(entity.Entity),
) !void {
    if (rl.isKeyPressed(.key_space)) {
        self.active = !self.active;
    }

    if (z.begin("Node editor", .{ .flags = .{ .no_scrollbar = true, .no_scroll_with_mouse = true } })) {
        // tutorial
        z.text("[a] to add node", .{});
        z.text("[c] to recenter", .{});

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

                // check if there are any spawners
                var first_spawner: ?*Spawner = null;
                for (entities.items) |*ent| {
                    switch (ent.kind) {
                        .spawner => |*spawner| {
                            first_spawner = spawner;
                            break;
                        },
                        inline else => {},
                    }
                }
                if (z.menuItem("Spawner", .{ .enabled = first_spawner != null })) {
                    if (first_spawner) |_| {
                        try self.graph.addNode(node.Node.initSpawner(
                            entities,
                            1_000,
                        ));
                    }
                }

                // check if there are any areas
                var first_area: ?*Area = null;
                for (entities.items) |*ent| {
                    switch (ent.kind) {
                        .area => |*area| {
                            first_area = area;
                            break;
                        },
                        inline else => {},
                    }
                }
                if (z.menuItem("Area", .{ .enabled = first_area != null })) {
                    if (first_area != null) {
                        try self.graph.addNode(node.Node.initArea(
                            entities,
                            .{ .constant = .{
                                .wait = 1000,
                            } },
                        ));
                    }
                }

                // // fork node
                if (z.menuItem("Fork", .{})) {
                    try self.graph.addNode(node.Node.initFork());
                }

                // sink node
                if (z.menuItem("Sink", .{})) {
                    try self.graph.addNode(node.Node.initSink());
                }
            }
        }

        // render entire graph using imnodes
        for (self.graph.nodes.items) |*n| {
            n.draw();
        }

        // create new connections
        var new_conn: node.NewConnection = .{};
        const input_node_ptr_ptr: *?*anyopaque = @ptrCast(&new_conn.input_node);
        const output_node_ptr_ptr: *?*anyopaque = @ptrCast(&new_conn.output_node);
        if (imnodes.getNewConnection(
            input_node_ptr_ptr,
            &new_conn.input_slot_title,
            output_node_ptr_ptr,
            &new_conn.output_slot_title,
        )) {
            // construct the in- and output the slots involved (see composite key)
            const input_slot: node.Slot = .{
                .node = new_conn.input_node.?,
                .title = new_conn.input_slot_title,
            };
            const output_slot: node.Slot = .{
                .node = new_conn.output_node.?,
                .title = new_conn.output_slot_title,
            };

            // create new connection
            try self.graph.addConnection(output_slot, input_slot);
        }

        // render existing connections
        for (self.graph.connections.items) |conn| {
            // cast the *Node pointer types to *anyopaque because C++ wants that;
            // they're otherwise the same thing
            const input_node_ptr: *anyopaque = @ptrCast(conn.input_slot.node);
            const output_node_ptr: *anyopaque = @ptrCast(conn.output_slot.node);
            _ = imnodes.ez.connection(
                input_node_ptr,
                conn.input_slot.title,
                output_node_ptr,
                conn.output_slot.title,
            );
        }
    }
    z.end();
}
