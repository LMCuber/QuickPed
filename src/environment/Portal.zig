const Self = @This();
const std = @import("std");
const rl = @import("raylib");
const color = @import("../color.zig");
const palette = @import("../palette.zig");
const commons = @import("../commons.zig");
const Entity = @import("entity.zig").Entity;
const SimData = @import("../editor/SimData.zig");
const Settings = @import("../Settings.zig");
const Agent = @import("../Agent.zig");
const z = @import("zgui");

source: commons.Line = .{},
dest: commons.Line = .{},
point_count: usize = 0,
placed: bool = false,
pos: rl.Vector2 = .{ .x = 0, .y = 0 },

pub const PortalSnapshot = struct {
    source: commons.Line,
    dest: commons.Line,
};

pub fn init() Self {
    return .{};
}

pub fn getSnapshot(self: Self) PortalSnapshot {
    return .{
        .source = self.source,
        .dest = self.dest,
    };
}

pub fn fromSnapshot(snap: PortalSnapshot) Self {
    return .{
        .source = snap.source,
        .dest = snap.dest,
        .point_count = 4,
        .placed = true,
    };
}

pub fn checkCollision(self: *Self, pos: rl.Vector2) bool {
    return commons.vecToLineSegment(pos, self.source.p1, self.source.p2).length() <= 5;
}

pub fn checkHover(self: *Self) bool {
    const threshold = 8;
    return rl.checkCollisionPointLine(commons.mousePos(), self.source.p1, self.source.p2, threshold) or
        rl.checkCollisionPointLine(commons.mousePos(), self.dest.p1, self.dest.p2, threshold);
}

pub fn getSourcePosFromU(self: Self, u: f32) rl.Vector2 {
    return self.source.p1.add(self.source.p2.subtract(self.source.p1).scale(u));
}

pub fn getDestPos(self: Self, u: f32) rl.Vector2 {
    return self.dest.p1.add(self.dest.p2.subtract(self.dest.p1).scale(u));
}

pub fn update(self: *Self, sim_data: SimData, settings: Settings) Entity.EntityAction {
    if (!self.placed) {
        self.pos = commons.roundMousePos(sim_data);
        // place new point
        if (commons.editorCapturingMouse(settings) and rl.isMouseButtonPressed(.left)) {
            self.point_count += 1;
            switch (self.point_count) {
                1 => self.source.p1 = self.pos,
                2 => self.source.p2 = self.pos,
                3 => self.dest.p1 = self.pos,
                4 => {
                    self.dest.p2 = self.pos;
                    self.point_count -= 1;
                    self.placed = true;
                    return .confirm;
                },
                else => unreachable,
            }
        }
    } else if (commons.editorCapturingMouse(settings) and rl.isMouseButtonPressed(.left) and self.checkHover()) {
        return .selected;
    }
    return .none;
}

pub fn confirm(self: *Self) void {
    if (z.beginTable("##portal_cols", .{ .column = 2, .flags = .{
        .sizing = .stretch_same,
    } })) {
        defer z.endTable();

        z.tableSetupColumn("##col1", .{});
        z.tableSetupColumn("##col2", .{});

        // source p1
        z.tableNextRow(.{});
        _ = z.tableNextColumn();
        _ = z.inputFloat("s.p1.x", .{ .v = &self.source.p1.x });
        _ = z.tableNextColumn();
        _ = z.inputFloat("s.p2.x", .{ .v = &self.source.p1.y });

        // source p2
        z.tableNextRow(.{});
        _ = z.tableNextColumn();
        _ = z.inputFloat("s.p2.x", .{ .v = &self.source.p2.x });
        _ = z.tableNextColumn();
        _ = z.inputFloat("s.p2.y", .{ .v = &self.source.p2.y });

        z.newLine();

        // dest p1
        z.tableNextRow(.{});
        _ = z.tableNextColumn();
        _ = z.inputFloat("d.p1.x", .{ .v = &self.dest.p1.x });
        _ = z.tableNextColumn();
        _ = z.inputFloat("d.p1.y", .{ .v = &self.dest.p1.y });

        // dest p2
        z.tableNextRow(.{});
        _ = z.tableNextColumn();
        _ = z.inputFloat("d.p2.x", .{ .v = &self.dest.p2.x });
        _ = z.tableNextColumn();
        _ = z.inputFloat("d.p2.y", .{ .v = &self.dest.p2.y });
    }
}

pub fn edit(self: *Self) void {
    self.confirm();
}

pub fn hover(self: *Self) void {
    drawLineSpaced(self.source.p1, self.source.p2, palette.env.hover);
    drawLineSpaced(self.dest.p1, self.dest.p2, palette.env.hover);
}

pub fn drawLineSpaced(p1: rl.Vector2, p2: rl.Vector2, col: rl.Color) void {
    const thick = 3;
    const spacing = 3;
    const BA: rl.Vector2 = p2.subtract(p1);

    var n1: rl.Vector2 = rl.Vector2{ .x = -BA.y, .y = BA.x };
    n1 = n1.normalize().scale(spacing);
    var n2: rl.Vector2 = rl.Vector2{ .x = BA.y, .y = -BA.x };
    n2 = n2.normalize().scale(spacing);

    rl.drawLineEx(p1.add(n1), p2.add(n1), thick, col);
    rl.drawLineEx(p1.add(n2), p2.add(n2), thick, col);
}

pub fn draw(self: Self) void {
    if (self.point_count == 0) {
        rl.drawCircleV(self.pos, 6, palette.env.light_blue);
    } else if (self.point_count == 1) {
        drawLineSpaced(self.source.p1, self.pos, palette.env.light_blue);
    }
    if (self.point_count >= 2) {
        drawLineSpaced(self.source.p1, self.source.p2, palette.env.light_blue);
    }
    if (self.point_count == 2) {
        rl.drawCircleV(self.pos, 6, palette.env.orange);
    }
    if (self.point_count == 3) {
        drawLineSpaced(self.dest.p1, self.pos, palette.env.orange);
    } else if (self.point_count == 4) {
        drawLineSpaced(self.dest.p1, self.dest.p2, palette.env.orange);
    }
}
