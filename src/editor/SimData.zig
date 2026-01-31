const Self = @This();
const z = @import("zgui");
const rl = @import("raylib");

bg_color: [4]f32 = [_]f32{ 0.05, 0.05, 0.14, 1.0 },
grid_size: i32 = 16,
paused: bool = false,

pub fn init() Self {
    return .{};
}

pub fn render(self: *Self, camera: *rl.Camera2D, camera_default: rl.Camera2D) void {
    if (z.collapsingHeader("Simulation", .{ .default_open = false })) {
        _ = z.colorEdit3("bg", .{ .col = @ptrCast(&self.bg_color) });
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
