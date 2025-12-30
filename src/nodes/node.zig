const z = @import("zgui");
const imnodes = @import("imnodes");
const color = @import("../color.zig");

pub const SpawnerNode = struct {
    spawner_id: usize,
    wait: i32,
    target: usize = undefined,

    pub fn draw(self: *SpawnerNode) void {
        imnodes.pushColorStyle(.ImNodesCol_TitleBar, 0xff40a140);
        imnodes.pushColorStyle(.ImNodesCol_TitleBarHovered, 0xff64CC61);
        imnodes.pushColorStyle(.ImNodesCol_TitleBarSelected, 0xff64CC61);
        defer imnodes.popColorStyle();
        defer imnodes.popColorStyle();
        defer imnodes.popColorStyle();

        imnodes.beginNode(0);
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
        z.setNextItemWidth(100);
        _ = z.inputInt("##", .{ .v = &self.wait });

        // target output
        imnodes.beginOutputAttribute(0);
        defer imnodes.endOutputAttribute();
    }
};

pub const Node = union(enum) {
    spawner: SpawnerNode,

    pub fn initSpawner(spawner_id: usize, wait: i32) Node {
        return .{ .spawner = .{
            .spawner_id = spawner_id,
            .wait = wait,
        } };
    }

    pub fn getName(self: Node) []const u8 {
        return switch (self) {
            .spawner => "Spawner",
        };
    }

    pub fn draw(self: *Node) void {
        switch (self.*) {
            .spawner => |*spawner| spawner.draw(),
        }
    }
};
