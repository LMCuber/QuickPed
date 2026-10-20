//
// THIS ENTIRE FILE SKELETON IS BASICALLY AI SINCE I
// REFUSE TO MANUALLY WRITE VECTOR GRAPHICS IN IMGUI
// I COULDN'T LITERALLY CARE LESS HOW BAD THE CODE IS
//

const Self = @This();
const z = @import("zgui");
const std = @import("std");

const palette = struct {
    const default: u32 = 0xFF734b26;
    const hover: u32 = 0xFF9e6b3c;
    const active: u32 = 0xFF613d1b;
};

const Glyph = struct { w: usize, rows: [5]u3 };

// Leftmost pixel = highest bit of each row
const exit_glyphs = [_]Glyph{
    .{ .w = 3, .rows = .{ 0b111, 0b100, 0b111, 0b100, 0b111 } }, // E
    .{ .w = 3, .rows = .{ 0b101, 0b101, 0b010, 0b101, 0b101 } }, // X
    .{ .w = 1, .rows = .{ 1, 1, 1, 1, 1 } }, // I
    .{ .w = 3, .rows = .{ 0b111, 0b010, 0b010, 0b010, 0b010 } }, // T
};

/// Fills the rect min..max with "EXIT". Cell width and height are computed
/// independently, so the letters stretch to the rect's proportions.
fn drawExitText(dl: anytype, min: [2]f32, max: [2]f32, col: u32) void {
    const total_cols: f32 = 13.0; // 3 + 3 + 1 + 3 glyph columns + 3 gap columns
    const cell_w = (max[0] - min[0]) / total_cols;
    const cell_h = (max[1] - min[1]) / 5.0;

    var col_idx: usize = 0;
    for (exit_glyphs) |g| {
        for (g.rows, 0..) |row, ry| {
            for (0..g.w) |c| {
                const bit: u2 = @intCast(g.w - 1 - c);
                if (((row >> bit) & 1) == 1) {
                    const gx: f32 = @floatFromInt(col_idx + c);
                    const gy: f32 = @floatFromInt(ry);
                    // Same expression for shared edges, so there are no seams between cells
                    dl.addRectFilled(.{
                        .pmin = .{ @round(min[0] + gx * cell_w), @round(min[1] + gy * cell_h) },
                        .pmax = .{ @round(min[0] + (gx + 1.0) * cell_w), @round(min[1] + (gy + 1.0) * cell_h) },
                        .col = col,
                    });
                }
            }
        }
        col_idx += g.w + 1; // advance past the glyph plus one gap column
    }
}

pub fn evacuationButton(alloc: std.mem.Allocator, bs: f32) !bool {
    const clicked = z.invisibleButton("##evacuation", .{ .w = bs, .h = bs });
    const min = z.getItemRectMin();
    const max = z.getItemRectMax();
    const dl = z.getWindowDrawList();

    const hovered = z.isItemHovered(.{});
    if (hovered) {
        _ = z.beginTooltip();
        try z.text(alloc, "evacuation plan", .{});
        z.endTooltip();
    }
    const active = z.isItemActive();

    // Regular blue background
    const bg_col: u32 = if (active)
        palette.active
    else if (hovered)
        palette.hover
    else
        palette.default;
    dl.addRectFilled(.{ .pmin = min, .pmax = max, .col = bg_col });

    // Green sign: dark green border rect, then the green fill inset by the border width
    const pad = @round(bs * 0.14);
    const g_min: [2]f32 = .{ @round(min[0] + pad), @round(min[1] + pad) };
    const g_max: [2]f32 = .{ @round(max[0] - pad), @round(max[1] - pad) };
    dl.addRectFilled(.{ .pmin = g_min, .pmax = g_max, .col = 0xff_1E_5A_14 }); // dark green border

    const bw = @max(2.0, @round(bs * 0.04));
    const in_min: [2]f32 = .{ g_min[0] + bw, g_min[1] + bw };
    const in_max: [2]f32 = .{ g_max[0] - bw, g_max[1] - bw };
    dl.addRectFilled(.{ .pmin = in_min, .pmax = in_max, .col = 0xff_43_A0_2E }); // green

    // Text fills the green with only a tiny margin
    const margin = @max(1.0, @round(bs * 0.03));
    drawExitText(
        dl,
        .{ in_min[0] + margin, in_min[1] + margin },
        .{ in_max[0] - margin, in_max[1] - margin },
        0xff_ff_ff_ff,
    );

    return clicked;
}

const mag_col: u32 = 0xff_A0_5A_C8; // muted magenta (ABGR)
const teal_col: u32 = 0xff_A0_B4_3C; // muted teal
const peak_col: u32 = 0xff_6A_7A_E0; // soft coral, same as person_cols[0]
const white_col: u32 = 0xff_E6_E6_E6;

// Diamond drawn as 1px rows: stepped, crisp, axis-aligned
fn pixelDiamond(dl: anytype, cx: f32, cy: f32, r: f32, dx: f32, col: u32) void {
    if (r < 1.0) return;
    const rows: usize = @intFromFloat(@round(2.0 * r));
    const top = cy - r;
    for (0..rows) |i| {
        const fi: f32 = @floatFromInt(i);
        const hw = @round(r - @abs(fi + 0.5 - r));
        rect(dl, .{ cx - hw, top + fi, cx + hw, top + fi + 1.0 }, dx, col);
    }
}
const sp_purple: u32 = 0xff_C8_50_8C; // muted purple (ABGR)
const sp_blue: u32 = 0xff_DC_78_3C; // muted blue

const sp_green: u32 = 0xff_50_B4_5A; // muted green (ABGR), brighter than the old 4C8F4C
const sp_cyan: u32 = 0xff_DC_C8_3C; // muted cyan
const sp_yellow: u32 = 0xff_3C_C8_EB; // muted yellow

// Right-pointing chevron drawn as 1px rows: crisp, axis-aligned, stepped
fn chevron(dl: anytype, tip: f32, cy: f32, hh: f32, th: f32, dx: f32, col: u32) void {
    const rows: usize = @intFromFloat(2.0 * hh);
    for (0..rows) |i| {
        const fi: f32 = @floatFromInt(i);
        const x = tip - @round(@abs(fi + 0.5 - hh));
        rect(dl, .{ x - th, cy - hh + fi, x, cy - hh + fi + 1.0 }, dx, col);
    }
}

pub fn spawnerButton(alloc: std.mem.Allocator, bs: f32) !bool {
    const clicked = z.invisibleButton("##spawner", .{ .w = bs, .h = bs });
    const min = z.getItemRectMin();
    const max = z.getItemRectMax();
    const dl = z.getWindowDrawList();

    const hovered = z.isItemHovered(.{});
    if (hovered) {
        _ = z.beginTooltip();
        try z.text(alloc, "spawner", .{});
        z.endTooltip();
    }
    const active = z.isItemActive();

    const bg_col: u32 = if (active) palette.active else if (hovered) palette.hover else palette.default;
    dl.addRectFilled(.{ .pmin = min, .pmax = max, .col = bg_col });

    const pad = @round(bs * 0.14);
    const off = @max(1.0, @round(bs * 0.035));
    const th = @max(3.0, @round(bs * 0.12)); // chunky chevron thickness
    const sp = @round(th * 1.6); // spacing between chevrons
    const ps = @max(3.0, @round(bs * 0.09)); // person half-size
    const hh0 = @round(bs * 0.28); // front chevron half-height

    const l = @round(min[0] + pad);
    const r = @round(max[0] - pad);
    const cy = @round((min[1] + max[1]) * 0.5);

    // Back (cyan, smaller) then front (green, bigger)
    const chevs = [2]struct { tip: f32, hh: f32, col: u32 }{
        .{ .tip = r - sp, .hh = @round(hh0 * 0.75), .col = sp_cyan },
        .{ .tip = r, .hh = hh0, .col = sp_green },
    };

    // Pass 1: shadows
    for (chevs) |c| chevron(dl, c.tip, cy, c.hh, th, off, shadow_col);
    rect(dl, .{ l, cy - ps, l + ps * 2.0, cy + ps }, off, shadow_col);

    // Pass 2: faces
    for (chevs) |c| chevron(dl, c.tip, cy, c.hh, th, 0, c.col);
    rect(dl, .{ l, cy - ps, l + ps * 2.0, cy + ps }, 0, sp_yellow);

    return clicked;
}

pub fn contourButton(alloc: std.mem.Allocator, bs: f32) !bool {
    const clicked = z.invisibleButton("##contour", .{ .w = bs, .h = bs });
    const min = z.getItemRectMin();
    const max = z.getItemRectMax();
    const dl = z.getWindowDrawList();

    const hovered = z.isItemHovered(.{});
    if (hovered) {
        _ = z.beginTooltip();
        try z.text(alloc, "contour", .{});
        z.endTooltip();
    }
    const active = z.isItemActive();

    const bg_col: u32 = if (active) palette.active else if (hovered) palette.hover else palette.default;
    dl.addRectFilled(.{ .pmin = min, .pmax = max, .col = bg_col });

    const off = @max(1.0, @round(bs * 0.035));
    const t = @max(2.0, @round(bs * 0.07)); // ring thickness
    const R = @round(bs * 0.42);
    const cx = @round((min[0] + max[0]) * 0.5);
    const cy = @round((min[1] + max[1]) * 0.5);

    // Shadow, then rings from outside in. Gaps are bg_col so hover still shows.
    pixelDiamond(dl, cx, cy, R, off, shadow_col);
    pixelDiamond(dl, cx, cy, R, 0, teal_col);
    pixelDiamond(dl, cx, cy, R - t, 0, bg_col);
    pixelDiamond(dl, cx, cy, R - t * 2.0, 0, white_col);
    pixelDiamond(dl, cx, cy, R - t * 3.0, 0, bg_col);
    pixelDiamond(dl, cx, cy, R - t * 4.0, 0, peak_col);

    return clicked;
}

// Shared with the other buttons: shadow_col, path_col, rect(), person_cols.
// Only declare them once per file.
const zone_col: u32 = 0xff_8C_5A_32; // muted blue (ABGR)

fn dashH(dl: anytype, x0: f32, x1: f32, y0: f32, y1: f32, d: f32, col: u32) void {
    var x = x0;
    while (x < x1) : (x += 2.0 * d) {
        rect(dl, .{ x, y0, @min(x + d, x1), y1 }, 0, col);
    }
}

fn dashV(dl: anytype, y0: f32, y1: f32, x0: f32, x1: f32, d: f32, col: u32) void {
    var y = y0;
    while (y < y1) : (y += 2.0 * d) {
        rect(dl, .{ x0, y, x1, @min(y + d, y1) }, 0, col);
    }
}

pub fn areaButton(alloc: std.mem.Allocator, bs: f32) !bool {
    const clicked = z.invisibleButton("##waiting_area", .{ .w = bs, .h = bs });
    const min = z.getItemRectMin();
    const max = z.getItemRectMax();
    const dl = z.getWindowDrawList();

    const hovered = z.isItemHovered(.{});
    if (hovered) {
        _ = z.beginTooltip();
        try z.text(alloc, "waiting area", .{});
        z.endTooltip();
    }
    const active = z.isItemActive();

    const bg_col: u32 = if (active) palette.active else if (hovered) palette.hover else palette.default;
    dl.addRectFilled(.{ .pmin = min, .pmax = max, .col = bg_col });

    const pad = @round(bs * 0.18);
    const t = @max(2.0, 2.0 * @round(bs * 0.02)); // border thickness (even)
    const off = @max(1.0, @round(bs * 0.035));
    const d = @max(2.0, @round(bs * 0.07)); // dash length = gap length

    const l = @round(min[0] + pad);
    const r = @round(max[0] - pad);
    const tp = @round(min[1] + pad);
    const b = @round(max[1] - pad);

    // Zone: shadow, then fill
    rect(dl, .{ l, tp, r, b }, off, shadow_col);
    rect(dl, .{ l, tp, r, b }, 0, zone_col);

    // Dashed border: square corners, dashes between them
    dashH(dl, l + t, r - t, tp, tp + t, d, path_col);
    dashH(dl, l + t, r - t, b - t, b, d, path_col);
    dashV(dl, tp + t, b - t, l, l + t, d, path_col);
    dashV(dl, tp + t, b - t, r - t, r, d, path_col);
    const corners = [4][2]f32{ .{ l, tp }, .{ r - t, tp }, .{ l, b - t }, .{ r - t, b - t } };
    for (corners) |c| rect(dl, .{ c[0], c[1], c[0] + t, c[1] + t }, 0, path_col);

    // Four people standing around, slightly off-grid so they look like they're milling
    const ps = @round(t * 1.5);
    const w = r - l;
    const h = b - tp;
    const people = [4][2]f32{
        .{ 0.30, 0.34 },
        .{ 0.68, 0.30 },
        .{ 0.34, 0.70 },
        .{ 0.70, 0.66 },
    };
    for (people) |p| {
        const px = @round(l + w * p[0]);
        const py = @round(tp + h * p[1]);
        rect(dl, .{ px - ps, py - ps, px + ps, py + ps }, off, shadow_col);
    }
    for (people, 0..) |p, i| {
        const px = @round(l + w * p[0]);
        const py = @round(tp + h * p[1]);
        rect(dl, .{ px - ps, py - ps, px + ps, py + ps }, 0, person_cols[i]);
    }

    return clicked;
}

const ring_col: u32 = 0xff_A0_8C_5A; // muted steel blue (ABGR)
const void_col: u32 = 0xff_28_20_1A;
const wing_col: u32 = 0xff_40_B0_DE; // muted amber, same as the queue path
const hub_col: u32 = 0xff_E6_E6_E6;
const trail_cols = [3]u32{ 0xff_E6_E6_E6, 0xff_B4_B4_B4, 0xff_82_82_82 };

// Filled disc drawn as 1px rows: round but crisp
fn pixelDisc(dl: anytype, cx: f32, cy: f32, r: f32, dx: f32, col: u32) void {
    if (r < 1.0) return;
    const rows: usize = @intFromFloat(@round(2.0 * r));
    const rf: f32 = @floatFromInt(rows);
    const top = cy - rf * 0.5;
    for (0..rows) |i| {
        const fi: f32 = @floatFromInt(i);
        const u = (fi + 0.5) / rf * 2.0 - 1.0;
        const hw = @round(r * @sqrt(1.0 - u * u));
        rect(dl, .{ cx - hw, top + fi, cx + hw, top + fi + 1.0 }, dx, col);
    }
}

pub fn revolverButton(alloc: std.mem.Allocator, bs: f32) !bool {
    const clicked = z.invisibleButton("##revolver", .{ .w = bs, .h = bs });
    const min = z.getItemRectMin();
    const max = z.getItemRectMax();
    const dl = z.getWindowDrawList();

    const hovered = z.isItemHovered(.{});
    if (hovered) {
        _ = z.beginTooltip();
        try z.text(alloc, "revolver", .{});
        z.endTooltip();
    }
    const active = z.isItemActive();

    const bg_col: u32 = if (active) palette.active else if (hovered) palette.hover else palette.default;
    dl.addRectFilled(.{ .pmin = min, .pmax = max, .col = bg_col });

    const off = @max(1.0, @round(bs * 0.035));
    const t = @max(2.0, 2.0 * @round(bs * 0.03)); // wing thickness (even)
    const h = t * 0.5;

    const cx = @round((min[0] + max[0]) * 0.5);
    const cy = @round((min[1] + max[1]) * 0.5);
    const R = @round(bs * 0.40); // housing radius
    const rim = @max(2.0, @round(bs * 0.045));
    const L = @round((R - rim) * 0.88); // wing half-length

    // Housing: shadow, ring, void
    pixelDisc(dl, cx, cy, R, off, shadow_col);
    pixelDisc(dl, cx, cy, R, 0, ring_col);
    pixelDisc(dl, cx, cy, R - rim, 0, void_col);

    // Wings (plus shape): shadows first, then faces
    const wings = [2][4]f32{
        .{ cx - L, cy - h, cx + L, cy + h },
        .{ cx - h, cy - L, cx + h, cy + L },
    };
    for (wings) |w| rect(dl, w, off, shadow_col);
    for (wings) |w| rect(dl, w, 0, wing_col);

    // Hub
    const hs = @round(t * 1.1);
    rect(dl, .{ cx - hs, cy - hs, cx + hs, cy + hs }, off, shadow_col);
    rect(dl, .{ cx - hs, cy - hs, cx + hs, cy + hs }, 0, hub_col);

    // Woosh: shrinking squares trailing behind each wing tip along a circle
    const pi: f32 = 3.14159265;
    const lag = [3]f32{ 0.20, 0.42, 0.66 }; // radians behind the tip
    const sizes = [3]f32{
        @max(1.0, @round(t * 0.7)),
        @max(1.0, @round(t * 0.5)),
        @max(1.0, @round(t * 0.3)),
    };
    for (0..4) |k| {
        const base = @as(f32, @floatFromInt(k)) * pi * 0.5;
        for (0..3) |j| {
            const ang = base - lag[j];
            const px = @round(cx + L * @cos(ang));
            const py = @round(cy + L * @sin(ang));
            const s = sizes[j];
            rect(dl, .{ px - s, py - s, px + s, py + s }, 0, trail_cols[j]);
        }
    }

    return clicked;
}

const blue_col: u32 = 0xff_C8_8C_3C;
const blue_void: u32 = 0xff_40_28_14;
const blue_core: u32 = 0xff_28_18_0C;
const orange_col: u32 = 0xff_32_82_DC;
const orange_void: u32 = 0xff_14_28_46;
const orange_core: u32 = 0xff_0C_18_2E;
const spark_col: u32 = 0xff_E6_E6_E6;

// Vertical oval drawn as 1px-tall rows: smooth but still axis-aligned and crisp
fn pixelOval(dl: anytype, cx: f32, cy: f32, a: f32, b: f32, dx: f32, col: u32) void {
    if (a < 1.0 or b < 1.0) return;
    const rows: usize = @intFromFloat(@round(2.0 * b));
    const rf: f32 = @floatFromInt(rows);
    const top = cy - rf * 0.5;
    for (0..rows) |i| {
        const fi: f32 = @floatFromInt(i);
        const u = (fi + 0.5) / rf * 2.0 - 1.0;
        const hw = @round(a * @sqrt(1.0 - u * u));
        const y = top + fi;
        rect(dl, .{ cx - hw, y, cx + hw, y + 1.0 }, dx, col);
    }
}

pub fn portalButton(alloc: std.mem.Allocator, bs: f32) !bool {
    const clicked = z.invisibleButton("##portal", .{ .w = bs, .h = bs });
    const min = z.getItemRectMin();
    const max = z.getItemRectMax();
    const dl = z.getWindowDrawList();

    const hovered = z.isItemHovered(.{});
    if (hovered) {
        _ = z.beginTooltip();
        try z.text(alloc, "portal", .{});
        z.endTooltip();
    }
    const active = z.isItemActive();

    const bg_col: u32 = if (active) palette.active else if (hovered) palette.hover else palette.default;
    dl.addRectFilled(.{ .pmin = min, .pmax = max, .col = bg_col });

    const off = @max(1.0, @round(bs * 0.035));
    const t = @max(2.0, @round(bs * 0.05)); // ring thickness

    const cy = @round((min[1] + max[1]) * 0.5);
    const mid_x = @round((min[0] + max[0]) * 0.5);
    const a = @round(bs * 0.14);
    const b = @round(bs * 0.38);
    const dist = @round(bs * 0.27);

    const lx = mid_x - dist;
    const rx = mid_x + dist;

    // Pass 1: shadows
    pixelOval(dl, lx, cy, a, b, off, shadow_col);
    pixelOval(dl, rx, cy, a, b, off, shadow_col);

    // Pass 2: ring faces
    pixelOval(dl, lx, cy, a, b, 0, blue_col);
    pixelOval(dl, rx, cy, a, b, 0, orange_col);

    // Pass 3: void
    pixelOval(dl, lx, cy, a - t, b - t, 0, blue_void);
    pixelOval(dl, rx, cy, a - t, b - t, 0, orange_void);

    // Pass 4: darker core for depth
    pixelOval(dl, lx, cy, a - t * 2.0, b - t * 2.0, 0, blue_core);
    pixelOval(dl, rx, cy, a - t * 2.0, b - t * 2.0, 0, orange_core);

    // Sparks traveling blue -> orange, shrinking
    const gap_l = lx + a;
    const gw = (rx - a) - gap_l;
    const s0 = @max(1.0, @round(t * 0.8));
    const s1 = @max(1.0, @round(t * 0.55));
    const s2 = @max(1.0, @round(t * 0.3));
    const sparks = [3]struct { fx: f32, s: f32 }{
        .{ .fx = 0.20, .s = s0 },
        .{ .fx = 0.50, .s = s1 },
        .{ .fx = 0.80, .s = s2 },
    };
    for (sparks) |sp| {
        const cx = @round(gap_l + gw * sp.fx);
        rect(dl, .{ cx - sp.s, cy - sp.s, cx + sp.s, cy + sp.s }, off, shadow_col);
    }
    for (sparks) |sp| {
        const cx = @round(gap_l + gw * sp.fx);
        rect(dl, .{ cx - sp.s, cy - sp.s, cx + sp.s, cy + sp.s }, 0, spark_col);
    }

    return clicked;
}

const shadow_col: u32 = 0xff_18_14_14;
const path_col: u32 = 0xff_40_B0_DE; // muted amber (ABGR)

// Slightly varied, muted person colors (ABGR)
const person_cols = [6]u32{
    0xff_6A_7A_E0, // soft coral
    0xff_A0_D2_E6, // sand
    0xff_8A_C8_9C, // sage
    0xff_E4_C4_9C, // pale sky
    0xff_D8_A4_C0, // lilac
    0xff_E6_E6_E6, // off-white
};

fn rect(dl: anytype, r: [4]f32, dx: f32, col: u32) void {
    dl.addRectFilled(.{
        .pmin = .{ r[0] + dx, r[1] + dx },
        .pmax = .{ r[2] + dx, r[3] + dx },
        .col = col,
    });
}

pub fn queueButton(alloc: std.mem.Allocator, bs: f32) !bool {
    const clicked = z.invisibleButton("##queue", .{ .w = bs, .h = bs });
    const min = z.getItemRectMin();
    const max = z.getItemRectMax();
    const dl = z.getWindowDrawList();

    const hovered = z.isItemHovered(.{});
    if (hovered) {
        _ = z.beginTooltip();
        try z.text(alloc, "queue", .{});
        z.endTooltip();
    }
    const active = z.isItemActive();

    const bg_col: u32 = if (active) palette.active else if (hovered) palette.hover else palette.default;
    dl.addRectFilled(.{ .pmin = min, .pmax = max, .col = bg_col });

    const pad = @round(bs * 0.2);
    const t = @max(2.0, 2.0 * @round(bs * 0.025)); // thin path (even)
    const h = t * 0.5;
    const off = @max(1.0, @round(bs * 0.035));

    const left = @round(min[0] + pad);
    const right = @round(max[0] - pad);
    const top = @round(min[1] + pad);
    const bot = @round(max[1] - pad);
    const mid = @round((top + bot) * 0.5);

    // Snake path
    const bars = [5][4]f32{
        .{ left - h, top - h, right + h, top + h },
        .{ right - h, top - h, right + h, mid + h },
        .{ left - h, mid - h, right + h, mid + h },
        .{ left - h, mid - h, left + h, bot + h },
        .{ left - h, bot - h, right + h, bot + h },
    };
    for (bars) |b| rect(dl, b, off, shadow_col);
    for (bars) |b| rect(dl, b, 0, path_col);

    // 6 people, listed in order along the snake:
    // row 0 left->right, row 1 right->left, row 2 left->right
    const ps = @round(t * 1.5);
    const w = right - left;
    const people = [6]struct { fx: f32, y: f32 }{
        .{ .fx = 0.30, .y = top },
        .{ .fx = 0.70, .y = top },
        .{ .fx = 0.70, .y = mid },
        .{ .fx = 0.30, .y = mid },
        .{ .fx = 0.30, .y = bot },
        .{ .fx = 0.70, .y = bot },
    };

    // Shadows first, then faces, so no shadow covers a person
    for (people) |p| {
        const cx = @round(left + w * p.fx);
        rect(dl, .{ cx - ps, p.y - ps, cx + ps, p.y + ps }, off, shadow_col);
    }
    for (people, 0..) |p, i| {
        const cx = @round(left + w * p.fx);
        rect(dl, .{ cx - ps, p.y - ps, cx + ps, p.y + ps }, 0, person_cols[i]);
    }

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
