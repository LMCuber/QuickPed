const rl = @import("raylib");
const commons = @import("commons.zig");

pub const navy: rl.Color = .{ .r = 15, .g = 42, .b = 65, .a = 255 };
pub const navy_t: rl.Color = .{ .r = 15, .g = 42, .b = 65, .a = 140 };
pub const light_blue: rl.Color = .{ .r = 173, .g = 216, .b = 230, .a = 255 };
pub const light_gray: rl.Color = .{ .r = 160, .g = 160, .b = 160, .a = 255 };
pub const white: rl.Color = .{ .r = 204, .g = 204, .b = 204, .a = 255 };
pub const white_t: rl.Color = .{ .r = 204, .g = 204, .b = 204, .a = 120 };
pub const black: rl.Color = .{ .r = 0, .g = 0, .b = 0, .a = 255 };
pub const orange: rl.Color = .{ .r = 255, .g = 144, .b = 0, .a = 255 };
pub const green: rl.Color = .{ .r = 0, .g = 190, .b = 0, .a = 255 };
pub const green_t: rl.Color = .{ .r = 0, .g = 245, .b = 0, .a = 120 };
pub const palette = [_][]const u8{
    "#73464c",
    "#ab5675",
    "#ee6a7c",
    "#ffa7a5",
    "#ffe07e",
    "#ffe7d6",
    "#72dcbb",
    "#34acba",
};

// pub const e_palette = [_][]const u8{

// }

const Palette = enum(u8) {
    hazel = 0,
    clay = 1,
    pink = 2,
    salmon = 3,
    lemon = 4,
    cream = 5,
    teal = 6,
    foam = 7,
};

pub fn fromPalette(p: Palette) []const u8 {
    return palette[@intFromEnum(p)];
}

pub fn getAgentColor() rl.Color {
    const index: i32 = rl.getRandomValue(0, palette.len - 1);
    const hex = palette[@as(usize, @intCast(index))];
    return hexToColor(hex);
}

pub fn arrToColor(col: [4]f32) rl.Color {
    return .{
        .r = @intFromFloat(col[0] * 255),
        .g = @intFromFloat(col[1] * 255),
        .b = @intFromFloat(col[2] * 255),
        .a = @intFromFloat(col[3] * 255),
    };
}

fn hexCharToInt(c: u8) u8 {
    if (c >= '0' and c <= '9') return c - '0';
    if (c >= 'A' and c <= 'F') return c - 'A' + 10;
    if (c >= 'a' and c <= 'f') return c - 'a' + 10;
    @panic("Invalid hex character");
}

fn hexPairToU8(hex: []const u8) u8 {
    return (hexCharToInt(hex[0]) << 4) | hexCharToInt(hex[1]);
}

pub fn hexToColor(hex: []const u8) rl.Color {
    if (hex.len != 7 or hex[0] != '#') {
        @panic("Expected hex string like '#RRGGBB'");
    }

    return rl.Color{
        .r = hexPairToU8(hex[1..3]),
        .g = hexPairToU8(hex[3..5]),
        .b = hexPairToU8(hex[5..7]),
        .a = 255,
    };
}
