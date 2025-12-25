const Self = @This();
const std = @import("std");
const rl = @import("raylib");
const color = @import("../color.zig");
const Entity = @import("entity.zig").Entity;

points: std.ArrayList(rl.Vector2),
placed: bool = false,

// static
pub fn init(allocator: std.mem.Allocator) !Self {
    return .{ .points = std.ArrayList(rl.Vector2).init(allocator) };
}

// instance
pub fn deinit(self: *Self) void {
    self.points.deinit();
}

pub fn prepare(self: Self) void {
    if (self) {}
    return;
}

pub fn draw(_: Self) void {
    return;
}
