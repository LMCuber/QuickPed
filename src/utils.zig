const rl = @import("raylib");

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
