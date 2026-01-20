const Self = @This();
const node = @import("node.zig");
const std = @import("std");

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

pub fn traverse(self: Self) !void {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // construct output_port_id -> []input_port_id
    var adjacency = std.AutoHashMap(i32, std.ArrayList(i32)).init(allocator);

    for (self.links.items) |link| {
        const entry = try adjacency.getOrPut(link.left_attr_id);
        // if left attr doesn't exist, make an empty arraylist
        if (!entry.found_existing) {
            entry.value_ptr.* = std.ArrayList(i32).init(allocator);
        }
        try entry.value_ptr.append(link.right_attr_id);
    }

    // construct port_id -> node pointer
    var port_to_node = std.AutoHashMap(i32, *node.Node).init(allocator);

    for (self.nodes.items) |*n| {
        switch (n.kind) {
            .spawner => |*s| try port_to_node.put(s.target.id, n),
            .sink => |*s| try port_to_node.put(s.from.id, n),
            .area => |*a| {
                try port_to_node.put(a.from.id, n);
                try port_to_node.put(a.target.id, n);
            },
        }
    }

    // Traverse from each spawner
    var visited = std.AutoHashMap(i32, void).init(allocator);

    for (self.nodes.items) |*n| {
        if (n.kind == .spawner) {
            std.debug.print("\n=== Starting from {s} ===\n", .{n.name});
            try self.traverseFrom(n.kind.spawner.target.id, &adjacency, &port_to_node, &visited);
        }
    }
}

fn traverseFrom(
    self: Self,
    port_id: i32,
    adjacency: *std.AutoHashMap(i32, std.ArrayList(i32)),
    port_to_node: *std.AutoHashMap(i32, *node.Node),
    visited: *std.AutoHashMap(i32, void),
) !void {
    if (visited.contains(port_id)) return;
    visited.put(port_id, {}) catch unreachable;

    // Get connected ports
    if (adjacency.get(port_id)) |connected_ports| {
        for (connected_ports.items) |next_port_id| {
            if (port_to_node.get(next_port_id)) |next_node| {
                std.debug.print("  -> Connected to node {s} (id={})\n", .{ next_node.name, next_node.id });

                // Continue traversal from output ports of this node
                switch (next_node.kind) {
                    .area => |*a| try self.traverseFrom(a.target.id, adjacency, port_to_node, visited),
                    .spawner => |*s| try self.traverseFrom(s.target.id, adjacency, port_to_node, visited),
                    .sink => {}, // Terminal node
                }
            }
        }
    }
}
