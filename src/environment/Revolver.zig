const Self = @This();
const std = @import("std");
const rl = @import("raylib");
const color = @import("../color.zig");
const palette = @import("../palette.zig");
const commons = @import("../commons.zig");
const SimData = @import("../editor/SimData.zig");
const Settings = @import("../Settings.zig");
const Entity = @import("../environment/entity.zig").Entity;

revolver_id: i32,
pos: rl.Vector2 = .{ .x = 0, .y = 0 },
placed: bool = false,
angle: f32 = 0, // radians
length: f32 = 50,

pub var next_id: i32 = 0;

pub const RevolverSnapshot = struct {
    revolver_id: i32,
    pos: rl.Vector2,
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
    };
}

pub fn fromSnapshot(snap: RevolverSnapshot) Self {
    return .{
        .revolver_id = snap.revolver_id,
        .pos = snap.pos,
        .placed = true,
    };
}

pub fn nextId() i32 {
    next_id += 1;
    return next_id - 1;
}

pub fn update(self: *Self, sim_data: SimData, settings: Settings) !Entity.EntityAction {
    if (!self.placed) {
        self.pos = commons.roundMousePos(sim_data);
        if (commons.editorCapturingMouse(settings) and rl.isMouseButtonPressed(.mouse_button_left)) {
            self.placed = true;
            return .placed;
        }
        return .none;
    }
    return .none;
}

pub fn draw(self: *Self) void {
    const line_width = 6;
    const col = if (self.placed) (palette.env.purple) else (color.light_gray);
    self.angle += 0.02;

    const extension: rl.Vector2 = .{ .x = self.length, .y = 0 };
    rl.drawLineEx(self.pos, self.pos.add(extension.rotate(self.angle)), line_width, col);
    rl.drawLineEx(self.pos, self.pos.add(extension.rotate(self.angle + 0.5 * commons.PI)), line_width, col);
    rl.drawLineEx(self.pos, self.pos.add(extension.rotate(self.angle + commons.PI)), line_width, col);
    rl.drawLineEx(self.pos, self.pos.add(extension.rotate(self.angle + 1.5 * commons.PI)), line_width, col);
}
