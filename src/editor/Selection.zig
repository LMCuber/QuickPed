const rl = @import("raylib");
const std = @import("std");
const Self = @This();
const palette = @import("../palette.zig");
const commons = @import("../commons.zig");
const utils = @import("../utils.zig");
const entity = @import("../environment/entity.zig");
const Environment = @import("../environment/Environment.zig");
const SimData = @import("SimData.zig");
const UUID = @import("../UUID.zig");

pub const State = union(enum) {
    none: void,
    anchor: rl.Vector2,
    released: void,
    dragging: struct {
        rect_origin: rl.Vector2,
        click_origin: rl.Vector2,
    },
};

pub const StateEnum = std.meta.Tag(State);

pub const Capture = struct {
    ent_id: UUID,
    origin: rl.Vector2,
};

state: State = .none,
pos: rl.Vector2 = .zero(),
bounding_rect: ?rl.Rectangle = null,
next_state: ?StateEnum = null,

// highlighted_entities: std.ArrayList(Capture) = .empty,
selected_entities: std.ArrayList(Capture) = .empty,

pub fn deinit(self: *Self, alloc: std.mem.Allocator) void {
    // self.highlighted_entities.deinit(alloc);
    self.selected_entities.deinit(alloc);
}

pub fn update(
    self: *Self,
    alloc: std.mem.Allocator,
    env: *Environment,
    sim_data: SimData,
) !void {
    // resolve unresolved state changes and initialize payloads
    if (self.next_state) |next_state| {
        switch (next_state) {
            .none => self.state = .none,
            .anchor => self.state = .{
                .anchor = commons.mousePos(),
            },
            .released => {
                // setup our own al-lencompassing rectangle
                var rectangles: std.ArrayList(rl.Rectangle) = .empty;
                defer rectangles.deinit(alloc);
                for (self.selected_entities.items) |cap| {
                    const ent = env.entities.getByUUID(cap.ent_id);
                    try rectangles.append(alloc, ent.getRect());
                }
                const margin: f32 = 10;
                self.bounding_rect = utils.getBoundingBox(rectangles.items, margin);
                self.pos = .init(
                    self.bounding_rect.?.x + self.bounding_rect.?.width,
                    self.bounding_rect.?.y + self.bounding_rect.?.height,
                );

                self.state = .released;
            },
            .dragging => {
                self.state = .{
                    .dragging = .{
                        .rect_origin = .init(
                            self.bounding_rect.?.x,
                            self.bounding_rect.?.y,
                        ),
                        .click_origin = commons.mousePos(),
                    },
                };
            },
        }
        self.next_state = null;
    }

    switch (self.state) {
        .none => {
            if (rl.isMouseButtonPressed(.left)) {
                self.selected_entities.clearRetainingCapacity();
                self.next_state = .anchor;
            }
        },
        .anchor => |anchor| {
            if (rl.isMouseButtonReleased(.left)) {
                // released, so save all highlighted entities
                const rect = utils.twoPointsToRec(anchor, commons.mousePos());
                for (env.entities.items()) |*ent| {
                    if (ent.checkSelected(rect)) {
                        try self.selected_entities.append(alloc, .{
                            .ent_id = ent.uuid,
                            .origin = ent.getCenter(),
                        });
                    }
                }

                // check if even highlighted anything]
                if (self.selected_entities.items.len > 0) {
                    // change state
                    self.next_state = .released;
                } else {
                    self.next_state = .none;
                }
            }
        },
        .released => {
            // when clicking inside, start dragging
            if (rl.isMouseButtonPressed(.left)) {
                if (rl.checkCollisionPointRec(commons.mousePos(), self.bounding_rect.?)) {
                    self.next_state = .dragging;
                } else {
                    // clicked out of bounds, so change to anchored
                    self.selected_entities.clearRetainingCapacity();
                    self.next_state = .anchor;
                }
            }
        },
        .dragging => |dragging| {
            for (self.selected_entities.items) |cap| {
                const ent = env.entities.getByUUID(cap.ent_id);

                // calculate where to move the entity
                const mouse_diff = commons.mousePos().subtract(dragging.click_origin);

                // move the entity AND the selection rectangle
                // std.debug.print("{}\n", .{mouse_diff});
                ent.selectedMove(cap.origin.add(mouse_diff), sim_data);
                const rect_dest = dragging.rect_origin.add(mouse_diff);
                self.bounding_rect = .{
                    .x = rect_dest.x,
                    .y = rect_dest.y,
                    .width = self.bounding_rect.?.width,
                    .height = self.bounding_rect.?.height,
                };
            }

            // go back to released if lets loose of mouse
            if (rl.isMouseButtonReleased(.left)) {
                self.next_state = .released;
                // also update the entity origins
                for (self.selected_entities.items) |*cap| {
                    const ent = env.entities.getByUUID(cap.ent_id);
                    cap.origin = ent.getCenter();
                }
            }
        },
    }
}

pub fn draw(self: Self, env: *Environment) void {
    switch (self.state) {
        .none => {},
        .anchor => |anchor| {
            const rect = utils.twoPointsToRec(anchor, commons.mousePos());
            rl.drawRectangleRec(rect, palette.env.light_gray_t);
            rl.drawRectangleLinesEx(rect, 0.5, .yellow);
            rl.drawCircleV(anchor, 4, .red);
        },
        .released => {
            rl.drawRectangleLinesEx(self.bounding_rect.?, 0.5, .yellow);
        },
        .dragging => {},
    }

    // draw the selected overlay to all highlighted entities
    for (self.selected_entities.items) |cap| {
        var ent = env.entities.getByUUID(cap.ent_id);
        ent.selectedDraw();
    }

    // debug
    const mouse = commons.mousePos();
    rl.drawText(
        @tagName(self.state),
        @intFromFloat(mouse.x + 15),
        @intFromFloat(mouse.y + 15),
        20,
        .white,
    );
}
