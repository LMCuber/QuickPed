const std = @import("std");
const rl = @import("raylib");
const SimData = @import("editor/SimData.zig");
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

pub fn mousePos() rl.Vector2 {
    return rl.getScreenToWorld2D(rl.getMousePosition(), camera);
}

pub fn roundMousePos(sim_data: SimData) rl.Vector2 {
    return roundVec2(mousePos(), sim_data);
}

pub fn roundVec2(vec2: rl.Vector2, sim_data: SimData) rl.Vector2 {
    return .init(
        @floatFromInt(roundN(@intFromFloat(vec2.x), sim_data.grid_size)),
        @floatFromInt(roundN(@intFromFloat(vec2.y), sim_data.grid_size)),
    );
}

pub fn roundN(value: i32, n: i32) i32 {
    return @divTrunc(value + @divTrunc(n, 2), n) * n;
}

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

//
// AI CODE
//
pub fn readFile(alloc: std.mem.Allocator, io: std.Io, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(io, path, alloc, .unlimited) catch |err| switch (err) {
        error.FileNotFound => {
            const file = try std.Io.Dir.cwd().createFile(io, path, .{});
            file.close(io);
            return try alloc.dupe(u8, "");
        },
        else => err,
    };
}

/// Formats an object to JSON and writes it to `path`
pub fn writeFile(alloc: std.mem.Allocator, io: std.Io, obj: anytype, path: []const u8) !void {
    var allocating = std.Io.Writer.Allocating.init(alloc);
    defer allocating.deinit();

    const formatter = std.json.fmt(obj, .{ .whitespace = .indent_4 });
    try formatter.format(&allocating.writer);

    // create file it it doesn't exist
    const file = try std.Io.Dir.cwd().createFile(io, path, .{ .truncate = true });
    defer file.close(io);

    try file.writeStreamingAll(io, allocating.written());
}

pub fn dupeCStr(allocator: std.mem.Allocator, cstr: [*c]const u8) ![:0]u8 {
    var len: usize = 0;
    while (cstr[len] != 0) : (len += 1) {}
    return try allocator.dupeZ(u8, cstr[0..len]);
}

pub fn tst() void {
    std.debug.print("{}\n", .{rl.getRandomValue(100, 999)});
}
