///
///  IMNODES COLORS IN 0x[A G B R] !!!
///
const rl = @import("raylib");
const std = @import("std");
const imnodes = @import("imnodesez");
const z = @import("zgui");
const Spawner = @import("../environment/Spawner.zig");
const Area = @import("../environment/Area.zig");
const Agent = @import("../Agent.zig");
const Graph = @import("Graph.zig");
const commons = @import("../commons.zig");
const entity = @import("../environment/entity.zig");

fn setNextItemWidth(width: f32) void {
    const zoom: f32 = imnodes.getZoom(imnodes.ez.getState());
    z.setNextItemWidth(width * zoom);
}

pub const Node = struct {
    pub var next_id: i32 = 0;

    id: i32,
    name: [:0]const u8,
    pos: imnodes.Vec2 = .{ .x = 230, .y = 230 },
    selected: bool = false,

    kind: union(enum) {
        spawner: SpawnerNode,
        sink: SinkNode,
        area: AreaNode,
        fork: ForkNode,
    },

    //
    // AI CODE
    //
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
            inline else => |*n| n.draw(self),
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
                },
            },
        };
    }

    pub fn initFork() Node {
        return .{
            .id = Node.nextId(),
            .name = "Fork",
            .kind = .{
                .fork = .{},
            },
        };
    }

    pub fn initSink() Node {
        return .{
            .id = Node.nextId(),
            .name = "Sink",
            .kind = .{
                .sink = .{},
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
                },
            },
        };
    }
};

pub const Slot = struct {
    node: *Node,
    title: [*c]const u8,

    pub fn equals(self: Slot, other: Slot) bool {
        return self.node == other.node and
            self.title == other.title;
    }
};

pub const NewConnection = struct {
    input_node: ?*Node = null,
    input_slot_title: [*c]const u8 = "",
    output_node: ?*Node = null,
    output_slot_title: [*c]const u8 = "",
};

pub const Connection = struct {
    output_slot: Slot,
    input_slot: Slot,

    pub fn equals(self: Connection, other: Connection) bool {
        return self.output_slot.equals(other.output_slot) and
            self.input_slot.equals(other.input_slot);
    }
};

pub const SinkNode = struct {
    input_slots: [1]imnodes.ez.SlotInfo = .{
        .{ .title = "in", .kind = 1 },
    },
    output_slots: [0]imnodes.ez.SlotInfo = .{},

    pub fn draw(
        self: *SinkNode,
        parent: *Node,
    ) void {
        // const node_width: f32 = 140;
        imnodes.ez.pushStyleColor(.node_title_bar_bg, 0xff53367d);
        imnodes.ez.pushStyleColor(.node_title_bar_bg_hovered, 0xff7656a3);
        defer imnodes.ez.popStyleColor(2);

        // init node
        _ = imnodes.ez.beginNode(parent, parent.name, &parent.pos, &parent.selected);
        defer imnodes.ez.endNode();

        // input slots
        imnodes.ez.inputSlots(&self.input_slots);

        // output slots
        imnodes.ez.outputSlots(&self.output_slots);
    }
};

pub const SpawnerNode = struct {
    entities: *std.ArrayList(entity.Entity),
    spawner_index: i32 = 0,
    wait: i32,

    input_slots: [0]imnodes.ez.SlotInfo = .{},
    output_slots: [1]imnodes.ez.SlotInfo = .{
        .{ .title = "out", .kind = 1 },
    },

    last_spawn: f64 = 0,

    pub fn getSpawner(self: *SpawnerNode) *Spawner {
        return Node.getEnvironmentalObject(self, Spawner, self.spawner_index);
    }

    pub fn draw(
        self: *SpawnerNode,
        parent: *Node,
    ) void {
        // style setup
        const node_width: f32 = 160;
        imnodes.ez.pushStyleColor(.node_title_bar_bg, 0xFF3d913c);
        imnodes.ez.pushStyleColor(.node_title_bar_bg_hovered, 0xFF52b851);
        defer imnodes.ez.popStyleColor(2);

        // start the node
        _ = imnodes.ez.beginNode(parent, parent.name, &parent.pos, &parent.selected);
        defer imnodes.ez.endNode();

        // input slots
        imnodes.ez.inputSlots(&self.input_slots);

        // spawner selector
        var buf: [2 << 11]u8 = undefined;
        const names = entity.Entity.buildNameComboString(
            .spawner,
            self.entities,
            &buf,
        );
        setNextItemWidth(node_width);
        const changed = z.combo("##spawner", .{
            .current_item = &self.spawner_index,
            .items_separated_by_zeros = names,
        });
        if (changed) {
            // clicked on a different spawner instance
            std.debug.print("{}", .{self.spawner_index});
        }

        // wait input
        z.text("wait", .{});
        z.sameLine(.{});
        setNextItemWidth(node_width - z.calcTextSize("wait", .{})[0]);
        _ = z.inputInt("##wait", .{ .v = &self.wait });

        // output slots
        imnodes.ez.outputSlots(&self.output_slots);
    }

    pub fn update(
        self: *SpawnerNode,
        agents: *std.ArrayList(Agent),
        graph: *Graph,
        parent: *Node,
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
    wait_type: i32 = 0,

    input_slots: [1]imnodes.ez.SlotInfo = .{
        .{ .title = "in", .kind = -1 },
    },
    output_slots: [1]imnodes.ez.SlotInfo = .{
        .{ .title = "out", .kind = 1 },
    },

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

    pub fn getPos(self: *AreaNode) rl.Vector2 {
        return self.getArea().getPos();
    }

    pub fn getWaitTime(self: AreaNode) i32 {
        return switch (self.wait) {
            inline else => |kind| kind.get(),
        };
    }

    pub fn draw(
        self: *AreaNode,
        parent: *Node,
    ) void {
        const node_width: f32 = 120;

        imnodes.ez.pushStyleColor(.node_title_bar_bg, 0xff2978c2);
        imnodes.ez.pushStyleColor(.node_title_bar_bg_hovered, 0xff379bde);
        defer imnodes.ez.popStyleColor(2);

        // start the node
        _ = imnodes.ez.beginNode(parent, parent.name, &parent.pos, &parent.selected);
        defer imnodes.ez.endNode();

        // input slots
        imnodes.ez.inputSlots(&self.input_slots);

        // area selector
        {
            var buf: [2048]u8 = undefined;
            const names = entity.Entity.buildNameComboString(
                .area,
                self.entities,
                &buf,
            );
            setNextItemWidth(node_width);
            const changed = z.combo("##area", .{
                .current_item = &self.area_index,
                .items_separated_by_zeros = names,
            });
            if (changed) {
                // clicked on a different spawner instance
                std.debug.print("{}", .{self.area_index});
            }
        }

        // wait time options
        {
            setNextItemWidth(node_width);
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
        }

        // wait time inputs
        switch (self.wait) {
            .constant => |*constant| {
                setNextItemWidth(node_width);
                _ = z.inputInt("wait", .{ .v = &constant.wait });
            },
            .uniform => |*uniform| {
                setNextItemWidth(node_width);
                _ = z.inputInt("min", .{ .v = &uniform.min });
                setNextItemWidth(node_width);
                _ = z.inputInt("max", .{ .v = &uniform.max });
            },
            .normal => |*normal| {
                setNextItemWidth(node_width);
                _ = z.inputInt("mu", .{ .v = &normal.mu });
                setNextItemWidth(node_width);
                _ = z.inputInt("sigma", .{ .v = &normal.sigma });
            },
        }

        // output slots
        imnodes.ez.outputSlots(&self.output_slots);
    }

    pub fn update(_: AreaNode, _: *std.ArrayList(Agent)) !void {}
};

pub const ForkNode = struct {
    input_slots: [1]imnodes.ez.SlotInfo = .{
        .{ .title = "in", .kind = -1 },
    },
    output_slots: [4]imnodes.ez.SlotInfo = .{
        .{ .title = "outA", .kind = 1 },
        .{ .title = "outB", .kind = 1 },
        .{ .title = "outC", .kind = 1 },
        .{ .title = "outD", .kind = 1 },
    },
    values: [4]f32 = .{ 0.25, 0.25, 0.25, 0.25 },

    pub fn getOutputSlotTitle(self: ForkNode) [*c]const u8 {
        var sum: f32 = 0;
        for (self.values) |prob| {
            sum += prob;
        }

        // add up until larger than cumulative
        const r: f32 = commons.rand01() * sum;
        var cum: f64 = 0;
        var i: usize = 0;
        for (self.values) |value| {
            cum += value;
            if (r < cum) {
                return self.output_slots[i].title;
            }
            i += 1;
        }
        unreachable;
    }

    pub fn draw(
        self: *ForkNode,
        parent: *Node,
    ) void {
        // style setup
        const node_width: f32 = 70;
        imnodes.ez.pushStyleColor(.node_title_bar_bg, 0xFF636363);
        imnodes.ez.pushStyleColor(.node_title_bar_bg_hovered, 0xFFA9A9A9);
        defer imnodes.ez.popStyleColor(2);

        // init node
        _ = imnodes.ez.beginNode(parent, parent.name, &parent.pos, &parent.selected);
        defer imnodes.ez.endNode();

        // input slots
        imnodes.ez.inputSlots(&self.input_slots);

        // output ports
        for (0..self.values.len) |i| {
            // make sure to have unique id
            z.pushIntId(@intCast(i));
            defer z.popId();

            // float input
            setNextItemWidth(node_width);
            if (z.inputFloat("##", .{ .v = &self.values[i], .cfmt = "%.2f" })) {
                // input changed
            }
        }

        // output slots
        imnodes.ez.outputSlots(&self.output_slots);
    }
};
