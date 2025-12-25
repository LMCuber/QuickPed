const std = @import("std");
const rl = @import("raylib");
//
const commons = @import("commons.zig");
const color = @import("color.zig");
const AgentData = @import("agent_data.zig");
const Contour = @import("environment/contour.zig");

const Self = @This();

pos: rl.Vector2,
target: rl.Vector2,
col: rl.Color,
agent_data: *AgentData,
agents: *std.ArrayList(Self),
contours: *std.ArrayList(Contour),
vel: rl.Vector2 = .{ .x = 0, .y = 0 },
acc: rl.Vector2 = .{ .x = 0, .y = 0 },

pub fn init(pos: rl.Vector2, target: rl.Vector2, agent_data: *AgentData, agents: *std.ArrayList(Self), contours: *std.ArrayList(Contour)) Self {
    const col: rl.Color = color.getAgentColor();
    return Self{
        .pos = pos,
        .target = target,
        .col = col,
        .agent_data = agent_data,
        .agents = agents,
        .contours = contours,
    };
}

fn calculateObstacleForce(self: *Self) rl.Vector2 {
    var force: rl.Vector2 = .{ .x = 0, .y = 0 };
    // iterate over all contour objects
    for (self.contours.items) |contour| {
        // iterate over all line segements in that contour
        for (0..contour.points.items.len) |i| {
            const A: rl.Vector2 = contour.points.items[i];
            const B: rl.Vector2 = contour.points.items[if (i == contour.points.items.len - 1) 0 else (i + 1)];
            const AB = B.subtract(A);
            const t: f32 = std.math.clamp(
                self.pos.subtract(A).dotProduct(AB) / AB.dotProduct(AB),
                0,
                1,
            );
            const C = A.add(AB.scale(t));
            const D = self.pos.subtract(C);
            const dist = D.length();
            const n = D.normalize();

            const radius_float: f32 = @floatFromInt(self.agent_data.radius);
            const exp_term: f32 = std.math.exp((radius_float - dist) / self.agent_data.b_ped);
            const f_ob = n.scale(self.agent_data.a_ob * exp_term);
            force = force.add(f_ob);
        }
    }
    return force;
}

fn calculateInteractiveForce(self: *Self) rl.Vector2 {
    var force: rl.Vector2 = .{ .x = 0, .y = 0 };
    for (self.agents.items) |*other| {
        if (self == other) continue;
        const n = self.pos.subtract(other.pos);
        const sum_radii: f32 = @floatFromInt(self.agent_data.radius * 2);
        const dist: f32 = other.pos.subtract(self.pos).length();
        const exp_term: f32 = std.math.exp((sum_radii - dist) / self.agent_data.b_ped);
        const f_ped = n.scale(self.agent_data.a_ped * exp_term);
        force = force.add(f_ped);
    }
    return force;
}

fn calculateDriveForce(self: *Self) rl.Vector2 {
    const e = self.target.subtract(self.pos).normalize();
    const v0_vec = e.scale(self.agent_data.speed);
    const f = v0_vec.subtract(self.vel)
        .scale(1 / self.agent_data.relaxation);
    return f;
}

pub fn update(self: *Self) void {
    // debug
    self.target = commons.mousePos();

    // get force components
    const drive_force = self.calculateDriveForce();
    const interactive_force = self.calculateInteractiveForce();
    const obstacle_force = self.calculateObstacleForce();
    self.acc = drive_force
        .add(interactive_force)
        .add(obstacle_force);

    // newton
    self.vel = self.vel.add(self.acc);
    self.pos = self.pos.add(self.vel);
}

pub fn draw(self: *const Self) void {
    // render sphere
    const f_radius: f32 = @floatFromInt(self.agent_data.radius);
    rl.drawCircleV(self.pos, f_radius, self.col);
    rl.drawCircleLinesV(self.pos, f_radius, color.white);

    if (self.agent_data.show_vectors) {
        const m: u32 = 12;
        // render velocity vector
        const norm_vel = self.vel.normalize().scale(m);
        rl.drawLineEx(self.pos, self.pos.add(norm_vel), 2, color.green);

        // render acceleration vector
        const norm_acc = self.acc.normalize().scale(m);
        rl.drawLineEx(self.pos, self.pos.add(norm_acc), 2, color.orange);
    }
}

pub fn create(agents: *std.ArrayList(Self), contours: *std.ArrayList(Contour), agent_data: *AgentData, num: i32) !void {
    for (0..@as(usize, @intCast(num))) |_| {
        try agents.append(Self.init(
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
            contours,
        ));
    }
}

pub fn delete(agents: *std.ArrayList(Self), num: i32) void {
    for (0..@as(usize, @intCast(num))) |_| {
        if (agents.items.len > 0) {
            _ = agents.swapRemove(0);
        } else {
            return;
        }
    }
}
