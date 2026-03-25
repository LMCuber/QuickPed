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

source: [2]rl.Vector2 = undefined,
dest: [2]rl.Vector2 = undefined,
point_count: usize = 0,
placed: bool = false,
pos: rl.Vector2 = .{ .x = 0, .y = 0 },

pub const PortalSnapshot = struct {
    source: [2]rl.Vector2,
    dest: [2]rl.Vector2,
};

pub fn init() Self {
    return .{};
}

pub fn getSnapshot(self: Self) PortalSnapshot {
    return .{
        .source = self.source,
        .dest = self.dest,
    };
}

pub fn fromSnapshot(snap: PortalSnapshot) Self {
    return .{
        .source = snap.source,
        .dest = snap.dest,
        .point_count = 4,
        .placed = true,
    };
}

pub fn checkCollision(self: *Self, pos: rl.Vector2) bool {
    return commons.vecToLineSegment(pos, self.source[0], self.source[1]).length() <= 5;
}

pub fn getSourcePosFromU(self: Self, u: f32) rl.Vector2 {
    return self.source[0].add(self.source[1].subtract(self.source[0]).scale(u));
}

pub fn getDestPos(self: Self, u: f32) rl.Vector2 {
    return self.dest[0].add(self.dest[1].subtract(self.dest[0]).scale(u));
}

pub fn update(self: *Self, sim_data: SimData, settings: Settings) Entity.EntityAction {
    if (!self.placed) {
        self.pos = commons.roundMousePos(sim_data);
        // place new point
        if (commons.editorCapturingMouse(settings) and rl.isMouseButtonPressed(.mouse_button_left)) {
            self.point_count += 1;
            switch (self.point_count) {
                1 => self.source[0] = self.pos,
                2 => self.source[1] = self.pos,
                3 => self.dest[0] = self.pos,
                4 => {
                    self.dest[1] = self.pos;
                    self.point_count -= 1;
                    self.placed = true;
                    return .confirm;
                },
                else => unreachable,
            }
        }
    }
    return .none;
}

pub fn draw(self: Self) void {
    const thick = 6;
    if (self.point_count == 0) {
        rl.drawCircleV(self.pos, 6, palette.env.light_blue);
    } else if (self.point_count == 1) {
        rl.drawLineEx(self.source[0], self.pos, thick, palette.env.light_blue);
    }
    if (self.point_count >= 2) {
        rl.drawLineEx(self.source[0], self.source[1], thick, palette.env.light_blue);
    }
    if (self.point_count == 2) {
        rl.drawCircleV(self.pos, 6, palette.env.orange);
    }
    if (self.point_count == 3) {
        rl.drawLineEx(self.dest[0], self.pos, thick, palette.env.orange);
    } else if (self.point_count == 4) {
        rl.drawLineEx(self.dest[0], self.dest[1], thick, palette.env.orange);
    }
}
