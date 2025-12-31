const z = @import("zgui");
const imnodes = @import("imnodes");
const color = @import("../color.zig");

pub const SpawnerNode = struct {
    node_id: i32,
    spawner_id: i32,
    wait: i32,
    target: usize = undefined,

    pub fn draw(self: *SpawnerNode) void {
        const node_width: f32 = 140;

        imnodes.pushColorStyle(.ImNodesCol_TitleBar, 0xff40a140);
        imnodes.pushColorStyle(.ImNodesCol_TitleBarHovered, 0xff64CC61);
        imnodes.pushColorStyle(.ImNodesCol_TitleBarSelected, 0xff64CC61);
        defer imnodes.popColorStyle();
        defer imnodes.popColorStyle();
        defer imnodes.popColorStyle();

        imnodes.beginNode(self.node_id);
        defer imnodes.endNode();

        imnodes.beginNodeTitleBar();
        z.text("Spawner", .{});
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
        imnodes.beginOutputAttribute(self.node_id);
        z.indent(.{ .indent_w = node_width - z.calcTextSize("target", .{})[0] });
        z.text("target", .{});
        imnodes.endOutputAttribute();
    }
};

pub const AreaNode = struct {
    node_id: i32,
    area_id: i32,
    wait: i32,
    target: usize = undefined,

    pub fn draw(self: *AreaNode) void {
        const node_width: f32 = 140;

        imnodes.pushColorStyle(.ImNodesCol_TitleBar, 0xff66543a);
        imnodes.pushColorStyle(.ImNodesCol_TitleBarHovered, 0xff8a7557);
        imnodes.pushColorStyle(.ImNodesCol_TitleBarSelected, 0xff8a7557);
        defer imnodes.popColorStyle();
        defer imnodes.popColorStyle();
        defer imnodes.popColorStyle();

        imnodes.beginNode(self.node_id);
        defer imnodes.endNode();

        imnodes.beginNodeTitleBar();
        z.text("Area", .{});
        imnodes.endNodeTitleBar();

        // wait input
        z.text("wait", .{});
        if (z.isItemHovered(.{})) {
            _ = z.beginTooltip();
            defer z.endTooltip();
            _ = z.text("wait time in ms", .{});
        }
        z.sameLine(.{});
        z.setNextItemWidth(node_width - z.calcTextSize("wait", .{})[0]);
        _ = z.inputInt("##", .{ .v = &self.wait });

        // input and output
        imnodes.beginInputAttribute(self.node_id + 100);
        z.text("from", .{});
        imnodes.endInputAttribute();
        z.sameLine(.{});
        //
        imnodes.beginOutputAttribute(self.node_id);
        z.indent(.{ .indent_w = node_width - z.calcTextSize("fromtarget", .{})[0] });
        z.text("target", .{});
        imnodes.endOutputAttribute();
    }
};

pub const SinkNode = struct {
    node_id: i32,

    pub fn draw(self: *SinkNode) void {
        // const node_width: f32 = 140;

        imnodes.pushColorStyle(.ImNodesCol_TitleBar, 0xff53367d);
        imnodes.pushColorStyle(.ImNodesCol_TitleBarHovered, 0xff7656a3);
        imnodes.pushColorStyle(.ImNodesCol_TitleBarSelected, 0xff7656a3);
        defer imnodes.popColorStyle();
        defer imnodes.popColorStyle();
        defer imnodes.popColorStyle();

        imnodes.beginNode(self.node_id);
        defer imnodes.endNode();

        imnodes.beginNodeTitleBar();
        z.text("Sink", .{});
        imnodes.endNodeTitleBar();

        // input
        imnodes.beginInputAttribute(self.node_id + 100);
        z.text("from", .{});
        imnodes.endInputAttribute();
    }
};

pub const Node = union(enum) {
    spawner: SpawnerNode,
    area: AreaNode,
    sink: SinkNode,

    pub var next_node_id: i32 = 0;

    pub fn nextNodeId() i32 {
        next_node_id += 1;
        return next_node_id - 1;
    }

    pub fn initSpawner(spawner_id: i32, wait: i32) Node {
        return .{ .spawner = .{
            .node_id = nextNodeId(),
            .spawner_id = spawner_id,
            .wait = wait,
        } };
    }

    pub fn initArea(area_id: i32, wait: i32) Node {
        return .{ .area = .{
            .node_id = nextNodeId(),
            .area_id = area_id,
            .wait = wait,
        } };
    }

    pub fn initSink() Node {
        return .{ .sink = .{ .node_id = nextNodeId() } };
    }

    pub fn getName(self: Node) []const u8 {
        return switch (self) {
            .spawner => "Spawner",
            .area => "Area",
            .sink => "Sink",
        };
    }

    pub fn draw(self: *Node) void {
        switch (self.*) {
            inline else => |*spawner| spawner.draw(),
        }
    }
};
