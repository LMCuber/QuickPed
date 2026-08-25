const Self = @This();
const std = @import("std");
const rl = @import("raylib");
const color = @import("../color.zig");
const palette = @import("../palette.zig");
const commons = @import("../commons.zig");
const Entity = @import("entity.zig").Entity;
const SimData = @import("../editor/SimData.zig");
const AgentData = @import("../editor/AgentData.zig");
const Settings = @import("../Settings.zig");

pos: rl.Vector2 = .{ .x = 0, .y = 0 },
points: std.ArrayList(rl.Vector2),
placed: bool = false,

pub const ContourSnapshot = struct {
    points: []rl.Vector2,
};

pub fn init() Self {
    return .{
        .points = .empty,
    };
}

pub fn deinit(self: *Self, alloc: std.mem.Allocator) void {
    self.points.deinit(alloc);
}

pub fn getSnapshot(self: Self) ContourSnapshot {
    return .{ .points = self.points.items };
}

pub fn fromSnapshot(
    alloc: std.mem.Allocator,
    snap: ContourSnapshot,
    _: SimData,
    _: AgentData,
) !Self {
    var points: std.ArrayList(rl.Vector2) = .empty;
    for (snap.points) |point| try points.append(alloc, point);
    const contour: Self = .{
        .points = points,
        .placed = true,
    };
    return contour;
}

fn centroid(self: Self) rl.Vector2 {
    var sum: rl.Vector2 = .init(0, 0);
    for (self.points.items) |p| sum = sum.add(p);
    return sum.scale(1.0 / @as(f32, @floatFromInt(self.points.items.len)));
}

pub fn update(
    self: *Self,
    alloc: std.mem.Allocator,
    sim_data: SimData,
    _: AgentData,
    settings: Settings,
) !Entity.EntityAction {
    if (!self.placed) {
        self.pos = commons.roundMousePos(sim_data);
        // place new point
        if (commons.editorCapturingMouse(settings) and rl.isMouseButtonPressed(.left)) {
            // only add if it's not the same point twice
            var can_add_point = false;
            if (self.points.items.len > 0) {
                const last_point = self.points.getLast();
                can_add_point = !self.pos.equals(last_point);
            } else {
                can_add_point = true;
            }
            if (can_add_point) {
                try self.points.append(alloc, self.pos);
            }
        }

        // finish points with keypress
        if (rl.isKeyPressed(.enter)) {
            self.placed = true;
            return .placed;
        }

        return .none;
    } else if (commons.editorCapturingMouse(settings) and rl.isMouseButtonPressed(.left) and self.checkHover()) {
        return .selected;
    }
    return .none;
}

pub fn checkHover(self: Self) bool {
    for (self.points.items, 0..) |point, i| {
        if (i == self.points.items.len - 1) continue;
        const next_point: rl.Vector2 = self.points.items[i + 1];
        if (rl.checkCollisionPointLine(commons.mousePos(), point, next_point, 8)) {
            return true;
        }
    }
    return false;
}

pub fn hover(self: *Self) void {
    const line_width = 3;
    for (self.points.items, 0..) |point, i| {
        if (i == self.points.items.len - 1) continue;
        const next_point = self.points.items[i + 1];
        rl.drawLineEx(point, next_point, line_width, palette.env.hover);
    }
}

pub fn draw(self: Self, _: SimData, _: AgentData) void {
    const line_width = 2;
    const col = if (self.placed)
        palette.env.white
    else
        color.white_t;

    if (self.points.items.len == 0) {
        // has placed nothing yet, so show white circle
        rl.drawCircleV(self.pos, 6, col);
    } else {
        // already has points, so display them
        for (self.points.items, 0..) |point, i| {
            const next_index = (i + 1) % self.points.items.len;
            const next_point = self.points.items[next_index];

            // only render connecting line if it isn't a wraparound
            if (i < self.points.items.len - 1) {
                rl.drawLineEx(point, next_point, line_width, col);
            }
        }
        if (!self.placed) {
            // display last point to mouse cursor
            rl.drawLineEx(self.points.items[self.points.items.len - 1], self.pos, line_width, col);
        }
    }
}
