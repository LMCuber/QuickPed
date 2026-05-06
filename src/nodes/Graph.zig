const Self = @This();
const std = @import("std");
const Agent = @import("../Agent.zig");
const entity = @import("../environment/entity.zig");
const imnodes = @import("imnodesez");
const commons = @import("../commons.zig");
const node = @import("node.zig");
const Environment = @import("../environment/Environment.zig");
const Manager = @import("../Manager.zig").Manager;
const UUID = @import("../UUID.zig");

pub const NodeManager: type = Manager(node.Node);

allocator: std.mem.Allocator,
nodes: NodeManager,
connections: std.ArrayList(node.Connection),

pub const GraphSnapshot = struct {
    version: []const u8,

    nodes: []const node.NodeSnapshot,
    connections: []const node.ConnectionSnapshot,
};

pub fn init(allocator: std.mem.Allocator) Self {
    return .{
        .allocator = allocator,
        .nodes = Manager(node.Node).init(allocator),
        .connections = .empty,
    };
}

pub fn deinit(self: *Self, alloc: std.mem.Allocator) void {
    for (self.connections.items) |*conn| conn.deinit(alloc);
    self.connections.deinit(alloc);
    self.nodes.deinit(alloc);
}

pub fn addNode(self: *Self, alloc: std.mem.Allocator, n: node.Node) !void {
    // creates node and positions it inside the canvas
    // ONLY CALL WHEN CANVAS EXISTS!
    try self.nodes.append(alloc, n);
    imnodes.autoPositionNode(self.nodes.getByUUID(n.uuid));
}

pub fn deleteNode(self: *Self, alloc: std.mem.Allocator, node_id: UUID) !void {
    // delete the connections connecting to that node (output and input)
    var i: usize = self.connections.items.len;
    while (i > 0) {
        i -= 1;
        var conn = self.connections.items[i];
        if (conn.output_slot.node_id.equals(node_id) or conn.input_slot.node_id.equals(node_id)) {
            conn.deinit(alloc);
            _ = self.connections.swapRemove(i);
        }
    }
    // delete the node
    try self.nodes.deleteByUUID(node_id);
}

pub fn addConnection(
    self: *Self,
    alloc: std.mem.Allocator,
    output_slot: node.Slot,
    input_slot: node.Slot,
) !void {
    try self.connections.append(alloc, .{
        .output_slot = output_slot,
        .input_slot = input_slot,
    });
}

pub fn processSpawners(self: *Self, alloc: std.mem.Allocator, env: *Environment) !void {
    for (self.nodes.items()) |*n| {
        switch (n.kind) {
            .spawner => |*spawner| try spawner.update(alloc, n, self, env),
            else => {},
        }
    }
}

pub fn getNextNodeId(self: *Self, alloc: std.mem.Allocator, current_node_id: UUID) !?UUID {
    const current_node: *node.Node = self.nodes.getByUUID(current_node_id);

    // get correct port ID from current node
    const current_title: [*c]const u8 = switch (current_node.kind) {
        inline .fork => |f| f.getOutputSlotTitle(),
        .sink => null,
        inline else => |kind| kind.output_slots[0].title,
    };

    // construct current (output) slot
    // as a combination of (node_ptr, title)
    // (we need allocator since it needs to create a [:0] from a [*c])
    var current_output_slot: node.Slot = try node.Slot.init(alloc, current_node_id, current_title);
    defer current_output_slot.deinit(alloc);

    // all nodes except for the queue fork give a singular child node
    switch (current_node.kind) {
        .queue_fork => |*qf_node| return try qf_node.getQueueNodeId(
            alloc,
            current_output_slot,
            &self.nodes,
            &self.connections,
        ),
        // find connection whose output slot is same as current node's output slot
        else => for (self.connections.items) |*conn| {
            if (current_output_slot.equals(conn.output_slot)) {
                return conn.input_slot.node_id;
            }
        },
    }

    // no connection found
    return null;
}

pub fn saveNodes(self: *Self, alloc: std.mem.Allocator, io: std.Io, path: []const u8) !void {
    var conn_snaps: std.ArrayList(node.ConnectionSnapshot) = .empty;
    defer conn_snaps.deinit(alloc);

    var node_snaps: std.ArrayList(node.NodeSnapshot) = .empty;
    defer node_snaps.deinit(alloc);

    for (self.nodes.items()) |*n| try node_snaps.append(alloc, n.getSnapshot());
    for (self.connections.items) |conn| try conn_snaps.append(alloc, conn.getSnapshot());

    const graph_snap: GraphSnapshot = .{
        .version = "0.1.0",
        .nodes = node_snaps.items,
        .connections = conn_snaps.items,
    };

    try commons.writeFile(alloc, io, graph_snap, path);
}

pub fn loadNodes(
    self: *Self,
    alloc: std.mem.Allocator,
    io: std.Io,
    path: []const u8,
    env: *Environment,
) !void {
    // parse file into JSON
    const json = try commons.readFile(alloc, io, path);
    defer alloc.free(json);

    // empty existing graph G = (V, E)
    self.nodes.clear();
    self.connections.clearRetainingCapacity();

    // if there is nothing in the file, return and don't load anything in
    if (json.len == 0) {
        return;
    }

    // get parsed scene
    const parsed = try std.json.parseFromSlice(GraphSnapshot, alloc, json, .{});
    defer parsed.deinit();
    const graph: GraphSnapshot = parsed.value;

    // repopulate nodes and connections
    for (graph.nodes) |node_snap|
        try self.nodes.append(alloc, node.Node.fromSnapshot(node_snap, env));

    // connect shit
    for (graph.connections) |conn_snap|
        try self.connections.append(alloc, try node.Connection.fromSnapshot(alloc, conn_snap));
}
