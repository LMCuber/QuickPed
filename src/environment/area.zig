const Self = @This();
const std = @import("std");
const rl = @import("raylib");
const color = @import("../color.zig");
const commons = @import("../commons.zig");
const Entity = @import("entity.zig").Entity;
const SimData = @import("../sim_data.zig");

area_id: i32,
topleft: rl.Vector2 = undefined,
rect: rl.Rectangle = undefined,
placed: bool = false,
anchored: bool = false,
pos: rl.Vector2 = .{ .x = 0, .y = 0 },

pub var next_id: i32 = 0;

pub const AreaSnapshot = struct {
    area_id: i32,
    rect: rl.Rectangle,
};

pub fn init() Self {
    return .{
        .area_id = nextId(),
    };
}

pub fn getSnapshot(self: Self) AreaSnapshot {
    return .{
        .area_id = self.area_id,
        .rect = self.rect,
    };
}

pub fn fromSnapshot(snap: AreaSnapshot) Self {
    return .{
        .area_id = snap.area_id,
        .rect = snap.rect,
        .anchored = true,
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
        self.pos = commons.roundMousePos(sim_data);
        if (rl.isMouseButtonPressed(.mouse_button_left)) {
            if (!self.anchored) {
                // not anchored yet; anchor
                self.topleft = self.pos;
                self.anchored = true;
            } else {
                // already anchored, finish
                self.placed = true;
                return .placed;
            }
        }
        if (self.anchored) {
            self.rect = rl.Rectangle.init(
                self.topleft.x,
                self.topleft.y,
                self.pos.x - self.topleft.x,
                self.pos.y - self.topleft.y,
            );
        }
    }
    return .none;
}

pub fn draw(self: Self) void {
    var col: rl.Color = undefined;
    if (self.placed) {
        col = .{ .r = 15, .g = 42, .b = 65, .a = 180 };
    } else if (self.anchored) {
        col = color.navy_t;
    } else {
        col = color.green;
    }
    const size = 10;
    if (!self.anchored) {
        // not placed topleft yet
        rl.drawRectangleV(self.pos.subtract(.{ .x = size / 2, .y = size / 2 }), .{ .x = size, .y = size }, col);
    } else {
        // placed topleft
        rl.drawRectangleRec(self.rect, col);
    }
}
