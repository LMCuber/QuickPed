const Self = @This();
const std = @import("std");
const rl = @import("raylib");

times: std.ArrayList(f64),

pub fn init(arr: std.ArrayList(f64)) Self {
    return .{ .times = arr };
}

pub fn deinit(self: *Self) void {
    self.times.deinit();
}

pub fn begin(self: *Self) !void {
    try self.times.append(rl.getTime());
}

pub fn end(self: *Self) !void {
    const last: f64 = self.times.pop();
    const diff: f64 = (rl.getTime() - last) * 1000; // ms
    try std.io.getStdOut().writer().print("{d:.3} ms\n", .{diff});
}
