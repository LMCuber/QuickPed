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

pub fn rebuildGraph(self: *Self, alloc: std.mem.Allocator, env: *Environment) !void {
    // first get union of all vertices
    self.vertices.clearRetainingCapacity();
    self.edges.clearRetainingCapacity();

    // add all vertices and inter-entity edges to the graph
    var vertex_index: usize = 0;
    for (env.entities.items()) |ent| {
        switch (ent.kind) {
            .contour => |c| {
                for (c.path_edges.items) |edge| {
                    // add the vertices
                    try self.vertices.append(alloc, .{
                        .pos = edge[0],
                        .source = ent.uuid,
                    });
                    try self.vertices.append(alloc, .{
                        .pos = edge[1],
                        .source = ent.uuid,
                    });

                    // add the edges
                    try self.edges.append(alloc, .{
                        .a = vertex_index,
                        .b = vertex_index + 1,
                    });

                    vertex_index += 2;
                }
            },
            else => {},
        }
    }

    // now check for EACH vertex pair if ANY edge from any polygon collides with it.
    // If no collisions, make that connection.
    // O(n ^ 2 * m), where n = #vertices, m = #edges

    // only test j < i to cover every unordered pair exactly once,
    // and naturally excludes the i == j self-pair
    var i: usize = self.vertices.items.len;
    while (i > 0) {
        i -= 1;
        const vertex = self.vertices.items[i];

        // iterate over all possible pairs now to find any possible connection :(
        inner_vertex_loop: for (self.vertices.items[0..i], 0..) |inner_vertex, j| {
            // ignore vertices that come from same source since they're already connected
            if (vertex.source.equals(inner_vertex.source)) continue;

            // check if any entity is in the way of this particular pair
            for (env.entities.items()) |entity| {
                // try to find any entity in the way
                switch (entity.kind) {
                    .contour => |c| {
                        // an entity is in the way; don't save this edge; continue to next pair
                        if (c.collideRay(vertex.pos, inner_vertex.pos)) {
                            std.debug.print("{}|{}\n", .{ vertex.pos, inner_vertex.pos });
                            continue :inner_vertex_loop;
                        }
                    },
                    else => {},
                }
            }
            // no collisions found after checking all entities - add this pair to the graph!
            try self.edges.append(alloc, .{ .a = i, .b = j });
        }
    }
}
