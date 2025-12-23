const Self = @This();
const rl = @import("raylib");
const std = @import("std");

width: i32 = 0,
height: i32 = 0,
fps_cap: i32 = 60,
sim_width: i32 = 0,
sim_height: i32 = 0,
tab_width: i32 = 0,
tab_height: i32 = 0,

pub fn init() Self {
    var ret: Self = .{
        .sim_width = 800,
        .sim_height = 800,
    };
    ret.tab_width = @intFromFloat(@as(f32, @floatFromInt(ret.sim_width)) * 0.3);
    ret.width = ret.sim_width + ret.tab_width;
    ret.height = ret.sim_height;
    return ret;
}
