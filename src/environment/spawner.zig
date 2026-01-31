const Self = @This();
const std = @import("std");
const rl = @import("raylib");
const color = @import("../color.zig");
const commons = @import("../commons.zig");
const Entity = @import("entity.zig").Entity;
const SimData = @import("../editor/SimData.zig");
const Agent = @import("../Agent.zig");

spawner_id: i32,
points: [2]rl.Vector2 = undefined,
point_count: usize = 0,
placed: bool = false,
pos: rl.Vector2 = .{ .x = 0, .y = 0 },

pub var next_id: i32 = 0;

pub const SpawnerSnapshot = struct {
    spawner_id: i32,
    points: [2]rl.Vector2,
};

pub fn init() Self {
    return .{
        .spawner_id = nextId(),
    };
}

pub fn getSnapshot(self: Self) SpawnerSnapshot {
    return .{
        .spawner_id = self.spawner_id,
        .points = self.points,
    };
}

pub fn fromSnapshot(snap: SpawnerSnapshot) Self {
    return .{
        .spawner_id = snap.spawner_id,
        .points = snap.points,
        .point_count = 2,
        .placed = true,
    };
}

pub fn nextId() i32 {
    next_id += 1;
    return next_id - 1;
}

pub fn update(self: *Self, sim_data: SimData) Entity.EntityAction {
    if (!self.placed) {
        self.pos = commons.roundMousePos(sim_data);
        // place new point
        if (rl.isMouseButtonPressed(.mouse_button_left)) {
            if (self.point_count < 2) {
                self.points[self.point_count] = self.pos;
                self.point_count += 1;
            }
            if (self.point_count == 2) {
                self.placed = true;
                return .placed;
            }
        }
    }
    return .none;
}

pub fn draw(self: Self) void {
    const line_width = 2;
    const col = if (self.placed) (color.green) else (color.green_t);
    if (self.point_count == 0) {
        // has placed nothing yet, so show white circle
        rl.drawCircleV(self.pos, 6, col);
    } else if (self.point_count == 1) {
        // has placed single point
        rl.drawLineEx(self.points[0], self.pos, line_width, col);
    } else if (self.point_count == 2) {
        // has placed all points
        rl.drawLineEx(self.points[0], self.points[1], line_width, col);
    } else {
        unreachable;
    }
}

pub fn randomSpawnPos(self: Self) rl.Vector2 {
    const diff: rl.Vector2 = self.points[1].subtract(self.points[0]);
    const p: f32 = commons.rand01();
    return self.points[0].add(diff.scale(p));
}
