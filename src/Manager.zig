const std = @import("std");
const UUID = @import("UUID.zig");

pub fn Manager(comptime T: type) type {
    return struct {
        const Self = @This();

        list: std.ArrayList(T),
        map: std.AutoHashMap(u128, usize), // maps from UUID to list index

        pub fn init(alloc: std.mem.Allocator) Self {
            return .{
                .list = .empty,
                .map = .init(alloc),
            };
        }

        pub fn items(self: *Self) []T {
            return self.list.items;
        }

        pub fn len(self: *Self) usize {
            return self.list.items.len;
        }

        pub fn append(self: *Self, alloc: std.mem.Allocator, item: T) !void {
            try self.list.append(alloc, item);
            const index = self.list.items.len - 1;
            try self.map.put(item.uuid.toInt(), index);
        }

        pub fn deleteByUUID(self: *Self, uuid: UUID) !void {
            const removed_index = self.map.get(uuid.toInt());
            if (removed_index) |i| {
                try self.deleteByIndex(i);
            } else {
                std.debug.print("UUID {} is not in the list\n", .{uuid.toInt()});
                std.debug.print("list of UUIDS:\n", .{});
                for (self.items()) |item| {
                    std.debug.print("{}\n", .{item.uuid.toInt()});
                }
                std.debug.panic("error\n", .{});
            }
        }

        pub fn deleteByIndex(self: *Self, index: usize) !void {
            // remove old UUID -> index pointer
            const uuid = self.list.items[index].uuid;
            _ = self.map.remove(uuid.toInt());

            // swap remove last item with the removed_index
            _ = self.list.swapRemove(index);

            // update new index mapping of the just moved entity
            // but not if we removed the last entry
            if (index < self.list.items.len) {
                try self.map.put(self.list.items[index].uuid.toInt(), index);
            }
        }

        pub fn uuidToIndex(self: *Self, uuid: UUID) ?usize {
            for (self.items(), 0..) |*item, i| {
                if (item.uuid.equals(uuid)) {
                    return i;
                }
            }
            return null;
        }

        pub fn clear(self: *Self) void {
            self.list.clearRetainingCapacity();
            self.map.clearRetainingCapacity();
        }

        pub fn getByUUID(self: *Self, uuid: UUID) *T {
            // *T so that the caller can edit the object T
            return &self.list.items[self.map.get(uuid.toInt()).?];
        }

        pub fn getByIndex(self: *Self, index: usize) *T {
            return &self.list.items[index];
        }

        pub fn scan(self: *Self, other: *T) ?UUID {
            for (self.items()) |*item| if (item.equals(other))
                return item.uuid;

            return null;
        }

        pub fn deinit(self: *Self, alloc: std.mem.Allocator) void {
            self.list.deinit(alloc);
            self.map.deinit();
        }
    };
}
