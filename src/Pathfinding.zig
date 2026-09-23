const Self = @This();
const std = @import("std");
const assert = std.debug.assert;
const rl = @import("raylib");
const Environment = @import("environment/Environment.zig");
const UUID = @import("UUID.zig");
const SimData = @import("editor/SimData.zig");
const palette = @import("palette.zig");
const delaunay = @import("delaunay.zig");
const astar = @import("astar.zig");

// !!! DON'T FUCKING USE POINTERS TO ARRAYLIST ITEMS! THE FUCKING ARRAYLIST
// REALLOCATES SO YOU'RE LEFT WITH A FUCKING DANGLING FUCKING POINTER ! USE INDICES INSTEAD !!!
// ...
// what did Pathfinding.zig do to you bro tell that to the Agent file

// "vertices" are the original obstacle corners, "edges" are all connections of those obstacles.
// We populate this and pass them to the triangulator
triangles: std.ArrayList(delaunay.Triangle),
obstacle_vertices: std.ArrayList(rl.Vector2),
obstacle_edges: std.ArrayList(delaunay.Edge),

// ! final pathfinding graph structures !
// all node objects
nodes: std.ArrayList(Node),
// maps edge to the triangle index (used to keep track of what triangle owns what edge,
// and then creates connection between the triangles if the edges coincide)
edge_map: std.AutoHashMap(delaunay.Edge, usize),

pub const Edge = struct {
    a: rl.Vector2,
    b: rl.Vector2,
};

pub const Node = struct {
    pos: rl.Vector2,
    neighbors: std.ArrayList(usize),

    pub fn init(pos: rl.Vector2, neighbors: std.ArrayList(usize)) @This() {
        return .{
            .pos = pos,
            .neighbors = neighbors,
        };
    }

    pub fn deinit(self: *@This(), alloc: std.mem.Allocator) void {
        self.neighbors.deinit(alloc);
    }
};

pub const ExtraNodes = struct {
    source: Node,
    target: Node,

    pub fn init(source: Node, target: Node) @This() {
        return .{
            .source = source,
            .target = target,
        };
    }

    pub fn deinit(self: *@This(), alloc: std.mem.Allocator) void {
        self.source.deinit(alloc);
        self.target.deinit(alloc);
    }
};

pub fn init(alloc: std.mem.Allocator) !Self {
    return .{
        .triangles = .empty,
        .obstacle_vertices = .empty,
        .obstacle_edges = .empty,
        .nodes = .empty,
        .edge_map = .init(alloc),
    };
}

pub fn deinit(self: *Self, alloc: std.mem.Allocator) void {
    self.triangles.deinit(alloc);
    self.obstacle_vertices.deinit(alloc);
    self.obstacle_edges.deinit(alloc);
    self.edge_map.deinit();

    for (self.nodes.items) |*node| {
        node.deinit(alloc);
    }
    self.nodes.deinit(alloc);
}

pub fn draw(self: Self, sim_data: SimData) void {
    if (sim_data.show_pathfinding) {
        // render navmesh
        for (self.triangles.items) |tri| {
            rl.drawTriangleLines(
                self.obstacle_vertices.items[tri.p1],
                self.obstacle_vertices.items[tri.p2],
                self.obstacle_vertices.items[tri.p3],
                palette.env.yellow_t,
            );
        }
        // render graph and connections
        for (self.nodes.items) |node| {
            // node
            rl.drawCircleV(node.pos, 4, palette.env.yellow);
            // connections
            for (node.neighbors.items) |nei_index| {
                const nei_node = self.nodes.items[nei_index];
                rl.drawLineV(node.pos, nei_node.pos, palette.env.green);
            }
        }
    }
}

const UserContext = struct {
    nodes: *std.ArrayList(Node),

    pub fn init(nodes: *std.ArrayList(Node)) @This() {
        return .{ .nodes = nodes };
    }

    pub fn cost(self: @This(), a: usize, b: usize) f32 {
        return rl.math.vector2Distance(self.nodes.items[a].pos, self.nodes.items[b].pos);
    }

    pub fn heuristic(self: @This(), node: usize, goal: usize) f32 {
        return self.cost(node, goal);
    }

    pub fn neighbors(self: @This(), node: usize) []usize {
        return self.nodes.items[node].neighbors.items;
    }
};

pub fn find(
    self: *Self,
    alloc: std.mem.Allocator,
    path: *std.ArrayList(Edge),
    start_pos: rl.Vector2,
    end_pos: rl.Vector2,
    env: *Environment,
) !void {
    var extra_nodes: ExtraNodes = .init(
        .init(start_pos, .empty),
        .init(end_pos, .empty),
    );
    defer extra_nodes.deinit(alloc);

    var path_vertices: std.ArrayList(rl.Vector2) = .empty;
    defer path_vertices.deinit(alloc);

    // find what connection to make based on in which triangle the points reside
    var start_index: ?usize = null;
    var end_index: ?usize = null;
    for (self.triangles.items, 0..) |tri, node_index| {
        // create slice for the polygon vertices
        const poly = [3]rl.Vector2{
            self.obstacle_vertices.items[tri.p1],
            self.obstacle_vertices.items[tri.p2],
            self.obstacle_vertices.items[tri.p3],
        };

        // check if the start and end point(s) is/are inside this polygon
        if (start_index == null and delaunay.isPointInPolygon(start_pos, &poly)) {
            // since this pos is in this polygon, the start node is this polygon
            start_index = node_index;
        }
        if (end_index == null and delaunay.isPointInPolygon(end_pos, &poly)) {
            end_index = node_index;
        }
        if (start_index != null and end_index != null) break;
    }
    // they need to be SOMEWHERE
    assert(start_index != null and end_index != null);

    // find the shortest path from start to end
    const user_ctx: UserContext = .{ .nodes = &self.nodes };

    var index_path: std.ArrayList(usize) = .empty;
    defer index_path.deinit(alloc);
    try astar.find(
        usize,
        alloc,
        start_index.?,
        end_index.?,
        &index_path,
        user_ctx,
    );

    // now we have the triangle indices, let's convert those to concrete points
    for (index_path.items, 0..) |tri_index_a, i| {
        if (i == index_path.items.len - 1) continue;

        // for each successing triangle, find their shared edge
        const tri_index_b: usize = index_path.items[i + 1];
        const tri_a = self.triangles.items[tri_index_a];
        const tri_b = self.triangles.items[tri_index_b];

        // check where the two vertices overlap
        var num_overlap: usize = 0;
        var final_edge: [2]rl.Vector2 = undefined;
        const a_vertices: [3]rl.Vector2 = .{
            self.obstacle_vertices.items[tri_a.p1],
            self.obstacle_vertices.items[tri_a.p2],
            self.obstacle_vertices.items[tri_a.p3],
        };
        const b_vertices: [3]rl.Vector2 = .{
            self.obstacle_vertices.items[tri_b.p1],
            self.obstacle_vertices.items[tri_b.p2],
            self.obstacle_vertices.items[tri_b.p3],
        };
        outer: for (a_vertices) |va| {
            for (b_vertices) |vb| {
                if (va.equals(vb)) {
                    final_edge[num_overlap] = va;
                    num_overlap += 1;
                }
                if (num_overlap == 2) {
                    break :outer;
                }
            }
        }
        assert(num_overlap == 2); // they must overlap SOMEWHERE
        const center = final_edge[0].add(final_edge[1]).scale(0.5);
        try path_vertices.append(alloc, center);
    }

    // add the target the path (this wasn't in the navmesh so also not in the pathfinding)
    try path_vertices.append(alloc, end_pos);

    // remove unnecessary lines by checking line of sight for every
    var current_index: usize = 0;
    var write_index: usize = 1;
    var test_index: usize = 2;
    while (test_index < path_vertices.items.len) : (test_index += 1) {
        const start_pt = path_vertices.items[current_index];
        const candidate_pt = path_vertices.items[test_index];

        const line = hasLineOfSight(start_pt, candidate_pt, env);
        if (line) {
            continue;
        } else {
            // the point before test_index is needed so we save it
            const corner_index = test_index - 1;
            path_vertices.items[write_index] = path_vertices.items[corner_index];
            current_index = corner_index;
            write_index += 1;
        }
    }
    path_vertices.items[write_index] = path_vertices.items[path_vertices.items.len - 1];
    write_index += 1;

    try path_vertices.resize(alloc, write_index);

    // create the path edges
    for (path_vertices.items, 0..) |pos, i| {
        if (i == path_vertices.items.len - 1) continue;
        try path.append(alloc, .{
            .a = pos,
            .b = path_vertices.items[i + 1],
        });
    }
}

fn hasLineOfSight(a: rl.Vector2, b: rl.Vector2, env: *Environment) bool {
    for (env.entities.items()) |ent| {
        switch (ent.kind) {
            .contour => |c| {
                for (c.points.items, 0..) |p1, i| {
                    if (i == c.points.items.len - 1) continue;
                    const p2 = c.points.items[i + 1];
                    var _collision_point: rl.Vector2 = .zero(); // throwaway
                    if (rl.checkCollisionLines(a, b, p1, p2, &_collision_point)) {
                        return false;
                    }
                }
            },
            else => {},
        }
    }
    return true;
}

pub fn rebuildGraph(self: *Self, alloc: std.mem.Allocator, env: *Environment) !void {
    // reset collections
    self.obstacle_vertices.clearRetainingCapacity();
    self.obstacle_edges.clearRetainingCapacity();
    self.edge_map.clearRetainingCapacity();
    for (self.nodes.items) |*node| {
        node.neighbors.deinit(alloc);
    }
    self.nodes.clearRetainingCapacity();

    // start algorithm
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

                    // extend all obstacle vertices by all the vertices in this contour's points
                    for (c.points.items[0..n]) |point| {
                        try self.obstacle_vertices.append(alloc, point);
                    }

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

    base = 0;
    for (env.entities.items()) |ent| {
        switch (ent.kind) {
            .contour => |c| {
                if (c.placed) {
                    const closed = c.points.items[0].equals(c.points.items[c.points.items.len - 1]);
                    const n: usize = if (closed) c.points.items.len - 1 else c.points.items.len;
                    try obstacle_polys.append(alloc, self.obstacle_vertices.items[base .. base + n]);
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

        try self.nodes.append(alloc, .{
            .pos = .{
                .x = (p1.x + p2.x + p3.x) / 3.0,
                .y = (p1.y + p2.y + p3.y) / 3.0,
            },
            .neighbors = .empty,
        });
    }

    // create hashmap from Edge -> triangle index (usize)
    // we iterate over all edges of all triangles, and it the edge is already in the map,
    // it means that we have a connection (the edge is already owned by another triangle)
    // NOTE: triangle index coincides with node index!!
    for (self.triangles.items, 0..) |tri, i| {
        // create direction agnostic edges
        const edges: [3]delaunay.Edge = .{
            .init(tri.p1, tri.p2),
            .init(tri.p2, tri.p3),
            .init(tri.p3, tri.p1),
        };
        for (edges) |edge| {
            const gop = try self.edge_map.getOrPut(edge);
            if (gop.found_existing) {
                // the edge already belongs to a different triangle, so create connection
                // between the two triangles
                const adj_tri_index = gop.value_ptr.*;
                try self.nodes.items[i].neighbors.append(alloc, adj_tri_index);
                try self.nodes.items[adj_tri_index].neighbors.append(alloc, i);
            } else {
                // claim the triangle index of this particular edge
                gop.value_ptr.* = i;
            }
        }
    }

    // std.debug.print("{}\n", .{result.triangles.items.len});
}
