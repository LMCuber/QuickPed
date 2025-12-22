const Self = @This();
const rl = @import("raylib");
const color = @import("color.zig");

rect: rl.Rectangle,

pub fn init(rect: rl.Rectangle) Self {
    return .{
        .rect = rect,
    };
}

pub fn update(_: *Self) void {
    return;
}

pub fn draw(self: Self) void {
    rl.drawRectangleRec(self.rect, color.LIGHT_GRAY);
    rl.drawRectangleLinesEx(self.rect, 2, color.WHITE);
}
