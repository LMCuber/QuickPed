const std = @import("std");
const rl = @import("raylib");
const SimData = @import("editor/SimData.zig");
const Settings = @import("Settings.zig");
const Environment = @import("environment/Environment.zig");
const entity = @import("environment/entity.zig");

pub const Line = struct {
    p1: rl.Vector2 = .{ .x = 0, .y = 0 },
    p2: rl.Vector2 = .{ .x = 0, .y = 0 },
};

pub var prng: std.Random.Xoshiro256 = std.Random.DefaultPrng.init(47);
pub var rng = prng.random();
pub const camera_default = rl.Camera2D{
    .target = .{ .x = 0, .y = 0 },
    .offset = .{ .x = 0, .y = 0 },
    .rotation = 0.0,
    .zoom = 1.0,
};
pub var camera = camera_default;

///
/// AI CODE
///
pub fn printUuid(id: [16]u8) void {
    // The format string '{s:0>2}' means:
    // x    -> hexadecimal
    // 0    -> pad with zeros
    // >    -> right align
    // 2    -> width of 2
    std.debug.print("{x:0>2}{x:0>2}{x:0>2}{x:0>2}-{x:0>2}{x:0>2}-{x:0>2}{x:0>2}-{x:0>2}{x:0>2}-{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}\n", .{
        id[0],  id[1],  id[2],  id[3],
        id[4],  id[5],  id[6],  id[7],
        id[8],  id[9],  id[10], id[11],
        id[12], id[13], id[14], id[15],
    });
}

pub fn editorCapturingMouse(settings: Settings) bool {
    const mouse: rl.Vector2 = rl.getMousePosition();
    return mouse.x <= @as(f32, @floatFromInt(settings.sim_width)) and
        mouse.y <= @as(f32, @floatFromInt((settings.height)));
}

pub fn roundN(value: i32, n: i32) i32 {
    return @divTrunc(value + @divTrunc(n, 2), n) * n;
}

pub fn existsAnyObject(env: *Environment, comptime kind: std.meta.Tag(entity.Entity.Kind)) bool {
    for (env.entities.items()) |*ent| {
        if (std.meta.activeTag(ent.kind) == kind) return true;
    }
    return false;
}

pub fn getRandomPointBetweenVectors(p1: rl.Vector2, p2: rl.Vector2) rl.Vector2 {
    const diff: rl.Vector2 = p2.subtract(p1);
    const p: f32 = rand01();
    return p1.add(diff.scale(p));
}

pub fn vecToLineSegment(pos: rl.Vector2, A: rl.Vector2, B: rl.Vector2) rl.Vector2 {
    const AB = B.subtract(A);
    const t: f32 = std.math.clamp(
        pos.subtract(A).dotProduct(AB) / AB.dotProduct(AB),
        0,
        1,
    );
    const C = A.add(AB.scale(t));
    const D = pos.subtract(C);
    return D;
}

///
/// gets the mouse position while taking scrolling into considersation.
/// basically the position of the map you are hovering above, relative to the topleft of the map
/// (inc. by target, since scrolling right = negative target, so actual location is more to the left)
///
pub fn mousePos() rl.Vector2 {
    return rl.getScreenToWorld2D(rl.getMousePosition(), camera);
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
pub fn readFile(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
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
    return @as(f32, @floatFromInt(rl.getRandomValue(0, 1_000_000))) / 1_000_000.0;
}

pub fn getTimeMillis() f64 {
    return rl.getTime() * 1000;
}

pub fn dupeCStr(allocator: std.mem.Allocator, cstr: [*c]const u8) ![:0]u8 {
    var len: usize = 0;
    while (cstr[len] != 0) : (len += 1) {}
    return try allocator.dupeZ(u8, cstr[0..len]);
}

pub fn tst() void {
    std.debug.print("{}\n", .{rl.getRandomValue(100, 999)});
}
