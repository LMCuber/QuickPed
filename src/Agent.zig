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
const Agent = @import("Agent.zig");
const SimData = @import("editor/SimData.zig");
const AgentData = @import("editor/AgentData.zig");
const Contour = @import("environment/Contour.zig");
const Revolver = @import("environment/Revolver.zig");
const Area = @import("environment/Area.zig");
const Queue = @import("environment/Queue.zig");
const node = @import("nodes/node.zig");
const Graph = @import("nodes/Graph.zig");
const Environment = @import("environment/Environment.zig");
const Manager = @import("Manager.zig").Manager;
const entity = @import("environment/entity.zig");
const Stats = @import("editor/Stats.zig");
const Settings = @import("Settings.zig");

pos: rl.Vector2,
target: rl.Vector2,
col: rl.Color,
vel: rl.Vector2 = .{ .x = 0, .y = 0 },
acc: rl.Vector2 = .{ .x = 0, .y = 0 },

graph: *Graph,
current_node_id: ?usize = null,
marked: bool = false, // marked to delete later

wait: WaitPayload,

payload: ?union(enum) {
    area: AreaPayload,
    queue: QueuePayload,
},

pub const WaitPayload = struct {
    waiting: bool = false,
    wait: i32 = 0,
    last_wait: f64 = 0,

    pub fn setWait(self: *WaitPayload, wait: i32) void {
        self.waiting = true;
        self.wait = wait;
        self.last_wait = commons.getTimeMillis();
    }
};

pub const AreaPayload = struct {
    area_index: usize,
    seat_index: ?usize = null,
};

pub const QueuePayload = struct {
    queue_index: usize,
    spot_index: usize,
    stationary: bool = false,
};

// FUNCTIONS
pub fn init(
    alloc: std.mem.Allocator,
    pos: rl.Vector2,
    spawner_node_id: usize,
    graph: *Graph,
    agent_id: usize,
    env: *Environment,
) !Self {
    const col: rl.Color = color.getAgentColor();
    var obj: Self = .{
        .pos = pos,
        .target = .{ .x = 100, .y = 100 },
        .col = col,
        .graph = graph,
        .wait = .{},
        .payload = null,
    };
    obj.current_node_id = spawner_node_id;
    try obj.traverseFromCurrent(alloc, agent_id, &graph.nodes, env);
    return obj;
}

pub fn traverseFromCurrent(
    self: *Self,
    alloc: std.mem.Allocator,
    agent_id: usize,
    nodes: *Graph.NodeManager,
    env: *Environment,
) !void {
    // get the next node from graph and then process it
    // !! getNextNodeId() take into account the next of forks !!
    if (try self.graph.getNextNodeId(alloc, self.current_node_id.?)) |next_node_id| {
        // set current node to next by default (might be changed by e.g. fork)
        self.current_node_id = next_node_id;

        const next_node: *node.Node = nodes.getItem(next_node_id);

        // check what type of node the next found node is
        switch (next_node.kind) {
            .spawner => unreachable,
            .area => |*area_node| {
                self.payload = .{
                    .area = .{
                        .area_index = @intCast(area_node.area_index),
                    },
                };
                switch (area_node.getArea().style) {
                    .individual => |*data| {
                        self.payload.?.area.seat_index = data.getSeatIndex();
                        self.target = data.getPosFromSeatIndex(self.payload.?.area.seat_index.?);
                    },
                    inline else => self.target = area_node.getArea().getPos(),
                }
            },
            .sink => self.marked = true, // next is sink, so destroy ourselves
            .fork => {
                self.current_node_id = next_node_id;
                try self.traverseFromCurrent(alloc, agent_id, nodes, env);
            },
            .queue_fork => unreachable,
            .queue => |*queue_node| {
                self.current_node_id = next_node_id;
                self.payload = .{
                    .queue = .{
                        .queue_index = @intCast(queue_node.queue_index),
                        .spot_index = queue_node.getQueue().getWaitingSpotIndex(),
                    },
                };
                self.target = queue_node.getQueue().getWaitingSpotFromIndex(
                    self.payload.?.queue.spot_index,
                );
            },
        }
    } else {
        // the spawner is standalone, so just kill the agent
        self.marked = true;
    }
}

pub fn getBehindVector(
    self: *Self,
    agent_id: usize,
    agents: *Environment.AgentManager,
    agent_data: AgentData,
) rl.Vector2 {
    // will only be called on agents that are NOT on the front of the queue
    // (ones which have valid prev_agent_ids)

    const queue_obj: *Queue = self.payload.?.queue.obj;
    const prev_agent_id: usize = queue_obj.getPreviousAgentId(agent_id).?;
    const prev_prev_agent: ?usize = queue_obj.getPreviousAgentId(prev_agent_id);

    var direction: ?rl.Vector2 = null;
    if (prev_prev_agent) |prev_prev_agent_id| {
        direction = agents.getItem(prev_agent_id).target
            .subtract(agents.getItem(prev_prev_agent_id).target).normalize();
    } else {
        // the prev prev is none, so the queue is only 2 long.
        // Calculate direction using queue.pos
        direction = agents.getItem(prev_agent_id).target.subtract(queue_obj.pos).normalize();
    }
    return self.target.add(direction.?.scale(queue_obj.getPadding(agent_data)));
}

/// every frame, processCurrentNode checks what node we are on currently
/// and then (for example) checks if we need to start waiting because we entered radius of a waiting area
pub fn processCurrentNode(
    self: *Self,
    alloc: std.mem.Allocator,
    agent_id: usize,
    sim_data: SimData,
    agent_data: AgentData,
    nodes: *Graph.NodeManager,
    env: *Environment,
) !void {
    const current_node: *node.Node = nodes.getItem(self.current_node_id.?);
    const time: f64 = commons.getTimeMillis();

    switch (current_node.kind) {
        .area => |*area_node| {
            const area_payload = self.payload.?.area;
            const a_obj: *Area = &env.entities.getItem(env.areas.items[area_payload.area_index]).kind.area;

            // check should start waiting
            if (!self.wait.waiting) {
                // start waiting if in bounds
                if (a_obj.checkCollision(self.pos, self.target)) {
                    self.wait.setWait(area_node.getWaitTime());
                }
            } else {
                // is already waiting; check if waited long enough in the area
                if (time - self.wait.last_wait >= @as(f64, @floatFromInt(self.wait.wait))) {
                    // waited long enough. continue
                    self.wait.waiting = false;
                    try self.traverseFromCurrent(alloc, agent_id, nodes, env);
                }
            }
        },
        .queue => |queue_node| {
            const q: *Self.QueuePayload = &self.payload.?.queue;
            var q_obj: *Queue = &env.entities.getItem(env.queues.items[q.queue_index]).kind.queue;

            // "waiting" means in the queue
            if (self.wait.waiting) {
                // is waiting
                if (q.spot_index == 0) {
                    // is at front
                    if (time - self.wait.last_wait >= @as(f64, @floatFromInt(self.wait.wait))) {
                        if (q.stationary) {
                            // can only dispatch if it is stationary
                            q_obj.freeIndex(q.spot_index);
                            self.wait.waiting = false;
                            try self.traverseFromCurrent(alloc, agent_id, nodes, env);
                        }
                    }
                }
            }

            // stationary -> in queue, but in queue -X> stationary
            // ^^^ wow Leo is so smart for using predicate logic in his comments look at him

            // is not stationary
            if (!q.stationary) {
                if (self.pos.distance(self.target) <= agent_data.radius * @as(f32, @floatFromInt(sim_data.scale))) {
                    self.wait.setWait(queue_node.getWaitTime());
                    q.stationary = true;
                }
            }

            // regardless of waiting or not
            if (q.spot_index != 0 and q_obj.isFree(q.spot_index - 1)) {
                // scoot up since one in front is free
                q_obj.freeIndex(q.spot_index);
                q.spot_index -= 1;
                q_obj.occupyIndex(q.spot_index);

                // if its at front of queue now because of shift, init waiting variables
                self.target = q_obj.getWaitingSpotFromIndex(q.spot_index);
                q.stationary = false;
            }
        },
        else => {},
    }
}

fn obstacleForceFromTwoVectors(
    self: *Self,
    A: rl.Vector2,
    B: rl.Vector2,
    sim_data: SimData,
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

    const radius_float: f32 = agent_data.radius * @as(f32, @floatFromInt(sim_data.scale));
    const exp_term: f32 = std.math.exp((radius_float - dist) / agent_data.b_ob);
    const f_ob = n.scale(agent_data.a_ob * exp_term);
    return f_ob;
}

fn calculateObstacleForce(
    self: *Self,
    env: *Environment,
    sim_data: SimData,
    agent_data: AgentData,
) rl.Vector2 {
    var force: rl.Vector2 = .{ .x = 0, .y = 0 };

    // iterate over all contour objects
    for (env.contours.items) |contour_id| {
        const contour: Contour = env.entities.getItem(contour_id).kind.contour;

        // iterate over all line segements in that contour
        for (0..contour.points.items.len) |i| {
            if (i == contour.points.items.len - 1) continue;
            const A: rl.Vector2 = contour.points.items[i];
            const B: rl.Vector2 = contour.points.items[i + 1];

            const f_ob: rl.Vector2 = self.obstacleForceFromTwoVectors(A, B, sim_data, agent_data);
            force = force.add(f_ob);
        }
    }

    // iterate over all the revolvers
    for (env.revolvers.items) |revolver_id| {
        const revolver: Revolver = env.entities.getItem(revolver_id).kind.revolver;

        // get 4 rotational symmetries
        for (0..4) |i| {
            const a: f32 = @as(f32, @floatFromInt(i)) * 0.5 * std.math.pi;
            const A: rl.Vector2 = revolver.pos;
            const AB: rl.Vector2 = revolver.getRotatedVector(a);
            const B: rl.Vector2 = A.add(AB);
            const f_rev = self.obstacleForceFromTwoVectors(A, B, sim_data, agent_data);
            force = force.add(f_rev);
        }
    }

    return force;
}

fn calculateInteractiveForce(
    self: *Self,
    agents: *Environment.AgentManager,
    sim_data: SimData,
    agent_data: AgentData,
) rl.Vector2 {
    var force: rl.Vector2 = .{ .x = 0, .y = 0 };
    for (&agents.items) |*other_aslot| {
        if (!other_aslot.alive) continue;
        const other = &other_aslot.value;

        if (self == &other_aslot.value) continue;

        const n = self.pos.subtract(other.pos);
        const sum_radii: f32 = agent_data.radius * @as(f32, @floatFromInt(sim_data.scale)) * 2.0;
        const dist: f32 = other.pos.subtract(self.pos).length();
        const exp_term: f32 = std.math.exp((sum_radii - dist) / agent_data.b_ped);
        const f_ped = n.scale(agent_data.a_ped * exp_term);
        force = force.add(f_ped);
    }
    return force;
}

fn calculateDriveForce(self: *Self, sim_data: SimData, agent_data: AgentData) rl.Vector2 {
    const e: rl.Vector2 = self.target.subtract(self.pos).normalize();
    var speed_in_pixels: f32 = @as(f32, @floatFromInt(sim_data.scale)) * agent_data.speed;
    speed_in_pixels *= (1.0 / 60.0);
    const v0_vec: rl.Vector2 = e.scale(speed_in_pixels);
    const f = v0_vec.subtract(self.vel).scale(1 / agent_data.relaxation);
    return f;
}

pub fn update(
    self: *Self,
    alloc: std.mem.Allocator,
    env: *Environment,
    stats: *Stats,
    settings: Settings,
    sim_data: SimData,
    agent_id: usize,
    agent_data: AgentData,
    n_rows: i32,
    n_cols: i32,
    nodes: *Graph.NodeManager,
) !void {
    // get force components
    const drive_force = self.calculateDriveForce(sim_data, agent_data);
    const interactive_force = self.calculateInteractiveForce(&env.agents, sim_data, agent_data);
    const obstacle_force = self.calculateObstacleForce(env, sim_data, agent_data);
    self.acc = drive_force
        .add(interactive_force)
        .add(obstacle_force);

    // newton
    self.vel = self.vel.add(self.acc);
    self.pos = self.pos.add(self.vel);

    // update the heatmap
    self.update_heatmap(stats, settings, n_rows, n_cols);

    // process node
    try self.processCurrentNode(
        alloc,
        agent_id,
        sim_data,
        agent_data,
        nodes,
        env,
    );
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

pub fn draw(self: *Self, sim_data: SimData, agent_data: AgentData) void {
    // render sphere
    const f_radius: f32 = agent_data.radius * @as(f32, @floatFromInt(sim_data.scale));

    if (self.wait.waiting) {
        rl.drawCircleV(self.pos, f_radius, color.hexToColor(color.fromPalette(.clay)));
    } else {
        rl.drawCircleV(self.pos, f_radius, self.col);
    }

    if (self.payload) |payload| {
        switch (payload) {
            .queue => |q| {
                if (q.stationary) {
                    rl.drawCircleV(self.pos, 2, palette.env.black);
                }
            },
            else => {},
        }
    }

    if (agent_data.show_vectors) {
        const m: u32 = 12;
        // render velocity vector
        const norm_vel = self.vel.normalize().scale(m);
        rl.drawLineEx(self.pos, self.pos.add(norm_vel), 2, color.green);

        // render acceleration vector
        const norm_acc = self.acc.normalize().scale(m);
        rl.drawLineEx(self.pos, self.pos.add(norm_acc), 2, color.orange);
    }

    if (agent_data.show_targets) {
        rl.drawCircleLinesV(self.target, agent_data.radius * @as(f32, @floatFromInt(sim_data.scale)) * 2.0, palette.env.red);
        rl.drawLineV(self.pos, self.target, palette.env.red);
    }
}
