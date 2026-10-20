const SimData = @import("../editor/SimData.zig");
const Settings = @import("../Settings.zig");
const Contour = @import("Contour.zig");
const Spawner = @import("Spawner.zig");
const Area = @import("Area.zig");
const Revolver = @import("Revolver.zig");
const Queue = @import("Queue.zig");
const Portal = @import("Portal.zig");
const Evac = @import("Evacuation.zig");
const Environment = @import("Environment.zig");
const AgentData = @import("../editor/AgentData.zig");
const Manager = @import("../Manager.zig").Manager;
const commons = @import("../commons.zig");
const utils = @import("../utils.zig");
const UUID = @import("../UUID.zig");
const std = @import("std");
const rl = @import("raylib");
const z = @import("zgui");

// any collision with mouse can either return entire entity (e.g. areas)
// or a portion of it (e.g. contours, where it returns vertex indices)
pub const CollisionResult = union(enum) { none: void, entity: void, capture: struct {
    entity: UUID,
    index: usize,
} };

pub const EntitySnapshot = struct {
    uuid: UUID.UUIDSnapshot,
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
    uuid: UUID,
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
        // evac: Evacuaion,
    };

    pub const EntityAction = enum {
        none,
        placed,
        cancelled,
        confirm,
        confirm_init,
        selected,
    };

    //
    // AI CODE
    //
    pub fn buildNameComboString(
        comptime kind_tag: std.meta.Tag(Entity.Kind),
        entities: *Manager(Entity),
        buf: []u8,
    ) [:0]u8 {
        var pos: usize = 0;

        for (entities.items()) |*ent| {
            if (ent.kind == kind_tag) {
                @memcpy(
                    buf[pos..][0..ent.name.len],
                    ent.name,
                );
                pos += ent.name.len;
                buf[pos] = 0;
                pos += 1;
            }
        }

        buf[pos] = 0; // Final sentinel
        return buf[0..pos :0];
    }

    pub fn update(
        self: *@This(),
        alloc: std.mem.Allocator,
        dt: f32,
        agent_data: AgentData,
        sim_data: SimData,
        settings: Settings,
    ) !EntityAction {
        return switch (self.kind) {
            .revolver => |*r| r.update(dt, sim_data, settings),
            .queue => |*r| r.update(alloc, dt, agent_data, sim_data, settings),
            .contour => |*c| c.update(alloc, sim_data, agent_data, settings),
            .area => |*kind| kind.update(alloc, sim_data, settings),
            inline else => |*kind| kind.update(sim_data, settings),
        };
    }

    pub fn setName(self: *@This(), alloc: std.mem.Allocator, new_name: [:0]const u8) !void {
        alloc.free(self.name);
        self.name = try alloc.dupeZ(u8, new_name);
    }

    pub fn init(
        comptime K: std.meta.Tag(Entity.Kind),
        alloc: std.mem.Allocator,
        rand: std.Random,
        id: usize,
        _: SimData,
        _: AgentData,
    ) !Entity {
        const T = switch (K) {
            .contour => Contour,
            .spawner => Spawner,
            .area => Area,
            .revolver => Revolver,
            .queue => Queue,
            .portal => Portal,
        };
        const entity = T.init();
        const name = try std.fmt.allocPrintSentinel(alloc, "{s}{}", .{ @typeName(T), id }, 0);
        return .{
            .uuid = UUID.init(rand),
            .name = name,
            .kind = @unionInit(Entity.Kind, @tagName(K), entity),
        };
    }

    pub fn deinit(self: *@This(), alloc: std.mem.Allocator) void {
        alloc.free(self.name);
        switch (self.kind) {
            inline .contour, .queue, .area => |*kind| kind.deinit(alloc),
            else => {},
        }
    }

    pub fn checkSelected(self: @This(), rect: rl.Rectangle) bool {
        return switch (self.kind) {
            .area => |c| c.checkSelected(rect),
            .contour => |k| utils.checkCollisionRecInside(k.getRect(), rect),
            inline else => false,
        };
    }

    pub fn getRect(self: @This()) rl.Rectangle {
        return switch (self.kind) {
            inline .area, .contour => |a| a.getRect(),
            else => unreachable,
        };
    }

    pub fn getCenter(self: @This()) rl.Vector2 {
        const rect = switch (self.kind) {
            inline .area, .contour => |a| a.getRect(),
            else => unreachable,
        };
        return .{
            .x = rect.x,
            .y = rect.y,
        };
    }

    pub fn selectedMove(self: *@This(), dest: rl.Vector2, sim_data: SimData, snap: bool) void {
        switch (self.kind) {
            .area => |*a| a.selectedMove(dest, sim_data, snap),
            else => {},
        }
    }

    pub fn getSnapshot(self: *@This()) EntitySnapshot {
        return .{
            .uuid = self.uuid.getSnapshot(),
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
            .uuid = UUID.fromSnapshot(snap.uuid.data),
            .name = try alloc.dupeZ(u8, snap.name),
            .kind = switch (snap.kind) {
                .contour => |cs| .{ .contour = try Contour.fromSnapshot(alloc, cs, sim_data, agent_data) },
                .spawner => |ss| .{ .spawner = Spawner.fromSnapshot(ss) },
                .area => |as| .{ .area = try Area.fromSnapshot(alloc, as) },
                .revolver => |rs| .{ .revolver = Revolver.fromSnapshot(rs) },
                .queue => |qs| .{ .queue = try Queue.fromSnapshot(alloc, qs, sim_data, agent_data) },
                .portal => |ps| .{ .portal = Portal.fromSnapshot(ps) },
            },
        };
    }

    pub fn selectedDraw(self: @This()) void {
        switch (self.kind) {
            .area => |a| a.selectedDraw(),
            else => {},
        }
    }

    pub fn draw(self: *@This(), sim_data: SimData, agent_data: AgentData, _: bool) void {
        // draw general entity
        switch (self.kind) {
            inline .contour, .queue => |*k| k.draw(sim_data, agent_data),
            inline else => |*kind| kind.draw(),
        }
    }

    pub fn confirm(self: *@This(), alloc: std.mem.Allocator, sim_data: SimData, agent_data: AgentData) !void {
        switch (self.kind) {
            .contour => {},
            .queue => |*q| try q.confirm(alloc, sim_data, agent_data),
            .revolver => |*k| try k.confirm(alloc),
            inline else => |*k| k.confirm(),
        }
    }

    pub fn edit(self: *@This(), alloc: std.mem.Allocator) !void {
        // all entities
        z.separatorText(self.name);

        // specialization
        switch (self.kind) {
            .contour => {},
            inline .spawner, .queue, .portal => |*kind| kind.edit(),
            inline else => |*kind| try kind.edit(alloc),
        }
    }
};
