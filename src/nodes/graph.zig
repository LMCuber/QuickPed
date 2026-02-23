const Self = @This();
const std = @import("std");
const Agent = @import("../Agent.zig");
const imnodes = @import("imnodesez");
const commons = @import("../commons.zig");
const node = @import("node.zig");
const Environment = @import("../environment/Environment.zig");

allocator: std.mem.Allocator,
nodes: std.ArrayList(node.Node),
connections: std.ArrayList(node.Connection),

pub const GraphSnapshot = struct {
    version: []const u8,

    nodes: []const node.NodeSnapshot,
    connections: []const node.ConnectionSnapshot,
    next_node_id: i32,
};

pub fn init(allocator: std.mem.Allocator) Self {
    return .{
        .allocator = allocator,
        .nodes = std.ArrayList(node.Node).init(allocator),
        .connections = std.ArrayList(node.Connection).init(allocator),
    };
}

pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    self.nodes.deinit();
    for (self.connections.items) |*conn| {
        conn.input_slot.deinit(allocator);
        conn.output_slot.deinit(allocator);
    }
    self.connections.deinit();
}

pub fn addNode(self: *Self, n: node.Node) !void {
    try self.nodes.append(n);
    imnodes.autoPositionNode(&self.nodes.items[self.nodes.items.len - 1]);
}

pub fn addConnection(
    self: *Self,
    output_slot: node.Slot,
    input_slot: node.Slot,
) !void {
    try self.connections.append(.{
        .output_slot = output_slot,
        .input_slot = input_slot,
    });
}

pub fn processSpawners(self: *Self, alloc: std.mem.Allocator, agents: *std.ArrayList(Agent)) !void {
    for (self.nodes.items) |*n| {
        switch (n.kind) {
            .spawner => |*spawner| try spawner.update(alloc, agents, self, n),
            inline else => {},
        }
    }
}

pub fn getNextNode(self: Self, alloc: std.mem.Allocator, current_node: *node.Node) !?*node.Node {
    // get correct port ID from current node
    const current_title: [*c]const u8 = switch (current_node.kind) {
        .spawner => |s| s.output_slots[0].title,
        .area => |a| a.output_slots[0].title,
        .fork => |f| f.getOutputSlotTitle(),
        .sink => null,
    };

    // construct current (output) slot
    // as a combination of (node_ptr, title)
    // we need allocator since it needs a [:0] from a [*c] now
    var current_output_slot: node.Slot = try node.Slot.init(
        alloc,
        current_node,
        current_title,
    );
    defer current_output_slot.deinit(alloc);

    // find connection where the its output slot is same as this output slot
    for (self.connections.items) |conn| {
        if (current_output_slot.equals(conn.output_slot)) {
            return conn.input_slot.node;
        }
    }

    // no connection found
    return null;
}

pub fn saveNodes(
    self: *Self,
    allocator: std.mem.Allocator,
    path: []const u8,
) !void {
    var conn_snaps = std.ArrayList(node.ConnectionSnapshot).init(allocator);
    defer conn_snaps.deinit();
    var node_snaps = std.ArrayList(node.NodeSnapshot).init(allocator);
    defer node_snaps.deinit();

    for (self.nodes.items) |n| {
        try node_snaps.append(n.getSnapshot());
    }
    for (self.connections.items) |conn| {
        try conn_snaps.append(conn.getSnapshot());
    }

    const graph_snap: GraphSnapshot = .{
        .version = "0.1.0",
        .nodes = node_snaps.items,
        .connections = conn_snaps.items,
        .next_node_id = node.Node.next_id,
    };

    // create buffer to write the snap data into as JSON
    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();

    try std.json.stringify(graph_snap, .{ .whitespace = .indent_2 }, buf.writer());

    // create file it it doesn't exist
    const file = try std.fs.cwd().createFile(path, .{ .truncate = true });
    defer file.close();
    try file.writeAll(buf.items);
}

pub fn loadNodes(
    self: *Self,
    allocator: std.mem.Allocator,
    path: []const u8,
    env: *Environment,
) !void {
    // parse file into JSON
    const json = try commons.readFile(allocator, path);
    defer allocator.free(json);

    // empty existing graph G = (V, E)
    self.nodes.clearRetainingCapacity();
    self.connections.clearRetainingCapacity();

    // if there is nothing in the file, return and don't load anything in
    if (json.len == 0) {
        return;
    }

    // get parsed scene
    const parsed = try std.json.parseFromSlice(
        GraphSnapshot,
        allocator,
        json,
        .{},
    );
    defer parsed.deinit();
    const graph: GraphSnapshot = parsed.value;

    // set the saved last ids
    node.Node.next_id = graph.next_node_id;

    // repopulate nodes and connections
    for (graph.nodes) |node_snap| {
        try self.nodes.append(node.Node.fromSnapshot(node_snap, env));
    }

    for (graph.connections) |conn_snap| {
        try self.connections.append(try node.Connection.fromSnapshot(
            allocator,
            conn_snap,
            &self.nodes,
        ));
    }
}
