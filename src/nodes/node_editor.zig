const Self = @This();

const z = @import("zgui");
const imnodes = @import("imnodes");
const rl = @import("raylib");
const std = @import("std");
const node = @import("node.zig");
const Graph = @import("graph.zig");
const Spawner = @import("../environment/spawner.zig");
const entity = @import("../environment/entity.zig");
const Area = @import("../environment/area.zig");
const Agent = @import("../agent.zig");

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
    entities: *std.ArrayList(entity.Entity),
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
                for (entities.items) |*ent| {
                    switch (ent.kind) {
                        .spawner => {
                            if (z.menuItem(ent.name, .{})) {
                                try self.graph.addNode(node.Node.initSpawner(
                                    &ent.kind.spawner,
                                    1_000,
                                ));
                            }
                        },
                        inline else => {},
                    }
                }
            }
            if (z.beginMenu("Area", true)) {
                defer z.endMenu();

                // query all area objects
                for (entities.items) |*ent| {
                    switch (ent.kind) {
                        .area => {
                            if (z.menuItem(ent.name, .{})) {
                                try self.graph.addNode(node.Node.initArea(
                                    &ent.kind.area,
                                    1000,
                                ));
                            }
                        },
                        inline else => {},
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
        // std.debug.print("{}|{}\n", .{ link.left_attr_id, link.right_attr_id });
        imnodes.link(link.id, link.left_attr_id, link.right_attr_id);
    }

    // imnodes.minimap();
    imnodes.endNodeEditor();

    // check for new connections
    var start_attr_id: i32 = 0;
    var end_attr_id: i32 = 0;

    _ = imnodes.isLinkCreated(&start_attr_id, &end_attr_id);
    if (start_attr_id | end_attr_id != 0) {
        // std.debug.print("{}|{}\n", .{ start_attr_id, end_attr_id });
        try self.graph.addLink(start_attr_id, end_attr_id);
    }

    // check for destroyed connections
    var link_id: i32 = 0;
    _ = imnodes.isLinkDestroyed(&link_id);
    // std.debug.print("{}\n", .{link_id});
}
