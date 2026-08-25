const Self = @This();
const std = @import("std");
const rl = @import("raylib");
const Environment = @import("environment/Environment.zig");
const UUID = @import("UUID.zig");
const SimData = @import("editor/SimData.zig");
const palette = @import("palette.zig");
const delaunay = @import("delaunay.zig");

// !!! DON'T FUCKING USE POINTERS TO ARRAYLIST ITEMS! THE FUCKING ARRAYLIST
// REALLOCATES SO YOU'RE LEFT WITH A FUCKING DANGLING FUCKING POINTER ! USE INDICES INSTEAD !!!
// ...
// what did Pathfinding.zig do to you bro tell that to the Agent file

// "vertices" are the original obstacle corners, "edges" are all connections of those obstacles.
// We populate this and pass them to the triangulator
triangles: std.ArrayList(delaunay.Triangle),
obstacle_vertices: std.ArrayList(rl.Vector2),
obstacle_edges: std.ArrayList(delaunay.Edge),
// these are the final pathfinding graph structures
vertices: std.ArrayList(rl.Vector2),
edges: std.ArrayList(delaunay.Edge),

pub fn init() Self {
    return .{
        .triangles = .empty,
        .obstacle_vertices = .empty,
        .obstacle_edges = .empty,
        .vertices = .empty,
        .edges = .empty,
    };
}

pub fn deinit(self: *Self, alloc: std.mem.Allocator) void {
    self.triangles.deinit(alloc);
    self.obstacle_vertices.deinit(alloc);
    self.obstacle_edges.deinit(alloc);
    self.vertices.deinit(alloc);
    self.edges.deinit(alloc);
}

pub fn draw(self: Self, sim_data: SimData) void {
    if (sim_data.show_pathfinding) {
        // render navmesh
        for (self.triangles.items) |tri| {
            rl.drawTriangleLines(
                self.obstacle_vertices.items[tri.p1],
                self.obstacle_vertices.items[tri.p2],
                self.obstacle_vertices.items[tri.p3],
                palette.env.yellow,
            );
        }
        // render graph
        for (self.vertices.items) |vertex| {
            rl.drawCircleV(vertex, 4, palette.env.yellow);
        }
    }
}

pub fn rebuildGraph(self: *Self, alloc: std.mem.Allocator, env: *Environment) !void {
    self.obstacle_vertices.clearRetainingCapacity();
    self.obstacle_edges.clearRetainingCapacity();
    self.vertices.clearRetainingCapacity();
    self.edges.clearRetainingCapacity();

    var obstacle_polys: std.ArrayList([]const rl.Vector2) = .empty;
    defer obstacle_polys.deinit(alloc);

    // generate the obstacles vertices and edges from the environment data
    var base: usize = 0;
    for (env.entities.items()) |ent| {
        switch (ent.kind) {
            .contour => |c| {
                if (c.placed) {
                    const closed = c.points.items[0].equals(c.points.items[c.points.items.len - 1]);
                    const n: usize = if (closed) c.points.items.len - 1 else c.points.items.len;

                    // get the slice of points for this obstacle
                    const start_idx = self.obstacle_vertices.items.len;
                    for (c.points.items[0..n]) |point| {
                        try self.obstacle_vertices.append(alloc, point);
                    }

                    // register this polygon slice
                    try obstacle_polys.append(alloc, self.obstacle_vertices.items[start_idx .. start_idx + n]);

                    const seg_count = if (closed) n else n - 1;
                    var i: usize = 0;
                    while (i < seg_count) : (i += 1) {
                        try self.obstacle_edges.append(alloc, .{
                            .p1 = base + i,
                            .p2 = base + (i + 1) % n,
                        });
                    }
                    base += n;
                }
            },
            else => {},
        }
    }

    // save the bounding box corners (not part of any obstacle polygon)
    try self.obstacle_vertices.append(alloc, .init(0, 0));
    try self.obstacle_vertices.append(alloc, .init(990, 0));
    try self.obstacle_vertices.append(alloc, .init(990, 990));
    try self.obstacle_vertices.append(alloc, .init(0, 990));

    // triangulate
    var result = try delaunay.triangulateConstrained(
        alloc,
        self.obstacle_vertices.items,
        self.obstacle_edges.items,
    );
    defer result.deinit(alloc);
    try delaunay.filterObstacleTriangles(alloc, &result, self.obstacle_vertices.items, obstacle_polys.items);

    // create the triangles
    self.triangles.clearRetainingCapacity();
    for (result.triangles.items) |tri| {
        try self.triangles.append(alloc, tri);
    }

    // create the vertices from the center of the triangles
    for (self.triangles.items) |tri| {
        const p1 = self.obstacle_vertices.items[tri.p1];
        const p2 = self.obstacle_vertices.items[tri.p2];
        const p3 = self.obstacle_vertices.items[tri.p3];

        try self.vertices.append(alloc, .{
            .x = (p1.x + p2.x + p3.x) / 3.0,
            .y = (p1.y + p2.y + p3.y) / 3.0,
        });
    }

    std.debug.print("{}\n", .{result.triangles.items.len});
}
