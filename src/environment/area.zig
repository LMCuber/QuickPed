const Self = @This();
const std = @import("std");
const rl = @import("raylib");
const color = @import("../color.zig");
const palette = @import("../palette.zig");
const commons = @import("../commons.zig");
const Entity = @import("entity.zig").Entity;
const SimData = @import("../editor/SimData.zig");
const Settings = @import("../Settings.zig");
const z = @import("zgui");

area_id: i32,
topleft: rl.Vector2 = undefined,
rect: rl.Rectangle = undefined,
placed: bool = false,
anchored: bool = false,
pos: rl.Vector2 = .{ .x = 0, .y = 0 },
seat_data: SeatData = .{},

pub var next_id: i32 = 0;

pub const SeatData = struct {
    open_popup: bool = true,
    seats: bool = false,
    num_cols: i32 = 1,
    num_rows: i32 = 1,
};

pub const AreaSnapshot = struct {
    area_id: i32,
    rect: rl.Rectangle,
    seat_data: SeatData,
};

pub fn init() Self {
    return .{
        .area_id = nextId(),
    };
}

pub fn getSnapshot(self: Self) AreaSnapshot {
    return .{
        .area_id = self.area_id,
        .rect = self.rect,
        .seat_data = self.seat_data,
    };
}

pub fn fromSnapshot(snap: AreaSnapshot) Self {
    return .{
        .area_id = snap.area_id,
        .rect = snap.rect,
        .anchored = true,
        .placed = true,
        .seat_data = snap.seat_data,
    };
}

pub fn nextId() i32 {
    next_id += 1;
    return next_id - 1;
}

pub fn update(self: *Self, sim_data: SimData, settings: Settings) Entity.EntityAction {
    if (!self.placed) {
        self.pos = commons.roundMousePos(sim_data);
        self.pos = commons.roundMousePos(sim_data);
        if (commons.editorCapturingMouse(settings) and rl.isMouseButtonPressed(.mouse_button_left)) {
            if (!self.anchored) {
                // not anchored yet; anchor
                self.topleft = self.pos;
                self.anchored = true;
            } else {
                // check if the width or height is negative
                if (self.rect.width <= 0 or self.rect.height <= 0) {
                    self.anchored = false;
                    return .cancelled;
                }
                self.placed = true;
                // return .placed;
                return .confirm;
            }
        }
        if (self.anchored) {
            self.rect = rl.Rectangle.init(
                self.topleft.x,
                self.topleft.y,
                self.pos.x - self.topleft.x,
                self.pos.y - self.topleft.y,
            );
        }
    }

    // confirm popup
    // if (z.beginPopupModal("Confirm", .{})) {
    //     z.text("Test", .{});
    //     z.text("Newline text", .{});
    //     if (z.button("OK", .{})) {
    //         z.closeCurrentPopup();
    //     }
    //     z.endPopup();
    // }

    return .none;
}

pub fn confirm(self: *Self) void {
    _ = z.checkbox("Seats", .{ .v = &self.seat_data.seats });

    // parameters for discrete
    if (self.seat_data.seats) {
        const w: f32 = 100;
        z.setNextItemWidth(w);
        _ = z.inputInt("cols ", .{ .v = &self.seat_data.num_cols });
        z.setNextItemWidth(w);
        _ = z.inputInt("rows ", .{ .v = &self.seat_data.num_rows });
    }
}

pub fn getPos(self: Self) rl.Vector2 {
    if (self.seat_data.seats) {
        const row_index: f32 = @floatFromInt(rl.getRandomValue(1, self.seat_data.num_rows));
        const col_index: f32 = @floatFromInt(rl.getRandomValue(1, self.seat_data.num_cols));
        const seat_offset: rl.Vector2 = self.getSeatOffset();
        const rel_seat_pos: rl.Vector2 = .{
            .x = col_index * seat_offset.x,
            .y = row_index * seat_offset.y,
        };
        return rel_seat_pos.add(.{ .x = self.rect.x, .y = self.rect.y });
    } else {
        return self.getCenter();
    }
}

pub fn getCenter(self: Self) rl.Vector2 {
    return .{
        .x = self.rect.x + self.rect.width / 2,
        .y = self.rect.y + self.rect.height / 2,
    };
}

fn getSeatOffset(self: Self) rl.Vector2 {
    return .{
        .x = self.rect.width / @as(f32, @floatFromInt(self.seat_data.num_cols + 1)),
        .y = self.rect.height / @as(f32, @floatFromInt(self.seat_data.num_rows + 1)),
    };
}

pub fn draw(self: Self) void {
    var col: rl.Color = undefined;
    if (self.placed) {
        col = palette.env.navy;
    } else if (self.anchored) {
        col = color.navy_t;
    } else {
        col = color.light_blue;
    }
    const size = 10;
    if (!self.anchored) {
        // not placed topleft yet
        rl.drawRectangleV(self.pos.subtract(.{ .x = size / 2, .y = size / 2 }), .{ .x = size, .y = size }, col);
    } else {
        // placed topleft
        rl.drawRectangleRec(self.rect, col);
    }

    // draw circles for seats if seats is turned on
    if (self.seat_data.seats) {
        const c: rl.Color = .{ .r = 96, .g = 166, .b = 180, .a = 150 };
        const seat_offset: rl.Vector2 = self.getSeatOffset();
        for (1..@intCast(self.seat_data.num_rows + 1)) |row_index| {
            for (1..@intCast(self.seat_data.num_cols + 1)) |col_index| {
                const seat_pos: rl.Vector2 = .{
                    .x = self.rect.x + @as(f32, @floatFromInt(col_index)) * seat_offset.x,
                    .y = self.rect.y + @as(f32, @floatFromInt(row_index)) * seat_offset.y,
                };
                rl.drawCircleV(seat_pos, 8, c);
            }
        }
    }
}
