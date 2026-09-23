const rl = @import("raylib");

pub fn vector2Project(a: rl.Vector2, b: rl.Vector2) rl.Vector2 {
    return b.scale(a.dotProduct(b) / b.lengthSqr());
}
