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
        .contours = std.ArrayList(UUID).init(alloc),
        .spawners = std.ArrayList(UUID).init(alloc),
        .areas = std.ArrayList(UUID).init(alloc),
        .revolvers = std.ArrayList(UUID).init(alloc),
        .queues = std.ArrayList(UUID).init(alloc),
        .portals = std.ArrayList(UUID).init(alloc),
        .quadtree = Quadtree.init(alloc, 8),
    };
}

pub fn deinit(self: *Self) void {
    self.contours.deinit();
    self.spawners.deinit();
    self.areas.deinit();
    self.revolvers.deinit();
    self.queues.deinit();
    self.portals.deinit();
    self.quadtree.deinit();
    self.agents.deinit();
    self.entities.deinit();
}

pub fn createEntity(self: *Self, ent: entity.Entity) !void {
    try self.entities.append(ent);

    // add entity to corresponding specialized arraylist
    switch (ent.kind) {
        .contour => try self.contours.append(ent.uuid),
        .spawner => try self.spawners.append(ent.uuid),
        .area => try self.areas.append(ent.uuid),
        .revolver => try self.revolvers.append(ent.uuid),
        .queue => try self.queues.append(ent.uuid),
        .portal => try self.portals.append(ent.uuid),
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
    allocator: std.mem.Allocator,
    path: []const u8,
    sim_data: SimData,
    agent_data: AgentData,
) !void {
    const json = try commons.readFile(allocator, path);
    defer allocator.free(json);

    // dealloc and delete existing entities (environmental objects)
    for (self.entities.items()) |*ent| {
        ent.deinit(allocator);
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
        allocator,
        json,
        .{},
    );
    defer parsed.deinit();
    const scene: EnvironmentSnapshot = parsed.value;

    // repopulate entities from saved snapshots
    for (scene.entities) |snap| {
        try self.createEntity(try entity.Entity.fromSnapshot(allocator, snap, sim_data, agent_data));
    }
}

pub fn saveScene(self: *Self, allocator: std.mem.Allocator, path: []const u8) !void {
    var snaps = std.ArrayList(entity.EntitySnapshot).init(allocator);
    defer snaps.deinit();

    for (self.entities.items()) |*ent| {
        try snaps.append(ent.getSnapshot());
    }
    const scene_snap: EnvironmentSnapshot = .{
        .version = "0.1.0",
        .entities = snaps.items,
    };
    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();

    try std.json.stringify(scene_snap, .{
        .whitespace = .indent_2,
    }, buf.writer());

    // create file it it doesn't exist
    const file = try std.fs.cwd().createFile(path, .{ .truncate = true });
    defer file.close();
    try file.writeAll(buf.items);
}
