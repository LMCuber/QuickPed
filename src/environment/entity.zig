const Contour = @import("contour.zig");
const SimData = @import("../sim_data.zig");
const Spawner = @import("spawner.zig");
const Area = @import("area.zig");
const commons = @import("../commons.zig");
const std = @import("std");
const rl = @import("raylib");

pub const EntitySnapshot = union(enum) {
    contour: Contour.ContourSnapshot,
    spawner: Spawner.SpawnerSnapshot,
    area: Area.AreaSnapshot,
};

pub const Entity = union(enum) {
    pub const EntityAction = enum { none, placed, cancelled };
<<<<<<< HEAD
    pub var next_id: i32 = 0;
=======
    pub var next_id: usize = 0;
>>>>>>> b1df9b51109d6ec82cc6091d6f95116dbebb8b96

    contour: Contour,
    spawner: Spawner,
    area: Area,

    pub fn update(self: *Entity, sim_data: SimData) !EntityAction {
        switch (self.*) {
            inline else => |*inner| return inner.update(sim_data),
        }
    }

<<<<<<< HEAD
    pub fn nextId() i32 {
=======
    pub fn nextId() usize {
>>>>>>> b1df9b51109d6ec82cc6091d6f95116dbebb8b96
        next_id += 1;
        return next_id - 1;
    }

    pub fn initContour(allocator: std.mem.Allocator) !Entity {
        return .{ .contour = try Contour.init(allocator, nextId()) };
    }

    pub fn initSpawner(allocator: std.mem.Allocator) !Entity {
        return .{ .spawner = try Spawner.init(allocator, nextId()) };
    }

    pub fn initArea(allocator: std.mem.Allocator) !Entity {
<<<<<<< HEAD
        return .{ .area = try Area.init(allocator, nextId()) };
=======
        return .{ .area = try Area.init(allocator) };
>>>>>>> b1df9b51109d6ec82cc6091d6f95116dbebb8b96
    }

    pub fn deinit(self: *Entity, allocator: std.mem.Allocator) void {
        switch (self.*) {
            inline else => |*inner| inner.deinit(allocator),
        }
    }

    pub fn getSnapshot(self: *Entity) EntitySnapshot {
        return switch (self.*) {
            .contour => |c| .{ .contour = c.getSnapshot() },
            .spawner => |s| .{ .spawner = s.getSnapshot() },
            .area => |a| .{ .area = a.getSnapshot() },
        };
    }

    pub fn fromSnapshot(allocator: std.mem.Allocator, snap: EntitySnapshot) !Entity {
        return switch (snap) {
            .contour => |cs| .{ .contour = try Contour.fromSnapshot(allocator, cs) },
            .spawner => |ss| .{ .spawner = try Spawner.fromSnapshot(allocator, ss) },
            .area => |as| .{ .area = try Area.fromSnapshot(allocator, as) },
        };
    }

    pub fn draw(self: Entity) void {
        switch (self) {
            inline else => |inner| inner.draw(),
        }
    }
};
