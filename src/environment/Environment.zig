const Self = @This();

const std = @import("std");
const entity = @import("entity.zig");
const AgentData = @import("../editor/AgentData.zig");
const Contour = @import("Contour.zig");
const Spawner = @import("Spawner.zig");
const Area = @import("Area.zig");
const Agent = @import("../Agent.zig");
const Manager = @import("../Manager.zig").Manager;
const Revolver = @import("Revolver.zig");
const commons = @import("../commons.zig");

pub const MAX_ENTITIES: usize = 512;
pub const EntityManager = Manager(entity.Entity, MAX_ENTITIES);
pub const AgentManager = Manager(Agent, MAX_ENTITIES);

entities: EntityManager,

agents: AgentManager,
contours: std.ArrayList(usize),
spawners: std.ArrayList(usize),
areas: std.ArrayList(usize),
revolvers: std.ArrayList(usize),
queues: std.ArrayList(usize),

const EnvironmentSnapshot = struct {
    version: []const u8,
    entities: []const entity.EntitySnapshot,
};

pub fn init(alloc: std.mem.Allocator) Self {
    return .{
        .agents = Manager(Agent, MAX_ENTITIES).init(),
        .entities = Manager(entity.Entity, MAX_ENTITIES).init(),
        .contours = std.ArrayList(usize).init(alloc),
        .spawners = std.ArrayList(usize).init(alloc),
        .areas = std.ArrayList(usize).init(alloc),
        .revolvers = std.ArrayList(usize).init(alloc),
        .queues = std.ArrayList(usize).init(alloc),
    };
}

pub fn deinit(self: *Self) void {
    self.contours.deinit();
    self.spawners.deinit();
    self.areas.deinit();
    self.revolvers.deinit();
    self.queues.deinit();
}

pub fn createEntity(self: *Self, ent: entity.Entity) !void {
    const new_index = self.entities.createItem(ent);

    // add entity to corresponding specialized arraylist
    switch (ent.kind) {
        .contour => try self.contours.append(new_index),
        .spawner => try self.spawners.append(new_index),
        .area => try self.areas.append(new_index),
        .revolver => try self.revolvers.append(new_index),
        .queue => try self.queues.append(new_index),
    }
}

pub fn clearEntities(self: *Self, alloc: std.mem.Allocator) void {
    // dealloc and delete existing entities
    for (&self.entities.items) |*eslot| {
        if (eslot.alive) {
            eslot.value.deinit(alloc);
        }
    }

    // clear the reference lists
    self.contours.clearRetainingCapacity();
    self.spawners.clearRetainingCapacity();
    self.revolvers.clearRetainingCapacity();
    self.queues.clearRetainingCapacity();
}

//
// HALF-AI CODE
//
pub fn loadScene(
    self: *Self,
    allocator: std.mem.Allocator,
    path: []const u8,
    agent_data: AgentData,
) !void {
    const json = try commons.readFile(allocator, path);
    defer allocator.free(json);

    // dealloc and delete existing entities (environmental objects)
    for (&self.entities.items) |*eslot| {
        if (!eslot.alive) continue;
        eslot.value.deinit(allocator);
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
        try self.createEntity(try entity.Entity.fromSnapshot(allocator, snap, agent_data));
    }
}

pub fn saveScene(self: *Self, allocator: std.mem.Allocator, path: []const u8) !void {
    var snaps = std.ArrayList(entity.EntitySnapshot).init(allocator);
    defer snaps.deinit();

    for (&self.entities.items) |*eslot| {
        if (!eslot.alive) continue;
        try snaps.append(eslot.value.getSnapshot());
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
