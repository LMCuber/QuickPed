const Self = @This();
const std = @import("std");
const rl = @import("raylib");
const Environment = @import("environment/Environment.zig");
const UUID = @import("UUID.zig");
const SimData = @import("editor/SimData.zig");
const palette = @import("palette.zig");

// !!! DON'T FUCKING USE POINTERS TO ARRAYLIST ITEMS! THE FUCKING ARRAYLIST
// REALLOCATES SO YOU'RE LEFT WITH A FUCKING DANGLING FUCKING POINTER ! USE INDICES INSTEAD !!!

const Vertex = struct {
    pos: rl.Vector2,
    source: UUID,
};
const Edge = struct {
    a: usize,
    b: usize,
};

vertices: std.ArrayList(Vertex),
edges: std.ArrayList(Edge),

pub fn init() Self {
    return .{
        .vertices = .empty,
        .edges = .empty,
    };
}

pub fn deinit(self: *Self, alloc: std.mem.Allocator) void {
    self.vertices.deinit(alloc);
    self.edges.deinit(alloc);
}

pub fn draw(self: Self, sim_data: SimData) void {
    if (sim_data.show_pathfinding) {
        // render all individual vertices of the graph
        for (self.edges.items) |edge| {
            const vec_a = self.vertices.items[edge.a].pos;
            const vec_b = self.vertices.items[edge.b].pos;
            rl.drawLineEx(vec_a, vec_b, 4, palette.env.orange);
            rl.drawCircleLinesV(vec_a, 10, palette.env.yellow);
            rl.drawCircleLinesV(vec_b, 10, palette.env.yellow);
        }
    }
}

pub fn rebuildGraph(self: *Self, _: std.mem.Allocator, _: *Environment) !void {
    // first get union of all vertices
    self.vertices.clearRetainingCapacity();
    self.edges.clearRetainingCapacity();
}
