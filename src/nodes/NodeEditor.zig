const Self = @This();

const z = @import("zgui");
const imnodes = @import("imnodes");
const rl = @import("raylib");
const std = @import("std");
const node = @import("node.zig");
const Graph = @import("Graph.zig");
const Spawner = @import("../environment/Spawner.zig");
const entity = @import("../environment/entity.zig");
const Area = @import("../environment/Area.zig");
const Agent = @import("../Agent.zig");

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

            // fork node
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

    // render existing links
    for (self.graph.links.items) |link| {
        // std.debug.print("{}|{}\n", .{ link.left_attr_id, link.right_attr_id });
        imnodes.link(link.id, link.left_attr_id, link.right_attr_id);
    }

    imnodes.minimap();
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
