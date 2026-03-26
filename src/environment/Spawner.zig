const Self = @This();
const std = @import("std");
const rl = @import("raylib");
const color = @import("../color.zig");
const palette = @import("../palette.zig");
const commons = @import("../commons.zig");
const Entity = @import("entity.zig").Entity;
const SimData = @import("../editor/SimData.zig");
const Settings = @import("../Settings.zig");
const Agent = @import("../Agent.zig");

points: [2]rl.Vector2 = undefined,
rect: rl.Rectangle = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
point_count: usize = 0,
placed: bool = false,
pos: rl.Vector2 = .{ .x = 0, .y = 0 },

pub const SpawnerSnapshot = struct {
    points: [2]rl.Vector2,
};

pub fn init() Self {
    return .{};
}

pub fn getSnapshot(self: Self) SpawnerSnapshot {
    return .{
        .points = self.points,
    };
}

pub fn fromSnapshot(snap: SpawnerSnapshot) Self {
    return .{
        .points = snap.points,
        .point_count = 2,
        .placed = true,
    };
}

pub fn update(self: *Self, sim_data: SimData, settings: Settings) Entity.EntityAction {
    const o = 5;
    self.rect = .{
        .x = @min(self.points[0].x, self.points[1].x) - o,
        .y = @min(self.points[0].y, self.points[1].y) - o,
        .width = @abs(self.points[0].x - self.points[1].x) + o * 2,
        .height = @abs(self.points[0].y - self.points[1].y) + o * 2,
    };
    if (!self.placed) {
        self.pos = commons.roundMousePos(sim_data);
        // place new point
        if (commons.editorCapturingMouse(settings) and rl.isMouseButtonPressed(.mouse_button_left)) {
            if (self.point_count < 2) {
                self.points[self.point_count] = self.pos;
                self.point_count += 1;
            }
            if (self.point_count == 2) {
                self.placed = true;
                return .confirm;
            }
        }
    } else {
        if (rl.checkCollisionPointRec(commons.mousePos(), self.rect)) {
            if (commons.editorCapturingMouse(settings) and rl.isMouseButtonPressed(.mouse_button_left)) {
                return .selected;
            }
        }
    }
    return .none;
}

pub fn draw(self: Self) void {
    const thick = 4;
    const col = if (self.placed) (palette.env.green) else (color.green_t);
    if (self.point_count == 0) {
        // has placed nothing yet, so show white circle
        rl.drawCircleV(self.pos, 6, col);
    } else if (self.point_count == 1) {
        // has placed single point
        rl.drawLineEx(self.points[0], self.pos, thick, col);
    } else if (self.point_count == 2) {
        // has placed all points
        rl.drawLineEx(self.points[0], self.points[1], thick, col);
    } else {
        unreachable;
    }

    if (self.placed) {
        if (rl.checkCollisionPointRec(commons.mousePos(), self.rect)) {
            rl.drawRectangleLinesEx(self.rect, 1, palette.env.orange);
        }
    }
}

pub fn getRandomSpawnPos(self: Self) rl.Vector2 {
    return commons.getRandomPointBetweenVectors(self.points[0], self.points[1]);
}
