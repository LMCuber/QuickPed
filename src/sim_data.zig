const Self = @This();
const z = @import("zgui");
const rl = @import("raylib");

bg_color: [4]f32 = [_]f32{ 0.0, 0.0, 0.1, 1.0 },

pub fn init() Self {
    return .{};
}

pub fn show_stats(self: *Self, camera: *rl.Camera2D, camera_default: rl.Camera2D) void {
    if (z.collapsingHeader("Simulation", .{ .default_open = true })) {
        _ = z.colorEdit3("bg", .{ .col = @ptrCast(&self.bg_color) });
        if (z.button("Recenter", .{})) {
            camera.target = camera_default.target;
            camera.offset = camera_default.offset;
            camera.rotation = camera_default.rotation;
            camera.zoom = camera_default.zoom;
        }
    }
}
