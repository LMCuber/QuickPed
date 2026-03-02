const std = @import("std");

pub fn Manager(comptime T: type, comptime size: usize) type {
    return struct {
        const Self = @This();

        pub const Slot = struct {
            value: T,
            alive: bool = false,
            gen: usize = 0,
        };

        items: [size]Slot,
        free_indices: [size]usize,
        free_count: usize = size,

        pub fn init() Self {
            var items: [size]Slot = undefined;
            for (&items) |*slot| {
                slot.alive = false;
            }

            var free_indices: [size]usize = undefined;
            for (0..size) |i| {
                free_indices[i] = size - 1 - i;
            }

            return .{
                .items = items,
                .free_indices = free_indices,
            };
        }

        pub fn createItem(self: *Self, value: T) usize {
            var free_index: usize = undefined;

            // if free count > 0, pop from free list
            if (self.free_count > 0) {
                free_index = self.free_indices[self.free_count - 1];
                const entity_slot: Slot = .{
                    .value = value,
                    .alive = true,
                };
                self.items[free_index] = entity_slot;
                self.free_count -= 1;
            } else {
                free_index = 0;
            }

            return free_index;
        }

        pub fn getNextIndex(self: *Self) usize {
            return self.free_indices[self.free_count - 1];
        }

        pub fn getItem(self: *Self, index: usize) *T {
            return &self.items[index].value;
        }

        pub fn deleteItem(self: *Self, index: usize) void {
            // disable the item in the slots
            self.items[index].alive = false;

            // add the index to be available
            if (self.free_count >= self.free_indices.len) unreachable;
            self.free_indices[self.free_count] = index;
            self.free_count += 1;
        }

        pub fn clear(self: *Self) void {
            // make all slots unused again
            for (&self.items) |*slot| {
                slot.alive = false;
                slot.gen = 0;
            }

            // reset free indices
            for (0..size) |i| {
                self.free_indices[i] = size - 1 - i;
            }
        }

        pub fn scan(self: *Self, other_ptr: *T) ?usize {
            for (&self.items, 0..) |*slot, i| {
                if (slot.value.equals(other_ptr)) {
                    return i;
                }
            }
            return null;
        }
    };
}
