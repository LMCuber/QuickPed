const Self = @This();
const std = @import("std");
const rl = @import("raylib");
const color = @import("../color.zig");
const commons = @import("../commons.zig");
const Entity = @import("entity.zig").Entity;

points: std.ArrayList(rl.Vector2),
placed: bool = false,

pub fn init(allocator: std.mem.Allocator, placed: bool) !Self {
    return .{
        .points = std.ArrayList(rl.Vector2).init(allocator),
        .placed = placed,
    };
}

pub fn deinit(self: *Self) void {
    self.points.deinit();
}

pub fn prepare(_: *Self) void {
    // std.debug.print("{}\n", .{self});
}

pub fn draw(self: Self) void {
    const c = color.hexToColor(color.fromPalette(if (self.placed) .teal else .salmon));
    rl.drawCircleV(self.pos, 8, c);
    rl.drawCircleLinesV(self.pos, 16, c);
}
