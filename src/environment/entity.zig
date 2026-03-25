const SimData = @import("../editor/SimData.zig");
const Settings = @import("../Settings.zig");
const Contour = @import("Contour.zig");
const Spawner = @import("Spawner.zig");
const Area = @import("Area.zig");
const Revolver = @import("Revolver.zig");
const Queue = @import("Queue.zig");
const Portal = @import("Portal.zig");
const Environment = @import("Environment.zig");
const AgentData = @import("../editor/AgentData.zig");
const Manager = @import("../Manager.zig").Manager;
const commons = @import("../commons.zig");
const std = @import("std");
const rl = @import("raylib");

pub const EntitySnapshot = struct {
    name: [:0]const u8,
    kind: Kind,

    const Kind = union(enum) {
        contour: Contour.ContourSnapshot,
        spawner: Spawner.SpawnerSnapshot,
        area: Area.AreaSnapshot,
        revolver: Revolver.RevolverSnapshot,
        queue: Queue.QueueSnapshot,
        portal: Portal.PortalSnapshot,
    };
};

pub const Entity = struct {
    name: [:0]const u8,
    name_edit_buf: [256:0]u8 = .{0} ** 256,
    kind: Kind,

    pub const Kind = union(enum) {
        contour: Contour,
        spawner: Spawner,
        area: Area,
        revolver: Revolver,
        queue: Queue,
        portal: Portal,
    };

    pub const EntityAction = enum {
        none,
        placed,
        cancelled,
        confirm,
        confirm_init,
    };

    //
    // AI CODE
    //
    pub fn buildNameComboString(
        comptime kind_tag: std.meta.Tag(Entity.Kind),
        entities: *Manager(Entity, Environment.MAX_ENTITIES),
        buf: []u8,
    ) [:0]u8 {
        var pos: usize = 0;

        for (&entities.items) |*eslot| {
            if (eslot.value.kind == kind_tag) {
                @memcpy(
                    buf[pos..][0..eslot.value.name.len],
                    eslot.value.name,
                );
                pos += eslot.value.name.len;
                buf[pos] = 0;
                pos += 1;
            }
        }

        buf[pos] = 0; // Final sentinel
        return buf[0..pos :0];
    }

    pub fn update(
        self: *Entity,
        alloc: std.mem.Allocator,
        dt: f32,
        agent_data: AgentData,
        sim_data: SimData,
        settings: Settings,
    ) !EntityAction {
        switch (self.kind) {
            .revolver => |*r| return r.update(dt, sim_data, settings),
            .queue => |*r| return r.update(alloc, dt, agent_data, sim_data, settings),
            inline else => |*kind| return kind.update(sim_data, settings),
        }
    }

    pub fn setName(self: *Entity, alloc: std.mem.Allocator, new_name: [:0]const u8) !void {
        alloc.free(self.name);
        self.name = try alloc.dupeZ(u8, new_name);
    }

    pub fn initContour(allocator: std.mem.Allocator, id: usize) !Entity {
        const contour = try Contour.init(allocator);
        const name = try std.fmt.allocPrintZ(allocator, "Contour{}", .{id});
        return .{
            .name = name,
            .kind = .{
                .contour = contour,
            },
        };
    }

    pub fn initSpawner(allocator: std.mem.Allocator, id: usize) !Entity {
        const spawner = Spawner.init();
        const name = try std.fmt.allocPrintZ(allocator, "Spawner{}", .{id});
        return .{
            .name = name,
            .kind = .{
                .spawner = spawner,
            },
        };
    }

    pub fn initArea(allocator: std.mem.Allocator, id: usize) !Entity {
        const area = Area.init();
        const name = try std.fmt.allocPrintZ(allocator, "Area{}", .{id});
        return .{
            .name = name,
            .kind = .{
                .area = area,
            },
        };
    }

    pub fn initRevolver(allocator: std.mem.Allocator, id: usize) !Entity {
        const revolver = Revolver.init();
        const name = try std.fmt.allocPrintZ(allocator, "Revolver{}", .{id});
        return .{
            .name = name,
            .kind = .{
                .revolver = revolver,
            },
        };
    }

    pub fn initQueue(allocator: std.mem.Allocator, id: usize) !Entity {
        const queue = try Queue.init(allocator);
        const name = try std.fmt.allocPrintZ(allocator, "Queue{}", .{id});
        return .{
            .name = name,
            .kind = .{
                .queue = queue,
            },
        };
    }

    pub fn initPortal(allocator: std.mem.Allocator, id: usize) !Entity {
        const portal = Portal.init();
        const name = try std.fmt.allocPrintZ(allocator, "Portal{}", .{id});
        return .{
            .name = name,
            .kind = .{
                .portal = portal,
            },
        };
    }

    pub fn deinit(self: *Entity, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        switch (self.kind) {
            .contour => |*c| c.deinit(),
            .queue => |*q| q.deinit(),
            .area => |*a| a.deinit(),
            else => {},
        }
    }

    pub fn getSnapshot(self: *Entity) EntitySnapshot {
        return .{
            .name = self.name,
            .kind = switch (self.kind) {
                inline else => |k, tag| @unionInit(
                    EntitySnapshot.Kind,
                    @tagName(tag),
                    k.getSnapshot(),
                ),
            },
        };
    }

    pub fn fromSnapshot(alloc: std.mem.Allocator, snap: EntitySnapshot, sim_data: SimData, agent_data: AgentData) !Entity {
        return .{
            .name = try alloc.dupeZ(u8, snap.name),
            .kind = switch (snap.kind) {
                .contour => |cs| .{ .contour = try Contour.fromSnapshot(alloc, cs) },
                .spawner => |ss| .{ .spawner = Spawner.fromSnapshot(ss) },
                .area => |as| .{ .area = try Area.fromSnapshot(alloc, as) },
                .revolver => |rs| .{ .revolver = Revolver.fromSnapshot(rs) },
                .queue => |qs| .{ .queue = try Queue.fromSnapshot(alloc, qs, sim_data, agent_data) },
                .portal => |ps| .{ .portal = Portal.fromSnapshot(ps) },
            },
        };
    }

    pub fn draw(self: *Entity, sim_data: SimData, agent_data: AgentData) void {
        switch (self.kind) {
            .queue => |*q| q.draw(sim_data, agent_data),
            inline else => |*kind| kind.draw(),
        }
    }
};
