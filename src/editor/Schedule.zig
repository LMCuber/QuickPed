const Self = @This();

const std = @import("std");
const z = @import("zgui");
const commons = @import("../commons.zig");

pub const Time = struct {
    hour: i32,
    min: i32,
    pub fn init(hour: i32, min: i32) @This() {
        if (hour < 0 or hour >= 24 or min < 0 or min >= 60) unreachable;
        return .{ .hour = hour, .min = min };
    }

    pub fn compareFn(_: void, a: Time, b: Time) bool {
        // primary sort (hour)
        if (a.hour != b.hour) {
            return a.hour > b.hour;
        }
        // secondary condition (min)
        return a.min > b.min;
    }

    pub fn render(self: *@This(), i: i32) !bool {
        // init
        var delete: bool = false;
        const w = 120;
        z.setNextItemWidth(w);

        // input hour
        var buf: [64]u8 = undefined;
        const hour_label = try std.fmt.bufPrintZ(&buf, "##schedule-start-time-input-int-hour{d}", .{i});
        var changed = z.inputInt(hour_label, .{ .v = &self.hour });
        if (changed) {
            self.hour = @max(0, self.hour);
            self.hour = @min(23, self.hour);
        }

        // delimiter
        z.sameLine(.{});
        z.text(":", .{});
        z.sameLine(.{});
        z.setNextItemWidth(w);

        // input minute
        const min_label = try std.fmt.bufPrintZ(&buf, "##schedule-start-time-input-int-min{d}", .{i});
        changed = z.inputInt(min_label, .{ .v = &self.min });
        if (changed) {
            self.min = @max(0, self.min);
            self.min = @min(59, self.min);
        }

        // delete button
        if (i != -1) {
            z.sameLine(.{});
            const delete_label = try std.fmt.bufPrintZ(&buf, "-##schedule-start-time-delete{d}", .{i});
            if (z.button(delete_label, .{ .w = 80 })) {
                delete = true;
            }
        }
        return delete;
    }
};

const Snapshot = struct {
    start_time: Time,
    times: []Time,
};

start_time: Time = Time.init(9, 0),
times: std.ArrayList(Time),

pub fn init(alloc: std.mem.Allocator) Self {
    return .{
        .times = std.ArrayList(Time).init(alloc),
    };
}

pub fn getSnapshot(self: Self) Snapshot {
    return .{
        .start_time = self.start_time,
        .times = self.times.items,
    };
}

pub fn saveToFile(self: Self, alloc: std.mem.Allocator, path: []const u8) !void {
    var buf = std.ArrayList(u8).init(alloc);
    defer buf.deinit();

    try std.json.stringify(self.getSnapshot(), .{
        .whitespace = .indent_2,
    }, buf.writer());

    // create file it it doesn't exist
    const file = try std.fs.cwd().createFile(path, .{ .truncate = true });
    defer file.close();
    try file.writeAll(buf.items);
}

pub fn loadFromFile(alloc: std.mem.Allocator, path: []const u8) !Self {
    const json = try commons.readFile(alloc, path);
    defer alloc.free(json);

    // if there is nothing in the file, return
    if (json.len == 0) return Self.init(alloc);

    // get parsed AgentData struct
    const parsed = try std.json.parseFromSlice(
        Snapshot,
        alloc,
        json,
        .{},
    );
    defer parsed.deinit();

    // construct schedule from snapshot
    var self = Self.init(alloc);
    var times = std.ArrayList(Time).init(alloc);
    for (parsed.value.times) |time| {
        try times.append(time);
    }
    self.times = times;
    return self;
}

pub fn deinit(self: *Self) void {
    self.times.deinit();
}

pub fn sortTimes(self: *Self) !void {
    std.mem.sort(Time, self.times.items, {}, Time.compareFn);
}

pub fn updateUi(self: *Self) !void {
    if (z.collapsingHeader("Schedule", .{ .default_open = false })) {
        // start hour
        z.text("start time:", .{});
        _ = try self.start_time.render(-1);

        // all current times
        z.newLine();
        var i = self.times.items.len;
        while (i > 0) {
            i -= 1;
            if (try self.times.items[i].render(@intCast(i))) {
                _ = self.times.orderedRemove(i);
            }
        }

        // handy dandy buttons
        if (self.times.items.len > 0) z.newLine();
        if (z.button("+", .{ .w = 80 })) {
            if (self.times.items.len == 0) {
                try self.times.insert(0, Time.init(10, 0));
            } else {
                const last_item = self.times.items[self.times.items.len - 1];
                try self.times.insert(0, last_item);
            }
        }
        z.sameLine(.{});
        if (z.button("sort", .{ .w = 80 })) {
            try self.sortTimes();
        }
        z.newLine();
    }
}
