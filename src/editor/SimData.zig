const Self = @This();
const std = @import("std");
const commons = @import("../commons.zig");
const palette = @import("../palette.zig");
const z = @import("zgui");
const rl = @import("raylib");

environment_width: i32 = 0,
environment_height: i32 = 0,
grid_size: i32 = 2 << 4,
scale: i32 = 32, // this many pixels is 1 meter in simulation
paused: bool = false,

pub fn init() Self {
    return .{};
}

pub fn render(self: *Self) void {
    const start: rl.Vector2 = .{ .x = 32, .y = 32 };
    const end: rl.Vector2 = start.add(.{ .x = @floatFromInt(self.scale), .y = 0 });
    const o: rl.Vector2 = .{ .x = 0, .y = 4 };
    const thick: i32 = 2;
    rl.drawLineEx(start, end, thick, palette.env.white);
    rl.drawLineEx(start.subtract(o), start.add(o), thick, palette.env.white);
    rl.drawLineEx(end.subtract(o), end.add(o), thick, palette.env.white);
    rl.drawText("1m", @intFromFloat(start.add(end.subtract(start).scale(0.5)).x), start.y + 12, 18, palette.env.white);
}

pub fn update_ui(self: *Self, camera: *rl.Camera2D, camera_default: rl.Camera2D) void {
    if (z.collapsingHeader("Simulation", .{ .default_open = false })) {
        _ = z.inputInt("width", .{ .v = &self.environment_width });
        _ = z.inputInt("height", .{ .v = &self.environment_height });

        if (z.button("recenter", .{})) {
            camera.target = camera_default.target;
            camera.offset = camera_default.offset;
            camera.rotation = camera_default.rotation;
            camera.zoom = camera_default.zoom;
        }
        z.sameLine(.{});
        _ = z.checkbox("paused", .{ .v = &self.paused });
        // _ = z.sliderInt("grid size", .{ .v = &self.grid_size, .min = 10, .max = 100 });]
        z.setNextItemWidth(120);
        z.sameLine(.{});
        _ = z.inputInt("scale", .{ .v = &self.scale });
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
