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

revolver_id: i32,
pos: rl.Vector2 = .{ .x = 0, .y = 0 },
placed: bool = false,
angle: f32 = 0, // degrees
speed: i32 = 37, // degrees
length: i32 = 50,

pub var next_id: i32 = 0;

pub const RevolverSnapshot = struct {
    revolver_id: i32,
    pos: rl.Vector2,
    speed: i32,
    length: i32,
};

pub fn init() Self {
    return .{
        .revolver_id = nextId(),
    };
}

pub fn getSnapshot(self: Self) RevolverSnapshot {
    return .{
        .revolver_id = self.revolver_id,
        .pos = self.pos,
        .speed = self.speed,
        .length = self.length,
    };
}

pub fn fromSnapshot(snap: RevolverSnapshot) Self {
    return .{
        .revolver_id = snap.revolver_id,
        .pos = snap.pos,
        .speed = snap.speed,
        .length = snap.length,
        .placed = true,
    };
}

pub fn nextId() i32 {
    next_id += 1;
    return next_id - 1;
}

pub fn update(self: *Self, dt: f32, sim_data: SimData, settings: Settings) !Entity.EntityAction {
    self.angle -= @as(f32, @floatFromInt(self.speed)) * dt;
    if (self.angle >= 360) {
        self.angle = @rem(self.angle, 360.0);
    }
    if (!self.placed) {
        self.pos = commons.roundMousePos(sim_data);
        if (commons.editorCapturingMouse(settings) and rl.isMouseButtonPressed(.mouse_button_left)) {
            self.placed = true;
            return .confirm;
        }
        return .none;
    }
    return .none;
}

pub fn confirm(self: *Self) void {
    const w: f32 = 100;
    z.setNextItemWidth(w);
    _ = z.inputInt("length", .{ .v = &self.length });
    z.setNextItemWidth(w);
    _ = z.inputInt("speed ", .{ .v = &self.speed });
}

pub fn getRotatedVector(self: Self, a: f32) rl.Vector2 {
    // a in radians
    const rad: f32 = std.math.degreesToRadians(self.angle);
    var vec: rl.Vector2 = .{ .x = @floatFromInt(self.length), .y = 0 };
    return vec.rotate(rad + a);
}

pub fn draw(self: *Self) void {
    const line_width = 6;
    const col = if (self.placed) (palette.env.orange) else (palette.env.white_t);

    rl.drawLineEx(self.pos, self.pos.add(self.getRotatedVector(0)), line_width, col);
    rl.drawLineEx(self.pos, self.pos.add(self.getRotatedVector(0.5 * std.math.pi)), line_width, col);
    rl.drawLineEx(self.pos, self.pos.add(self.getRotatedVector(std.math.pi)), line_width, col);
    rl.drawLineEx(self.pos, self.pos.add(self.getRotatedVector(1.5 * std.math.pi)), line_width, col);
}
