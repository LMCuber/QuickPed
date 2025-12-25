const Self = @This();
const std = @import("std");
const z = @import("zgui");
const Agent = @import("agent.zig");
const Contour = @import("environment/contour.zig");

// lifetime
num_to_place: i32 = 10,

// properties
speed: f32 = 2.0,
relaxation: f32 = 10,
radius: i32 = 8,
a_ped: f32 = 0.08,
b_ped: f32 = 4,
a_ob: f32 = 2.0,
b_ob: f32 = 0.5,
show_vectors: bool = false,

const default_data = Self.init();

pub fn init() Self {
    return .{};
}

pub fn render(self: *Self, agents: *std.ArrayList(Agent), contours: *std.ArrayList(Contour)) !void {
    if (z.collapsingHeader("Agent", .{ .default_open = false })) {
        z.separatorText("Creation");
        // place N agents
        _ = z.sliderInt("count", .{ .v = &self.num_to_place, .min = 1, .max = 50 });
        if (z.button("place", .{})) {
            try Agent.create(
                agents,
                contours,
                self,
                self.num_to_place,
            );
        }
        z.sameLine(.{});
        if (z.button("delete", .{})) {
            Agent.delete(
                agents,
                self.num_to_place,
            );
        }

        z.separatorText("Properties");

        _ = z.sliderFloat("##speed", .{ .v = &self.speed, .min = 0.1, .max = 10.0 });
        z.sameLine(.{});
        _ = z.text("speed", .{});
        if (z.isItemHovered(.{})) {
            _ = z.beginTooltip();
            defer z.endTooltip();
            _ = z.text("Speed of the agents", .{});
        }

        _ = z.sliderFloat("##tau", .{ .v = &self.relaxation, .min = 1, .max = 30 });
        z.sameLine(.{});
        _ = z.text("tau", .{});
        if (z.isItemHovered(.{})) {
            _ = z.beginTooltip();
            defer z.endTooltip();
            _ = z.text("Relaxation time: how fast the agents adjust to their desired force of movement", .{});
        }

        _ = z.sliderInt("##radius", .{ .v = &self.radius, .min = 2, .max = 16 });
        z.sameLine(.{});
        _ = z.text("radius", .{});
        if (z.isItemHovered(.{})) {
            _ = z.beginTooltip();
            defer z.endTooltip();
            _ = z.text("Radius of the agents in pixels", .{});
        }

        _ = z.sliderFloat("##a_ped", .{ .v = &self.a_ped, .min = 0.01, .max = 0.2 });
        z.sameLine(.{});
        _ = z.text("A_ped", .{});
        if (z.isItemHovered(.{})) {
            _ = z.beginTooltip();
            defer z.endTooltip();
            _ = z.text("Repulsive force: how badly the agents want to stay away from each other", .{});
        }

        _ = z.sliderFloat("##b_ped", .{ .v = &self.b_ped, .min = 1, .max = 10 });
        z.sameLine(.{});
        _ = z.text("B_ped", .{});
        if (z.isItemHovered(.{})) {
            _ = z.beginTooltip();
            defer z.endTooltip();
            _ = z.text("The distance the agents want to keep from obstacles", .{});
        }

        _ = z.sliderFloat("##a_ob", .{ .v = &self.a_ob, .min = 0.1, .max = 4 });
        z.sameLine(.{});
        _ = z.text("A_ob", .{});
        if (z.isItemHovered(.{})) {
            _ = z.beginTooltip();
            defer z.endTooltip();
            _ = z.text("Repulsive force: how badly the agents want to stay away from the obstacles", .{});
        }

        _ = z.sliderFloat("##b_ob", .{ .v = &self.b_ob, .min = 0.1, .max = 2 });
        z.sameLine(.{});
        _ = z.text("B_ob", .{});
        if (z.isItemHovered(.{})) {
            _ = z.beginTooltip();
            defer z.endTooltip();
            _ = z.text("The distance the agents want to keep from each other", .{});
        }

        if (z.button("reset", .{})) {
            self.* = default_data;
        }

        _ = z.checkbox("show vectors", .{ .v = &self.show_vectors });
        z.newLine();
    }
}
