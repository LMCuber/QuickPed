//
// THIS ENTIRE FILE SKELETON IS BASICALLY AI SINCE I
// REFUSE TO MANUALLY WRITE CSS IN IMGUI
//

const Self = @This();
const z = @import("zgui");

const palette = struct {
    const default: u32 = 0xFF734b26;
    const hover: u32 = 0xFF9e6b3c;
    const active: u32 = 0xFF613d1b;
};

pub fn contourButton(bs: f32) bool {
    const clicked = z.invisibleButton("##contour", .{ .w = bs, .h = bs });

    const min = z.getItemRectMin();
    const max = z.getItemRectMax();
    const dl = z.getWindowDrawList();

    // Hover / active detection
    const hovered = z.isItemHovered(.{});
    if (hovered) {
        _ = z.beginTooltip();
        z.text("contour", .{});
        z.endTooltip();
    }
    const active = z.isItemActive();

    const bg_col: u32 = if (active)
        palette.active
    else if (hovered)
        palette.hover
    else
        palette.default;

    // Draw background
    dl.addRectFilled(.{ .pmin = min, .pmax = max, .col = bg_col });

    // Polygon points (random-ish shape inside the button)
    const mid_x = (min[0] + max[0]) * 0.5;
    const mid_y = (min[1] + max[1]) * 0.5;

    const points: [5][2]f32 = .{
        .{ mid_x, min[1] + 4 },
        .{ max[0] - 4, mid_y },
        .{ mid_x, max[1] - 4 },
        .{ min[0] + 4, mid_y },
        .{ mid_x, min[1] + 4 },
    };

    dl.addPolyline(points[0..], .{ .col = 0xff_ff_ff_ff, .thickness = 2.0 });

    // // Text on top
    // const text_size = z.calcTextSize("Ctr", .{});
    // const pos = .{
    //     (min[0] + max[0] - text_size[0]) * 0.5,
    //     (min[1] + max[1] - text_size[1]) * 0.5,
    // };
    // dl.addText(pos, 0xff_ff_ff_ff, "{s}", .{"Ctr"});

    return clicked;
}

pub fn spawnerButton(bs: f32) bool {
    const clicked = z.invisibleButton("##spawner", .{ .w = bs, .h = bs });

    const min = z.getItemRectMin();
    const max = z.getItemRectMax();
    const dl = z.getWindowDrawList();

    // Hover / active detection
    const hovered = z.isItemHovered(.{});
    if (hovered) {
        _ = z.beginTooltip();
        z.text("spawner", .{});
        z.endTooltip();
    }
    const active = z.isItemActive();

    // Matte navy background, lighter on hover, darker when pressed (ABGR)
    const bg_col: u32 = if (active)
        palette.active
    else if (hovered)
        palette.hover
    else
        palette.default;

    dl.addRectFilled(.{ .pmin = min, .pmax = max, .col = bg_col });

    // Triangle arrow pointing right
    const mid_x = (min[0] + max[0]) * 0.5;
    const mid_y = (min[1] + max[1]) * 0.5;
    const size_icon: f32 = bs * 0.2; // scale relative to button size

    // Right-pointing triangle
    const p1 = .{ mid_x - size_icon, mid_y - size_icon };
    const p2 = .{ mid_x - size_icon, mid_y + size_icon };
    const p3 = .{ mid_x + size_icon, mid_y }; // tip pointing right

    dl.addTriangleFilled(.{ .p1 = p1, .p2 = p2, .p3 = p3, .col = 0xFF00A000 }); // green

    return clicked;
}

pub fn areaButton(bs: f32) bool {
    const clicked = z.invisibleButton("##area", .{ .w = bs, .h = bs });

    const min = z.getItemRectMin();
    const max = z.getItemRectMax();
    const dl = z.getWindowDrawList();

    // Hover / active detection
    const hovered = z.isItemHovered(.{});
    if (hovered) {
        _ = z.beginTooltip();
        z.text("area", .{});
        z.endTooltip();
    }
    const active = z.isItemActive();

    const bg_col: u32 = if (active)
        palette.active
    else if (hovered)
        palette.hover
    else
        palette.default;

    // Draw main background
    dl.addRectFilled(.{ .pmin = min, .pmax = max, .col = bg_col });

    // Inner blue rectangle (keep original styling)
    const pad: f32 = 8.0;
    const inner_min = .{ min[0] + pad, min[1] + pad };
    const inner_max = .{ max[0] - pad, max[1] - pad };

    dl.addRectFilled(.{ .pmin = inner_min, .pmax = inner_max, .col = 0xC8803D00 });
    dl.addRect(.{ .pmin = inner_min, .pmax = inner_max, .col = 0xFF562A1E, .thickness = 2 });

    // // Text on top
    // const text_size = z.calcTextSize("Area", .{});
    // const pos = .{
    //     (min[0] + max[0] - text_size[0]) * 0.5,
    //     (min[1] + max[1] - text_size[1]) * 0.5,
    // };
    // dl.addText(pos, 0xff_ff_ff_ff, "{s}", .{"Area"});

    return clicked;
}

pub fn revolverButton(bs: f32) bool {
    const clicked = z.invisibleButton("##cross", .{ .w = bs, .h = bs });

    const min = z.getItemRectMin();
    const max = z.getItemRectMax();
    const dl = z.getWindowDrawList();

    // Hover / active detection
    const hovered = z.isItemHovered(.{});
    if (hovered) {
        _ = z.beginTooltip();
        z.text("Revolver", .{});
        z.endTooltip();
    }
    const active = z.isItemActive();

    // Background color
    const bg_col: u32 = if (active)
        palette.active
    else if (hovered)
        palette.hover
    else
        palette.default;

    dl.addRectFilled(.{ .pmin = min, .pmax = max, .col = bg_col });

    // Draw cross
    const pad: f32 = 6.0; // space from edges
    const thick: f32 = 4.0;
    dl.addLine(.{ .p1 = .{ min[0] + pad, min[1] + pad }, .p2 = .{ max[0] - pad, max[1] - pad }, .col = 0xff_00_00_00, .thickness = thick });
    dl.addLine(.{ .p1 = .{ min[0] + pad, max[1] - pad }, .p2 = .{ max[0] - pad, min[1] + pad }, .col = 0xff_00_00_00, .thickness = thick });

    return clicked;
}

pub fn clearButton() bool {
    z.pushStyleColor4f(.{ .idx = .button, .c = .{ 0.55, 0.2, 0.32, 1 } });
    z.pushStyleColor4f(.{ .idx = .button_hovered, .c = .{ 0.65, 0.3, 0.4, 2 } });
    z.pushStyleColor4f(.{ .idx = .button_active, .c = .{ 0.8, 0.5, 0.7, 2 } });
    const clicked = z.button("Clear", .{});
    z.popStyleColor(.{ .count = 3 });
    //
    return clicked;
}
