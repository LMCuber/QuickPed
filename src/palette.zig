const rl = @import("raylib");

pub const env = struct {
    pub const black = rl.Color.init(10, 10, 10, 255);
    pub const light_gray = rl.Color.init(150, 150, 150, 255);
    pub const white = rl.Color.init(255, 240, 230, 255);
    pub const white_t = rl.Color.init(255, 240, 230, 180);
    pub const dark_blue = rl.Color.init(12, 11, 35, 255);
    pub const navy = rl.Color.init(16, 41, 65, 255);
    pub const navy_t = rl.Color.init(16, 41, 65, 180);
    pub const light_blue = rl.Color.init(34, 152, 219, 255);
    pub const red = rl.Color.init(184, 60, 70, 255);
    pub const green = rl.Color.init(116, 185, 100, 255);
    pub const dark_green = rl.Color.init(16, 145, 29, 255);
    pub const orange = rl.Color.init(235, 150, 38, 255);
    pub const orange_t = rl.Color.init(235, 150, 38, 180);
    pub const light_orange = rl.Color.init(209, 173, 100, 255);
    pub const yellow = rl.Color.init(238, 220, 130, 255);
    pub const hover = rl.Color.init(255, 182, 193, 255);
};

pub const ui = struct {
    pub const green: u32 = rgbaToU32(71, 135, 120, 255);
};

pub fn rgbaToU32(comptime r: u32, comptime g: u32, comptime b: u32, comptime a: u32) u32 {
    return (a << 24) | (b << 16) | (g << 8) | r;
}

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
