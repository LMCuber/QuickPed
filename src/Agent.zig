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
const Portal = @import("environment/Portal.zig");
const Queue = @import("environment/Queue.zig");
const node = @import("nodes/node.zig");
const Graph = @import("nodes/Graph.zig");
const Environment = @import("environment/Environment.zig");
const Manager = @import("Manager.zig").Manager;
const entity = @import("environment/entity.zig");
const Stats = @import("editor/Stats.zig");
const Settings = @import("Settings.zig");
const Quadtree = @import("Quadtree.zig");
const Benchmarker = @import("Benchmarker.zig");
const UUID = @import("UUID.zig");

uuid: UUID,
pos: rl.Vector2,
target: rl.Vector2,
col: rl.Color,
vel: rl.Vector2 = .{ .x = 0, .y = 0 },
acc: rl.Vector2 = .{ .x = 0, .y = 0 },

graph: *Graph,
current_node_id: ?UUID = null,

wait: WaitPayload,

payload: ?union(enum) {
    area: AreaPayload,
    portal: PortalPayload,
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
    area_id: UUID,
    seat_index: ?usize = null,
};

pub const PortalPayload = struct {
    portal_id: UUID,
    u: f32, // [0, 1]: the location in the spawn portal
};

pub const QueuePayload = struct {
    queue_index: UUID,
    spot_index: usize,
    stationary: bool = false,
};

// FUNCTIONS
pub fn init(
    alloc: std.mem.Allocator,
    pos: rl.Vector2,
    spawner_node_id: UUID,
    graph: *Graph,
    env: *Environment,
) !Self {
    // INIT CAUSES TRAVERSE FROM CURRENT!
    const col: rl.Color = color.getAgentColor();
    var obj: Self = .{
        .uuid = UUID.init(),
        .pos = pos,
        .target = .{ .x = 100, .y = 100 },
        .col = col,
        .graph = graph,
        .wait = .{},
        .payload = null,
    };
    obj.current_node_id = spawner_node_id;
    try obj.traverseFromCurrent(alloc, &graph.nodes, env);
    return obj;
}

pub fn traverseFromCurrent(
    self: *Self,
    alloc: std.mem.Allocator,
    nodes: *Graph.NodeManager,
    env: *Environment,
) !void {
    // get the next node from graph and then process it
    // !! getNextNodeId() take into account the next of forks !!
    if (try self.graph.getNextNodeId(alloc, self.current_node_id.?)) |next_node_id| {
        // set current node to next by default (might be changed by e.g. fork)
        self.current_node_id = next_node_id;

        const next_node: *node.Node = nodes.getByUUID(next_node_id);

        // check what type of node the next found node is
        switch (next_node.kind) {
            .spawner => unreachable,
            .area => |*area_node| {
                const a_obj: *Area = &env.entities.getByUUID(area_node.getAreaUUID()).kind.area;

                self.payload = .{
                    .area = .{
                        .area_id = area_node.getAreaUUID(),
                    },
                };
                switch (a_obj.style) {
                    .individual => |*data| {
                        self.payload.?.area.seat_index = data.getSeatIndex();
                        self.target = data.getPosFromSeatIndex(self.payload.?.area.seat_index.?);
                    },
                    inline else => self.target = a_obj.getPos(),
                }
            },
            .portal => |*portal_node| {
                self.payload = .{
                    .portal = .{
                        .portal_id = portal_node.getPortalUUID(),
                        .u = commons.rand01(),
                    },
                };
                self.target = env.entities.getByUUID(portal_node.getPortalUUID()).kind.portal.getSourcePosFromU(self.payload.?.portal.u);
            },
            .sink => {
                // delete ourselves
                try env.agents.deleteByUUID(self.uuid);
            },
            inline .fork, .queue_fork => {
                self.current_node_id = next_node_id;
                try self.traverseFromCurrent(alloc, nodes, env);
            },
            .queue => |_| {
                // self.current_node_id = next_node_id;
                // self.payload = .{
                //     .queue = .{
                //         .queue_index = @intCast(queue_node.queue_index),
                //         .spot_index = queue_node.getQueue().getWaitingSpotIndex(),
                //     },
                // };
                // self.target = queue_node.getQueue().getWaitingSpotFromIndex(
                //     self.payload.?.queue.spot_index,
                // );
            },
        }
    } else {
        // the node has no output port, so just kill the agent
        try env.agents.deleteByUUID(self.uuid);
    }
}

/// every frame, processCurrentNode checks what node we are on currently
/// and then (for example) checks if we need to start waiting because we entered radius of a waiting area
pub fn processCurrentNode(
    self: *Self,
    alloc: std.mem.Allocator,
    sim_data: SimData,
    agent_data: AgentData,
    nodes: *Graph.NodeManager,
    env: *Environment,
) !void {
    const current_node: *node.Node = nodes.getByUUID(self.current_node_id.?);
    const time: f64 = commons.getTimeMillis();

    switch (current_node.kind) {
        .area => |*area_node| {
            const area_payload = self.payload.?.area;
            const a_obj: *Area = &env.entities.getByUUID(area_payload.area_id).kind.area;

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

                    // check if needs to release waiting spot
                    switch (a_obj.style) {
                        .individual => |*data| try data.freeSeatIndex(area_payload.seat_index.?),
                        else => {},
                    }

                    // traverse to next
                    try self.traverseFromCurrent(alloc, nodes, env);
                }
            }
        },
        .portal => {
            const portal_payload = self.payload.?.portal;
            const p_obj: *Portal = &env.entities.getByUUID(portal_payload.portal_id).kind.portal;

            // start waiting if in bounds
            if (p_obj.checkCollision(self.pos)) {
                self.pos = p_obj.getDestPos(portal_payload.u);
                try self.traverseFromCurrent(alloc, nodes, env);
            }
        },
        .queue => |queue_node| {
            const q: *Self.QueuePayload = &self.payload.?.queue;
            var q_obj: *Queue = &env.entities.getByUUID(q.queue_index).kind.queue;

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
                            try self.traverseFromCurrent(alloc, nodes, env);
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

pub fn getAABB(self: *Self, agent_data: AgentData, sim_data: SimData) rl.Rectangle {
    const cutoff_dist = 2 * agent_data.radius * @as(f32, @floatFromInt(sim_data.scale)) -
        agent_data.b_ped * std.math.log2(0.01 / agent_data.a_ped);
    const r = cutoff_dist;
    return .{
        .x = self.pos.x - r,
        .y = self.pos.y - r,
        .width = r * 2,
        .height = r * 2,
    };
}

fn obstacleForceFromTwoVectors(
    self: *Self,
    A: rl.Vector2,
    B: rl.Vector2,
    sim_data: SimData,
    agent_data: AgentData,
) rl.Vector2 {
    const D = commons.vecToLineSegment(self.pos, A, B);
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
        const contour: Contour = env.entities.getByUUID(contour_id).kind.contour;

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
        const revolver: Revolver = env.entities.getByUUID(revolver_id).kind.revolver;

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
    env: *Environment,
    sim_data: SimData,
    agent_data: AgentData,
    check_count: *i32,
    scratch_buf: *std.ArrayList(rl.Vector2),
) !rl.Vector2 {
    var force: rl.Vector2 = .{ .x = 0, .y = 0 };

    // get all close agents to check collision with
    scratch_buf.clearRetainingCapacity();
    try env.quadtree.query(self.pos, self.getAABB(agent_data, sim_data), scratch_buf);

    for (scratch_buf.items) |other_point| {
        check_count.* += 1;
        if (other_point.equals(self.pos) != 0) continue;

        const n = self.pos.subtract(other_point);
        const sum_radii: f32 = agent_data.radius * @as(f32, @floatFromInt(sim_data.scale)) * 2.0;
        const dist: f32 = other_point.subtract(self.pos).length();
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
    agent_data: AgentData,
    n_rows: i32,
    n_cols: i32,
    nodes: *Graph.NodeManager,
    check_count: *i32,
    scratch_buf: *std.ArrayList(rl.Vector2),
) !void {
    // get force components
    const drive_force = self.calculateDriveForce(sim_data, agent_data);
    const interactive_force = try self.calculateInteractiveForce(env, sim_data, agent_data, check_count, scratch_buf);
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

pub fn draw(self: *Self, env: *Environment, sim_data: SimData, agent_data: AgentData) void {
    // render sphere
    const f_radius: f32 = agent_data.radius * @as(f32, @floatFromInt(sim_data.scale));

    if (self.wait.waiting) {
        rl.drawCircleV(self.pos, f_radius, color.hexToColor(color.fromPalette(.clay)));
    } else {
        if (self.payload) |payload| {
            var col_index = (2 + 5 * switch (payload) {
                .area => |a| env.entities.uuidToIndex(a.area_id).?,
                .portal => |p| env.entities.uuidToIndex(p.portal_id).?,
                else => 5,
            }) % color.palette.len;
            if (col_index == 1) col_index += 1;
            const col: rl.Color = color.hexToColor(color.palette[col_index]);
            rl.drawCircleV(self.pos, f_radius, col);
        }
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

        // render hitbox
        rl.drawRectangleLinesEx(self.getAABB(agent_data, sim_data), 1, palette.env.hover);
    }

    if (agent_data.show_targets) {
        rl.drawCircleLinesV(self.target, agent_data.radius * @as(f32, @floatFromInt(sim_data.scale)) * 2.0, palette.env.red);
        rl.drawLineV(self.pos, self.target, palette.env.red);
    }
}
