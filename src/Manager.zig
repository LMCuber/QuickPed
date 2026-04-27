const std = @import("std");
const UUID = @import("UUID.zig");

pub fn Manager(comptime T: type) type {
    return struct {
        const Self = @This();

        list: std.ArrayList(T),
        map: std.AutoHashMap(u128, usize), // maps from UUID to list index

        pub fn init(alloc: std.mem.Allocator) Self {
            return .{
                .list = std.ArrayList(T).init(alloc),
                .map = std.AutoHashMap(u128, usize).init(alloc),
            };
        }

        pub fn items(self: *Self) []T {
            return self.list.items;
        }

        pub fn len(self: *Self) usize {
            return self.list.items.len;
        }

        pub fn append(self: *Self, item: T) !void {
            try self.list.append(item);
            const index = self.list.items.len - 1;
            try self.map.put(item.uuid.toInt(), index);
        }

        pub fn deleteByUUID(self: *Self, uuid: UUID) !void {
            const removed_index = self.map.get(uuid.toInt());
            if (removed_index) |i| {
                try self.deleteByIndex(i);
            } else {
                std.debug.panic("UUID {} is not in the list", .{uuid});
            }
        }

        pub fn deleteByIndex(self: *Self, index: usize) !void {
            // remove old UUID -> index pointer
            const uuid = self.list.items[index].uuid;
            _ = self.map.remove(uuid.toInt());
            // swap remove last item with the removed_index
            _ = self.list.swapRemove(index);
            // update new index mapping of the just moved entity
            try self.map.put(self.list.items[index].uuid.toInt(), index);
        }

        pub fn clear(self: *Self) void {
            self.list.clearRetainingCapacity();
            self.map.clearRetainingCapacity();
        }

        pub fn getByUUID(self: *Self, uuid: UUID) *T {
            // *T so that the caller can edit the object T
            const index: ?usize = self.map.get(uuid.toInt());
            if (index) |i| {
                return &self.list.items[i];
            } else {
                unreachable;
            }
        }

        pub fn scan(self: *Self, other: *T) ?UUID {
            for (self.items()) |*item| {
                if (item.equals(other)) {
                    return item.uuid;
                }
            }
            return null;
        }

        pub fn deinit(self: *Self) void {
            self.list.deinit();
            self.map.deinit();
        }
    };
}

// const std = @import("std");

// pub fn Manager(comptime T: type, comptime size: usize) type {
//     return struct {
//         const Self = @This();

//         pub const Slot = struct {
//             value: T,
//             alive: bool = false,
//             gen: usize = 0,
//         };

//         items: [size]Slot,
//         free_indices: [size]usize,
//         free_count: usize = size,

//         pub fn init() Self {
//             var items: [size]Slot = undefined;
//             for (&items) |*slot| {
//                 slot.alive = false;
//             }

//             var free_indices: [size]usize = undefined;
//             for (0..size) |i| {
//                 free_indices[i] = size - 1 - i;
//             }

//             return .{
//                 .items = items,
//                 .free_indices = free_indices,
//             };
//         }

//         pub fn getLen(self: *Self) usize {
//             return self.free_indices.len - self.free_count;
//         }

//         pub fn createItem(self: *Self, value: T) usize {
//             var free_index: usize = undefined;

//             // if free count > 0, pop from free list
//             if (self.free_count > 0) {
//                 free_index = self.free_indices[self.free_count - 1];
//                 const entity_slot: Slot = .{
//                     .value = value,
//                     .alive = true,
//                 };
//                 self.items[free_index] = entity_slot;
//                 self.free_count -= 1;
//             } else {
//                 unreachable;
//                 // free_index = 0;
//             }

//             return free_index;
//         }

//         pub fn getNextIndex(self: *Self) usize {
//             return self.free_indices[self.free_count - 1];
//         }

//         pub fn get(self: *Self, index: usize) *T {
//             if (index < 0 or index >= self.getLen()) {
//                 std.debug.panic("index {} out of bounds (len: {}) ", .{ index, self.getLen() });
//             }
//             if (!self.items[index].alive) {
//                 std.debug.panic("index {} is unalive", .{index});
//             }
//             return &self.items[index].value;
//         }

//         pub fn delete(self: *Self, index: usize) void {
//             // disable the item in the slots
//             self.items[index].alive = false;

//             // add the index to be available
//             if (self.free_count >= self.free_indices.len) unreachable;
//             self.free_indices[self.free_count] = index;
//             self.free_count += 1;
//         }

//         pub fn clear(self: *Self) void {
//             // make all slots unused again
//             for (&self.items) |*slot| {
//                 slot.alive = false;
//                 slot.gen = 0;
//             }

//             // reset free indices
//             for (0..size) |i| {
//                 self.free_indices[i] = size - 1 - i;
//             }
//         }

//         pub fn scan(self: *Self, other_ptr: *T) ?usize {
//             // returns the index of a pointer to an other item
//             for (&self.items, 0..) |*slot, i| {
//                 if (slot.value.equals(other_ptr)) {
//                     return i;
//                 }
//             }
//             return null;
//         }

//         pub fn cleanup(self: *Self) void {
//             for (&self.items, 0..) |*slot, i| {
//                 if (!slot.alive) continue;
//                 if (slot.value.marked) {
//                     self.delete(i);
//                 }
//             }
//         }
//     };
// }
