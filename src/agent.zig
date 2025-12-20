const std = @import("std");
const rl = @import("raylib");
//
const commons = @import("commons.zig");
const color = @import("color.zig").Color;
const AgentData = @import("agent_data.zig").AgentData;

pub const Agent = struct {
    pos: rl.Vector2,
    vel: rl.Vector2,

    pub fn update(self: *Agent, _: *const AgentData) void {
        self.pos.x += self.vel.x;
        self.pos.y += self.vel.y;
    }

    pub fn draw(self: *Agent, data: *const AgentData) void {
        rl.drawCircleV(self.pos, @floatFromInt(data.radius), commons.arrToColor(color.WHITE));
    }
};

pub fn create(agents: *std.ArrayList(Agent), _: rl.Vector2, num: i32) !void {
    for (1..@as(usize, @intCast(num))) |_| {
        try agents.append(.{ .pos = .{
            .x = @floatFromInt(rl.getRandomValue(200, 300)),
            .y = @floatFromInt(rl.getRandomValue(200, 300)),
        }, .vel = .{
            .x = @floatFromInt(rl.getRandomValue(-1, 1)),
            .y = @floatFromInt(rl.getRandomValue(-1, 1)),
        } });
    }
}
