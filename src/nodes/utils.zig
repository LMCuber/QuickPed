const rl = @import("raylib");
const commons = @import("../commons.zig");

pub const Wait = union(enum) {
    pub const zeroSepItems: [:0]const u8 = "constant\x00uniform\x00normal\x00";

    pub const Constant = struct {
        wait: i32 = 1000,

        pub fn get(self: Constant) i32 {
            return self.wait;
        }
    };
    pub const Uniform = struct {
        min: i32 = 500,
        max: i32 = 1500,

        pub fn get(self: Uniform) i32 {
            return rl.getRandomValue(self.min, self.max);
        }
    };
    pub const Normal = struct {
        mu: i32 = 1000,
        sigma: i32 = 500,

        pub fn get(self: Normal) i32 {
            return @intFromFloat(@as(f32, @floatFromInt(self.mu)) + @as(f32, @floatFromInt(self.sigma)) * commons.rng.floatNorm(f32));
        }
    };

    constant: Constant,
    uniform: Uniform,
    normal: Normal,
};
