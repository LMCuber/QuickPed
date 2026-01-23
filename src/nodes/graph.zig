const Self = @This();
const node = @import("node.zig");
const std = @import("std");
const Agent = @import("../agent.zig");

allocator: std.mem.Allocator,
nodes: std.ArrayList(node.Node),
links: std.ArrayList(node.Link),

pub fn init(allocator: std.mem.Allocator) Self {
    return .{
        .allocator = allocator,
        .nodes = std.ArrayList(node.Node).init(allocator),
        .links = std.ArrayList(node.Link).init(allocator),
    };
}

pub fn deinit(self: *Self) void {
    self.nodes.deinit();
    self.links.deinit();
}

pub fn addNode(self: *Self, n: node.Node) !void {
    try self.nodes.append(n);
}

pub fn addLink(self: *Self, left_attr_id: i32, right_attr_id: i32) !void {
    try self.links.append(.{
        .id = node.Link.nextId(),
        .left_attr_id = left_attr_id,
        .right_attr_id = right_attr_id,
    });
}

pub fn processSpawners(self: *Self, agents: *std.ArrayList(Agent)) !void {
    for (self.nodes.items) |*n| {
        switch (n.kind) {
            .spawner => |*spawner| {
                try spawner.update(agents, self, n);
            },
            inline else => {},
        }
    }
}

// NEW: Get the next node given current node
pub fn getNextNode(self: Self, current_node: *const node.Node) ?*node.Node {
    // Get output port ID from current node
    const output_port_id = switch (current_node.kind) {
        .spawner => |*s| s.target.id,
        .area => |*a| a.target.id,
        .sink => return null, // Sink has no output
    };

    // Find link where left_attr_id matches our output port
    for (self.links.items) |link| {
        if (link.left_attr_id == output_port_id) {
            // Found a connection, now find the node with this input port
            const next_port_id = link.right_attr_id;

            for (self.nodes.items) |*n| {
                const has_port = switch (n.kind) {
                    .spawner => |*s| s.target.id == next_port_id,
                    .sink => |*s| s.from.id == next_port_id,
                    .area => |*a| a.from.id == next_port_id or a.target.id == next_port_id,
                };

                if (has_port) return n;
            }
        }
    }

    return null; // No connection found
}
