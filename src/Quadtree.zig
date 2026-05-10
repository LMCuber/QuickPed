const Self = @This();

const std = @import("std");
const rl = @import("raylib");
const Environment = @import("environment/Environment.zig");
const palette = @import("palette.zig");

pub const Node = struct {
    rect: rl.Rectangle,
    points: std.ArrayList(rl.Vector2),
    children: ?*[4]Node = null, // opt. POINTER to an array of 4 nodes!!

    pub fn getQuadrantIndex(self: *Node, point: rl.Vector2) usize {
        const mid_x = self.rect.x + self.rect.width * 0.5;
        const mid_y = self.rect.y + self.rect.height * 0.5;

        const is_right: usize = @intFromBool(point.x >= mid_x);
        var is_bottom: usize = @intFromBool(point.y >= mid_y);
        is_bottom <<= 1;

        // topleft: 00, topright: 01, bottomleft: 10, bottomright: 11
        return is_right | is_bottom;
    }
};

arena: std.heap.ArenaAllocator,
root: ?*Node = null,
cap: usize = 4,

pub fn init(backing_alloc: std.mem.Allocator, cap: usize) Self {
    return .{
        .arena = std.heap.ArenaAllocator.init(backing_alloc),
        .root = null,
        .cap = cap,
    };
}

pub fn deinit(self: *Self) void {
    self.arena.deinit();
}

fn teardown(self: *Self) void {
    self.arena.deinit();
    self.root = null;
    self.arena = std.heap.ArenaAllocator.init(self.arena.child_allocator);
}

pub fn rebuild(
    self: *Self,
    alloc: std.mem.Allocator,
    agents: *Environment.AgentManager,
    bounds: rl.Rectangle,
) !void {
    self.teardown();

    const allocator = self.arena.allocator();
    self.root = try allocator.create(Node);
    self.root.?.* = .{
        .rect = bounds,
        .points = .empty,
        .children = null,
    };

    for (agents.items()) |*agent| {
        try self.insert(alloc, self.root.?, agent.pos);
    }
}

fn insert(self: *Self, alloc: std.mem.Allocator, node: *Node, point: rl.Vector2) !void {
    // if node is leaf and has room for more, just add it
    if (node.children == null and node.points.items.len < self.cap) {
        try node.points.append(alloc, point);
        return;
    }

    // if is leaf but is full, split it!
    if (node.children == null and node.points.items.len >= self.cap)
        try self.splitNode(alloc, node);

    // else: it is not leaf, so we need to traverse further
    if (node.children) |children| {
        const quad_index = node.getQuadrantIndex(point);
        return self.insert(alloc, &children[quad_index], point);
    }
}

fn splitNode(self: *Self, alloc: std.mem.Allocator, node: *Node) !void {
    const allocator = self.arena.allocator();

    // create the 4 children
    const children = try allocator.create([4]Node);
    const half_w = node.rect.width * 0.5;
    const half_h = node.rect.height * 0.5;
    const x = node.rect.x;
    const y = node.rect.y;
    const rects = [4]rl.Rectangle{
        .init(x, y, half_w, half_h), // topleft
        .init(x + half_w, y, half_w, half_h), // topright
        .init(x, y + half_h, half_w, half_h), // bottomleft
        .init(x + half_w, y + half_h, half_w, half_h), // bottomright
    };

    // for each children, make a new node with the previously made rects
    for (rects, 0..) |rect, i|
        children[i] = .{
            .rect = rect,
            .points = .empty,
            .children = null,
        };

    // set the children of the current node to the ones we just created
    node.children = children;

    // redistribute the existing points from parent to the correct child
    for (node.points.items) |point| {
        const quad_index = node.getQuadrantIndex(point);
        try node.children.?[quad_index].points.append(alloc, point);
    }
}

pub fn render(self: *Self) void {
    if (self.root) |root| {
        draw(root);
    }
}

fn draw(node: *Node) void {
    // draw the rectangle
    const thick = 0.5;
    rl.drawRectangleLinesEx(node.rect, thick, palette.env.yellow);

    // recursive step
    if (node.children) |children|
        for (children) |*child|
            draw(child);
}

pub fn query(
    self: *Self,
    alloc: std.mem.Allocator,
    point: rl.Vector2,
    aabb: rl.Rectangle,
    out: *std.ArrayList(rl.Vector2),
) !void {
    // get all points from all quads which collide with the aabb
    try traverse(alloc, self.root, point, aabb, out);
}

fn traverse(
    alloc: std.mem.Allocator,
    opt_node: ?*Node,
    point: rl.Vector2,
    aabb: rl.Rectangle,
    out: *std.ArrayList(rl.Vector2),
) !void {
    // base case
    if (opt_node == null) return;

    // check if the current quad collides with the hitbox
    if (opt_node) |node| {
        if (rl.checkCollisionRecs(aabb, node.rect)) {
            // if has no children, means that it is leaf so we add the points
            if (node.children == null) {
                for (node.points.items) |p| try out.append(alloc, p);
                return;
            }

            // if has children, recurse to them
            for (&node.children.?.*) |*child|
                try traverse(alloc, child, point, aabb, out);
        }
    }
}
