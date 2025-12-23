const Self = @This();
const rl = @import("raylib");
const color = @import("color.zig");

pos: rl.Vector2,

pub fn init(pos: rl.Vector2) Self {
    return .{
        .pos = pos,
    };
}

pub fn draw(self: Self) void {
    rl.drawCircleV(self.pos, color.GREEN);
}
