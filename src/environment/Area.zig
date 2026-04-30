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

pub var zeroSepTypes: [:0]const u8 = "area\x00seats\x00scattered\x00";

placed: bool = false,
pos: rl.Vector2 = .{ .x = 0, .y = 0 },
confirmed_init_popup: bool = false,
style_index: i32 = 0,
style: Style,

pub const Style = union(enum) {
    const StyleSnapshot = union(enum) {
        standing: StandingData.StandingDataSnapshot,
        seating: SeatingData.SeatingDataSnapshot,
        individual: IndividualData.IndividualDataSnapshot,
    };

    standing: StandingData,
    seating: SeatingData,
    individual: IndividualData,

    pub fn getSnapshot(self: @This()) StyleSnapshot {
        switch (self) {
            inline else => |k, tag| return @unionInit(
                StyleSnapshot,
                @tagName(tag),
                k.getSnapshot(),
            ),
        }
    }

    pub fn fromSnapshot(alloc: std.mem.Allocator, snap: StyleSnapshot) !Style {
        return switch (snap) {
            .standing => |standing| .{ .standing = StandingData.fromSnapshot(standing) },
            .seating => |seating| .{ .seating = SeatingData.fromSnapshot(seating) },
            .individual => |ind| .{ .individual = try IndividualData.fromSnapshot(alloc, ind) },
        };
    }
};

pub const StandingData = struct {
    pub const StandingDataSnapshot = struct {
        rect: rl.Rectangle,
    };

    topleft: rl.Vector2 = .{ .x = 0, .y = 0 },
    rect: rl.Rectangle = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
    anchored: bool = false,

    pub fn getPos(self: @This()) rl.Vector2 {
        return .{
            .x = self.rect.x + self.rect.width / 2,
            .y = self.rect.y + self.rect.height / 2,
        };
    }

    pub fn getSnapshot(self: @This()) StandingDataSnapshot {
        return .{
            .rect = self.rect,
        };
    }

    pub fn fromSnapshot(snap: StandingDataSnapshot) StandingData {
        return .{
            .rect = snap.rect,
            .anchored = true,
        };
    }

    pub fn checkHover(self: *@This()) bool {
        return rl.checkCollisionPointRec(commons.mousePos(), self.rect);
    }

    pub fn hover(self: *@This()) void {
        rl.drawRectangleLinesEx(self.rect, 3, palette.env.hover);
    }
};

pub const SeatingData = struct {
    pub const SeatingDataSnapshot = struct {
        rect: rl.Rectangle,
        num_cols: i32,
        num_rows: i32,
    };

    open_popup: bool = true,
    topleft: rl.Vector2 = .{ .x = 0, .y = 0 },
    rect: rl.Rectangle = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
    anchored: bool = false,
    num_cols: i32 = 1,
    num_rows: i32 = 1,

    pub fn getPos(self: @This()) rl.Vector2 {
        const row_index: f32 = @floatFromInt(rl.getRandomValue(1, self.num_rows));
        const col_index: f32 = @floatFromInt(rl.getRandomValue(1, self.num_cols));
        const seat_offset: rl.Vector2 = self.getSeatOffset(self.rect.width, self.rect.height);
        const rel_seat_pos: rl.Vector2 = .{
            .x = col_index * seat_offset.x,
            .y = row_index * seat_offset.y,
        };
        return rel_seat_pos.add(.{ .x = self.rect.x, .y = self.rect.y });
    }

    pub fn getSeatOffset(self: @This(), w: f32, h: f32) rl.Vector2 {
        return .{
            .x = w / @as(f32, @floatFromInt(self.num_cols + 1)),
            .y = h / @as(f32, @floatFromInt(self.num_rows + 1)),
        };
    }

    pub fn getSnapshot(self: @This()) SeatingDataSnapshot {
        return .{
            .num_cols = self.num_cols,
            .num_rows = self.num_rows,
            .rect = self.rect,
        };
    }

    pub fn fromSnapshot(snap: SeatingDataSnapshot) SeatingData {
        return .{
            .num_cols = snap.num_cols,
            .num_rows = snap.num_rows,
            .rect = snap.rect,
            .anchored = true,
        };
    }

    pub fn checkHover(self: *@This()) bool {
        return rl.checkCollisionPointRec(commons.mousePos(), self.rect);
    }

    pub fn hover(_: *@This()) void {
        return;
    }
};

pub const IndividualData = struct {
    pub const IndividualDataSnapshot = struct {
        points: []rl.Vector2,
    };

    points: std.ArrayList(rl.Vector2),
    free_indices: std.ArrayList(usize),
    selected_seat_index: ?usize = null,
    last_selected_seat_index: ?usize = null,
    radius: f32 = 16,

    pub fn init(alloc: std.mem.Allocator) !IndividualData {
        return .{
            .points = std.ArrayList(rl.Vector2).init(alloc),
            .free_indices = std.ArrayList(usize).init(alloc),
        };
    }

    pub fn deinit(self: *@This()) void {
        self.points.deinit();
        self.free_indices.deinit();
    }

    pub fn getSeatIndex(self: *@This()) usize {
        if (self.free_indices.items.len == 0) return 0;
        const u: usize = @intCast(rl.getRandomValue(0, @intCast(self.free_indices.items.len - 1)));
        const free_index: usize = self.free_indices.swapRemove(u);
        return free_index;
    }

    pub fn freeSeatIndex(self: *@This(), index: usize) !void {
        try self.free_indices.append(index);
    }

    pub fn getPosFromSeatIndex(self: *@This(), index: usize) rl.Vector2 {
        return self.points.items[index];
    }

    pub fn getSnapshot(self: @This()) IndividualDataSnapshot {
        return .{
            .points = self.points.items,
        };
    }

    pub fn fromSnapshot(alloc: std.mem.Allocator, snap: IndividualDataSnapshot) !IndividualData {
        var points = std.ArrayList(rl.Vector2).init(alloc);
        for (snap.points) |point| {
            try points.append(point);
        }
        var free_indices = std.ArrayList(usize).init(alloc);
        for (0..points.items.len) |i| {
            try free_indices.append(i);
        }
        return .{
            .free_indices = free_indices,
            .points = points,
        };
    }

    pub fn checkHover(self: *@This()) bool {
        for (self.points.items) |seat_pos| {
            if (rl.checkCollisionPointCircle(commons.mousePos(), seat_pos, self.radius)) {
                return true;
            }
        }
        return false;
    }

    pub fn hover(self: *@This()) void {
        for (self.points.items) |seat_pos| {
            // the one colliding should be highlighted color
            if (rl.checkCollisionPointCircle(commons.mousePos(), seat_pos, self.radius)) {
                rl.drawCircleLinesV(seat_pos, self.radius, palette.env.yellow);
                // cross
                const line: rl.Vector2 = .{ .x = self.radius, .y = 0 };
                inline for (0..4) |i| {
                    rl.drawLineV(
                        seat_pos,
                        seat_pos.add(line.rotate(@as(f32, @floatFromInt(i)) * std.math.pi * 0.5)),
                        palette.env.yellow,
                    );
                }
            } else {
                // only render pink if not currently dragging
                if (self.selected_seat_index == null) {
                    rl.drawCircleLinesV(seat_pos, self.radius, palette.env.hover);
                }
            }
        }
    }

    pub fn addNewPoint(self: *@This()) !void {
        try self.points.append(.{
            .x = self.points.items[self.points.items.len - 1].x + self.radius * 2,
            .y = self.points.items[self.points.items.len - 1].y,
        });
        // NOT selected_seat_index, since it's not selected. it should just
        // be highlighted
        self.last_selected_seat_index = self.points.items.len - 1;
    }
};

pub const AreaSnapshot = struct {
    style: Style.StyleSnapshot,
};

pub fn init() Self {
    z.openPopup("Select area type", .{});
    return .{
        .style = .{
            .standing = .{},
        },
    };
}

pub fn deinit(self: *Self) void {
    switch (self.style) {
        .individual => |*ind| ind.deinit(),
        else => {},
    }
}

pub fn getSnapshot(self: Self) AreaSnapshot {
    return .{
        .style = self.style.getSnapshot(),
    };
}

pub fn fromSnapshot(alloc: std.mem.Allocator, snap: AreaSnapshot) !Self {
    return .{
        .placed = true,
        .confirmed_init_popup = true,
        .style = try Style.fromSnapshot(alloc, snap.style),
    };
}

pub fn update(self: *Self, sim_data: SimData, settings: Settings) !Entity.EntityAction {
    if (!self.confirmed_init_popup) {
        return .confirm_init;
    }

    if (!self.placed) {
        self.pos = commons.roundMousePos(sim_data);
        self.pos = commons.roundMousePos(sim_data);
        if (commons.editorCapturingMouse(settings) and rl.isMouseButtonPressed(.mouse_button_left)) {
            switch (self.style) {
                inline .standing, .seating => |*data| {
                    if (!data.anchored) {
                        // not anchored yet; anchor
                        data.topleft = self.pos;
                        data.anchored = true;
                    } else {
                        // check if the width or height is negative
                        if (data.rect.width <= 0 or data.rect.height <= 0) {
                            data.anchored = false;
                            return .cancelled;
                        }
                        self.placed = true;
                        return .confirm;
                    }
                },
                .individual => |*data| {
                    try data.points.append(self.pos);
                },
            }
        }

        switch (self.style) {
            inline .standing, .seating => |*data| {
                if (data.anchored) {
                    data.rect = rl.Rectangle.init(
                        data.topleft.x,
                        data.topleft.y,
                        self.pos.x - data.topleft.x,
                        self.pos.y - data.topleft.y,
                    );
                }
            },
            .individual => |*data| {
                if (rl.isKeyPressed(.key_enter)) {
                    for (0..data.points.items.len) |i| {
                        try data.free_indices.append(i);
                    }
                    self.placed = true;
                    return .confirm;
                }
            },
        }
    } else {
        // is placed
        switch (self.style) {
            .individual => |*ind| {
                if (ind.selected_seat_index) |seat_index| {
                    // update current seat if currently one hovered
                    var seat_pos: *rl.Vector2 = &ind.points.items[seat_index];
                    seat_pos.x = commons.roundMousePos(sim_data).x;
                    seat_pos.y = commons.roundMousePos(sim_data).y;

                    // check if not hovered anymore
                    if (!rl.isMouseButtonDown(.mouse_button_left)) {
                        ind.selected_seat_index = null;
                    }
                } else {
                    // check for clicking on new seat
                    for (ind.points.items, 0..) |*seat_pos, i| {
                        if (rl.isMouseButtonPressed(.mouse_button_left) and
                            rl.checkCollisionPointCircle(commons.mousePos(), seat_pos.*, ind.radius))
                        {
                            if (ind.selected_seat_index == null) {
                                ind.selected_seat_index = i;
                                ind.last_selected_seat_index = ind.selected_seat_index;
                                break;
                            }
                        }
                    }
                }
            },
            else => {},
        }

        if (commons.editorCapturingMouse(settings) and rl.isMouseButtonPressed(.mouse_button_left) and self.checkHover()) {
            return .selected;
        }
    }

    return .none;
}

pub fn confirm(self: *Self) void {
    switch (self.style) {
        .seating => |*seat_data| {
            const w: f32 = 100;
            z.setNextItemWidth(w);
            _ = z.inputInt("cols ", .{ .v = &seat_data.num_cols });
            z.setNextItemWidth(w);
            _ = z.inputInt("rows ", .{ .v = &seat_data.num_rows });
        },
        else => {},
    }
}

pub fn edit(self: *Self) !void {
    switch (self.style) {
        .individual => |*ind| {
            if (z.collapsingHeader("seats", .{})) {
                // the current points
                var i: usize = ind.points.items.len;
                while (i > 0) {
                    i -= 1;

                    // check if the index is the currently selected index for change of color
                    if (i == ind.last_selected_seat_index) {
                        z.pushStyleColor1u(.{ .idx = .frame_bg, .c = palette.ui.green });
                        z.pushStyleColor1u(.{ .idx = .button, .c = palette.ui.green });
                    }
                    var seat_pos: *rl.Vector2 = &ind.points.items[i];

                    // position input
                    var buf: [32]u8 = undefined;
                    var label = try std.fmt.bufPrintZ(&buf, "P{d}##delete-seat-button{d}", .{ i, i });
                    _ = z.inputFloat2(
                        label,
                        .{ .v = @as(*[2]f32, @ptrCast(&seat_pos.x)) },
                    );

                    // deleting the point
                    if (ind.points.items.len > 1) {
                        z.sameLine(.{});
                        label = try std.fmt.bufPrintZ(&buf, "-##delete-seat{}", .{i});
                        if (z.button(label, .{ .w = 40 })) {
                            _ = ind.points.orderedRemove(i);
                        }
                    }

                    // pop the style
                    if (i == ind.last_selected_seat_index) {
                        z.popStyleColor(.{ .count = 2 });
                    }
                }

                // add new point
                if (z.button("+", .{ .w = 80 })) {
                    try ind.addNewPoint();
                }
            }
        },
        else => {},
    }
}

pub fn confirmInit(self: *Self) void {
    z.setNextItemWidth(120);
    _ = z.combo("area type", .{ .current_item = &self.style_index, .items_separated_by_zeros = zeroSepTypes });
}

pub fn finishConfirm(self: *Self, alloc: std.mem.Allocator) !void {
    self.style = switch (self.style_index) {
        0 => .{ .standing = .{} },
        1 => .{ .seating = .{} },
        2 => .{ .individual = try IndividualData.init(alloc) },
        else => unreachable,
    };
    self.confirmed_init_popup = true;
}

pub fn getPos(self: *Self) rl.Vector2 {
    switch (self.style) {
        .individual => @panic("must call getSeatIndex on .individual first"),
        inline else => |*data| return data.getPos(),
    }
}

pub fn checkCollision(self: Self, pos: rl.Vector2, target: rl.Vector2) bool {
    switch (self.style) {
        inline .standing, .seating => |data| return rl.checkCollisionPointRec(pos, data.rect),
        .individual => return pos.distance(target) <= 12,
    }
}

pub fn checkHover(self: *Self) bool {
    switch (self.style) {
        inline else => |*style| return style.checkHover(),
    }
}

pub fn hover(self: *Self) void {
    switch (self.style) {
        inline else => |*style| style.hover(),
    }
}

pub fn draw(self: Self) void {
    if (!self.confirmed_init_popup) {
        return;
    }

    // standing & seating
    switch (self.style) {
        inline .standing, .seating => |data| {
            const col = if (self.placed)
                palette.env.navy_t
            else if (data.anchored)
                color.navy_t
            else
                color.navy;
            const size = 10;
            if (!data.anchored) {
                // not placed topleft yet
                rl.drawRectangleV(self.pos.subtract(.{ .x = size / 2, .y = size / 2 }), .{ .x = size, .y = size }, col);
            } else {
                // placed topleft
                rl.drawRectangleRec(data.rect, col);
                rl.drawRectangleLinesEx(data.rect, 4, palette.env.navy);
            }
        },
        else => {},
    }

    // other individual drawings
    switch (self.style) {
        .seating => |seating_data| {
            const c: rl.Color = .{ .r = 96, .g = 166, .b = 180, .a = 150 };
            const seat_offset: rl.Vector2 = seating_data.getSeatOffset(seating_data.rect.width, seating_data.rect.height);
            for (1..@intCast(seating_data.num_rows + 1)) |row_index| {
                for (1..@intCast(seating_data.num_cols + 1)) |col_index| {
                    const seat_pos: rl.Vector2 = .{
                        .x = seating_data.rect.x + @as(f32, @floatFromInt(col_index)) * seat_offset.x,
                        .y = seating_data.rect.y + @as(f32, @floatFromInt(row_index)) * seat_offset.y,
                    };
                    rl.drawCircleV(seat_pos, 8, c);
                }
            }
        },
        .individual => |*ind| {
            for (ind.points.items) |point| {
                rl.drawCircleV(point, ind.radius, palette.env.navy_t);
                rl.drawCircleLinesV(point, ind.radius, if (self.placed) palette.env.white else palette.env.orange);
            }
            if (!self.placed) {
                rl.drawCircleV(self.pos, ind.radius, palette.env.orange);
                rl.drawCircleLinesV(self.pos, ind.radius, palette.env.white);
                rl.drawText("<enter> to finish", @intFromFloat(self.pos.x + 32), @intFromFloat(self.pos.y + 62), 16, palette.env.white);
            }
        },
        else => {},
    }
}
