const rl = @import("raylib");

pub const env = struct {
    pub const black: rl.Color = .{ .r = 54, .g = 49, .b = 61, .a = 255 }; // #494252
    pub const gray: rl.Color = .{ .r = 138, .g = 127, .b = 133, .a = 255 }; // #8a7f85
    pub const white: rl.Color = .{ .r = 199, .g = 182, .b = 141, .a = 255 }; // #c7b68d
    pub const orange: rl.Color = .{ .r = 199, .g = 146, .b = 117, .a = 255 }; // #c79275
    pub const purple: rl.Color = .{ .r = 150, .g = 96, .b = 127, .a = 255 }; // #96607f
    pub const navy: rl.Color = .{ .r = 85, .g = 82, .b = 122, .a = 255 }; // #55527a
    pub const blue: rl.Color = .{ .r = 98, .g = 132, .b = 161, .a = 255 }; // #6284a1
    pub const green: rl.Color = .{ .r = 124, .g = 158, .b = 100, .a = 255 }; // #7c9e64
};
