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
const Agent = @import("../Agent.zig");

pos: rl.Vector2 = .{ .x = 0, .y = 0 },
direction: rl.Vector2 = .{ .x = 0, .y = -1 },
placed: bool = false,

pub const QueueSnapshot = struct {
    pos: rl.Vector2,
    direction: rl.Vector2,
};

pub fn init() Self {
    return .{};
}

pub fn getSnapshot(self: Self) QueueSnapshot {
    return .{
        .pos = self.pos,
        .direction = self.direction,
    };
}

pub fn fromSnapshot(snap: QueueSnapshot) Self {
    return .{
        .pos = snap.pos,
        .direction = snap.direction,
        .placed = true,
    };
}

pub fn getTarget(self: *Self) rl.Vector2 {
    return self.pos;
}

pub fn registerNewAgent(self: *Self, agents: *std.ArrayList(Agent)) ?*Agent {
    // find the last agent of the queue
    for (agents.items) |*agent| {
        const payload = agent.current_payload.?.queue;
        if (payload.obj == self) {
            if (payload.is_last) {
                return agent;
            }
        }
    }
    return null;
}

pub fn update(self: *Self, sim_data: SimData, settings: Settings) !Entity.EntityAction {
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
    if (z.button("rotate", .{})) {
        self.direction = self.direction.rotate(std.math.pi / 2.0);
    }
    return;
}

pub fn draw(self: *Self) void {
    // draw queue
    const col = if (self.placed) (palette.env.orange) else (palette.env.white_t);
    rl.drawCircleLinesV(self.pos, 8, col);

    // draw direction
    const mag = 16;
    rl.drawLineV(self.pos, self.pos.add(self.direction.scale(mag)), palette.env.green);
}
