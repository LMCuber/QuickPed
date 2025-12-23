const Self = @This();
const std = @import("std");
const rl = @import("raylib");
const color = @import("color.zig");

points: []const rl.Vector2,

pub fn init(points: []const rl.Vector2) Self {
    return .{
        .points = points,
    };
}

pub fn draw(self: Self) void {
    rl.drawLineStrip(@constCast(self.points), color.WHITE);
    rl.drawLineV(self.points[0], self.points[self.points.len - 1], color.WHITE);
}
