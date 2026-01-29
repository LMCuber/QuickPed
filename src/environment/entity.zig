const Contour = @import("Contour.zig");
const SimData = @import("../SimData.zig");
const Spawner = @import("Spawner.zig");
const Area = @import("Area.zig");
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

    ///
    /// AI CODE
    ///
    pub fn buildNameComboString(
        comptime kind_tag: std.meta.Tag(Entity.Kind),
        entities: *std.ArrayList(Entity),
        buf: []u8,
    ) [:0]u8 {
        var pos: usize = 0;

        for (entities.items) |entity| {
            if (entity.kind == kind_tag) {
                @memcpy(buf[pos..][0..entity.name.len], entity.name);
                pos += entity.name.len;
                buf[pos] = 0;
                pos += 1;
            }
        }

        buf[pos] = 0; // Final sentinel
        return buf[0..pos :0];
    }

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
        const contour = try Contour.init(allocator);
        const name = try std.fmt.allocPrintZ(allocator, "Contour{}", .{contour.contour_id});
        return .{
            .id = id,
            .name = name,
            .kind = .{
                .contour = contour,
            },
        };
    }

    pub fn initSpawner(allocator: std.mem.Allocator) !Entity {
        const id = nextId();
        const spawner = Spawner.init();
        const name = try std.fmt.allocPrintZ(allocator, "Spawner{}", .{spawner.spawner_id});
        return .{
            .id = id,
            .name = name,
            .kind = .{
                .spawner = spawner,
            },
        };
    }

    pub fn initArea(allocator: std.mem.Allocator) !Entity {
        const id = nextId();
        const area = Area.init();
        const name = try std.fmt.allocPrintZ(allocator, "Area{}", .{area.area_id});
        return .{
            .id = id,
            .name = name,
            .kind = .{
                .area = area,
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
