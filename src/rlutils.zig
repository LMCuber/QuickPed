const std = @import("std");
const rl = @import("raylib");
const Settings = @import("Settings.zig");
const SimData = @import("editor/SimData.zig");
const Environment = @import("environment/Environment.zig");
const entity = @import("environment/entity.zig");

pub fn getTimeMillis() f64 {
    return rl.getTime() * 1000;
}

pub fn hasLineOfSight(a: rl.Vector2, b: rl.Vector2, env: *Environment) bool {
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
pub fn lineIntersection(line1: [2]rl.Vector2, line2: [2]rl.Vector2) ?rl.Vector2 {
    const p1 = line1[0];
    const p2 = line1[1];
    const p3 = line2[0];
    const p4 = line2[1];

    const d1 = p2.subtract(p1); // direction of line 1
    const d2 = p4.subtract(p3); // direction of line 2

    const denom = d1.x * d2.y - d1.y * d2.x;

    // lines are parallel (or coincident) — no unique intersection
    if (@abs(denom) < 1e-6) return null;

    const diff = p3.subtract(p1);
    const t = (diff.x * d2.y - diff.y * d2.x) / denom;

    return p1.add(d1.scale(t));
}

pub fn existsAnyObject(env: *Environment, kind: std.meta.Tag(entity.Entity.Kind)) bool {
    for (env.entities.items()) |*ent| {
        if (std.meta.activeTag(ent.kind) == kind) return true;
    }
    return false;
}

pub fn getRandomPointBetweenVectors(rand: std.Random, p1: rl.Vector2, p2: rl.Vector2) rl.Vector2 {
    const diff: rl.Vector2 = p2.subtract(p1);
    const p: f32 = rand.float(f32);
    return p1.add(diff.scale(p));
}

pub fn vecToLineSegment(pos: rl.Vector2, A: rl.Vector2, B: rl.Vector2) rl.Vector2 {
    const AB = B.subtract(A);
    const t: f32 = std.math.clamp(pos.subtract(A).dotProduct(AB) / AB.dotProduct(AB), 0, 1);
    const C = A.add(AB.scale(t));
    const D = pos.subtract(C);
    return D;
}

///
/// gets the mouse position while taking scrolling into considersation.
/// basically the position of the map you are hovering above, relative to the topleft of the map
/// (inc. by target, since scrolling right = negative target, so actual location is more to the left)
///
pub fn editorCapturingMouse(settings: Settings) bool {
    const mouse: rl.Vector2 = rl.getMousePosition();
    return mouse.x <= @as(f32, @floatFromInt(settings.sim_width)) and
        mouse.y <= @as(f32, @floatFromInt((settings.height)));
}

pub fn vector2Project(a: rl.Vector2, b: rl.Vector2) rl.Vector2 {
    return b.scale(a.dotProduct(b) / b.lengthSqr());
}

pub fn checkCollisionRecInside(inner: rl.Rectangle, outer: rl.Rectangle) bool {
    return (inner.x >= outer.x and
        inner.y >= outer.y and
        (inner.x + inner.width) <= (outer.x + outer.width) and
        (inner.y + inner.height) <= (outer.y + outer.height));
}

/// LLM CODE!!!
/// Computes a bounding box enclosing a slice of rectangles with an added margin.
pub fn getBoundingBox(rects: []const rl.Rectangle, margin: f32) rl.Rectangle {
    if (rects.len == 0) {
        return .{ .x = 0, .y = 0, .width = 0, .height = 0 };
    }

    // Initialize bounds using the first rectangle
    var min_x: f32 = rects[0].x;
    var min_y: f32 = rects[0].y;
    var max_x: f32 = rects[0].x + rects[0].width;
    var max_y: f32 = rects[0].y + rects[0].height;

    // Find the absolute min/max across all rectangles
    for (rects[1..]) |r| {
        min_x = @min(min_x, r.x);
        min_y = @min(min_y, r.y);
        max_x = @max(max_x, r.x + r.width);
        max_y = @max(max_y, r.y + r.height);
    }

    // Apply the margin (shrink position, expand width/height by 2x margin)
    return .{
        .x = min_x - margin,
        .y = min_y - margin,
        .width = (max_x - min_x) + (margin * 2.0),
        .height = (max_y - min_y) + (margin * 2.0),
    };
}

/// Draws a thicker dashed rectangle border by rendering parallel dashed lines.
pub fn drawDashedRectangle(rect: rl.Rectangle, thickness: f32, dash_size: i32, space_size: i32, color: rl.Color) void {
    const t = @max(1.0, thickness);

    // We loop through the thickness and offset each edge slightly inward/outward
    var i: f32 = 0;
    while (i < t) : (i += 1.0) {
        // Inset/Outset the rectangle bounds slightly for each parallel line layer
        const r = rl.Rectangle{
            .x = rect.x + (i * 0.5),
            .y = rect.y + (i * 0.5),
            .width = rect.width - i,
            .height = rect.height - i,
        };

        const top_left = rl.Vector2{ .x = r.x, .y = r.y };
        const top_right = rl.Vector2{ .x = r.x + r.width, .y = r.y };
        const bottom_right = rl.Vector2{ .x = r.x + r.width, .y = r.y + r.height };
        const bottom_left = rl.Vector2{ .x = r.x, .y = r.y + r.height };

        rl.drawLineDashed(top_left, top_right, dash_size, space_size, color);
        rl.drawLineDashed(top_right, bottom_right, dash_size, space_size, color);
        rl.drawLineDashed(bottom_right, bottom_left, dash_size, space_size, color);
        rl.drawLineDashed(bottom_left, top_left, dash_size, space_size, color);
    }
}

pub fn twoPointsToRec(a: rl.Vector2, b: rl.Vector2) rl.Rectangle {
    const min_x = @min(a.x, b.x);
    const min_y = @min(a.y, b.y);
    const max_x = @max(a.x, b.x);
    const max_y = @max(a.y, b.y);

    return .{
        .x = min_x,
        .y = min_y,
        .width = max_x - min_x,
        .height = max_y - min_y,
    };
}

pub fn GeometryMixin(comptime T: type) type {
    return struct {
        pub fn getOrigin(self: T) rl.Vector2 {
            const rect = self.getRect();
            return .init(rect.x, rect.y);
        }
    };
}
