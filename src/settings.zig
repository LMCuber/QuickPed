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
        .width = rl.getMonitorWidth(rl.getCurrentMonitor()),
        .height = rl.getMonitorHeight(rl.getCurrentMonitor()) - 100,
    };
    ret.tab_width = @intFromFloat(@as(f32, @floatFromInt(ret.width)) * 0.24);
    ret.sim_width = ret.width - ret.tab_width;
    ret.sim_height = ret.height;
    return ret;
}
