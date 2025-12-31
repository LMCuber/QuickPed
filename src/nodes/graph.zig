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
