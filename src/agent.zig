///
///  rl.getTime() is in SECONDS
///
const std = @import("std");
const rl = @import("raylib");
//
const commons = @import("commons.zig");
const color = @import("color.zig");
const AgentData = @import("AgentData.zig");
const Contour = @import("environment/Contour.zig");
const Area = @import("environment/Area.zig");
const node = @import("nodes/node.zig");
const Graph = @import("nodes/Graph.zig");

const Self = @This();

pos: rl.Vector2,
target: rl.Vector2,
col: rl.Color,
vel: rl.Vector2 = .{ .x = 0, .y = 0 },
acc: rl.Vector2 = .{ .x = 0, .y = 0 },

graph: *Graph,
current_node: ?*node.Node = null,
wait: i32 = 0,
last_wait: f64 = 0,
waiting: bool = false,

marked: bool = false, // marked to delete later

pub fn init(
    pos: rl.Vector2,
    spawner_node: *node.Node,
    graph: *Graph,
) Self {
    const col: rl.Color = color.getAgentColor();
    var obj = Self{
        .pos = pos,
        .target = .{ .x = 100, .y = 100 },
        .col = col,
        .graph = graph,
    };
    obj.traverse(spawner_node);
    return obj;
}

pub fn traverse(self: *Self, spawner_node: *node.Node) void {
    if (self.graph.getNextNode(spawner_node)) |next| {
        // check if the spawner is connected to another node
        switch (next.kind) {
            .spawner => unreachable,
            .area => |*area_node| {
                self.target = area_node.getCenter();
                self.wait = area_node.getWaitTime();
            },
            .sink => {
                // next is sink, so destroy outselves
                self.marked = true;
            },
        }
        self.current_node = next;
    } else {
        // the spawner is standalone, so just kill the agent
        self.marked = true;
    }
}

/// every frame, processCurrentNode checks what node we are on currently, and then
/// checks (for example) if we need to start waiting
pub fn processCurrentNode(self: *Self) void {
    if (self.current_node) |n| {
        switch (n.kind) {
            .area => |*area_node| {
                // check should start waiting
                if (!self.waiting) {
                    // start waiting if in bounds
                    if (rl.checkCollisionPointRec(self.pos, area_node.getArea().rect)) {
                        self.waiting = true;
                        self.last_wait = commons.getTimeMillis();
                    }
                } else {
                    // is already waiting; check if waited long enough in the area
                    const time: f64 = commons.getTimeMillis();
                    if (time - self.last_wait >= @as(f64, @floatFromInt(self.wait))) {
                        // waited long enough. continue
                        if (self.current_node) |current_node| {
                            self.traverse(current_node);
                        }
                    }
                }
            },
            inline else => {},
        }
    }
}

fn calculateObstacleForce(
    self: *Self,
    contours: *std.ArrayList(*Contour),
    agent_data: AgentData,
) rl.Vector2 {
    var force: rl.Vector2 = .{ .x = 0, .y = 0 };
    // iterate over all contour objects
    for (contours.items) |contour| {
        // iterate over all line segements in that contour
        for (0..contour.points.items.len) |i| {
            if (i == contour.points.items.len - 1) continue;
            const A: rl.Vector2 = contour.points.items[i];
            const B: rl.Vector2 = contour.points.items[i + 1];
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

            const radius_float: f32 = @floatFromInt(agent_data.radius);
            const exp_term: f32 = std.math.exp((radius_float - dist) / agent_data.b_ob);
            const f_ob = n.scale(agent_data.a_ob * exp_term);
            force = force.add(f_ob);
        }
    }
    return force;
}

fn calculateInteractiveForce(self: *Self, agents: *std.ArrayList(Self), agent_data: AgentData) rl.Vector2 {
    var force: rl.Vector2 = .{ .x = 0, .y = 0 };
    for (agents.items) |*other| {
        if (self == other) continue;
        const n = self.pos.subtract(other.pos);
        const sum_radii: f32 = @floatFromInt(agent_data.radius * 2);
        const dist: f32 = other.pos.subtract(self.pos).length();
        const exp_term: f32 = std.math.exp((sum_radii - dist) / agent_data.b_ped);
        const f_ped = n.scale(agent_data.a_ped * exp_term);
        force = force.add(f_ped);
    }
    return force;
}

fn calculateDriveForce(self: *Self, agent_data: AgentData) rl.Vector2 {
    const e = self.target.subtract(self.pos).normalize();
    const v0_vec = e.scale(agent_data.speed);
    const f = v0_vec.subtract(self.vel)
        .scale(1 / agent_data.relaxation);
    return f;
}

pub fn update(
    self: *Self,
    agents: *std.ArrayList(Self),
    contours: *std.ArrayList(*Contour),
    agent_data: AgentData,
) void {
    // get force components
    const drive_force = self.calculateDriveForce(agent_data);
    const interactive_force = self.calculateInteractiveForce(agents, agent_data);
    const obstacle_force = self.calculateObstacleForce(contours, agent_data);
    self.acc = drive_force
        .add(interactive_force)
        .add(obstacle_force);

    // newton
    self.vel = self.vel.add(self.acc);
    self.pos = self.pos.add(self.vel);

    // process node
    self.processCurrentNode();
}

pub fn draw(self: *const Self, agent_data: AgentData) void {
    // render sphere
    const f_radius: f32 = @floatFromInt(agent_data.radius);
    if (self.waiting) {
        // waiting pedestrians have reddish color
        rl.drawCircleV(self.pos, f_radius, color.hexToColor(color.fromPalette(.clay)));
    } else {
        rl.drawCircleV(self.pos, f_radius, self.col);
    }
    rl.drawCircleLinesV(self.pos, f_radius, color.white);

    if (agent_data.show_vectors) {
        const m: u32 = 12;
        // render velocity vector
        const norm_vel = self.vel.normalize().scale(m);
        rl.drawLineEx(self.pos, self.pos.add(norm_vel), 2, color.green);

        // render acceleration vector
        const norm_acc = self.acc.normalize().scale(m);
        rl.drawLineEx(self.pos, self.pos.add(norm_acc), 2, color.orange);
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
