const Contour = @import("contour.zig");
const SimData = @import("../sim_data.zig");
const Spawner = @import("spawner.zig");
const commons = @import("../commons.zig");
const std = @import("std");
const rl = @import("raylib");

pub const EntityAction = enum { none, place };

pub const Entity = union(enum) {
    contour: Contour,
    // spawner: Spawner,

    pub fn update(self: *Entity, _: SimData) void {
        switch (self.*) {
            .contour => |_| {},
            // inline else => |*inner| {
            //     if (inner.placed) return;

            //     inner.prepare();
            //     inner.pos.x = @floatFromInt(commons.roundN(@intFromFloat(commons.mousePos().x), sim_data.grid_size));
            //     inner.pos.y = @floatFromInt(commons.roundN(@intFromFloat(commons.mousePos().y), sim_data.grid_size));
            // },
        }
    }

    pub fn initContour(allocator: std.mem.Allocator) !Entity {
        return .{ .contour = try Contour.init(allocator) };
    }

    pub fn draw(self: Entity) void {
        switch (self) {
            inline else => |inner| inner.draw(),
        }
    }
};
