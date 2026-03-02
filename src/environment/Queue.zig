const Self = @This();
const std = @import("std");
const rl = @import("raylib");
const z = @import("zgui");
const color = @import("../color.zig");
const palette = @import("../palette.zig");
const commons = @import("../commons.zig");
const SimData = @import("../editor/SimData.zig");
const AgentData = @import("../editor/AgentData.zig");
const Settings = @import("../Settings.zig");
const Entity = @import("../environment/entity.zig").Entity;
const Environment = @import("../environment/Environment.zig");
const Agent = @import("../Agent.zig");

pos: rl.Vector2 = .{ .x = 0, .y = 0 },
direction: rl.Vector2 = .{ .x = 0, .y = -1 },
padding: i32 = 6,
placed: bool = false,
agents: std.ArrayList(usize),

pub const QueueSnapshot = struct {
    pos: rl.Vector2,
    direction: rl.Vector2,
    padding: i32,
};

pub fn init(alloc: std.mem.Allocator) !Self {
    return .{
        .agents = std.ArrayList(usize).init(alloc),
    };
}

pub fn deinit(self: *Self) void {
    self.agents.deinit();
}

pub fn getSnapshot(self: Self) QueueSnapshot {
    return .{
        .pos = self.pos,
        .direction = self.direction,
        .padding = self.padding,
    };
}

pub fn fromSnapshot(alloc: std.mem.Allocator, snap: QueueSnapshot) !Self {
    return .{
        .pos = snap.pos,
        .direction = snap.direction,
        .padding = snap.padding,
        .placed = true,
        .agents = std.ArrayList(usize).init(alloc),
    };
}

pub fn getPadding(self: Self, agent_data: AgentData) f32 {
    return @floatFromInt(agent_data.radius * 2 + self.padding);
}

pub fn getTarget(self: *Self, agent_data: AgentData) rl.Vector2 {
    return self.pos.add(self.direction.scale(self.getPadding(agent_data)));
}

pub fn getPreviousAgentId(self: *Self, agent_id: usize) ?usize {
    var before: ?usize = null;
    for (self.agents.items) |other_id| {
        if (agent_id == other_id) {
            return before;
        }
        before = other_id;
    }
    return before;
}

pub fn registerNewAgent(self: *Self, agent_id: usize) !?usize {
    try self.agents.append(agent_id);
    if (self.agents.items.len == 1) return null;
    return self.agents.items[self.agents.items.len - 2];
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
    _ = z.sliderInt("padding", .{ .v = &self.padding, .min = 0, .max = 16 });
    if (z.button("rotate", .{})) {
        self.direction = self.direction.rotate(std.math.pi / 2.0);
    }
    return;
}

pub fn draw(self: *Self, agent_data: AgentData) void {
    // draw queue
    const col = if (self.placed) (palette.env.orange) else (palette.env.white_t);
    rl.drawCircleLinesV(self.pos, 8, col);

    // draw direction
    rl.drawLineV(self.pos, self.pos.add(self.direction.scale(self.getPadding(agent_data))), palette.env.green);
}
