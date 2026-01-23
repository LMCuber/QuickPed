const Contour = @import("contour.zig");
const SimData = @import("../sim_data.zig");
const Spawner = @import("spawner.zig");
const Area = @import("area.zig");
const commons = @import("../commons.zig");
const std = @import("std");
const rl = @import("raylib");

pub const EntitySnapshot = struct {
    id: i32,
    name: [:0]const u8,
    kind: Kind,

    const Kind = union(enum) {
        contour: Contour.ContourSnapshot,
        spawner: Spawner.SpawnerSnapshot,
        area: Area.AreaSnapshot,
    };
};

pub const Entity = struct {
    id: i32,
    name: [:0]const u8,
    kind: Kind,

    const Kind = union(enum) {
        contour: Contour,
        spawner: Spawner,
        area: Area,
    };

    pub const EntityAction = enum { none, placed, cancelled };
    pub var next_id: i32 = 0;

    pub fn update(self: *Entity, sim_data: SimData) !EntityAction {
        switch (self.kind) {
            inline else => |*kind| return kind.update(sim_data),
        }
    }

    pub fn nextId() i32 {
        next_id += 1;
        return next_id - 1;
    }

    pub fn initContour(allocator: std.mem.Allocator) !Entity {
        const id = nextId();
        const name = try std.fmt.allocPrintZ(allocator, "Contour{}", .{id});
        return .{
            .id = id,
            .name = name,
            .kind = .{
                .contour = try Contour.init(allocator),
            },
        };
    }

    pub fn initSpawner(allocator: std.mem.Allocator) !Entity {
        const id = nextId();
        const name = try std.fmt.allocPrintZ(allocator, "Spawner{}", .{id});
        return .{
            .id = id,
            .name = name,
            .kind = .{
                .spawner = Spawner.init(),
            },
        };
    }

    pub fn initArea(allocator: std.mem.Allocator) !Entity {
        const id = nextId();
        const name = try std.fmt.allocPrintZ(allocator, "Area{}", .{id});
        return .{
            .id = id,
            .name = name,
            .kind = .{
                .area = Area.init(),
            },
        };
    }

    pub fn deinit(self: *Entity, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        switch (self.kind) {
            .contour => |*c| c.deinit(),
            else => {},
        }
    }

    pub fn getSnapshot(self: *Entity) EntitySnapshot {
        return .{
            .id = self.id,
            .name = self.name,
            .kind = switch (self.kind) {
                inline else => |k, tag| @unionInit(
                    EntitySnapshot.Kind,
                    //
                    @tagName(tag),
                    k.getSnapshot(),
                ),
            },
        };
    }

    pub fn fromSnapshot(allocator: std.mem.Allocator, snap: EntitySnapshot) !Entity {
        return .{
            .id = snap.id,
            .name = try allocator.dupeZ(u8, snap.name),
            .kind = switch (snap.kind) {
                .contour => |cs| .{ .contour = try Contour.fromSnapshot(allocator, cs) },
                .spawner => |ss| .{ .spawner = Spawner.fromSnapshot(ss) },
                .area => |as| .{ .area = Area.fromSnapshot(as) },
            },
        };
    }

    pub fn draw(self: Entity) void {
        switch (self.kind) {
            inline else => |kind| kind.draw(),
        }
    }
};
