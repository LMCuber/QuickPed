const std = @import("std");
const Order = std.math.Order;
const assert = std.debug.assert;
const rl = @import("raylib");
const Pathfinding = @import("Pathfinding.zig");
const delaunay = @import("delaunay.zig");

// plain old A*:
pub fn find(
    comptime Node: type,
    alloc: std.mem.Allocator,
    start_node: Node,
    end_node: Node,
    paths: *std.ArrayList(Node),
    user_ctx: anytype,
) !void {
    const Ctx: type = @TypeOf(user_ctx);

    comptime {
        // heuristic accepts 2 arguments: source and target
        if (!@hasDecl(Ctx, "neighbors")) @compileError(@typeName(Ctx) ++ " must implement neighbors(node: Node) []const Node");
        if (!@hasDecl(Ctx, "cost")) @compileError(@typeName(Ctx) ++ " must implement cost(a: Node, b: Node) f32");
        if (!@hasDecl(Ctx, "heuristic")) @compileError(@typeName(Ctx) ++ " must implement heuristic(node: Node, goal: Node) f32");
    }

    const SearchState = struct {
        g_scores: std.AutoHashMap(Node, f32),
        prev_nodes: std.AutoHashMap(Node, Node), // either index to previous or not used in traversal (null)
        end_node: Node,
        user_ctx: Ctx,

        pub fn init(
            _alloc: std.mem.Allocator,
            goal: Node,
            ctx: Ctx,
        ) !@This() {
            return .{
                .g_scores = .init(_alloc),
                .prev_nodes = .init(_alloc),
                .user_ctx = ctx,
                .end_node = goal,
            };
        }

        pub fn deinit(self: *@This()) void {
            self.g_scores.deinit();
            self.prev_nodes.deinit();
        }

        pub fn fScore(self: @This(), node: Node) f32 {
            const g = self.g_scores.get(node) orelse std.math.inf(f32);
            return g + self.user_ctx.heuristic(node, self.end_node);
        }

        pub fn lessThan(ctx: *@This(), a: Node, b: Node) Order {
            return std.math.order(ctx.fScore(a), ctx.fScore(b));
        }
    };

    var state: SearchState = try .init(alloc, end_node, user_ctx);
    defer state.deinit();

    var pq = std.PriorityQueue(
        Node,
        *SearchState,
        SearchState.lessThan,
    ).initContext(&state);
    defer pq.deinit(alloc);

    // adj_src and adj_target are the nodes of the triangles where the actual
    // source and target are within.
    try state.g_scores.put(start_node, 0);
    try pq.push(alloc, start_node);

    // keep popping the current lowest "f" distance
    while (pq.pop()) |node| {
        // if the popped node is the goal node, stop.
        if (node == end_node) break;

        // update the data of their neighbors
        // const node: Node = ctx.
        for (user_ctx.neighbors(node)) |nei_node| {
            // initialize the heuristic values for the discovered nodes
            const link_cost = user_ctx.cost(node, nei_node);
            const cur_f = state.fScore(nei_node);
            const new_f = (state.g_scores.get(node) orelse std.math.inf(f32)) + link_cost + state.user_ctx.heuristic(nei_node, end_node);
            if (new_f < cur_f) {
                // since we found something < infinity, the goal of
                // master node must be in the hashmap
                assert(state.g_scores.get(node) != null);

                // update cost of neighbor (heuristic stays the same)
                try state.g_scores.put(nei_node, state.g_scores.get(node).? + link_cost);
                // push neighbors to pq
                try pq.push(alloc, nei_node);
                // save the path connection at relaxation (here)
                try state.prev_nodes.put(nei_node, node);
            }
        }
    }

    // backtrack to find correct path and populate the given list
    var current_node = end_node;
    while (true) {
        try paths.append(alloc, current_node);
        if (state.prev_nodes.get(current_node)) |prev_node| {
            current_node = prev_node;
        } else {
            // there is no prev for this node.
            break;
        }
    }
    std.mem.reverse(Node, paths.items);
}
