const rl = @import("raylib");

pub const env = struct {
    pub const black = rl.Color{ .r = 10, .g = 10, .b = 10, .a = 255 };
    pub const light_gray = rl.Color{ .r = 150, .g = 150, .b = 150, .a = 255 };
    pub const white = rl.Color{ .r = 255, .g = 240, .b = 230, .a = 255 };
    pub const white_t = rl.Color{ .r = 255, .g = 240, .b = 230, .a = 180 };
    pub const dark_blue = rl.Color{ .r = 12, .g = 11, .b = 35, .a = 255 };
    pub const navy = rl.Color{ .r = 16, .g = 41, .b = 65, .a = 255 };
    pub const navy_t = rl.Color{ .r = 16, .g = 41, .b = 65, .a = 180 };
    pub const light_blue = rl.Color{ .r = 34, .g = 152, .b = 219, .a = 255 };
    pub const red = rl.Color{ .r = 184, .g = 60, .b = 70, .a = 255 };
    pub const green = rl.Color{ .r = 116, .g = 185, .b = 100, .a = 255 };
    pub const dark_green = rl.Color{ .r = 16, .g = 145, .b = 29, .a = 255 };
    pub const orange = rl.Color{ .r = 235, .g = 150, .b = 38, .a = 255 };
    pub const orange_t = rl.Color{ .r = 235, .g = 150, .b = 38, .a = 180 };
    pub const light_orange = rl.Color{ .r = 235, .g = 191, .b = 102, .a = 255 };
};

pub fn iden(col: rl.Color) u32 {
    return colorToU32(col);
}

pub fn lighten(col: rl.Color) u32 {
    return colorToU32(colorMult(col, 1.2));
}

pub fn darken(col: rl.Color) u32 {
    return colorToU32(colorMult(col, 0.9));
}

//
// AI CODE
//
pub fn colorToU32(col: rl.Color) u32 {
    return (@as(u32, col.a) << 24) |
        (@as(u32, col.b) << 16) |
        (@as(u32, col.g) << 8) |
        (@as(u32, col.r));
}

pub fn colorMult(color: rl.Color, factor: f32) rl.Color {
    return .{
        .r = clampChannel(@as(f32, @floatFromInt(color.r)) * factor),
        .g = clampChannel(@as(f32, @floatFromInt(color.g)) * factor),
        .b = clampChannel(@as(f32, @floatFromInt(color.b)) * factor),
        .a = color.a,
    };
}

fn clampChannel(value: f32) u8 {
    if (value < 0) return 0;
    if (value > 255) return 255;
    return @intFromFloat(value);
}
