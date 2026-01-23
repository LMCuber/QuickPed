///
///  IMNODES COLORS IN 0x[A G B R] !!!
///
const rl = @import("raylib");
const std = @import("std");
const imnodes = @import("imnodes");
const z = @import("zgui");
const Spawner = @import("../environment/spawner.zig");
const Area = @import("../environment/area.zig");
const Agent = @import("../agent.zig");
const Graph = @import("graph.zig");
const node = @import("node.zig");
const commons = @import("../commons.zig");

pub const Node = struct {
    pub var next_id: i32 = 0;

    id: i32,
    name: [:0]const u8,
    kind: union(enum) {
        spawner: SpawnerNode,
        sink: SinkNode,
        area: AreaNode,
    },

    pub fn nextId() i32 {
        next_id += 1;
        return next_id - 1;
    }

    pub fn draw(self: *Node) void {
        switch (self.kind) {
            inline else => |*n| n.draw(self.id, self.name),
        }
    }

    pub fn initSpawner(spawner: *Spawner, wait: i32) Node {
        return .{
            .id = Node.nextId(),
            .name = "SpawnerNode",
            .kind = .{
                .spawner = .{
                    .spawner = spawner,
                    .wait = wait,
                    .target = .{
                        .id = Port.nextId(),
                    },
                },
            },
        };
    }

    pub fn initSink() Node {
        return .{
            .id = Node.nextId(),
            .name = "SinkNode",
            .kind = .{
                .sink = .{
                    .from = .{
                        .id = Port.nextId(),
                    },
                },
            },
        };
    }

    pub fn initArea(area: *Area, wait: i32) Node {
        return .{
            .id = Node.nextId(),
            .name = "AreaNode",
            .kind = .{
                .area = .{
                    .area = area,
                    .wait = wait,
                    .from = .{
                        .id = Port.nextId(),
                    },
                    .target = .{
                        .id = Port.nextId(),
                    },
                },
            },
        };
    }
};

pub const Port = struct {
    pub var next_id: i32 = 0;

    id: i32,

    pub fn nextId() i32 {
        next_id += 1;
        return next_id - 1;
    }
};

pub const Link = struct {
    pub var next_id: i32 = 0;

    id: i32,
    left_attr_id: i32,
    right_attr_id: i32,

    pub fn nextId() i32 {
        next_id += 1;
        return next_id - 1;
    }
};

pub const SinkNode = struct {
    from: Port,

    pub fn draw(self: *SinkNode, id: i32, name: [:0]const u8) void {
        // const node_width: f32 = 140;
        imnodes.pushColorStyle(.ImNodesCol_TitleBar, 0xff53367d);
        imnodes.pushColorStyle(.ImNodesCol_TitleBarHovered, 0xff7656a3);
        imnodes.pushColorStyle(.ImNodesCol_TitleBarSelected, 0xff7656a3);
        defer imnodes.popColorStyle();
        defer imnodes.popColorStyle();
        defer imnodes.popColorStyle();

        imnodes.beginNode(id);
        defer imnodes.endNode();

        imnodes.beginNodeTitleBar();
        z.text("{s}", .{name});
        imnodes.endNodeTitleBar();

        // input
        imnodes.beginInputAttribute(self.from.id);
        z.text("from", .{});
        imnodes.endInputAttribute();
    }

    pub fn update(_: SinkNode, _: *std.ArrayList(Agent)) !void {}
};

pub const SpawnerNode = struct {
    spawner: *Spawner,
    wait: i32,
    target: Port,

    last_spawn: f64 = 0,

    pub fn draw(self: *SpawnerNode, id: i32, name: [:0]const u8) void {
        const node_width: f32 = 140;

        imnodes.pushColorStyle(.ImNodesCol_TitleBar, 0xff40a140);
        imnodes.pushColorStyle(.ImNodesCol_TitleBarHovered, 0xff64CC61);
        imnodes.pushColorStyle(.ImNodesCol_TitleBarSelected, 0xff64CC61);
        defer imnodes.popColorStyle();
        defer imnodes.popColorStyle();
        defer imnodes.popColorStyle();

        imnodes.beginNode(id);
        defer imnodes.endNode();

        imnodes.beginNodeTitleBar();
        z.text("{s}", .{name});
        imnodes.endNodeTitleBar();

        // wait input
        z.text("wait", .{});
        if (z.isItemHovered(.{})) {
            _ = z.beginTooltip();
            defer z.endTooltip();
            _ = z.text("arrival interval in ms", .{});
        }
        z.sameLine(.{});
        z.setNextItemWidth(node_width - z.calcTextSize("wait", .{})[0]);
        _ = z.inputInt("##", .{ .v = &self.wait });

        // target output
        imnodes.beginOutputAttribute(self.target.id);
        z.indent(.{ .indent_w = node_width - z.calcTextSize("target", .{})[0] });
        z.text("target", .{});
        imnodes.endOutputAttribute();
    }

    pub fn update(
        self: *SpawnerNode,
        agents: *std.ArrayList(Agent),
        graph: *Graph,
        parent: *node.Node,
    ) !void {
        const time: f64 = commons.getTimeMillis();
        if (time - self.last_spawn >= @as(f64, @floatFromInt(self.wait))) {
            // spawn new agent
            const pos: rl.Vector2 = self.spawner.randomSpawnPos();
            const a = Agent.init(pos, parent, graph);
            try agents.append(a);

            // reset last spawn
            self.last_spawn = commons.getTimeMillis();
        }
    }
};

pub const AreaNode = struct {
    area: *Area,
    wait: i32,
    from: Port,
    target: Port,

    pub fn draw(self: *AreaNode, id: i32, name: [:0]const u8) void {
        const node_width: f32 = 140;

        imnodes.pushColorStyle(.ImNodesCol_TitleBar, 0xff2978c2);
        imnodes.pushColorStyle(.ImNodesCol_TitleBarHovered, 0xff379bde);
        imnodes.pushColorStyle(.ImNodesCol_TitleBarSelected, 0xff379bde);
        defer imnodes.popColorStyle();
        defer imnodes.popColorStyle();
        defer imnodes.popColorStyle();

        imnodes.beginNode(id);
        defer imnodes.endNode();

        imnodes.beginNodeTitleBar();
        z.text("{s}", .{name});
        imnodes.endNodeTitleBar();

        // wait input
        z.text("wait", .{});
        if (z.isItemHovered(.{})) {
            _ = z.beginTooltip();
            defer z.endTooltip();
            _ = z.text("arrival interval in ms", .{});
        }
        z.sameLine(.{});
        z.setNextItemWidth(node_width - z.calcTextSize("wait", .{})[0]);
        _ = z.inputInt("##", .{ .v = &self.wait });

        // input
        // input
        imnodes.beginInputAttribute(self.from.id);
        z.text("from", .{});
        imnodes.endInputAttribute();

        // target output
        imnodes.beginOutputAttribute(self.target.id);
        z.indent(.{ .indent_w = node_width - z.calcTextSize("target", .{})[0] });
        z.text("target", .{});
        imnodes.endOutputAttribute();
    }

    pub fn getCenter(self: AreaNode) rl.Vector2 {
        return self.area.getCenter();
    }

    pub fn update(_: AreaNode, _: *std.ArrayList(Agent)) !void {}
};
