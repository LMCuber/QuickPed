const Self = @This();
const std = @import("std");
const rl = @import("raylib");
const color = @import("../color.zig");
const commons = @import("../commons.zig");
const Entity = @import("entity.zig").Entity;
const SimData = @import("../sim_data.zig");

id: usize,
spawner_id: usize,
name: [:0]const u8,
points: [2]rl.Vector2 = undefined,
point_count: usize = 0,
placed: bool = false,
pos: rl.Vector2 = .{ .x = 0, .y = 0 },

pub var next_id: usize = 0;

pub const SpawnerSnapshot = struct {
    id: usize,
    spawner_id: usize,
    name: [:0]const u8,
    points: [2]rl.Vector2,
};

pub fn init(allocator: std.mem.Allocator, id: usize) !Self {
    const spawner_id = nextId();
    return .{
        .id = id,
        .spawner_id = spawner_id,
        .name = try std.fmt.allocPrintZ(
            allocator,
            "Spawner{}",
            .{spawner_id},
        ),
    };
}

pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    allocator.free(self.name);
}

pub fn getSnapshot(self: Self) SpawnerSnapshot {
    return .{
        .id = self.id,
        .spawner_id = self.spawner_id,
        .name = self.name,
        .points = self.points,
    };
}

pub fn fromSnapshot(allocator: std.mem.Allocator, snap: SpawnerSnapshot) !Self {
    return .{
        .id = snap.id,
        .spawner_id = snap.spawner_id,
        .name = try allocator.dupeZ(u8, snap.name),
        .points = snap.points,
        .point_count = 2,
        .placed = true,
    };
}

pub fn nextId() usize {
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
