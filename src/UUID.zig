const Self = @This();
const std = @import("std");

bytes: [16]u8,

pub const UUIDSnapshot = struct {
    data: u128,
};

pub fn init() Self {
    // UUIDv4
    var bytes: [16]u8 = undefined;
    std.crypto.random.bytes(&bytes);
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    return .{ .bytes = bytes };
}

pub fn getSnapshot(self: Self) UUIDSnapshot {
    return .{ .data = self.toInt() };
}

pub fn fromSnapshot(data: u128) Self {
    var bytes: [16]u8 = undefined;
    std.mem.writeInt(u128, &bytes, data, .big);
    return .{ .bytes = bytes };
}

pub fn equals(self: Self, other: Self) bool {
    return std.mem.eql(u8, &self.bytes, &other.bytes);
}

pub fn toInt(self: Self) u128 {
    return std.mem.readInt(u128, &self.bytes, .big);
}

pub fn format(self: Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
    _ = fmt;
    _ = options;
    try writer.print("{x:0>2}...", .{self.bytes[0]});
}
