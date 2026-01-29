///
///  IMNODES COLORS IN 0x[A G B R] !!!
///
const rl = @import("raylib");
const std = @import("std");
const imnodes = @import("imnodes");
const z = @import("zgui");
const Spawner = @import("../environment/Spawner.zig");
const Area = @import("../environment/Area.zig");
const Agent = @import("../agent.zig");
const Graph = @import("Graph.zig");
const node = @import("node.zig");
const commons = @import("../commons.zig");
const entity = @import("../environment/entity.zig");

pub const Node = struct {
    pub var next_id: i32 = 0;

    id: i32,
    name: [:0]const u8,
    kind: union(enum) {
        spawner: SpawnerNode,
        sink: SinkNode,
        area: AreaNode,
    },

    ///
    /// AI CODE
    ///
    pub fn getEnvironmentalObject(n: anytype, comptime T: type, index: i32) *T {
        // n is *SpawnerNode, *AreaNode, etc.
        const uindex: u32 = @intCast(index);
        var i: usize = 0;
        for (n.entities.items) |*ent| {
            switch (ent.kind) {
                inline else => |*payload| {
                    if (T == @TypeOf(payload.*)) {
                        if (i == uindex) {
                            return payload;
                        }
                        i += 1;
                    }
                },
            }
        }
        unreachable;
    }

    pub fn nextId() i32 {
        next_id += 1;
        return next_id - 1;
    }

    pub fn draw(self: *Node) void {
        switch (self.kind) {
            inline else => |*n| n.draw(self.id),
        }
    }

    pub fn initSpawner(entities: *std.ArrayList(entity.Entity), wait: i32) Node {
        return .{
            .id = Node.nextId(),
            .name = "Spawner",
            .kind = .{
                .spawner = .{
                    .entities = entities,
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
            .name = "Sink",
            .kind = .{
                .sink = .{
                    .from = .{
                        .id = Port.nextId(),
                    },
                },
            },
        };
    }

    pub fn initArea(entities: *std.ArrayList(entity.Entity), wait: AreaNode.Wait) Node {
        return .{
            .id = Node.nextId(),
            .name = "Area",
            .kind = .{
                .area = .{
                    .entities = entities,
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

    pub fn draw(
        self: *SinkNode,
        id: i32,
    ) void {
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
        z.text("Sink", .{});
        imnodes.endNodeTitleBar();

        // input
        imnodes.beginInputAttribute(self.from.id);
        z.text("from", .{});
        imnodes.endInputAttribute();
    }

    pub fn update(_: SinkNode, _: *std.ArrayList(Agent)) !void {}
};

pub const SpawnerNode = struct {
    entities: *std.ArrayList(entity.Entity),
    spawner_index: i32 = 0,
    wait: i32,
    target: Port,

    last_spawn: f64 = 0,

    pub fn getSpawner(self: *SpawnerNode) *Spawner {
        return Node.getEnvironmentalObject(self, Spawner, self.spawner_index);
    }

    pub fn draw(
        self: *SpawnerNode,
        id: i32,
    ) void {
        // style setup
        const node_width: f32 = 140;
        imnodes.pushColorStyle(.ImNodesCol_TitleBar, 0xff40a140);
        imnodes.pushColorStyle(.ImNodesCol_TitleBarHovered, 0xff64CC61);
        imnodes.pushColorStyle(.ImNodesCol_TitleBarSelected, 0xff64CC61);
        defer imnodes.popColorStyle();
        defer imnodes.popColorStyle();
        defer imnodes.popColorStyle();

        // start the node
        imnodes.beginNode(id);
        defer imnodes.endNode();

        // title bar + spawner node selector
        {
            imnodes.beginNodeTitleBar();
            defer imnodes.endNodeTitleBar();

            var buf: [2048]u8 = undefined;
            const names = entity.Entity.buildNameComboString(
                .spawner,
                self.entities,
                &buf,
            );
            z.setNextItemWidth(node_width);
            const changed = z.combo("##spawner", .{
                .current_item = &self.spawner_index,
                .items_separated_by_zeros = names,
            });
            if (changed) {
                // clicked on a different spawner instance
                std.debug.print("{}", .{self.spawner_index});
            }
        }

        // wait input
        z.text("wait", .{});
        if (z.isItemHovered(.{})) {
            _ = z.beginTooltip();
            defer z.endTooltip();
            _ = z.text("arrival interval in ms", .{});
        }
        z.sameLine(.{});
        z.setNextItemWidth(node_width - z.calcTextSize("wait", .{})[0]);
        _ = z.inputInt("##wait", .{ .v = &self.wait });

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
            const pos: rl.Vector2 = self.getSpawner().randomSpawnPos();
            // const pos: rl.Vector2 = .{ .x = 0, .y = 0 };
            const a = Agent.init(pos, parent, graph);
            try agents.append(a);

            // reset last spawn
            self.last_spawn = commons.getTimeMillis();
        }
    }
};

pub const AreaNode = struct {
    entities: *std.ArrayList(entity.Entity),
    area_index: i32 = 0,
    wait: Wait,
    from: Port,
    target: Port,
    wait_type: i32 = 0,

    pub const Wait = union(enum) {
        constant: Constant,
        uniform: Uniform,
        normal: Normal,
    };
    pub const Constant = struct {
        wait: i32 = 1000,

        pub fn get(self: Constant) i32 {
            return self.wait;
        }
    };
    pub const Uniform = struct {
        min: i32 = 500,
        max: i32 = 1500,

        pub fn get(self: Uniform) i32 {
            return rl.getRandomValue(self.min, self.max);
        }
    };
    pub const Normal = struct {
        mu: i32 = 1000,
        sigma: i32 = 500,

        pub fn get(self: Normal) i32 {
            // TODO: gauss
            return self.mu;
        }
    };

    pub fn getArea(self: *AreaNode) *Area {
        return Node.getEnvironmentalObject(self, Area, self.area_index);
    }

    pub fn getCenter(self: *AreaNode) rl.Vector2 {
        return self.getArea().getCenter();
    }

    pub fn getWaitTime(self: AreaNode) i32 {
        return switch (self.wait) {
            inline else => |kind| kind.get(),
        };
    }

    pub fn draw(
        self: *AreaNode,
        id: i32,
    ) void {
        const node_width: f32 = 140;

        imnodes.pushColorStyle(.ImNodesCol_TitleBar, 0xff2978c2);
        imnodes.pushColorStyle(.ImNodesCol_TitleBarHovered, 0xff379bde);
        imnodes.pushColorStyle(.ImNodesCol_TitleBarSelected, 0xff379bde);

        defer imnodes.popColorStyle();
        defer imnodes.popColorStyle();
        defer imnodes.popColorStyle();

        imnodes.beginNode(id);
        defer imnodes.endNode();

        // title bar + area selector
        {
            imnodes.beginNodeTitleBar();
            defer imnodes.endNodeTitleBar();

            // select area
            var buf: [2048]u8 = undefined;
            const names = entity.Entity.buildNameComboString(
                .area,
                self.entities,
                &buf,
            );
            z.setNextItemWidth(node_width);
            z.setNextItemWidth(node_width);
            const changed = z.combo("##area", .{
                .current_item = &self.area_index,
                .items_separated_by_zeros = names,
            });
            if (changed) {
                // clicked on a different spawner instance
                std.debug.print("{}", .{self.area_index});
            }
        }

        // wait type
        z.setNextItemWidth(node_width);
        const changed = z.combo("##type", .{
            .current_item = &self.wait_type,
            .items_separated_by_zeros = "constant\x00uniform\x00normal\x00",
        });
        // if the combo box changes, change the base wait struct we operate on
        if (changed) {
            self.wait = switch (self.wait_type) {
                0 => .{ .constant = .{} },
                1 => .{ .uniform = .{} },
                2 => .{ .normal = .{} },
                else => unreachable,
            };
        }

        // now render the corresponding input boxes
        switch (self.wait) {
            .constant => |*constant| {
                z.setNextItemWidth(node_width);
                _ = z.inputInt("wait", .{ .v = &constant.wait });
            },
            .uniform => |*uniform| {
                z.setNextItemWidth(node_width);
                _ = z.inputInt("min", .{ .v = &uniform.min });
                z.setNextItemWidth(node_width);
                _ = z.inputInt("max", .{ .v = &uniform.max });
            },
            .normal => |*normal| {
                z.setNextItemWidth(node_width);
                _ = z.inputInt("mu", .{ .v = &normal.mu });
                z.setNextItemWidth(node_width);
                _ = z.inputInt("sigma", .{ .v = &normal.sigma });
            },
        }

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

    pub fn update(_: AreaNode, _: *std.ArrayList(Agent)) !void {}
};
