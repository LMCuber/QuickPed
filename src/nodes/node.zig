///
///  IMNODES COLORS IN 0x[A G B R] !!!
///
const rl = @import("raylib");
const std = @import("std");
const imnodes = @import("imnodesez");
const z = @import("zgui");
const utils = @import("utils.zig");
const Spawner = @import("../environment/Spawner.zig");
const Area = @import("../environment/Area.zig");
const Queue = @import("../environment/Queue.zig");
const Agent = @import("../Agent.zig");
const Graph = @import("Graph.zig");
const commons = @import("../commons.zig");
const palette = @import("../palette.zig");
const entity = @import("../environment/entity.zig");
const Environment = @import("../environment/Environment.zig");
const Manager = @import("../Manager.zig").Manager;

fn setNextItemWidth(width: f32) void {
    const zoom: f32 = imnodes.getZoom(imnodes.ez.getState());
    z.setNextItemWidth(width * zoom);
}

pub const NodeSnapshot = struct {
    pos: imnodes.Vec2 = .{ .x = 230, .y = 230 },
    kind: Kind,

    const Kind = union(enum) {
        spawner: SpawnerNodeSnapshot,
        sink: SinkNodeSnapshot,
        area: AreaNodeSnapshot,
        fork: ForkNodeSnapshot,
        queue: QueueNodeSnapshot,
        queue_fork: QueueForkNodeSnapshot,
    };
};

pub const Node = struct {
    pos: imnodes.Vec2 = .{ .x = 230, .y = 230 },
    selected: bool = false,
    kind: Kind,

    pub const Kind = union(enum) {
        spawner: SpawnerNode,
        sink: SinkNode,
        area: AreaNode,
        fork: ForkNode,
        queue: QueueNode,
        queue_fork: QueueForkNode,
    };

    pub const NodeState = enum {
        none,
        selected,
    };

    pub fn equals(self: *Node, other: *Node) bool {
        return self == other;
    }

    pub fn getSnapshot(self: Node) NodeSnapshot {
        return .{
            .pos = self.pos,
            .kind = switch (self.kind) {
                inline else => |k, tag| @unionInit(
                    NodeSnapshot.Kind,
                    @tagName(tag),
                    k.getSnapshot(),
                ),
            },
        };
    }

    pub fn fromSnapshot(
        snap: NodeSnapshot,
        env: *Environment,
    ) Node {
        return .{
            .pos = snap.pos,
            .kind = switch (snap.kind) {
                .sink => |sk| .{ .sink = SinkNode.fromSnapshot(sk) },
                .spawner => |sk| .{ .spawner = SpawnerNode.fromSnapshot(sk, env) },
                .area => |sk| .{ .area = AreaNode.fromSnapshot(sk, env) },
                .fork => |sk| .{ .fork = ForkNode.fromSnapshot(sk) },
                .queue => |qk| .{ .queue = QueueNode.fromSnapshot(qk, env) },
                .queue_fork => |qf| .{ .queue_fork = QueueForkNode.fromSnapshot(qf) },
            },
        };
    }

    pub fn update(self: *Node) NodeState {
        // check if wants to delete
        if (self.selected) {
            return .selected;
        }
        return .none;
    }

    pub fn draw(self: *Node) void {
        switch (self.kind) {
            inline else => |*n| n.draw(self),
        }
    }

    pub fn initSpawner(env: *Environment, wait: i32) Node {
        return .{
            .kind = .{
                .spawner = .{
                    .env = env,
                    .wait = wait,
                },
            },
        };
    }

    pub fn initArea(env: *Environment, wait: utils.Wait) Node {
        return .{
            .kind = .{
                .area = .{
                    .env = env,
                    .wait = wait,
                },
            },
        };
    }

    pub fn initQueue(env: *Environment, wait: utils.Wait) Node {
        return .{
            .kind = .{
                .queue = .{
                    .env = env,
                    .wait = wait,
                },
            },
        };
    }

    pub fn initQueueFork() Node {
        return .{
            .kind = .{
                .queue_fork = .{ .selection = .random },
            },
        };
    }

    pub fn initFork() Node {
        return .{
            .kind = .{
                .fork = .{},
            },
        };
    }

    pub fn initSink() Node {
        return .{
            .kind = .{
                .sink = .{},
            },
        };
    }
};

// slot is identified by composite key: (node_ptr, title)
// since title weakly identifies inside a node
pub const Slot = struct {
    node_id: usize,
    title: [:0]const u8,

    pub fn init(alloc: std.mem.Allocator, node_id: usize, title: [*c]const u8) !Slot {
        return .{
            .node_id = node_id,
            .title = try commons.dupeCStr(alloc, title),
        };
    }

    pub fn deinit(self: *Slot, alloc: std.mem.Allocator) void {
        alloc.free(self.title);
    }

    pub fn equals(self: Slot, other: Slot) bool {
        return self.node_id == other.node_id and
            std.mem.eql(u8, self.title, other.title);
    }

    pub fn getSnapshot(self: Slot) SlotSnapshot {
        return .{
            .node_id = self.node_id,
            .title = self.title,
        };
    }

    pub fn fromSnapshot(alloc: std.mem.Allocator, snap: SlotSnapshot) !Slot {
        // find the node with the saved ID to get its pointer
        return .{
            .node_id = snap.node_id,
            .title = try alloc.dupeZ(u8, snap.title),
        };
    }
};

pub const SlotSnapshot = struct {
    node_id: usize, // node id instead of runtime pointer
    title: []const u8,
};

pub const NewConnection = struct {
    // optional, because we want it to be null at creation.
    // the underlying imnodes API will assign a node pointer (*anyopaque) to it later
    input_node: ?*Node = null,
    input_slot_title: [*c]const u8 = "",
    output_node: ?*Node = null,
    output_slot_title: [*c]const u8 = "",
};

pub const ConnectionSnapshot = struct {
    output_slot: SlotSnapshot,
    input_slot: SlotSnapshot,
};

pub const Connection = struct {
    output_slot: Slot,
    input_slot: Slot,

    pub fn init(output_slot: Slot, input_slot: Slot) Connection {
        return .{
            .output_slot = output_slot,
            .input_slot = input_slot,
        };
    }

    pub fn deinit(self: *Connection, alloc: std.mem.Allocator) void {
        self.output_slot.deinit(alloc);
        self.input_slot.deinit(alloc);
    }

    pub fn equals(self: Connection, other: Connection) bool {
        return self.output_slot.equals(other.output_slot) and
            self.input_slot.equals(other.input_slot);
    }

    pub fn getSnapshot(self: Connection) ConnectionSnapshot {
        return .{
            .output_slot = self.output_slot.getSnapshot(),
            .input_slot = self.input_slot.getSnapshot(),
        };
    }

    pub fn fromSnapshot(alloc: std.mem.Allocator, snap: ConnectionSnapshot) !Connection {
        return .{
            .output_slot = try Slot.fromSnapshot(alloc, snap.output_slot),
            .input_slot = try Slot.fromSnapshot(alloc, snap.input_slot),
        };
    }
};

pub const SinkNodeSnapshot = struct {};

pub const SinkNode = struct {
    input_slots: [1]imnodes.ez.SlotInfo = .{
        .{ .title = "in", .kind = 1 },
    },
    output_slots: [0]imnodes.ez.SlotInfo = .{},

    pub fn getSnapshot(_: SinkNode) SinkNodeSnapshot {
        return .{};
    }

    pub fn fromSnapshot(_: SinkNodeSnapshot) SinkNode {
        return .{};
    }

    pub fn draw(
        self: *SinkNode,
        parent: *Node,
    ) void {
        // const node_width: f32 = 140;
        imnodes.ez.pushStyleColor(.node_title_bar_bg, palette.iden(palette.env.red));
        imnodes.ez.pushStyleColor(.node_title_bar_bg_hovered, palette.lighten(palette.env.red));
        defer imnodes.ez.popStyleColor(2);

        // init node
        _ = imnodes.ez.beginNode(parent, "Sink", &parent.pos, &parent.selected);
        defer imnodes.ez.endNode();

        // input slots
        imnodes.ez.inputSlots(&self.input_slots);

        // output slots
        imnodes.ez.outputSlots(&self.output_slots);
    }
};

pub const SpawnerNodeSnapshot = struct {
    spawner_index: i32,
    wait: i32,
};

pub const SpawnerNode = struct {
    env: *Environment,
    // later converted to usize; needs to be i32 for imgui combo selector
    spawner_index: i32 = 0,
    wait: i32,

    input_slots: [0]imnodes.ez.SlotInfo = .{},
    output_slots: [1]imnodes.ez.SlotInfo = .{
        .{ .title = "out", .kind = 1 },
    },

    last_spawn: f64 = 0,

    pub fn getSnapshot(self: SpawnerNode) SpawnerNodeSnapshot {
        return .{
            .spawner_index = self.spawner_index,
            .wait = self.wait,
        };
    }

    pub fn fromSnapshot(snap: SpawnerNodeSnapshot, env: *Environment) SpawnerNode {
        return .{
            .env = env,
            .spawner_index = snap.spawner_index,
            .wait = snap.wait,
        };
    }

    pub fn getSpawner(self: *SpawnerNode) *Spawner {
        return &self.env.entities.getItem(self.env.spawners.items[@intCast(self.spawner_index)]).kind.spawner;
    }

    pub fn draw(
        self: *SpawnerNode,
        parent: *Node,
    ) void {
        // style setup
        const node_width: f32 = 160;
        imnodes.ez.pushStyleColor(.node_title_bar_bg, palette.iden(palette.env.green));
        imnodes.ez.pushStyleColor(.node_title_bar_bg_hovered, palette.lighten(palette.env.green));
        defer imnodes.ez.popStyleColor(2);

        // start the node
        _ = imnodes.ez.beginNode(parent, "Spawner", &parent.pos, &parent.selected);
        defer imnodes.ez.endNode();

        // input slots
        imnodes.ez.inputSlots(&self.input_slots);

        // spawner selector
        var buf: [2 << 11]u8 = undefined;
        const names = entity.Entity.buildNameComboString(
            .spawner,
            &self.env.entities,
            &buf,
        );
        setNextItemWidth(node_width);
        const changed = z.combo("##spawner-selector", .{
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
        _ = z.inputInt("##wait-int", .{ .v = &self.wait });

        // output slots
        imnodes.ez.outputSlots(&self.output_slots);
    }

    pub fn update(
        self: *SpawnerNode,
        alloc: std.mem.Allocator,
        graph: *Graph,
        node_id: usize,
        env: *Environment,
    ) !void {
        const time: f64 = commons.getTimeMillis();
        if (time - self.last_spawn >= @as(f64, @floatFromInt(self.wait))) {
            const pos: rl.Vector2 = self.getSpawner().randomSpawnPos();
            const a = try Agent.init(
                alloc,
                pos,
                node_id,
                graph,
                env.agents.getNextIndex(),
                env,
            );
            _ = env.agents.createItem(a);

            // reset last spawn
            self.last_spawn = commons.getTimeMillis();
        }
    }
};

pub const AreaNodeSnapshot = struct {
    area_index: i32,
    wait: utils.Wait,
    wait_type: i32,
};

pub const AreaNode = struct {
    env: *Environment,
    area_index: i32 = 0,
    wait: utils.Wait,
    wait_type: i32 = 0,

    input_slots: [1]imnodes.ez.SlotInfo = .{
        .{ .title = "in", .kind = -1 },
    },
    output_slots: [1]imnodes.ez.SlotInfo = .{
        .{ .title = "out", .kind = 1 },
    },

    pub fn getSnapshot(self: AreaNode) AreaNodeSnapshot {
        return .{
            .area_index = self.area_index,
            .wait = self.wait,
            .wait_type = self.wait_type,
        };
    }

    pub fn fromSnapshot(snap: AreaNodeSnapshot, env: *Environment) AreaNode {
        return .{
            .env = env,
            .area_index = snap.area_index,
            .wait = snap.wait,
            .wait_type = snap.wait_type,
        };
    }

    pub fn getWaitTime(self: AreaNode) i32 {
        return switch (self.wait) {
            inline else => |kind| kind.get(),
        };
    }

    pub fn getArea(self: *AreaNode) *Area {
        return &self.env.entities.getItem(self.env.areas.items[@intCast(self.area_index)]).kind.area;
    }

    pub fn draw(self: *AreaNode, parent: *Node) void {
        const node_width: f32 = 120;

        imnodes.ez.pushStyleColor(.node_title_bar_bg, palette.iden(palette.env.light_blue));
        imnodes.ez.pushStyleColor(.node_title_bar_bg_hovered, palette.lighten(palette.env.light_blue));
        defer imnodes.ez.popStyleColor(2);

        // start the node
        _ = imnodes.ez.beginNode(parent, "Area", &parent.pos, &parent.selected);
        defer imnodes.ez.endNode();

        // input slots
        imnodes.ez.inputSlots(&self.input_slots);

        // area selector
        {
            var buf: [2048]u8 = undefined;
            const names = entity.Entity.buildNameComboString(
                .area,
                &self.env.entities,
                &buf,
            );
            setNextItemWidth(node_width);
            const changed = z.combo("##area-selector", .{
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
            const changed = z.combo("##area-wait-type", .{
                .current_item = &self.wait_type,
                .items_separated_by_zeros = utils.Wait.zeroSepItems,
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
                _ = z.inputInt(utils.Wait.Normal.mu_text, .{ .v = &normal.mu });
                setNextItemWidth(node_width);
                _ = z.inputInt(utils.Wait.Normal.sigma_text, .{ .v = &normal.sigma });
            },
        }

        // output slots
        imnodes.ez.outputSlots(&self.output_slots);
    }

    pub fn update(_: AreaNode, _: *std.ArrayList(Agent)) !void {}
};

pub const QueueNodeSnapshot = struct {
    queue_index: i32,
    wait: utils.Wait,
    wait_type: i32,
};

pub const QueueNode = struct {
    env: *Environment,
    queue_index: i32 = 0,
    wait: utils.Wait,
    wait_type: i32 = 0,

    input_slots: [1]imnodes.ez.SlotInfo = .{
        .{ .title = "in", .kind = -1 },
    },
    output_slots: [1]imnodes.ez.SlotInfo = .{
        .{ .title = "out", .kind = 1 },
    },

    pub fn getSnapshot(self: QueueNode) QueueNodeSnapshot {
        return .{
            .queue_index = self.queue_index,
            .wait = self.wait,
            .wait_type = self.wait_type,
        };
    }

    pub fn fromSnapshot(snap: QueueNodeSnapshot, env: *Environment) QueueNode {
        return .{
            .env = env,
            .queue_index = snap.queue_index,
            .wait = snap.wait,
            .wait_type = snap.wait_type,
        };
    }

    pub fn getWaitTime(self: QueueNode) i32 {
        return switch (self.wait) {
            inline else => |kind| kind.get(),
        };
    }

    pub fn getQueue(self: *QueueNode) *Queue {
        return &self.env.entities.getItem(self.env.queues.items[@intCast(self.queue_index)]).kind.queue;
    }

    pub fn draw(self: *QueueNode, parent: *Node) void {
        const node_width: f32 = 120;

        imnodes.ez.pushStyleColor(.node_title_bar_bg, palette.iden(palette.env.orange));
        imnodes.ez.pushStyleColor(.node_title_bar_bg_hovered, palette.lighten(palette.env.orange));
        defer imnodes.ez.popStyleColor(2);

        // start the node
        _ = imnodes.ez.beginNode(parent, "Queue", &parent.pos, &parent.selected);
        defer imnodes.ez.endNode();

        // input slots
        imnodes.ez.inputSlots(&self.input_slots);

        // queue selector
        {
            var buf: [2048]u8 = undefined;
            const names = entity.Entity.buildNameComboString(
                .queue,
                &self.env.entities,
                &buf,
            );
            setNextItemWidth(node_width);
            const changed = z.combo("##queue-selector", .{
                .current_item = &self.queue_index,
                .items_separated_by_zeros = names,
            });
            if (changed) {
                // clicked on a different spawner instance
                std.debug.print("{}", .{self.queue_index});
            }
        }

        // wait time options
        {
            setNextItemWidth(node_width);
            const changed = z.combo("##queue-wait-type", .{
                .current_item = &self.wait_type,
                .items_separated_by_zeros = utils.Wait.zeroSepItems,
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
                _ = z.inputInt(utils.Wait.Normal.mu_text, .{ .v = &normal.mu });
                setNextItemWidth(node_width);
                _ = z.inputInt(utils.Wait.Normal.sigma_text, .{ .v = &normal.sigma });
            },
        }

        // output slots
        imnodes.ez.outputSlots(&self.output_slots);
    }

    pub fn update(_: AreaNode, _: *std.ArrayList(Agent)) !void {}
};

pub const ForkNodeSnapshot = struct {
    values: [4]f32,
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

    pub fn getSnapshot(self: ForkNode) ForkNodeSnapshot {
        return .{
            .values = self.values,
        };
    }

    pub fn fromSnapshot(snap: ForkNodeSnapshot) ForkNode {
        return .{ .values = snap.values };
    }

    pub fn getOutputSlotTitle(self: ForkNode) [*c]const u8 {
        var sum: f32 = 0;
        for (self.values) |prob| {
            sum += prob;
        }

        // if all-zeroes just in case
        if (sum <= 0) {
            return self.output_slots[0].title;
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

        // fallback for floating-point precision issues
        return self.output_slots[self.output_slots.len - 1].title;
    }

    pub fn draw(
        self: *ForkNode,
        parent: *Node,
    ) void {
        // style setup
        const node_width: f32 = 70;
        imnodes.ez.pushStyleColor(.node_title_bar_bg, palette.iden(palette.env.light_gray));
        imnodes.ez.pushStyleColor(.node_title_bar_bg_hovered, palette.lighten(palette.env.light_gray));
        defer imnodes.ez.popStyleColor(2);

        // init node
        _ = imnodes.ez.beginNode(parent, "Fork", &parent.pos, &parent.selected);
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
            if (z.inputFloat("##fork-output-nodes", .{ .v = &self.values[i], .cfmt = "%.2f" })) {
                // input changed
            }
        }

        // output slots
        imnodes.ez.outputSlots(&self.output_slots);
    }
};

const QueueForkNodeSelection = enum {
    pub const zeroSepItems: [:0]const u8 = "shortest\x00closest\x00uniform\x00";

    shortest,
    closest,
    random,
};

pub const QueueForkNodeSnapshot = struct {
    selection: QueueForkNodeSelection,
};

pub const QueueForkNode = struct {
    input_slots: [1]imnodes.ez.SlotInfo = .{
        .{ .title = "in", .kind = -1 },
    },
    output_slots: [1]imnodes.ez.SlotInfo = .{
        .{ .title = "outs", .kind = 1 },
    },
    selection: QueueForkNodeSelection,
    selection_type: i32 = 0,

    pub fn getSnapshot(self: QueueForkNode) QueueForkNodeSnapshot {
        return .{ .selection = self.selection };
    }

    pub fn fromSnapshot(snap: QueueForkNodeSnapshot) QueueForkNode {
        return .{ .selection = snap.selection };
    }

    // pub fn getOutputSlotTitle(self: QueueForkNode) [*c]const u8 {
    //     switch (self.selection) {
    //         .random => {
    //             const r = rl.getRandomValue(0, );
    //         },
    //         else => unreachable,
    //     }

    //     var sum: f32 = 0;
    //     for (self.values) |prob| {
    //         sum += prob;
    //     }

    //     // if all-zeroes just in case
    //     if (sum <= 0) {
    //         return self.output_slots[0].title;
    //     }

    //     // add up until larger than cumulative
    //     const r: f32 = commons.rand01() * sum;
    //     var cum: f64 = 0;
    //     var i: usize = 0;
    //     for (self.values) |value| {
    //         cum += value;
    //         if (r < cum) {
    //             return self.output_slots[i].title;
    //         }
    //         i += 1;
    //     }

    //     // fallback for floating-point precision issues
    //     return self.output_slots[self.output_slots.len - 1].title;
    // }

    pub fn draw(self: *QueueForkNode, parent: *Node) void {
        // style setup
        const node_width: f32 = 110;
        imnodes.ez.pushStyleColor(.node_title_bar_bg, palette.iden(palette.env.light_orange));
        imnodes.ez.pushStyleColor(.node_title_bar_bg_hovered, palette.lighten(palette.env.light_orange));
        defer imnodes.ez.popStyleColor(2);

        // init node
        _ = imnodes.ez.beginNode(parent, "Queue Fork", &parent.pos, &parent.selected);
        defer imnodes.ez.endNode();

        // input slots
        imnodes.ez.inputSlots(&self.input_slots);

        // selection type
        {
            setNextItemWidth(node_width);
            _ = z.combo("##queue_fork-selection-type", .{
                .current_item = &self.selection_type,
                .items_separated_by_zeros = QueueForkNodeSelection.zeroSepItems,
            });
        }

        // output slots
        imnodes.ez.outputSlots(&self.output_slots);
    }
};
