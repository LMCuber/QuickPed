const std = @import("std");
const Order = std.math.Order;
const assert = std.debug.assert;
const rl = @import("raylib");
const Pathfinding = @import("Pathfinding.zig");
const Node = Pathfinding.Node;

pub const Context = struct {
    g_scores: std.ArrayList(f32),
    h_scores: std.ArrayList(f32),
    prev_nodes: std.ArrayList(?usize),  // either index to previous or not used in traversal (null)

    pub fn init(alloc: std.mem.Allocator, size: usize) !@This() {
        var ret: @This() = .{
            .g_scores = .empty,
            .h_scores = .empty,
            .prev_nodes = .empty
        };
        try ret.g_scores.appendNTimes(alloc, std.math.inf(f32), size);
        try ret.h_scores.appendNTimes(alloc, std.math.inf(f32), size);
        try ret.prev_nodes.appendNTimes(alloc, null, size);
        return ret;
    }

    pub fn deinit(self: *@This(), alloc: std.mem.Allocator) void {
        self.g_scores.deinit(alloc);
        self.h_scores.deinit(alloc);
        self.prev_nodes.deinit(alloc);
    }
};

// comparator for the "f" value of nodes (f = g + h)
fn lessThan(ctx: *Context, a: usize, b: usize) Order {
    const a_g: f32 = ctx.g_scores.items[a];
    const a_h: f32 = ctx.h_scores.items[a];
    const b_g: f32 = ctx.g_scores.items[b];
    const b_h: f32 = ctx.h_scores.items[b];

    const a_f = a_g + a_h;
    const b_f = b_g + b_h;
    return std.math.order(a_f, b_f);
}

pub fn find(
    alloc: std.mem.Allocator,
    path: *std.ArrayList(rl.Vector2),
    nodes: []Node,
    extra_nodes: *Pathfinding.ExtraNodes,
) !void {
    // A* algorithm: basically Dijkstra, but with an added heuristic h for given node
    // (Dijkstra's is a special case of A* where h = 0)
    // f = g + h

    // 0. All nodes start with an infinitely high f (std.math.inf) inside a priority queue,
    //    except for the source node (has a cost of 0)
    //    + make sure to calculate their h (this h stays constant throughout)
    // 1. Get the node with the currently lowest f (g + h) value from the priority queue

    // context
    var ctx: Context = try .init(alloc, nodes.len);
    defer ctx.deinit(alloc);

    var pq = std.PriorityQueue(usize, *Context, lessThan).initContext(&ctx);
    defer pq.deinit(alloc);

    // adj_src and adj_target are the nodes of the triangles where the actual
    // source and target are within.
    const adj_src_node_index = extra_nodes.source.neighbors.items[0];
    ctx.g_scores.items[adj_src_node_index] = 0;
    try pq.push(alloc, adj_src_node_index);

    const adj_target_node_index = extra_nodes.target.neighbors.items[0];
    for (nodes, 0..) |node, i| {
        // set all heuristic scores to their correct values
        ctx.h_scores.items[i] = rl.math.vector2Distance(node.pos, nodes[adj_target_node_index].pos);
    }

    // keep popping the current lowest "f" distance
    while (pq.pop()) |node_index| {
        // if the popped node is the goal node, stop.
        if (node_index == adj_target_node_index) break;

        // update the data of their neighbors
        const node: Node = nodes[node_index];
        for (node.neighbors.items) |nei_index| {
            const link_cost = rl.math.vector2Distance(nodes[node_index].pos, nodes[nei_index].pos);
            const cur_f = ctx.g_scores.items[nei_index] + ctx.h_scores.items[nei_index];
            const new_f = ctx.g_scores.items[node_index] + link_cost + ctx.h_scores.items[nei_index];
            if (new_f < cur_f) {
                // update cost (heuristic stays the same)
                ctx.g_scores.items[nei_index] = ctx.g_scores.items[node_index] + link_cost;
                // push neighbors to pq
                try pq.push(alloc, nei_index);
                // save the path connection at relaxation (here)
                ctx.prev_nodes.items[nei_index] = node_index;
            }
        }
        //std.debug.print("{} | {} | {} | {}\n", .{ node_index, ctx.g_scores.items[node_index], ctx.h_scores.items[node_index],
            // ctx.g_scores.items[node_index] + ctx.h_scores.items[node_index]});
    }

    // backtrack to find correct path and populate the given list
    var current_node = adj_target_node_index;
    while (true) {
        try path.append(alloc, nodes[current_node].pos);        
        if (ctx.prev_nodes.items[current_node]) |current_index| {
            // prev exists
            current_node = current_index;
        } else {
            // there is no prev for this node.
            break;
        }
    }

    // actual target
    try path.append(alloc, extra_nodes.target.pos);
}