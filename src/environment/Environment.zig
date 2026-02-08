const Self = @This();

const std = @import("std");
const entity = @import("entity.zig");
const Contour = @import("Contour.zig");
const Spawner = @import("Spawner.zig");
const Area = @import("Area.zig");
const Revolver = @import("Revolver.zig");

entities: std.ArrayList(entity.Entity),
contours: std.ArrayList(*Contour),
spawners: std.ArrayList(*Spawner),
areas: std.ArrayList(*Area),
revolvers: std.ArrayList(*Revolver),

pub fn init(alloc: std.mem.Allocator) Self {
    return .{
        .entities = std.ArrayList(entity.Entity).init(alloc),
        .contours = std.ArrayList(*Contour).init(alloc),
        .spawners = std.ArrayList(*Spawner).init(alloc),
        .areas = std.ArrayList(*Area).init(alloc),
        .revolvers = std.ArrayList(*Revolver).init(alloc),
    };
}

pub fn deinit(self: *Self) void {
    self.entities.deinit();
    self.contours.deinit();
    self.spawners.deinit();
    self.areas.deinit();
    self.revolvers.deinit();
}
