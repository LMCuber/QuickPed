const Self = @This();
const std = @import("std");
const commons = @import("../commons.zig");
const z = @import("zgui");
const rl = @import("raylib");

grid_size: i32 = 2 << 4,
paused: bool = false,

pub fn init() Self {
    return .{};
}

pub fn render(self: *Self, camera: *rl.Camera2D, camera_default: rl.Camera2D) void {
    if (z.collapsingHeader("Simulation", .{ .default_open = false })) {
        if (z.button("recenter", .{})) {
            camera.target = camera_default.target;
            camera.offset = camera_default.offset;
            camera.rotation = camera_default.rotation;
            camera.zoom = camera_default.zoom;
        }
        z.sameLine(.{});
        _ = z.checkbox("paused", .{ .v = &self.paused });
        // _ = z.sliderInt("grid size", .{ .v = &self.grid_size, .min = 10, .max = 100 });
        z.newLine();
    }
}

pub fn loadFromFile(alloc: std.mem.Allocator, path: []const u8) !Self {
    const json = try commons.readFile(alloc, path);
    defer alloc.free(json);

    // if there is nothing in the file, return
    if (json.len == 0) {
        return Self.init();
    }

    // get parsed AgentData struct
    const parsed = try std.json.parseFromSlice(
        Self,
        alloc,
        json,
        .{},
    );
    defer parsed.deinit();
    return parsed.value;
}

pub fn saveToFile(self: Self, alloc: std.mem.Allocator, path: []const u8) !void {
    var buf = std.ArrayList(u8).init(alloc);
    defer buf.deinit();

    try std.json.stringify(self, .{
        .whitespace = .indent_2,
    }, buf.writer());

    // create file it it doesn't exist
    const file = try std.fs.cwd().createFile(path, .{ .truncate = true });
    defer file.close();
    try file.writeAll(buf.items);
}
