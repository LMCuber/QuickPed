const Self = @This();
const std = @import("std");
const rl = @import("raylib");
const color = @import("../color.zig");
const palette = @import("../palette.zig");
const commons = @import("../commons.zig");
const Entity = @import("entity.zig").Entity;
const SimData = @import("../editor/SimData.zig");
const AgentData = @import("../editor/AgentData.zig");
const Settings = @import("../Settings.zig");

pos: rl.Vector2 = .{ .x = 0, .y = 0 },
points: std.ArrayList(rl.Vector2),
paths: std.ArrayList(rl.Vector2),
path_edges: std.ArrayList([2]rl.Vector2),
placed: bool = false,

pub const ContourSnapshot = struct {
    points: []rl.Vector2,
};

pub fn init() Self {
    return .{
        .points = .empty,
        .paths = .empty,
        .path_edges = .empty,
    };
}

pub fn deinit(self: *Self, alloc: std.mem.Allocator) void {
    self.points.deinit(alloc);
    self.paths.deinit(alloc);
    self.path_edges.deinit(alloc);
}

pub fn getSnapshot(self: Self) ContourSnapshot {
    return .{ .points = self.points.items };
}

pub fn fromSnapshot(
    alloc: std.mem.Allocator,
    snap: ContourSnapshot,
    sim_data: SimData,
    agent_data: AgentData,
) !Self {
    var points: std.ArrayList(rl.Vector2) = .empty;
    for (snap.points) |point| try points.append(alloc, point);
    var contour: Self = .{
        .points = points,
        .paths = .empty,
        .path_edges = .empty,
        .placed = true,
    };
    try contour.savePaths(alloc, sim_data, agent_data);
    return contour;
}

fn centroid(self: Self) rl.Vector2 {
    var sum: rl.Vector2 = .init(0, 0);
    for (self.points.items) |p| sum = sum.add(p);
    return sum.scale(1.0 / @as(f32, @floatFromInt(self.points.items.len)));
}

fn savePaths(self: *Self, alloc: std.mem.Allocator, sim_data: SimData, agent_data: AgentData) !void {
    var edges: std.ArrayList([2]rl.Vector2) = .empty;
    defer edges.deinit(alloc);

    // clear previous saved data in case this runs more than once (e.g. agent radius changes)
    self.paths.clearRetainingCapacity();
    self.path_edges.clearRetainingCapacity();

    // construct extruded edges (but watch out those don't intersect anymore)
    for (self.points.items, 0..) |point, i| {
        const next_index = (i + 1) % self.points.items.len;
        const next_point = self.points.items[next_index];

        const edge_vec: rl.Vector2 = next_point.subtract(point);
        var n: rl.Vector2 = edge_vec.rotate(-std.math.pi * 0.5).normalize();
        // flip the normal if it points towards the center of the polygon
        const mid = point.add(next_point).scale(0.5);
        const center = self.centroid();
        if (n.dotProduct(mid.subtract(center)) < 0) {
            n = n.scale(-1); // flip if pointing inward
        }

        const r: f32 = agent_data.radius * @as(f32, @floatFromInt(sim_data.scale));
        const scaled_first_point: rl.Vector2 = point.add(n.scale(r));
        const scaled_second_point: rl.Vector2 = next_point.add(n.scale(r));

        try edges.append(alloc, .{ scaled_first_point, scaled_second_point });
    }

    // find intersections between consecutive offset edges to get final vertices
    for (edges.items, 0..) |edge, i| {
        const next_index = (i + 1) % edges.items.len;
        const next_edge = edges.items[next_index];

        const intersection = commons.lineIntersection(edge, next_edge) orelse edge[1];
        // fallback: if parallel (rare, e.g. collinear original points), just use the
        // offset endpoint instead of crashing — safer than `unreachable` for edge cases
        try self.paths.append(alloc, intersection);
    }

    // build final polygon edges from the intersection vertices themselves
    for (self.paths.items, 0..) |point, i| {
        const next_index = (i + 1) % self.paths.items.len;
        const next_point = self.paths.items[next_index];
        try self.path_edges.append(alloc, .{ point, next_point });
    }
}

pub fn update(self: *Self, alloc: std.mem.Allocator, sim_data: SimData, agent_data: AgentData, settings: Settings) !Entity.EntityAction {
    if (!self.placed) {
        self.pos = commons.roundMousePos(sim_data);
        // place new point
        if (commons.editorCapturingMouse(settings) and rl.isMouseButtonPressed(.left)) {
            // only add if it's not the same point twice
            const last_point = self.points.getLast();
            if (!self.pos.equals(last_point)) {
                try self.points.append(alloc, self.pos);
            }
        }

        // finish points with keypress
        if (rl.isKeyPressed(.enter)) {
            self.placed = true;
            try self.savePaths(alloc, sim_data, agent_data);
            return .placed;
        }

        return .none;
    } else if (commons.editorCapturingMouse(settings) and rl.isMouseButtonPressed(.left) and self.checkHover()) {
        return .selected;
    }
    return .none;
}

/// AI-CODE
/// checks if ANY path edge is in the way of the infinite spanned bewteen these two vectors
pub fn collideRay(self: Self, a: rl.Vector2, b: rl.Vector2) bool {
    for (self.path_edges.items) |edge| {
        if (segmentsIntersect(a, b, edge[0], edge[1])) return true;
    }
    return false;
}

fn segmentsIntersect(p1: rl.Vector2, p2: rl.Vector2, p3: rl.Vector2, p4: rl.Vector2) bool {
    const d1 = p2.subtract(p1);
    const d2 = p4.subtract(p3);

    const denom = d1.x * d2.y - d1.y * d2.x;

    // parallel (or collinear) segments — treat as no crossing
    if (@abs(denom) < 1e-6) return false;

    const diff = p3.subtract(p1);
    const t = (diff.x * d2.y - diff.y * d2.x) / denom;
    const u = (diff.x * d1.y - diff.y * d1.x) / denom;

    // both params must land within their own segment's span, not just anywhere on the infinite line
    return t >= 0.0 and t <= 1.0 and u >= 0.0 and u <= 1.0;
}

pub fn checkHover(self: Self) bool {
    for (self.points.items, 0..) |point, i| {
        if (i == self.points.items.len - 1) continue;
        const next_point: rl.Vector2 = self.points.items[i + 1];
        if (rl.checkCollisionPointLine(commons.mousePos(), point, next_point, 8)) {
            return true;
        }
    }
    return false;
}

pub fn hover(self: *Self) void {
    const line_width = 3;
    for (self.points.items, 0..) |point, i| {
        if (i == self.points.items.len - 1) continue;
        const next_point = self.points.items[i + 1];
        rl.drawLineEx(point, next_point, line_width, palette.env.hover);
    }
}

pub fn draw(self: Self, _: SimData, _: AgentData) void {
    const line_width = 2;
    const col = if (self.placed)
        palette.env.white
    else
        color.white_t;

    if (self.points.items.len == 0) {
        // has placed nothing yet, so show white circle
        rl.drawCircleV(self.pos, 6, col);
    } else {
        // already has points, so display them
        for (self.points.items, 0..) |point, i| {
            const next_index = (i + 1) % self.points.items.len;
            const next_point = self.points.items[next_index];

            // only render connecting line if it isn't a wraparound
            if (i < self.points.items.len - 1) {
                rl.drawLineEx(point, next_point, line_width, col);
            }
        }
        if (!self.placed) {
            // display last point to mouse cursor
            rl.drawLineEx(self.points.items[self.points.items.len - 1], self.pos, line_width, col);
        } else {
            // it's placed so also display the extruded line and the extruded vertices
            // for (self.paths.items) |path| {
            // rl.drawCircleLinesV(path, 10, palette.env.white);
            // }
            for (self.path_edges.items) |path_edge| {
                const a: rl.Vector2 = path_edge[0];
                const b: rl.Vector2 = path_edge[1];
                rl.drawLineEx(a, b, line_width, palette.env.yellow);
            }
        }
    }
}
