//
//  rl.getTime() is in SECONDS
//
const Self = @This();
const std = @import("std");
const rl = @import("raylib");
//
const commons = @import("commons.zig");
const color = @import("color.zig");
const palette = @import("palette.zig");
const AgentData = @import("editor/AgentData.zig");
const Contour = @import("environment/Contour.zig");
const Revolver = @import("environment/Revolver.zig");
const Area = @import("environment/Area.zig");
const node = @import("nodes/node.zig");
const Graph = @import("nodes/Graph.zig");
const Environment = @import("environment/Environment.zig");
const Stats = @import("editor/Stats.zig");
const Settings = @import("Settings.zig");

pos: rl.Vector2,
target_area: ?*Area = null,
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
    alloc: std.mem.Allocator,
    pos: rl.Vector2,
    spawner_node: *node.Node,
    graph: *Graph,
) !Self {
    const col: rl.Color = color.getAgentColor();
    var obj = Self{
        .pos = pos,
        .target = .{ .x = 100, .y = 100 },
        .col = col,
        .graph = graph,
    };
    obj.current_node = spawner_node;
    try obj.traverseFromCurrent(alloc);
    return obj;
}

pub fn traverseFromCurrent(self: *Self, alloc: std.mem.Allocator) !void {
    // check if current node exists at all to traverse from
    const from_node: *node.Node = self.current_node orelse unreachable;

    // get the next node from graph and then process it
    if (try self.graph.getNextNode(alloc, from_node)) |next| {
        // set current node to next by default (might be changed by e.g. fork)
        self.current_node = next;

        // check what type of node the next found node is
        switch (next.kind) {
            .spawner => unreachable,
            .area => |*area_node| {
                self.target_area = area_node.getArea();
                self.target = self.target_area.?.getPos();
                self.waiting = false;
            },
            .sink => {
                // next is sink, so destroy outselves
                self.marked = true;
            },
            .fork => {
                self.current_node = next;
                try self.traverseFromCurrent(alloc);
            },
        }
    } else {
        // the spawner is standalone, so just kill the agent
        // this works for both a dangling Spawner & Area
        // but have different effects
        self.marked = true;
    }
}

/// every frame, processCurrentNode checks what node we are on currently, and then
/// checks (for example) if we need to start waiting because we entered radius of waiting area
pub fn processCurrentNode(self: *Self, alloc: std.mem.Allocator) !void {
    if (self.current_node) |n| {
        switch (n.kind) {
            .area => |*area_node| {
                // check should start waiting
                if (!self.waiting) {
                    // start waiting if in bounds
                    if (rl.checkCollisionPointRec(self.pos, self.target_area.?.rect)) {
                        self.wait = area_node.getWaitTime();
                        self.waiting = true;
                        self.last_wait = commons.getTimeMillis();
                    }
                } else {
                    // is already waiting; check if waited long enough in the area
                    const time: f64 = commons.getTimeMillis();
                    if (time - self.last_wait >= @as(f64, @floatFromInt(self.wait))) {
                        // waited long enough. continue
                        try self.traverseFromCurrent(alloc);
                    }
                }
            },
            inline else => {},
        }
    }
}

fn obstacleForceFromTwoVectors(
    self: *Self,
    A: rl.Vector2,
    B: rl.Vector2,
    agent_data: AgentData,
) rl.Vector2 {
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
    return f_ob;
}

fn calculateObstacleForce(
    self: *Self,
    env: *Environment,
    agent_data: AgentData,
) rl.Vector2 {
    var force: rl.Vector2 = .{ .x = 0, .y = 0 };

    // iterate over all contour objects
    for (env.contours.items) |contour| {
        // iterate over all line segements in that contour
        for (0..contour.points.items.len) |i| {
            if (i == contour.points.items.len - 1) continue;
            const A: rl.Vector2 = contour.points.items[i];
            const B: rl.Vector2 = contour.points.items[i + 1];

            const f_ob: rl.Vector2 = self.obstacleForceFromTwoVectors(A, B, agent_data);
            force = force.add(f_ob);
        }
    }

    // iterate over all the revolvers
    for (env.revolvers.items) |revolver| {
        // get 4 rotational symmetries
        for (0..4) |i| {
            const a: f32 = @as(f32, @floatFromInt(i)) * 0.5 * std.math.pi;
            const A: rl.Vector2 = revolver.pos;
            const AB: rl.Vector2 = revolver.getRotatedVector(a);
            const B: rl.Vector2 = A.add(AB);
            const f_rev = self.obstacleForceFromTwoVectors(A, B, agent_data);
            force = force.add(f_rev);
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
    alloc: std.mem.Allocator,
    agents: *std.ArrayList(Self),
    env: *Environment,
    stats: *Stats,
    settings: Settings,
    agent_data: AgentData,
    n_rows: i32,
    n_cols: i32,
) !void {
    // get force components
    const drive_force = self.calculateDriveForce(agent_data);
    const interactive_force = self.calculateInteractiveForce(agents, agent_data);
    const obstacle_force = self.calculateObstacleForce(env, agent_data);
    self.acc = drive_force
        .add(interactive_force)
        .add(obstacle_force);

    // newton
    self.vel = self.vel.add(self.acc);
    self.pos = self.pos.add(self.vel);

    // update the heatmap
    self.update_heatmap(stats, settings, n_rows, n_cols);

    // process node
    try self.processCurrentNode(alloc);
}

pub fn update_heatmap(self: *Self, stats: *Stats, settings: Settings, n_rows: i32, n_cols: i32) void {
    if (self.pos.x < 0) return;
    if (self.pos.y < 0) return;
    const int_x: i32 = @intFromFloat((self.pos.x / @as(f32, @floatFromInt(settings.width))) * @as(f32, @floatFromInt(n_cols)));
    const int_y: i32 = @intFromFloat((self.pos.y / @as(f32, @floatFromInt(settings.height))) * @as(f32, @floatFromInt(n_rows)));
    if (int_x >= n_rows) return;
    if (int_y >= n_cols) return;

    stats.add_to_heatmap(int_x, int_y);
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
