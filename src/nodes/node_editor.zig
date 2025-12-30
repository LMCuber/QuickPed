const Self = @This();

const z = @import("zgui");
const imnodes = @import("imnodes");
const rl = @import("raylib");
const std = @import("std");
const node = @import("node.zig");
const Graph = @import("graph.zig");
const Spawner = @import("../environment/spawner.zig");

active: bool = false,
graph: Graph,

pub const NodeType = enum {
    SPAWNER,
    AREA,
};

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
    spawners: *std.ArrayList(*Spawner),
) !void {
    if (rl.isKeyPressed(.key_space)) {
        self.active = !self.active;
    }
    if (!self.active) {
        return;
    }

    z.setNextWindowCollapsed(.{
        .collapsed = false,
    });

    _ = z.begin("Node Editor", .{});
    defer z.end();

    imnodes.beginNodeEditor();
    defer imnodes.endNodeEditor();

    // user adds new nodes
    const open_popup: bool = (imnodes.isEditorHovered() and rl.isKeyReleased(.key_a));
    if (!z.isAnyItemHovered() and open_popup) {
        z.openPopup("edit", .{});
    }
    if (z.beginPopup("edit", .{})) {
        defer z.endPopup();
        if (z.beginMenu("Add node", true)) {
            defer z.endMenu();
            if (z.beginMenu("Spawner", true)) {
                defer z.endMenu();
                // query all spawner objects
                for (spawners.items) |spawner| {
                    if (z.menuItem(spawner.name, .{})) {
                        const n = node.Node.initSpawner(
                            spawner.spawner_id,
                            100,
                        );
                        try self.graph.addNode(n);
                    }
                }
            }
        }
    }

    // render entire graph using imnodes
    for (self.graph.nodes.items) |*n| {
        n.draw();
    }

    // imnodes.minimap();
}
