const Self = @This();
const std = @import("std");

bytes: [16]u8,

pub const UUIDSnapshot = struct {
    data: u128,
};

pub fn init(rand: std.Random) Self {
    // UUIDv4
    var uuid = Self{ .bytes = undefined };
    rand.bytes(&uuid.bytes);
    uuid.bytes[6] = (uuid.bytes[6] & 0x0F) | 0x40;
    uuid.bytes[8] = (uuid.bytes[8] & 0x3F) | 0x80;
    return uuid;
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
