const Self = @This();
const std = @import("std");
const rl = @import("raylib");
const z = @import("zgui");
const color = @import("../color.zig");
const palette = @import("../palette.zig");
const commons = @import("../commons.zig");
const Entity = @import("entity.zig").Entity;
const SimData = @import("../editor/SimData.zig");
const Settings = @import("../Settings.zig");
const Agent = @import("../Agent.zig");

points: commons.Line = .{},
point_count: usize = 0,
placed: bool = false,
pos: rl.Vector2 = .{ .x = 0, .y = 0 },

pub const SpawnerSnapshot = struct {
    points: commons.Line,
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

pub fn getRandomSpawnPos(self: Self) rl.Vector2 {
    return commons.getRandomPointBetweenVectors(self.points.p1, self.points.p2);
}

pub fn update(self: *Self, sim_data: SimData, settings: Settings) Entity.EntityAction {
    if (!self.placed) {
        self.pos = commons.roundMousePos(sim_data);
        // place new point
        if (commons.editorCapturingMouse(settings) and rl.isMouseButtonPressed(.left)) {
            if (self.point_count == 0) {
                self.points.p1 = self.pos;
                self.point_count += 1;
            } else if (self.point_count == 1) {
                self.points.p2 = self.pos;
                self.point_count += 1;
                if (self.point_count == 2) {
                    self.placed = true;
                    return .confirm;
                }
            }
        }
    } else {
        if (commons.editorCapturingMouse(settings) and rl.isMouseButtonPressed(.left) and self.checkHover()) {
            return .selected;
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
        rl.drawLineEx(self.points.p1, self.pos, thick, col);
    } else if (self.point_count == 2) {
        // has placed all points
        rl.drawLineEx(self.points.p1, self.points.p2, thick, col);
    } else {
        unreachable;
    }
}

pub fn hover(self: *Self) void {
    if (self.placed) {
        if (self.checkHover()) {
            rl.drawLineEx(self.points.p1, self.points.p2, 4, palette.env.hover);
        }
    }
}

pub fn checkHover(self: Self) bool {
    return rl.checkCollisionPointLine(commons.mousePos(), self.points.p1, self.points.p2, 8);
}

pub fn confirm(self: *Self) void {
    _ = z.inputFloat("p1 x", .{ .v = &self.points.p1.x });
    _ = z.inputFloat("p1 y", .{ .v = &self.points.p1.y });
    _ = z.inputFloat("p2 x", .{ .v = &self.points.p2.x });
    _ = z.inputFloat("p2 y", .{ .v = &self.points.p2.y });
}

pub fn edit(self: *Self) void {
    self.confirm();
}
