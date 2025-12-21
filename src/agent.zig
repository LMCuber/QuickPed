const std = @import("std");
const rl = @import("raylib");
//
const commons = @import("commons.zig");
const color = @import("color.zig").Color;
const AgentData = @import("agent_data.zig").AgentData;
const Settings = @import("settings.zig").Settings;

pub const Agent = struct {
    pos: rl.Vector2,
    target: rl.Vector2,
    col: rl.Color,
    agent_data: *AgentData,
    agents: *std.ArrayList(Agent),
    vel: rl.Vector2 = .{ .x = 0, .y = 0 },
    acc: rl.Vector2 = .{ .x = 0, .y = 0 },

    pub fn init(
        pos: rl.Vector2,
        target: rl.Vector2,
        agent_data: *AgentData,
        agents: *std.ArrayList(Agent),
    ) Agent {
        const col: rl.Color = color.getAgentColor();
        return Agent{
            .pos = pos,
            .target = target,
            .col = col,
            .agent_data = agent_data,
            .agents = agents,
        };
    }

    fn calculateInteractiveForce(self: *Agent) rl.Vector2 {
        var force: rl.Vector2 = .{ .x = 0, .y = 0 };
        for (self.agents.items) |*other| {
            if (self == other) continue;
            const n = self.pos.subtract(other.pos);
            const sum_radii: f32 = @floatFromInt(self.agent_data.radius * 2);
            const dist: f32 = other.pos.subtract(self.pos).length();
            const exp_term: f32 = std.math.exp((sum_radii - dist) / self.agent_data.b_ped);
            const f_ped: rl.Vector2 = n.scale(self.agent_data.a_ped * exp_term);
            force = force.add(f_ped);
        }
        return force;
    }

    fn calculateDriveForce(self: *Agent) rl.Vector2 {
        const e: rl.Vector2 = self.target.subtract(self.pos).normalize();
        const v0_vec: rl.Vector2 = e.scale(self.agent_data.speed);
        const f: rl.Vector2 = v0_vec.subtract(self.vel)
            .scale(1 / self.agent_data.relaxation);
        return f;
    }

    pub fn update(self: *Agent) void {
        // debug
        self.target = rl.getMousePosition();

        // get force components
        const drive_force: rl.Vector2 = self.calculateDriveForce();
        const interactive_force: rl.Vector2 = self.calculateInteractiveForce();
        self.acc = drive_force.add(interactive_force);

        // newton
        self.vel = self.vel.add(self.acc);
        self.pos = self.pos.add(self.vel);
    }

    pub fn draw(self: *Agent) void {
        // render sphere
        const f_radius: f32 = @floatFromInt(self.agent_data.radius);
        rl.drawCircleV(self.pos, f_radius, self.col);
        rl.drawCircleLinesV(self.pos, f_radius, color.WHITE);

        if (self.agent_data.show_vectors) {
            const m: u32 = 12;
            // render velocity vector
            const norm_vel: rl.Vector2 = self.vel.normalize().scale(m);
            rl.drawLineEx(self.pos, self.pos.add(norm_vel), 2, color.GREEN);

            // render acceleration vector
            const norm_acc: rl.Vector2 = self.acc.normalize().scale(m);
            rl.drawLineEx(self.pos, self.pos.add(norm_acc), 2, color.ORANGE);
        }
    }
};

pub fn create(agents: *std.ArrayList(Agent), agent_data: *AgentData, num: i32) !void {
    for (0..@as(usize, @intCast(num))) |_| {
        try agents.append(Agent.init(
            .{
                .x = @floatFromInt(rl.getRandomValue(200, 300)),
                .y = @floatFromInt(rl.getRandomValue(200, 300)),
            },
            .{
                .x = 500,
                .y = 500,
            },
            agent_data,
            agents,
        ));
    }
}

pub fn delete(agents: *std.ArrayList(Agent), num: i32) void {
    for (0..@as(usize, @intCast(num))) |_| {
        if (agents.items.len > 0) {
            _ = agents.swapRemove(0);
        } else {
            return;
        }
    }
}
