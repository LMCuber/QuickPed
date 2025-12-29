const Contour = @import("contour.zig");
const SimData = @import("../sim_data.zig");
const Spawner = @import("spawner.zig");
const commons = @import("../commons.zig");
const std = @import("std");
const rl = @import("raylib");

pub const EntitySnapshot = union(enum) {
    contour: Contour.ContourSnapshot,
    spawner: Spawner.SpawnerSnapshot,
};

pub const Entity = union(enum) {
    pub const EntityAction = enum { none, placed, cancelled };

    contour: Contour,
    spawner: Spawner,

    pub fn update(self: *Entity, sim_data: SimData) !EntityAction {
        switch (self.*) {
            inline else => |*inner| {
                return inner.update(sim_data);
            },
        }
    }

    pub fn initContour(allocator: std.mem.Allocator) !Entity {
        return .{ .contour = try Contour.init(allocator) };
    }

    pub fn initSpawner(allocator: std.mem.Allocator) !Entity {
        return .{ .spawner = try Spawner.init(allocator) };
    }

    pub fn deinit(self: *Entity, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .contour => |*c| c.deinit(allocator),
            .spawner => |*c| c.deinit(allocator),
        }
    }

    pub fn getSnapshot(self: *Entity) EntitySnapshot {
        return switch (self.*) {
            .contour => |c| .{ .contour = c.getSnapshot() },
            .spawner => |s| .{ .spawner = s.getSnapshot() },
        };
    }

    pub fn fromSnapshot(allocator: std.mem.Allocator, snap: EntitySnapshot) !Entity {
        return switch (snap) {
            .contour => |cs| .{ .contour = try Contour.fromSnapshot(allocator, cs) },
            .spawner => |ss| .{ .spawner = try Spawner.fromSnapshot(allocator, ss) },
        };
    }

    pub fn draw(self: Entity) void {
        switch (self) {
            inline else => |inner| inner.draw(),
        }
    }
};
