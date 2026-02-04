const Self = @This();
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
