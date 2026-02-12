const Self = @This();
const std = @import("std");
const z = @import("zgui");
const implot = @import("implot");
const Agent = @import("../Agent.zig");
const commons = @import("../commons.zig");
const rl = @import("raylib");

render_checks: struct {
    graph: bool = true,
    heatmap: bool = false,
} = .{},

// graph
x_width: f64 = 10,
x_data: std.ArrayList(f64),
num_agents: std.ArrayList(f64),
num_waiting_agents: std.ArrayList(f64),
update_interval: i32 = 100,
last_update: f64 = 0,

// heatmap
heatmap: []f32,
n_cols: i32,
n_rows: i32,

pub fn init(alloc: std.mem.Allocator, buffer: []f32, cols: i32, rows: i32) Self {
    return .{
        .x_data = std.ArrayList(f64).init(alloc),
        .num_agents = std.ArrayList(f64).init(alloc),
        .num_waiting_agents = std.ArrayList(f64).init(alloc),
        .heatmap = buffer,
        .n_cols = cols,
        .n_rows = rows,
    };
}

pub fn deinit(self: *Self) void {
    self.x_data.deinit();
    self.num_agents.deinit();
    self.num_waiting_agents.deinit();
}

///
/// half-AI CODE
///
fn maxItemBetweenInterval(
    comptime T: type,
    slice: []const T,
    min_index: usize,
    max_index: usize,
) T {
    if (slice.len == 0) {
        return @as(T, 1);
    }
    var max: T = slice[0];
    for (min_index..max_index) |index| {
        if (slice[index] > max) {
            max = slice[index];
        }
    }
    return if (max == 0) (@as(T, 1)) else (max);
}

fn getNumWaitingAgents(agents: *std.ArrayList(Agent)) f64 {
    var count: f64 = 0;
    for (agents.items) |agent| {
        if (agent.waiting) {
            count += 1.0;
        }
    }
    return count;
}

pub fn render(self: *Self, agents: *std.ArrayList(Agent)) !void {
    if (z.collapsingHeader("Statistics", .{ .default_open = false })) {
        _ = z.checkbox("Graph", .{ .v = &self.render_checks.graph });
        z.sameLine(.{});
        _ = z.checkbox("Heatmap", .{ .v = &self.render_checks.heatmap });

        // graph
        if (self.render_checks.graph) {
            if (implot.beginPlot("Agents", -1.0, 0.0, implot.Flags.none)) {
                defer implot.endPlot();

                const time: f64 = commons.getTimeMillis();
                if (time - self.last_update >= @as(f64, @floatFromInt(self.update_interval))) {
                    // make a new point pair
                    try self.x_data.append(rl.getTime());
                    try self.num_agents.append(@floatFromInt(agents.items.len));
                    try self.num_waiting_agents.append(getNumWaitingAgents(agents));

                    // reset last update
                    self.last_update = commons.getTimeMillis();
                }
                // calculate x-interval
                const x_count: f64 = rl.getTime();
                var x_min: f64 = 0.0;
                var x_max: f64 = self.x_width;
                if (x_count > self.x_width) {
                    x_min = x_count - self.x_width;
                    x_max = x_count;
                }

                // calculate y-interval
                const y_max: f64 = maxItemBetweenInterval(
                    f64,
                    self.num_agents.items,
                    self.num_agents.items.len -| 50,
                    self.num_agents.items.len,
                ) * 2;

                // setup graph axes
                implot.setupAxisLimits(.Y1, 0.0, y_max, .Always);
                implot.setupAxisLimits(.X1, x_min, x_max, .Always);

                // all agents
                implot.plotLine(f64, "Agents", self.x_data.items, self.num_agents.items, .{});

                // all waiting agents
                implot.plotLine(f64, "Waiting agents", self.x_data.items, self.num_waiting_agents.items, .{});

                // TEXTUAL INFO
                // X
                z.text("X = ", .{});
                if (z.isItemHovered(.{})) {
                    _ = z.beginTooltip();
                    defer z.endTooltip();
                    z.text("waiting/total ratio", .{});
                }
                z.sameLine(.{});
                if (self.num_waiting_agents.getLast() > self.num_agents.getLast()) unreachable;
                const ratio = if (self.num_agents.getLast() == 0) 0 else self.num_waiting_agents.getLast() / self.num_agents.getLast() * 100;
                z.text("{d:.0}%", .{ratio});
            }
        }

        // heatmap
        if (self.render_checks.heatmap) {
            if (implot.beginPlot("Agents", -1.0, 0.0, implot.Flags.none)) {
                defer implot.endPlot();

                // reset graph axes
                implot.setupAxisLimits(.Y1, 0.0, 1.0, .Always);
                implot.setupAxisLimits(.X1, 0.0, 1.0, .Always);

                implot.pushColormap(.Spectral);
                defer implot.popColormap(1);

                implot.plotHeatmap(f32, "heatmap", self.heatmap, @intCast(self.n_rows), @intCast(self.n_cols), 0, 0, null, 0, 0, 1, 1, .{});
            }
        }
    }
}

pub fn add_to_heatmap(self: *Self, x_pos: i32, y_pos: i32) void {
    self.heatmap[@intCast(y_pos * self.n_cols + x_pos)] += 1;
    // for (0..@intCast(self.n_cols)) |x| {
    //     for (0..@intCast(self.n_rows)) |y| {
    //         self.heatmap[y * @as(usize, @intCast(self.n_rows)) + x] = @sqrt(@as(f32, @floatFromInt(x * x + y * y)));
    //         self.heatmap[y * @as(usize, @intCast(self.n_rows)) + x] = @as(f32, @floatFromInt(x + y));
    //     }
    // }
}
