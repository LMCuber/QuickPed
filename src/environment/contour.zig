const Self = @This();
const std = @import("std");
const rl = @import("raylib");
const color = @import("../color.zig");
const commons = @import("../commons.zig");
const Entity = @import("entity.zig").Entity;
const SimData = @import("../sim_data.zig");

<<<<<<< HEAD
id: i32,
contour_id: i32,
=======
id: usize,
>>>>>>> b1df9b51109d6ec82cc6091d6f95116dbebb8b96
name: [:0]const u8,
pos: rl.Vector2 = .{ .x = 0, .y = 0 },
points: std.ArrayList(rl.Vector2),
placed: bool = false,

pub var next_id: i32 = 0;

pub const ContourSnapshot = struct {
<<<<<<< HEAD
    id: i32,
    contour_id: i32,
=======
    id: usize,
>>>>>>> b1df9b51109d6ec82cc6091d6f95116dbebb8b96
    name: [:0]const u8,
    points: []rl.Vector2,
};

pub fn init(allocator: std.mem.Allocator, id: i32) !Self {
    const contour_id = nextId();
    return .{
        .id = id,
<<<<<<< HEAD
        .contour_id = contour_id,
=======
>>>>>>> b1df9b51109d6ec82cc6091d6f95116dbebb8b96
        .name = try std.fmt.allocPrintZ(
            allocator,
            "Contour{}",
            .{contour_id},
        ),
        .points = std.ArrayList(rl.Vector2).init(allocator),
    };
}

pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    self.points.deinit();
    allocator.free(self.name);
}

pub fn getSnapshot(self: Self) ContourSnapshot {
    return .{
        .id = self.id,
        .contour_id = self.contour_id,
        .name = self.name,
        .points = self.points.items,
    };
}

pub fn fromSnapshot(allocator: std.mem.Allocator, snap: ContourSnapshot) !Self {
    var points = std.ArrayList(rl.Vector2).init(allocator);
    for (snap.points) |point| {
        try points.append(point);
    }
    return .{
        .id = snap.id,
<<<<<<< HEAD
        .contour_id = snap.contour_id,
=======
>>>>>>> b1df9b51109d6ec82cc6091d6f95116dbebb8b96
        .name = try allocator.dupeZ(u8, snap.name),
        .points = points,
        .placed = true,
    };
}

pub fn nextId() i32 {
    next_id += 1;
    return next_id - 1;
}

pub fn update(self: *Self, sim_data: SimData) !Entity.EntityAction {
    if (!self.placed) {
        self.pos = commons.roundMousePos(sim_data);
        // place new point
        if (rl.isMouseButtonPressed(.mouse_button_left)) {
            try self.points.append(self.pos);
        }
        // finish points with keypress
        if (rl.isKeyPressed(.key_enter)) {
            self.placed = true;
            return .placed;
        }
        return .none;
    } else {
        return .none;
    }
}

pub fn draw(self: Self) void {
    const line_width = 2;
    const col = if (self.placed) (color.white) else (color.white_t);
    if (self.points.items.len == 0) {
        // has placed nothing yet, so show white circle
        rl.drawCircleV(self.pos, 6, col);
    } else {
        // already has points, so display them
        for (self.points.items, 0..) |point, i| {
            if (i == self.points.items.len - 1) continue;
            const next_point = self.points.items[i + 1];
            rl.drawLineEx(point, next_point, line_width, col);
        }
        if (!self.placed) {
            // display last point to mouse cursor
            rl.drawLineEx(self.points.items[self.points.items.len - 1], self.pos, line_width, col);
        }
    }
}
