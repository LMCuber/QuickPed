const Self = @This();

const z = @import("zgui");
const imnodes = @import("imnodes");
const rl = @import("raylib");
const std = @import("std");
const node = @import("node.zig");
const Graph = @import("graph.zig");
const Spawner = @import("../environment/spawner.zig");
const Area = @import("../environment/area.zig");

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
    areas: *std.ArrayList(*Area),
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
                        try self.graph.addNode(node.Node.initSpawner(
                            spawner,
                            100,
                        ));
                    }
                }
            }
            if (z.beginMenu("Area", true)) {
                defer z.endMenu();

                // query all area objects
                for (areas.items) |area| {
                    if (z.menuItem(area.name, .{})) {
                        try self.graph.addNode(node.Node.initArea(
                            area,
                            100,
                        ));
                    }
                }
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

    // render existing links
    for (self.graph.links.items) |link| {
        imnodes.link(0, link.left_attr_id, link.right_attr_id);
    }

    // imnodes.minimap();
    imnodes.endNodeEditor();

    // check for new connections
    var start_attr: i32 = 0;
    var end_attr: i32 = 0;

    const b = imnodes.isLinkCreated(&start_attr, &end_attr);
    std.debug.print("{}|{}|{}\n", .{ b, start_attr, end_attr });
}
