const Self = @This();
const std = @import("std");
const rl = @import("raylib");
const z = @import("zgui");
const color = @import("../color.zig");
const palette = @import("../palette.zig");
const commons = @import("../commons.zig");
const Entity = @import("entity.zig").Entity;
const SimData = @import("../editor/SimData.zig");
const AgentData = @import("../editor/AgentData.zig");
const Settings = @import("../Settings.zig");

pos: rl.Vector2 = .{ .x = 0, .y = 0 },
points: std.ArrayList(rl.Vector2),
waiting_spots: std.ArrayList(rl.Vector2),
occupied_spots: std.ArrayList(bool),
padding: i32 = 4,
placed: bool = false,

pub const QueueSnapshot = struct {
    points: []rl.Vector2,
    waiting_spots: []rl.Vector2,
};

pub fn init(allocator: std.mem.Allocator) !Self {
    return .{
        .points = std.ArrayList(rl.Vector2).init(allocator),
        .waiting_spots = std.ArrayList(rl.Vector2).init(allocator),
        .occupied_spots = std.ArrayList(bool).init(allocator),
    };
}

pub fn deinit(self: *Self) void {
    self.points.deinit();
    self.waiting_spots.deinit();
    self.occupied_spots.deinit();
}

pub fn getSnapshot(self: Self) QueueSnapshot {
    return .{
        .points = self.points.items,
        .waiting_spots = self.waiting_spots.items,
    };
}

pub fn fromSnapshot(allocator: std.mem.Allocator, snap: QueueSnapshot) !Self {
    var points = std.ArrayList(rl.Vector2).init(allocator);
    for (snap.points) |point| {
        try points.append(point);
    }
    var waiting_spots = std.ArrayList(rl.Vector2).init(allocator);
    for (snap.waiting_spots) |spot| {
        try waiting_spots.append(spot);
    }
    var occupied_spots = std.ArrayList(bool).init(allocator);
    try occupied_spots.appendNTimes(false, waiting_spots.items.len);
    return .{
        .points = points,
        .waiting_spots = waiting_spots,
        .occupied_spots = occupied_spots,
        .placed = true,
    };
}

pub fn update(
    self: *Self,
    alloc: std.mem.Allocator,
    _: f32,
    agent_data: AgentData,
    sim_data: SimData,
    settings: Settings,
) !Entity.EntityAction {
    if (!self.placed) {
        self.pos = commons.roundMousePos(sim_data);
        // place new point
        if (commons.editorCapturingMouse(settings) and rl.isMouseButtonPressed(.mouse_button_left)) {
            try self.points.append(self.pos);
        }
        // finish points with keypress
        if (rl.isKeyPressed(.key_enter)) {
            self.placed = true;
            try self.calculatePoints(alloc, agent_data);
            return .confirm;
        }
        return .none;
    }
    return .none;
}

fn getDistBetweenSpots(self: *Self, agent_data: AgentData) f32 {
    return @floatFromInt((agent_data.radius * 2 + self.padding));
}

fn calculatePoints(self: *Self, alloc: std.mem.Allocator, agent_data: AgentData) !void {
    self.waiting_spots.clearRetainingCapacity();

    // calculate total length and cumulative distances
    var cum_distances: std.ArrayList(f32) = std.ArrayList(f32).init(alloc);
    defer cum_distances.deinit();
    for (self.points.items, 0..) |point, i| {
        if (i == 0) continue;
        const prev_cum_dist: f32 = if (i > 1) cum_distances.getLast() else 0;
        try cum_distances.append(prev_cum_dist + point.subtract(self.points.items[i - 1]).length());
    }
    const total_length: f32 = cum_distances.getLast();
    const step_size: f32 = self.getDistBetweenSpots(agent_data);

    // find the correct part
    var i: usize = 0;
    const num_spots: usize = @as(usize, @intFromFloat(total_length / step_size)) + 1;
    while (i < num_spots) : (i += 1) {
        const actual_distance: f32 = step_size * @as(f32, @floatFromInt(i));
        var waiting_spot: rl.Vector2 = undefined;

        for (cum_distances.items, 0..) |cum_dist, cum_dist_index| {
            if (cum_dist >= actual_distance) {
                const p_a: rl.Vector2 = self.points.items[cum_dist_index];
                const p_b: rl.Vector2 = self.points.items[cum_dist_index + 1];
                const distance_missing: f32 = cum_dist - actual_distance;
                const ratio_covered: f32 = 1 - distance_missing / p_b.subtract(p_a).length();
                waiting_spot = p_a.lerp(p_b, ratio_covered);
                break;
            }
        }
        try self.waiting_spots.append(waiting_spot);
    }
    try self.occupied_spots.appendNTimes(false, self.waiting_spots.items.len);
}

pub fn getWaitingSpotFromIndex(self: *Self, index: usize) rl.Vector2 {
    return self.waiting_spots.items[index];
}

pub fn getWaitingSpotIndex(self: *Self) usize {
    for (self.occupied_spots.items, 0..) |occupied, i| {
        if (!occupied) {
            self.occupied_spots.items[i] = true;
            return i;
        }
    }
    return self.occupied_spots.items.len - 1;
}

pub fn isFree(self: *Self, index: usize) bool {
    return !self.occupied_spots.items[index];
}

pub fn freeIndex(self: *Self, index: usize) void {
    self.occupied_spots.items[index] = false;
}

pub fn occupyIndex(self: *Self, index: usize) void {
    self.occupied_spots.items[index] = true;
}

pub fn confirm(self: *Self, alloc: std.mem.Allocator, agent_data: AgentData) !void {
    const w: f32 = 100;
    z.setNextItemWidth(w);
    if (z.sliderInt("padding", .{ .v = &self.padding, .min = 0, .max = 64 })) {
        try self.calculatePoints(alloc, agent_data);
    }
}

pub fn draw(self: Self, agent_data: AgentData) void {
    const line_width = 2;
    const col = if (self.placed) (palette.env.orange) else (palette.env.orange_t);
    if (self.points.items.len == 0) {
        // has placed nothing yet, so show white circle
        rl.drawCircleV(self.pos, 6, col);
    } else {
        // already has points, so display them
        for (self.points.items, 0..) |point, i| {
            if (i == self.points.items.len - 1) continue;
            const next_point = self.points.items[i + 1];
            rl.drawLineEx(point, next_point, line_width, col);
        }
        if (!self.placed) {
            // display last point to mouse cursor
            rl.drawLineEx(self.points.items[self.points.items.len - 1], self.pos, line_width, col);
        }

        // render the waiting spots
        for (self.waiting_spots.items) |waiting_spot| {
            rl.drawCircleV(waiting_spot, @as(f32, @floatFromInt(agent_data.radius)) * 0.7, palette.env.green);
        }
    }
}
