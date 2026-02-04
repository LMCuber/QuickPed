const std = @import("std");
const rl = @import("raylib");
const SimData = @import("editor/SimData.zig");

pub const PI: f32 = 4.0 * std.math.atan(@as(f32, @floatCast(1.0)));
pub var camera: *rl.Camera2D = undefined;

pub fn roundN(value: i32, n: i32) i32 {
    return @divTrunc(value + @divTrunc(n, 2), n) * n;
}

pub fn mousePos() rl.Vector2 {
    return .{
        .x = rl.getMousePosition().x + camera.target.x,
        .y = rl.getMousePosition().y + camera.target.y,
    };
}

pub fn roundMousePos(sim_data: SimData) rl.Vector2 {
    return .{
        .x = @floatFromInt(roundN(@intFromFloat(mousePos().x), sim_data.grid_size)),
        .y = @floatFromInt(roundN(@intFromFloat(mousePos().y), sim_data.grid_size)),
    };
}

//
// AI CODE
//
fn arrSum(comptime T: type, comptime arr: []const T) T {
    var s: T = 0;
    comptime for (arr) |x| {
        s += x;
    };
    return s;
}

//
// AI CODE
//
pub fn readFile(
    allocator: std.mem.Allocator,
    path: []const u8,
) ![]u8 {
    const file = std.fs.cwd().openFile(path, .{}) catch |err| {
        if (err == error.FileNotFound) {
            // create empty file
            const new_file = try std.fs.cwd().createFile(path, .{});
            new_file.close();
            return try allocator.dupe(u8, "");
        }
        return err;
    };
    defer file.close();
    return try file.readToEndAlloc(
        allocator,
        std.math.maxInt(usize),
    );
}

//
// AI CODE
//
pub fn rand01() f32 {
    return @as(f32, @floatFromInt(rl.getRandomValue(0, 1_000_000))) / 1_000_000.0;
}

pub fn getTimeMillis() f64 {
    return rl.getTime() * 1000;
}
