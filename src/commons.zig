const std = @import("std");
const rl = @import("raylib");
const SimData = @import("sim_data.zig");

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

pub fn roundMousePos(sim_data: SimData) rl.Vector2 {
    return .{
        .x = @floatFromInt(roundN(@intFromFloat(mousePos().x), sim_data.grid_size)),
        .y = @floatFromInt(roundN(@intFromFloat(mousePos().y), sim_data.grid_size)),
    };
}

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

pub fn rand01() f32 {
    return @as(f32, @floatFromInt(rl.getRandomValue(0, 1000000))) / 1_000_000.0;
}

pub fn getTimeMillis() f64 {
    return rl.getTime() * 1000;
}
