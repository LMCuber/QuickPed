const Self = @This();
const node = @import("node.zig");
const std = @import("std");
const Agent = @import("../Agent.zig");
const imnodes = @import("imnodesez");

allocator: std.mem.Allocator,
nodes: std.ArrayList(node.Node),
connections: std.ArrayList(node.Connection),

pub fn init(allocator: std.mem.Allocator) Self {
    return .{
        .allocator = allocator,
        .nodes = std.ArrayList(node.Node).init(allocator),
        .connections = std.ArrayList(node.Connection).init(allocator),
    };
}

pub fn deinit(self: *Self) void {
    self.nodes.deinit();
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

pub fn processSpawners(self: *Self, agents: *std.ArrayList(Agent)) !void {
    for (self.nodes.items) |*n| {
        switch (n.kind) {
            .spawner => |*spawner| try spawner.update(agents, self, n),
            inline else => {},
        }
    }
}

pub fn getNextNode(self: Self, current_node: *node.Node) ?*node.Node {
    // get correct port ID from current node
    const current_title: [*c]const u8 = switch (current_node.kind) {
        .spawner => |s| s.output_slots[0].title,
        .area => |a| a.output_slots[0].title,
        .fork => |f| f.getOutputSlotTitle(),
        .sink => null,
    };

    // construct current (output) slot
    const current_output_slot: node.Slot = .{ .node = current_node, .title = current_title };

    // find connection where the its output slot is same as this output slot
    for (self.connections.items) |conn| {
        if (current_output_slot.equals(conn.output_slot)) {
            return conn.input_slot.node;
        }
    }

    // no connection found
    return null;
}
