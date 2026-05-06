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
const UUID = @import("../UUID.zig");
const std = @import("std");
const rl = @import("raylib");
const z = @import("zgui");

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
        self: *Entity,
        alloc: std.mem.Allocator,
        dt: f32,
        agent_data: AgentData,
        sim_data: SimData,
        settings: Settings,
    ) !EntityAction {
        return switch (self.kind) {
            .revolver => |*r| r.update(dt, sim_data, settings),
            .queue => |*r| r.update(alloc, dt, agent_data, sim_data, settings),
            inline .contour, .area => |*kind| kind.update(alloc, sim_data, settings),
            inline else => |*kind| kind.update(sim_data, settings),
        };
    }

    pub fn setName(self: *Entity, alloc: std.mem.Allocator, new_name: [:0]const u8) !void {
        alloc.free(self.name);
        self.name = try alloc.dupeZ(u8, new_name);
    }

    pub fn init(
        comptime K: std.meta.Tag(Entity.Kind),
        alloc: std.mem.Allocator,
        id: usize,
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
            .uuid = UUID.init(),
            .name = name,
            .kind = @unionInit(Entity.Kind, @tagName(K), entity),
        };
    }

    pub fn deinit(self: *Entity, alloc: std.mem.Allocator) void {
        alloc.free(self.name);
        switch (self.kind) {
            inline .contour, .queue, .area => |*kind| kind.deinit(alloc),
            else => {},
        }
    }

    pub fn getSnapshot(self: *Entity) EntitySnapshot {
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
                .contour => |cs| .{ .contour = try Contour.fromSnapshot(alloc, cs) },
                .spawner => |ss| .{ .spawner = Spawner.fromSnapshot(ss) },
                .area => |as| .{ .area = try Area.fromSnapshot(alloc, as) },
                .revolver => |rs| .{ .revolver = Revolver.fromSnapshot(rs) },
                .queue => |qs| .{ .queue = try Queue.fromSnapshot(alloc, qs, sim_data, agent_data) },
                .portal => |ps| .{ .portal = Portal.fromSnapshot(ps) },
            },
        };
    }

    pub fn draw(self: *Entity, sim_data: SimData, agent_data: AgentData, node_editor_active: bool) void {
        // draw general entity
        switch (self.kind) {
            .queue => |*q| q.draw(sim_data, agent_data),
            inline else => |*kind| kind.draw(),
        }
        // check hover behavior (after draw)
        // split up since we don't want to pass node_editor_active to each hover() function
        switch (self.kind) {
            .queue => {},
            inline else => |*ent| {
                if (!node_editor_active and ent.placed and ent.checkHover()) {
                    ent.hover();
                }
            },
        }
    }

    pub fn confirm(self: *Entity, alloc: std.mem.Allocator, sim_data: SimData, agent_data: AgentData) !void {
        switch (self.kind) {
            .contour => {},
            .queue => |*q| try q.confirm(alloc, sim_data, agent_data),
            .revolver => |*k| try k.confirm(alloc),
            inline else => |*k| k.confirm(),
        }
    }

    pub fn edit(self: *Entity, alloc: std.mem.Allocator) !void {
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
