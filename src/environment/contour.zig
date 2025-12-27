const Self = @This();
const std = @import("std");
const rl = @import("raylib");
const color = @import("../color.zig");
const commons = @import("../commons.zig");
const Entity = @import("entity.zig").Entity;
const SimData = @import("../sim_data.zig");

id: usize = nextId(),
pos: rl.Vector2 = .{ .x = 0, .y = 0 },
points: std.ArrayList(rl.Vector2),
placed: bool = false,

pub var next_id: usize = 0;

pub const ContourSnapshot = struct {
    id: usize,
    points: []rl.Vector2,
};

pub fn init(allocator: std.mem.Allocator) !Self {
    return .{
        .points = std.ArrayList(rl.Vector2).init(allocator),
    };
}

pub fn deinit(self: *Self) void {
    self.points.deinit();
}

pub fn getSnapshot(self: Self) ContourSnapshot {
    return .{
        .id = self.id,
        .points = self.points.items,
    };
}

pub fn fromSnapshot(allocator: std.mem.Allocator, snap: ContourSnapshot) !Self {
    //
    var ret = try Self.init(allocator);
    //
    ret.id = snap.id;
    ret.placed = true;
    for (snap.points) |point| {
        try ret.points.append(point);
    }
    return ret;
}

pub fn nextId() usize {
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
