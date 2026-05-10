const Self = @This();

const std = @import("std");
const entity = @import("entity.zig");
const SimData = @import("../editor/SimData.zig");
const AgentData = @import("../editor/AgentData.zig");
const Contour = @import("Contour.zig");
const Spawner = @import("Spawner.zig");
const Area = @import("Area.zig");
const Agent = @import("../Agent.zig");
const Manager = @import("../Manager.zig").Manager;
const Revolver = @import("Revolver.zig");
const Quadtree = @import("../Quadtree.zig");
const commons = @import("../commons.zig");
const UUID = @import("../UUID.zig");

pub const EntityManager = Manager(entity.Entity);
pub const AgentManager = Manager(Agent);

entities: EntityManager,
agents: AgentManager,
contours: std.ArrayList(UUID),
spawners: std.ArrayList(UUID),
areas: std.ArrayList(UUID),
revolvers: std.ArrayList(UUID),
queues: std.ArrayList(UUID),
portals: std.ArrayList(UUID),
quadtree: Quadtree,

const EnvironmentSnapshot = struct {
    version: []const u8,
    entities: []const entity.EntitySnapshot,
};

pub fn init(alloc: std.mem.Allocator) Self {
    return .{
        .agents = Manager(Agent).init(alloc),
        .entities = Manager(entity.Entity).init(alloc),
        .contours = .empty,
        .spawners = .empty,
        .areas = .empty,
        .revolvers = .empty,
        .queues = .empty,
        .portals = .empty,
        .quadtree = Quadtree.init(alloc, 8),
    };
}

pub fn deinit(self: *Self, alloc: std.mem.Allocator) void {
    self.contours.deinit(alloc);
    self.spawners.deinit(alloc);
    self.areas.deinit(alloc);
    self.revolvers.deinit(alloc);
    self.queues.deinit(alloc);
    self.portals.deinit(alloc);
    self.quadtree.deinit();
    self.agents.deinit(alloc);
    self.entities.deinit(alloc);
}

pub fn createEntity(self: *Self, alloc: std.mem.Allocator, ent: entity.Entity) !void {
    try self.entities.append(alloc, ent);

    // add entity to corresponding specialized arraylist
    switch (ent.kind) {
        .contour => try self.contours.append(alloc, ent.uuid),
        .spawner => try self.spawners.append(alloc, ent.uuid),
        .area => try self.areas.append(alloc, ent.uuid),
        .revolver => try self.revolvers.append(alloc, ent.uuid),
        .queue => try self.queues.append(alloc, ent.uuid),
        .portal => try self.portals.append(alloc, ent.uuid),
    }
}

pub fn clearEntities(self: *Self, alloc: std.mem.Allocator) void {
    // dealloc and delete existing entities
    for (self.entities.items()) |*ent| {
        ent.deinit(alloc);
    }

    // clear the uuid lists
    self.contours.clearRetainingCapacity();
    self.spawners.clearRetainingCapacity();
    self.revolvers.clearRetainingCapacity();
    self.queues.clearRetainingCapacity();
    self.portals.clearRetainingCapacity();
}

//
// HALF-AI CODE
//
pub fn loadScene(
    self: *Self,
    alloc: std.mem.Allocator,
    io: std.Io,
    path: []const u8,
    sim_data: SimData,
    agent_data: AgentData,
) !void {
    const json = try commons.readFile(alloc, io, path);
    defer alloc.free(json);

    // dealloc and delete existing entities (environmental objects)
    for (self.entities.items()) |*ent| {
        ent.deinit(alloc);
    }
    self.contours.clearRetainingCapacity();
    self.spawners.clearRetainingCapacity();
    self.areas.clearRetainingCapacity();

    // if there is nothing in the file, return
    if (json.len == 0) {
        return;
    }

    // get parsed scene
    const parsed = try std.json.parseFromSlice(
        EnvironmentSnapshot,
        alloc,
        json,
        .{},
    );
    defer parsed.deinit();
    const scene: EnvironmentSnapshot = parsed.value;

    // repopulate entities from saved snapshots
    for (scene.entities) |snap| {
        try self.createEntity(alloc, try entity.Entity.fromSnapshot(alloc, snap, sim_data, agent_data));
    }
}

pub fn saveScene(self: *Self, alloc: std.mem.Allocator, io: std.Io, path: []const u8) !void {
    var snaps: std.ArrayList(entity.EntitySnapshot) = .empty;
    defer snaps.deinit(alloc);

    for (self.entities.items()) |*ent|
        try snaps.append(alloc, ent.getSnapshot());

    const scene_snap: EnvironmentSnapshot = .{
        .version = "0.1.0",
        .entities = snaps.items,
    };

    try commons.writeFile(alloc, io, scene_snap, path);
}
