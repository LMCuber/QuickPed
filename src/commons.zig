const std = @import("std");
const rl = @import("raylib");

pub var camera: *rl.Camera2D = undefined;

pub fn intToStr() []u8 {
    return "";
}

pub fn roundN(value: i32, n: i32) i32 {
    return @divTrunc(value + @divTrunc(n, 2), n) * n;
}

pub fn mousePos() rl.Vector2 {
    return .{
        .x = rl.getMousePosition().x + camera.target.x,
        .y = rl.getMousePosition().y + camera.target.y,
    };
}
