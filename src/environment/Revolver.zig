const Self = @This();
const std = @import("std");
const rl = @import("raylib");
const z = @import("zgui");
const color = @import("../color.zig");
const palette = @import("../palette.zig");
const commons = @import("../commons.zig");
const SimData = @import("../editor/SimData.zig");
const Settings = @import("../Settings.zig");
const Entity = @import("../environment/entity.zig").Entity;

pos: rl.Vector2 = .{ .x = 0, .y = 0 },
placed: bool = false,
angle: f32 = 0, // degrees
speed: i32 = 37, // degrees
length: i32 = 50,
clockwise: bool = false, // counterclockwise rotation

pub const RevolverSnapshot = struct {
    pos: rl.Vector2,
    speed: i32,
    length: i32,
    clockwise: bool,
};

pub fn init() Self {
    return .{};
}

pub fn getSnapshot(self: Self) RevolverSnapshot {
    return .{
        .pos = self.pos,
        .speed = self.speed,
        .length = self.length,
        .clockwise = self.clockwise,
    };
}

pub fn fromSnapshot(snap: RevolverSnapshot) Self {
    return .{
        .pos = snap.pos,
        .speed = snap.speed,
        .length = snap.length,
        .placed = true,
        .clockwise = snap.clockwise,
    };
}

pub fn update(self: *Self, dt: f32, sim_data: SimData, settings: Settings) !Entity.EntityAction {
    self.angle -= @as(f32, @floatFromInt(self.speed)) * dt *
        (if (self.clockwise) @as(f32, -1) else @as(f32, 1));
    if (self.angle >= 360) {
        self.angle = @rem(self.angle, 360.0);
    }
    if (!self.placed) {
        self.pos = commons.roundMousePos(sim_data);
        if (commons.editorCapturingMouse(settings) and rl.isMouseButtonPressed(.left)) {
            self.placed = true;
            return .confirm;
        }
        return .none;
    } else {
        if (commons.editorCapturingMouse(settings) and rl.isMouseButtonPressed(.left) and self.checkHover()) {
            return .selected;
        }
    }
    return .none;
}

pub fn confirm(self: *Self, alloc: std.mem.Allocator) !void {
    const w: f32 = 100;
    z.setNextItemWidth(w);
    _ = z.inputInt("length", .{ .v = &self.length });
    z.setNextItemWidth(w);
    _ = z.inputInt("##revolver-speed", .{ .v = &self.speed });
    z.sameLine(.{});
    try z.text(alloc, "speed", .{});
    if (z.isItemHovered(.{})) {
        _ = z.beginTooltip();
        defer z.endTooltip();
        try z.text(alloc, "in degrees/second", .{});
    }
    _ = z.checkbox("clockwise", .{ .v = &self.clockwise });
}

pub fn edit(self: *Self, alloc: std.mem.Allocator) !void {
    try self.confirm(alloc);
}

pub fn getRotatedVector(self: Self, a: f32) rl.Vector2 {
    // a in radians
    const rad: f32 = std.math.degreesToRadians(self.angle);
    var vec: rl.Vector2 = .{ .x = @floatFromInt(self.length), .y = 0 };
    return vec.rotate(rad + a);
}

pub fn checkHover(self: *Self) bool {
    const threshold = 8;
    for (0..4) |i| {
        const angle: f32 = @as(f32, @floatFromInt(i)) * 0.5 * std.math.pi;
        if (rl.checkCollisionPointLine(commons.mousePos(), self.pos, self.pos.add(self.getRotatedVector(angle)), threshold)) {
            return true;
        }
    }
    return false;
}

pub fn hover(self: *Self) void {
    const line_width = 6;

    for (0..4) |i| {
        const angle: f32 = @as(f32, @floatFromInt(i)) * 0.5 * std.math.pi;
        rl.drawLineEx(self.pos, self.pos.add(self.getRotatedVector(angle)), line_width, palette.env.hover);
    }
}

pub fn draw(self: *Self) void {
    const line_width = 6;
    const col = if (self.placed) (palette.env.light_gray) else (palette.env.white_t);

    for (0..4) |i| {
        const angle: f32 = @as(f32, @floatFromInt(i)) * 0.5 * std.math.pi;
        rl.drawLineEx(self.pos, self.pos.add(self.getRotatedVector(angle)), line_width, col);
    }
}
