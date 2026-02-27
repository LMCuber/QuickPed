const Self = @This();

const std = @import("std");
const entity = @import("entity.zig");
const Contour = @import("Contour.zig");
const Spawner = @import("Spawner.zig");
const Area = @import("Area.zig");
const Revolver = @import("Revolver.zig");
const commons = @import("../commons.zig");

pub const MAX_ENTITIES: usize = 512;

entities: [MAX_ENTITIES]entity.EntitySlot,
free_indices: [MAX_ENTITIES]usize, // stack
free_count: usize = MAX_ENTITIES,

contours: std.ArrayList(usize),
spawners: std.ArrayList(usize),
areas: std.ArrayList(usize),
revolvers: std.ArrayList(usize),

const EnvironmentSnapshot = struct {
    version: []const u8,
    entities: []const entity.EntitySnapshot,
};

pub fn init(alloc: std.mem.Allocator) Self {
    var entities: [MAX_ENTITIES]entity.EntitySlot = undefined;
    for (entities[0..]) |*slot| {
        slot.* = entity.EntitySlot{
            .entity = undefined,
            .alive = false,
        };
    }
    //
    var free_indices: [MAX_ENTITIES]usize = undefined;
    for (0..MAX_ENTITIES) |i| {
        free_indices[i] = MAX_ENTITIES - 1 - i;
    }
    return .{
        .entities = entities,
        .free_indices = free_indices,
        .contours = std.ArrayList(usize).init(alloc),
        .spawners = std.ArrayList(usize).init(alloc),
        .areas = std.ArrayList(usize).init(alloc),
        .revolvers = std.ArrayList(usize).init(alloc),
    };
}

pub fn deinit(self: *Self) void {
    self.contours.deinit();
    self.spawners.deinit();
    self.areas.deinit();
    self.revolvers.deinit();
}

pub fn createEntity(self: *Self, ent: entity.Entity) !void {
    var free_index: usize = undefined;

    // if free count > 0, pop from free list
    if (self.free_count > 0) {
        free_index = self.free_indices[self.free_count - 1];
        const entity_slot: entity.EntitySlot = .{
            .entity = ent,
            .gen = 0,
            .alive = true,
        };
        self.entities[free_index] = entity_slot;
        self.free_count -= 1;
    } else {
        free_index = 0;
    }

    // add entity to corresponding specialized arraylist
    switch (ent.kind) {
        .contour => try self.contours.append(free_index),
        .spawner => try self.spawners.append(free_index),
        .area => try self.areas.append(free_index),
        .revolver => try self.revolvers.append(free_index),
    }
}

pub fn getEntity(self: *Self, index: usize) *entity.Entity {
    return &self.entities[index].entity;
}

pub fn clearEntities(self: *Self, alloc: std.mem.Allocator) void {
    // dealloc and delete existing entities
    for (self.entities[0..]) |*eslot| {
        if (eslot.alive) {
            eslot.entity.deinit(alloc);
        }
    }

    // clear the reference lists
    self.contours.clearRetainingCapacity();
    self.spawners.clearRetainingCapacity();
    self.revolvers.clearRetainingCapacity();
}

//
// HALF-AI CODE
//
pub fn loadScene(self: *Self, allocator: std.mem.Allocator, path: []const u8) !void {
    const json = try commons.readFile(allocator, path);
    defer allocator.free(json);

    // dealloc and delete existing entities (environmental objects)
    for (self.entities[0..]) |*eslot| {
        if (eslot.alive) {
            eslot.entity.deinit(allocator);
        }
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
        try self.createEntity(try entity.Entity.fromSnapshot(allocator, snap));
    }
}

pub fn saveScene(self: *Self, allocator: std.mem.Allocator, path: []const u8) !void {
    var snaps = std.ArrayList(entity.EntitySnapshot).init(allocator);
    defer snaps.deinit();

    for (self.entities[0..]) |*eslot| {
        if (!eslot.alive) continue;
        try snaps.append(eslot.entity.getSnapshot());
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
