const Self = @This();
const std = @import("std");
const commons = @import("../commons.zig");
const z = @import("zgui");
const Agent = @import("../Agent.zig");
const AgentData = @import("../editor/AgentData.zig");
const Environment = @import("../environment/Environment.zig");
const Contour = @import("../environment/Contour.zig");

// lifetime
num_to_place: i32 = 10,

// properties
speed: f32 = 1.3, // in m/s
relaxation: f32 = 10,
radius: f32 = 0.25, // in m!!!!!!!
a_ped: f32 = 0.08,
b_ped: f32 = 4,
a_ob: f32 = 2.0,
b_ob: f32 = 4,
show_vectors: bool = false,
show_targets: bool = false,

const default_data = Self.init();

pub fn init() Self {
    return .{};
}

pub fn updateUi(self: *Self, alloc: std.mem.Allocator, agents: *Environment.AgentManager) !void {
    if (z.collapsingHeader("Agent", .{ .default_open = false })) {
        if (z.button("delete", .{})) {
            for (0..@intCast(self.num_to_place)) |i| {
                try agents.deleteByIndex(i);
            }
        }

        z.separatorText("Properties");

        _ = z.sliderFloat("##agent-speed", .{ .v = &self.speed, .min = 0.3, .max = 3.0 });
        z.sameLine(.{});
        try z.text(alloc, "speed", .{});
        if (z.isItemHovered(.{})) {
            _ = z.beginTooltip();
            defer z.endTooltip();
            try z.text(alloc, "Agent speed in m/s", .{});
        }

        _ = z.sliderFloat("##tau", .{ .v = &self.relaxation, .min = 1, .max = 30 });
        z.sameLine(.{});
        try z.text(alloc, "tau", .{});
        if (z.isItemHovered(.{})) {
            _ = z.beginTooltip();
            defer z.endTooltip();
            try z.text(alloc, "Relaxation time: how fast the agents adjust to their desired force of movement", .{});
        }

        _ = z.sliderFloat("##radius", .{ .v = &self.radius, .min = 0.1, .max = 1.0 });
        z.sameLine(.{});
        try z.text(alloc, "radius", .{});
        if (z.isItemHovered(.{})) {
            _ = z.beginTooltip();
            defer z.endTooltip();
            try z.text(alloc, "Radius of the agents in pixels", .{});
        }

        _ = z.sliderFloat("##a_ped", .{ .v = &self.a_ped, .min = 0.01, .max = 0.2 });
        z.sameLine(.{});
        try z.text(alloc, "A_ped", .{});
        if (z.isItemHovered(.{})) {
            _ = z.beginTooltip();
            defer z.endTooltip();
            try z.text(alloc, "Repulsive force: how badly the agents want to stay away from each other", .{});
        }

        _ = z.sliderFloat("##b_ped", .{ .v = &self.b_ped, .min = 1, .max = 10 });
        z.sameLine(.{});
        try z.text(alloc, "B_ped", .{});
        if (z.isItemHovered(.{})) {
            _ = z.beginTooltip();
            defer z.endTooltip();
            try z.text(alloc, "The distance the agents want to keep from each other", .{});
        }

        _ = z.sliderFloat("##a_ob", .{ .v = &self.a_ob, .min = 0.1, .max = 4 });
        z.sameLine(.{});
        try z.text(alloc, "A_ob", .{});
        if (z.isItemHovered(.{})) {
            _ = z.beginTooltip();
            defer z.endTooltip();
            try z.text(alloc, "Repulsive force: how badly the agents want to stay away from the obstacles", .{});
        }

        _ = z.sliderFloat("##b_ob", .{ .v = &self.b_ob, .min = 0.1, .max = 10 });
        z.sameLine(.{});
        try z.text(alloc, "B_ob", .{});
        if (z.isItemHovered(.{})) {
            _ = z.beginTooltip();
            defer z.endTooltip();
            try z.text(alloc, "The distance the agents want to keep from the obstacles", .{});
        }

        if (z.button("reset", .{}))
            self.* = default_data;

        _ = z.checkbox("show vectors", .{ .v = &self.show_vectors });
        _ = z.checkbox("show targets", .{ .v = &self.show_targets });
        z.newLine();
    }
}

pub fn loadFromFile(alloc: std.mem.Allocator, io: std.Io, path: []const u8) !Self {
    const json = try commons.readFile(alloc, io, path);
    defer alloc.free(json);

    // if there is nothing in the file, return
    if (json.len == 0) {
        return Self.init();
    }

    // get parsed AgentData struct
    const parsed = try std.json.parseFromSlice(
        Self,
        alloc,
        json,
        .{},
    );
    defer parsed.deinit();
    return parsed.value;
}
