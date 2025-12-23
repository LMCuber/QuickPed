const Self = @This();

const z = @import("zgui");
const imnodes = @import("imnodes");
const rl = @import("raylib");
const std = @import("std");

active: bool = false,

pub fn init() Self {
    return .{};
}

pub fn render(self: *Self) void {
    if (rl.isKeyPressed(.key_space)) {
        self.active = !self.active;
    }
    if (!self.active) {
        return;
    }

    z.setNextWindowCollapsed(.{
        .collapsed = false,
    });

    _ = z.begin("Node Editor", .{});
    defer z.end();

    imnodes.beginNodeEditor();

    imnodes.beginNode(1);

    imnodes.beginNodeTitleBar();
    z.textUnformatted("Nodetext");
    imnodes.endNodeTitleBar();

    imnodes.beginInputAttribute(2);
    z.text("input", .{});
    imnodes.endInputAttribute();

    imnodes.beginOutputAttribute(3);
    z.indent(.{ .indent_w = 40 });
    z.text("output", .{});
    imnodes.endOutputAttribute();

    imnodes.endNode();

    imnodes.beginNode(2);

    imnodes.beginNodeTitleBar();
    z.textUnformatted("Nodetext");
    imnodes.endNodeTitleBar();

    imnodes.beginInputAttribute(4);
    z.text("input", .{});
    imnodes.endInputAttribute();

    imnodes.beginOutputAttribute(5);
    z.indent(.{ .indent_w = 40 });
    z.text("output", .{});
    imnodes.endOutputAttribute();

    imnodes.endNode();

    imnodes.link(6, 3, 4);

    // imnodes.minimap();
    imnodes.endNodeEditor();
}
