// *CONSTRAINED* DELAUNAY TRIANGULATION (CDT)
// LLM GENERATED SINCE I'M NOT A MATHEMATICIAN
// HELL NAH I AIN'T HANDROLLING MY OWN DELAUNAY TRIANGULATION ALGORITHM

const std = @import("std");
const rl = @import("raylib");

pub const Triangle = struct {
    p1: usize,
    p2: usize,
    p3: usize,
};

pub const Edge = struct {
    p1: usize,
    p2: usize,

    pub fn eql(a: Edge, b: Edge) bool {
        return (a.p1 == b.p1 and a.p2 == b.p2) or (a.p1 == b.p2 and a.p2 == b.p1);
    }
};

pub const DelaunayResult = struct {
    triangles: std.ArrayList(Triangle),

    pub fn deinit(self: *DelaunayResult, alloc: std.mem.Allocator) void {
        self.triangles.deinit(alloc);
    }
};

pub fn triangulateConstrained(
    alloc: std.mem.Allocator,
    points: []const rl.Vector2,
    constraints: []const Edge,
) !DelaunayResult {
    // Step 1: Perform standard Delaunay triangulation
    var result = try triangulate(alloc, points);
    errdefer result.deinit(alloc);

    // Step 2: Enforce constraints by edge-flipping intersecting edges
    for (constraints) |constraint| {
        if (constraint.p1 == constraint.p2) continue;

        var guard: usize = 0;
        const max_iters: usize = result.triangles.items.len * 4 + 64;

        while (!containsEdge(result.triangles.items, constraint)) {
            guard += 1;
            if (guard > max_iters) break; // give up on this constraint rather than hang

            // Find the first triangle edge intersecting our constraint segment
            const c_a = points[constraint.p1];
            const c_b = points[constraint.p2];
            var flipped_any = false;

            var i: usize = 0;
            while (i < result.triangles.items.len) : (i += 1) {
                const tri = result.triangles.items[i];
                const edges = [_]Edge{
                    .{ .p1 = tri.p1, .p2 = tri.p2 },
                    .{ .p1 = tri.p2, .p2 = tri.p3 },
                    .{ .p1 = tri.p3, .p2 = tri.p1 },
                };

                for (edges) |e| {
                    if (e.eql(constraint)) continue;

                    const e_a = points[e.p1];
                    const e_b = points[e.p2];

                    if (segmentsIntersect(c_a, c_b, e_a, e_b)) {
                        if (findAdjacentTriangle(result.triangles.items, i, e)) |adj_idx| {
                            if (flipDiagonal(result.triangles.items, points, i, adj_idx, e)) {
                                flipped_any = true;
                                break;
                            }
                            // illegal flip — keep looking at other edges/triangles instead of giving up
                        }
                    }
                }
                if (flipped_any) break;
            }

            // Fallback safety to avoid infinite loops on invalid or overlapping constraints
            if (!flipped_any) break;
        }
    }

    return result;
}

// Filter function to purge triangles sitting inside obstacle polygons
pub fn filterObstacleTriangles(
    alloc: std.mem.Allocator,
    result: *DelaunayResult,
    points: []const rl.Vector2,
    obstacle_polygons: []const []const rl.Vector2,
) !void {
    var clean_list: std.ArrayList(Triangle) = .empty;
    errdefer clean_list.deinit(alloc);

    for (result.triangles.items) |tri| {
        const p1 = points[tri.p1];
        const p2 = points[tri.p2];
        const p3 = points[tri.p3];

        // Calculate triangle centroid
        const centroid = rl.Vector2{
            .x = (p1.x + p2.x + p3.x) / 3.0,
            .y = (p1.y + p2.y + p3.y) / 3.0,
        };

        var inside_obstacle = false;
        for (obstacle_polygons) |poly| {
            if (isPointInPolygon(centroid, poly)) {
                inside_obstacle = true;
                break;
            }
        }

        if (!inside_obstacle) {
            try clean_list.append(alloc, tri);
        }
    }

    result.triangles.deinit(alloc);
    result.triangles = clean_list;
}

// ----------------------------------------------------------------------------
// HELPER MATH & GEOMETRY
// ----------------------------------------------------------------------------

pub fn triangulate(alloc: std.mem.Allocator, points: []const rl.Vector2) !DelaunayResult {
    var triangles: std.ArrayList(Triangle) = .empty;
    errdefer triangles.deinit(alloc);

    if (points.len < 3) {
        return DelaunayResult{ .triangles = triangles };
    }

    var min_x = points[0].x;
    var max_x = points[0].x;
    var min_y = points[0].y;
    var max_y = points[0].y;

    for (points) |pt| {
        min_x = @min(min_x, pt.x);
        max_x = @max(max_x, pt.x);
        min_y = @min(min_y, pt.y);
        max_y = @max(max_y, pt.y);
    }

    const dx = max_x - min_x;
    const dy = max_y - min_y;
    const dmax = @max(dx, dy);
    const mid_x = min_x + dx * 0.5;
    const mid_y = min_y + dy * 0.5;

    var extended_points: std.ArrayList(rl.Vector2) = .empty;
    defer extended_points.deinit(alloc);
    try extended_points.appendSlice(alloc, points);

    const st1 = try extended_points.addOne(alloc);
    st1.* = .{ .x = mid_x - 20.0 * dmax, .y = mid_y - dmax };
    const st2 = try extended_points.addOne(alloc);
    st2.* = .{ .x = mid_x, .y = mid_y + 20.0 * dmax };
    const st3 = try extended_points.addOne(alloc);
    st3.* = .{ .x = mid_x + 20.0 * dmax, .y = mid_y - dmax };

    const i1_ = extended_points.items.len - 3;
    const i2_ = extended_points.items.len - 2;
    const i3_ = extended_points.items.len - 1;

    try triangles.append(alloc, .{ .p1 = i1_, .p2 = i2_, .p3 = i3_ });

    var i: usize = 0;
    while (i < points.len) : (i += 1) {
        const pt = extended_points.items[i];
        var bad_triangles: std.ArrayList(usize) = .empty;
        defer bad_triangles.deinit(alloc);

        for (triangles.items, 0..) |tri, t_idx| {
            if (isPointInsideCircumcircle(pt, extended_points.items[tri.p1], extended_points.items[tri.p2], extended_points.items[tri.p3])) {
                try bad_triangles.append(alloc, t_idx);
            }
        }

        var polygon: std.ArrayList(Edge) = .empty;
        defer polygon.deinit(alloc);

        for (bad_triangles.items) |t_idx| {
            const tri = triangles.items[t_idx];
            const edges = [_]Edge{
                .{ .p1 = tri.p1, .p2 = tri.p2 },
                .{ .p1 = tri.p2, .p2 = tri.p3 },
                .{ .p1 = tri.p3, .p2 = tri.p1 },
            };

            for (edges) |edge| {
                var shared = false;
                for (bad_triangles.items) |other_t_idx| {
                    if (t_idx == other_t_idx) continue;
                    const other_tri = triangles.items[other_t_idx];
                    const other_edges = [_]Edge{
                        .{ .p1 = other_tri.p1, .p2 = other_tri.p2 },
                        .{ .p1 = other_tri.p2, .p2 = other_tri.p3 },
                        .{ .p1 = other_tri.p3, .p2 = other_tri.p1 },
                    };
                    for (other_edges) |oe| {
                        if (Edge.eql(edge, oe)) {
                            shared = true;
                            break;
                        }
                    }
                    if (shared) break;
                }
                if (!shared) {
                    try polygon.append(alloc, edge);
                }
            }
        }

        std.mem.sort(usize, bad_triangles.items, {}, std.sort.desc(usize));
        for (bad_triangles.items) |t_idx| {
            _ = triangles.swapRemove(t_idx);
        }

        for (polygon.items) |edge| {
            try triangles.append(alloc, .{ .p1 = edge.p1, .p2 = edge.p2, .p3 = i });
        }
    }

    var clean_triangles: std.ArrayList(Triangle) = .empty;
    errdefer clean_triangles.deinit(alloc);

    for (triangles.items) |tri| {
        if (tri.p1 < points.len and tri.p2 < points.len and tri.p3 < points.len) {
            try clean_triangles.append(alloc, tri);
        }
    }

    triangles.deinit(alloc);
    return DelaunayResult{ .triangles = clean_triangles };
}

fn isPointInsideCircumcircle(p: rl.Vector2, a: rl.Vector2, b: rl.Vector2, c: rl.Vector2) bool {
    const ax = a.x - p.x;
    const ay = a.y - p.y;
    const bx = b.x - p.x;
    const by = b.y - p.y;
    const cx = c.x - p.x;
    const cy = c.y - p.y;

    const ab_det = ax * by - ay * bx;
    const bc_det = bx * cy - by * cx;
    const ca_det = cx * ay - cy * ax;

    const ccw = ab_det + bc_det + ca_det;

    const sa = ax * ax + ay * ay;
    const sb = bx * bx + by * by;
    const sc = cx * cx + cy * cy;

    const det = sa * (bx * cy - by * cx) -
        sb * (ax * cy - ay * cx) +
        sc * (ax * by - ay * bx);

    return if (ccw > 0.0) det > 0.0 else det < 0.0;
}

fn containsEdge(triangles: []const Triangle, target: Edge) bool {
    for (triangles) |tri| {
        const edges = [_]Edge{
            .{ .p1 = tri.p1, .p2 = tri.p2 },
            .{ .p1 = tri.p2, .p2 = tri.p3 },
            .{ .p1 = tri.p3, .p2 = tri.p1 },
        };
        for (edges) |e| {
            if (e.eql(target)) return true;
        }
    }
    return false;
}

fn segmentsIntersect(a: rl.Vector2, b: rl.Vector2, c: rl.Vector2, d: rl.Vector2) bool {
    const ccw = struct {
        fn check(p1: rl.Vector2, p2: rl.Vector2, p3: rl.Vector2) bool {
            return (p3.y - p1.y) * (p2.x - p1.x) > (p2.y - p1.y) * (p3.x - p1.x);
        }
    }.check;

    return (ccw(a, c, d) != ccw(b, c, d)) and (ccw(a, b, c) != ccw(a, b, d));
}

fn findAdjacentTriangle(triangles: []const Triangle, current_idx: usize, shared_edge: Edge) ?usize {
    for (triangles, 0..) |tri, idx| {
        if (idx == current_idx) continue;
        const edges = [_]Edge{
            .{ .p1 = tri.p1, .p2 = tri.p2 },
            .{ .p1 = tri.p2, .p2 = tri.p3 },
            .{ .p1 = tri.p3, .p2 = tri.p1 },
        };
        for (edges) |e| {
            if (e.eql(shared_edge)) return idx;
        }
    }
    return null;
}

fn flipDiagonal(triangles: []Triangle, points: []const rl.Vector2, t1_idx: usize, t2_idx: usize, shared_edge: Edge) bool {
    const t1 = triangles[t1_idx];
    const t2 = triangles[t2_idx];

    var opp1: usize = undefined;
    if (t1.p1 != shared_edge.p1 and t1.p1 != shared_edge.p2) opp1 = t1.p1;
    if (t1.p2 != shared_edge.p1 and t1.p2 != shared_edge.p2) opp1 = t1.p2;
    if (t1.p3 != shared_edge.p1 and t1.p3 != shared_edge.p2) opp1 = t1.p3;

    var opp2: usize = undefined;
    if (t2.p1 != shared_edge.p1 and t2.p1 != shared_edge.p2) opp2 = t2.p1;
    if (t2.p2 != shared_edge.p1 and t2.p2 != shared_edge.p2) opp2 = t2.p2;
    if (t2.p3 != shared_edge.p1 and t2.p3 != shared_edge.p2) opp2 = t2.p3;

    if (opp1 == opp2) return false; // degenerate

    // Legal iff the new diagonal actually crosses the old one (convex quad).
    if (!segmentsIntersect(points[opp1], points[opp2], points[shared_edge.p1], points[shared_edge.p2])) {
        return false;
    }

    triangles[t1_idx] = .{ .p1 = opp1, .p2 = opp2, .p3 = shared_edge.p1 };
    triangles[t2_idx] = .{ .p1 = opp1, .p2 = opp2, .p3 = shared_edge.p2 };
    return true;
}

fn isPointInPolygon(pt: rl.Vector2, poly: []const rl.Vector2) bool {
    var inside = false;
    var j = poly.len - 1;
    for (poly, 0..) |p_i, i| {
        const p_j = poly[j];
        if (((p_i.y > pt.y) != (p_j.y > pt.y)) and
            (pt.x < (p_j.x - p_i.x) * (pt.y - p_i.y) / (p_j.y - p_i.y) + p_i.x))
        {
            inside = !inside;
        }
        j = i;
    }
    return inside;
}
