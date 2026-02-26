const Self = @This();

const std = @import("std");
const entity = @import("entity.zig");
const Contour = @import("Contour.zig");
const Spawner = @import("Spawner.zig");
const Area = @import("Area.zig");
const Revolver = @import("Revolver.zig");

pub const MAX_ENTITIES: usize = 1024;

entities: [MAX_ENTITIES]entity.EntitySlot = undefined,
free_indices: [MAX_ENTITIES]usize = undefined, // stack
free_count: usize = MAX_ENTITIES,

contours: std.ArrayList(usize),
spawners: std.ArrayList(usize),
areas: std.ArrayList(usize),
revolvers: std.ArrayList(usize),

pub fn init(alloc: std.mem.Allocator) Self {
    var indices: [MAX_ENTITIES]usize = undefined;
    for (0..MAX_ENTITIES) |i| {
        indices[i] = MAX_ENTITIES - 1 - i;
    }
    return .{
        .free_indices = indices,
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
