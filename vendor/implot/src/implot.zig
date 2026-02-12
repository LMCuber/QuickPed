const std = @import("std");

// Enums
pub const Axis = enum(c_int) {
    X1 = 0,
    X2 = 1,
    X3 = 2,
    Y1 = 3,
    Y2 = 4,
    Y3 = 5,
};

pub const Cond = enum(c_int) {
    None = 0,
    Always = 1,
    Once = 2,
};

pub const Flags = packed struct(c_int) {
    _reserved0: bool = false,
    no_title: bool = false,
    no_legend: bool = false,
    no_mouse_text: bool = false,
    no_inputs: bool = false,
    no_menus: bool = false,
    no_box_select: bool = false,
    no_frame: bool = false,
    equal: bool = false,
    crosshairs: bool = false,
    _padding: u22 = 0,

    pub const none: Flags = .{};
    pub const canvas_only: Flags = .{
        .no_title = true,
        .no_legend = true,
        .no_menus = true,
        .no_box_select = true,
        .no_mouse_text = true,
    };
};

pub const LineFlags = packed struct(c_int) {
    _padding0: u10 = 0,
    segments: bool = false,
    loop: bool = false,
    skip_nan: bool = false,
    no_clip: bool = false,
    shaded: bool = false,
    _padding1: u17 = 0,

    pub const none: LineFlags = .{};
};

// External C functions
extern fn ImPlot_CreateContext() void;
extern fn ImPlot_DestroyContext() void;
extern fn ImPlot_BeginPlot(title_id: [*:0]const u8, width: f32, height: f32, flags: Flags) bool;
extern fn ImPlot_EndPlot() void;
extern fn ImPlot_SetupAxisLimits(axis: Axis, v_min: f64, v_max: f64, cond: Cond) void;
extern fn ImPlot_PlotLineDoublePtr(label_id: [*:0]const u8, xs: [*]const f64, ys: [*]const f64, count: c_int, flags: LineFlags, offset: c_int, stride: c_int) void;
extern fn ImPlot_PlotLineFloatPtr(label_id: [*:0]const u8, xs: [*]const f32, ys: [*]const f32, count: c_int, flags: LineFlags, offset: c_int, stride: c_int) void;
extern fn ImPlot_PlotLineS32Ptr(label_id: [*:0]const u8, xs: [*]const i32, ys: [*]const i32, count: c_int, flags: LineFlags, offset: c_int, stride: c_int) void;
extern fn ImPlot_PlotHeatmapFloatPtr(label_id: [*:0]const u8, values: [*]const f32, rows: c_int, cols: c_int, scale_min: f64, scale_max: f64, fmt: ?[*:0]const u8, bounds_min_x: f64, bounds_min_y: f64, bounds_max_x: f64, bounds_max_y: f64, flags: HeatmapFlags) void;
extern fn ImPlot_PlotHeatmapDoublePtr(label_id: [*:0]const u8, values: [*]const f64, rows: c_int, cols: c_int, scale_min: f64, scale_max: f64, fmt: ?[*:0]const u8, bounds_min_x: f64, bounds_min_y: f64, bounds_max_x: f64, bounds_max_y: f64, flags: HeatmapFlags) void;
extern fn ImPlot_PlotHeatmapS32Ptr(label_id: [*:0]const u8, values: [*]const i32, rows: c_int, cols: c_int, scale_min: f64, scale_max: f64, fmt: ?[*:0]const u8, bounds_min_x: f64, bounds_min_y: f64, bounds_max_x: f64, bounds_max_y: f64, flags: HeatmapFlags) void;

// Zig wrapper functions

pub fn createContext() void {
    ImPlot_CreateContext();
}

pub fn destroyContext() void {
    ImPlot_DestroyContext();
}

pub fn beginPlot(title_id: [*:0]const u8, width: f32, height: f32, flags: Flags) bool {
    return ImPlot_BeginPlot(title_id, width, height, flags);
}

pub fn endPlot() void {
    ImPlot_EndPlot();
}

pub fn setupAxisLimits(axis: Axis, v_min: f64, v_max: f64, cond: Cond) void {
    ImPlot_SetupAxisLimits(axis, v_min, v_max, cond);
}

pub fn plotLine(comptime T: type, label_id: [*:0]const u8, xs: []const T, ys: []const T, flags: LineFlags) void {
    std.debug.assert(xs.len == ys.len);
    const count: c_int = @intCast(xs.len);

    switch (T) {
        f64 => ImPlot_PlotLineDoublePtr(label_id, xs.ptr, ys.ptr, count, flags, 0, @sizeOf(T)),
        f32 => ImPlot_PlotLineFloatPtr(label_id, xs.ptr, ys.ptr, count, flags, 0, @sizeOf(T)),
        i32 => ImPlot_PlotLineS32Ptr(label_id, xs.ptr, ys.ptr, count, flags, 0, @sizeOf(T)),
        else => @compileError("plotLine only supports f32, f64, and i32"),
    }
}

pub const HeatmapFlags = packed struct(c_int) {
    _padding0: u10 = 0,
    col_major: bool = false,
    _padding1: u21 = 0,

    pub const none: HeatmapFlags = .{};
};

pub fn plotHeatmap(
    comptime T: type,
    label_id: [*:0]const u8,
    values: []const T,
    rows: usize,
    cols: usize,
    scale_min: f64,
    scale_max: f64,
    fmt: ?[*:0]const u8,
    bounds_min_x: f64,
    bounds_min_y: f64,
    bounds_max_x: f64,
    bounds_max_y: f64,
    flags: HeatmapFlags,
) void {
    std.debug.assert(values.len == rows * cols);
    const rows_c: c_int = @intCast(rows);
    const cols_c: c_int = @intCast(cols);

    switch (T) {
        f64 => ImPlot_PlotHeatmapDoublePtr(label_id, values.ptr, rows_c, cols_c, scale_min, scale_max, fmt, bounds_min_x, bounds_min_y, bounds_max_x, bounds_max_y, flags),
        f32 => ImPlot_PlotHeatmapFloatPtr(label_id, values.ptr, rows_c, cols_c, scale_min, scale_max, fmt, bounds_min_x, bounds_min_y, bounds_max_x, bounds_max_y, flags),
        i32 => ImPlot_PlotHeatmapS32Ptr(label_id, values.ptr, rows_c, cols_c, scale_min, scale_max, fmt, bounds_min_x, bounds_min_y, bounds_max_x, bounds_max_y, flags),
        else => @compileError("plotHeatmap only supports f32, f64, and i32"),
    }
}

// ImPlot enums
pub const Colormap = enum(c_int) {
    Deep = 0,
    Dark = 1,
    Pastel = 2,
    Paired = 3,
    Viridis = 4,
    Plasma = 5,
    Hot = 6,
    Cool = 7,
    Pink = 8,
    Jet = 9,
    Twilight = 10,
    RdBu = 11,
    BrBG = 12,
    PiYG = 13,
    Spectral = 14,
    Greys = 15,
};

pub const Col = enum(c_int) {
    Line = 0,
    Fill = 1,
    MarkerOutline = 2,
    MarkerFill = 3,
    ErrorBar = 4,
    FrameBg = 5,
    PlotBg = 6,
    PlotBorder = 7,
    LegendBg = 8,
    LegendBorder = 9,
    LegendText = 10,
    TitleText = 11,
    InlayText = 12,
    AxisText = 13,
    AxisGrid = 14,
    AxisTick = 15,
    AxisBg = 16,
    AxisBgHovered = 17,
    AxisBgActive = 18,
    Selection = 19,
    Crosshairs = 20,
    COUNT = 21,
};

pub const AUTO = -1;
pub const AUTO_COL = Vec4{ .x = 0, .y = 0, .z = 0, .w = -1 };

pub const Vec4 = extern struct {
    x: f32,
    y: f32,
    z: f32,
    w: f32,
};

pub const Style = extern struct {
    LineWeight: f32,
    Marker: c_int,
    MarkerSize: f32,
    MarkerWeight: f32,
    FillAlpha: f32,
    ErrorBarSize: f32,
    ErrorBarWeight: f32,
    DigitalBitHeight: f32,
    DigitalBitGap: f32,
    PlotBorderSize: f32,
    MinorAlpha: f32,
    MajorTickLen: [2]f32,
    MinorTickLen: [2]f32,
    MajorTickSize: [2]f32,
    MinorTickSize: [2]f32,
    MajorGridSize: [2]f32,
    MinorGridSize: [2]f32,
    PlotPadding: [2]f32,
    LabelPadding: [2]f32,
    LegendPadding: [2]f32,
    LegendInnerPadding: [2]f32,
    LegendSpacing: [2]f32,
    MousePosPadding: [2]f32,
    AnnotationPadding: [2]f32,
    FitPadding: [2]f32,
    PlotDefaultSize: [2]f32,
    PlotMinSize: [2]f32,
    Colors: [21]Vec4,
    Colormap: c_int,
    UseLocalTime: bool,
    UseISO8601: bool,
    Use24HourClock: bool,
};

// Colormap functions
extern fn ImPlot_AddColormapVec4(name: [*:0]const u8, cols: [*]const Vec4, size: c_int, qual: bool) c_int;
extern fn ImPlot_AddColormapU32(name: [*:0]const u8, cols: [*]const u32, size: c_int, qual: bool) c_int;
extern fn ImPlot_GetColormapCount() c_int;
extern fn ImPlot_GetColormapName(cmap: c_int) [*:0]const u8;
extern fn ImPlot_GetColormapIndex(name: [*:0]const u8) c_int;
extern fn ImPlot_PushColormap(cmap: c_int) void;
extern fn ImPlot_PushColormapName(name: [*:0]const u8) void;
extern fn ImPlot_PopColormap(count: c_int) void;
extern fn ImPlot_NextColormapColor() Vec4;
extern fn ImPlot_GetColormapSize(cmap: c_int) c_int;
extern fn ImPlot_GetColormapColor(idx: c_int, cmap: c_int) Vec4;
extern fn ImPlot_SampleColormap(t: f32, cmap: c_int) Vec4;
extern fn ImPlot_ColormapScale(label: [*:0]const u8, scale_min: f64, scale_max: f64, width: f32, height: f32, format: [*:0]const u8, flags: c_int, cmap: c_int) void;
extern fn ImPlot_ColormapSlider(label: [*:0]const u8, t: *f32, out: ?*Vec4, format: [*:0]const u8, cmap: c_int) bool;
extern fn ImPlot_ColormapButton(label: [*:0]const u8, width: f32, height: f32, cmap: c_int) bool;
extern fn ImPlot_BustColorCache(plot_title_id: ?[*:0]const u8) void;

// Style color functions
extern fn ImPlot_PushStyleColorU32(idx: c_int, col: u32) void;
extern fn ImPlot_PushStyleColorVec4(idx: c_int, r: f32, g: f32, b: f32, a: f32) void;
extern fn ImPlot_PopStyleColor(count: c_int) void;

// Style functions
extern fn ImPlot_GetStyle() *Style;
extern fn ImPlot_StyleColorsAuto() void;
extern fn ImPlot_StyleColorsClassic() void;
extern fn ImPlot_StyleColorsDark() void;
extern fn ImPlot_StyleColorsLight() void;
extern fn ImPlot_GetStyleColorVec4(idx: c_int) Vec4;
extern fn ImPlot_SetStyleColorVec4(idx: c_int, r: f32, g: f32, b: f32, a: f32) void;
extern fn ImPlot_GetStyleColormap() c_int;
extern fn ImPlot_SetStyleColormap(cmap: c_int) void;

// Public API
pub fn addColormapVec4(name: [:0]const u8, cols: []const Vec4, qual: bool) Colormap {
    return @enumFromInt(ImPlot_AddColormapVec4(name.ptr, cols.ptr, @intCast(cols.len), qual));
}

pub fn addColormapU32(name: [:0]const u8, cols: []const u32, qual: bool) Colormap {
    return @enumFromInt(ImPlot_AddColormapU32(name.ptr, cols.ptr, @intCast(cols.len), qual));
}

pub fn getColormapCount() i32 {
    return ImPlot_GetColormapCount();
}

pub fn getColormapName(cmap: Colormap) [:0]const u8 {
    const ptr = ImPlot_GetColormapName(@intFromEnum(cmap));
    return std.mem.span(ptr);
}

pub fn getColormapIndex(name: [:0]const u8) ?Colormap {
    const idx = ImPlot_GetColormapIndex(name.ptr);
    if (idx < 0) return null;
    return @enumFromInt(idx);
}

pub fn pushColormap(cmap: Colormap) void {
    ImPlot_PushColormap(@intFromEnum(cmap));
}

pub fn pushColormapName(name: [:0]const u8) void {
    ImPlot_PushColormapName(name.ptr);
}

pub fn popColormap(count: i32) void {
    ImPlot_PopColormap(count);
}

pub fn nextColormapColor() Vec4 {
    return ImPlot_NextColormapColor();
}

pub fn getColormapSize(cmap: Colormap) i32 {
    return ImPlot_GetColormapSize(@intFromEnum(cmap));
}

pub fn getColormapColor(idx: i32, cmap: Colormap) Vec4 {
    return ImPlot_GetColormapColor(idx, @intFromEnum(cmap));
}

pub fn sampleColormap(t: f32, cmap: Colormap) Vec4 {
    return ImPlot_SampleColormap(t, @intFromEnum(cmap));
}

pub fn colormapScale(label: [:0]const u8, scale_min: f64, scale_max: f64, size: [2]f32, format: [:0]const u8, flags: c_int, cmap: Colormap) void {
    ImPlot_ColormapScale(label.ptr, scale_min, scale_max, size[0], size[1], format.ptr, flags, @intFromEnum(cmap));
}

pub fn colormapSlider(label: [:0]const u8, t: *f32, out: ?*Vec4, format: [:0]const u8, cmap: Colormap) bool {
    return ImPlot_ColormapSlider(label.ptr, t, out, format.ptr, @intFromEnum(cmap));
}

pub fn colormapButton(label: [:0]const u8, size: [2]f32, cmap: Colormap) bool {
    return ImPlot_ColormapButton(label.ptr, size[0], size[1], @intFromEnum(cmap));
}

pub fn bustColorCache(plot_title_id: ?[:0]const u8) void {
    const ptr = if (plot_title_id) |id| id.ptr else null;
    ImPlot_BustColorCache(ptr);
}

pub fn pushStyleColorU32(idx: Col, col: u32) void {
    ImPlot_PushStyleColorU32(@intFromEnum(idx), col);
}

pub fn pushStyleColor(idx: Col, color: Vec4) void {
    ImPlot_PushStyleColorVec4(@intFromEnum(idx), color.x, color.y, color.z, color.w);
}

pub fn popStyleColor(count: i32) void {
    ImPlot_PopStyleColor(count);
}

pub fn getStyle() *Style {
    return ImPlot_GetStyle();
}

pub fn styleColorsAuto() void {
    ImPlot_StyleColorsAuto();
}

pub fn styleColorsClassic() void {
    ImPlot_StyleColorsClassic();
}

pub fn styleColorsDark() void {
    ImPlot_StyleColorsDark();
}

pub fn styleColorsLight() void {
    ImPlot_StyleColorsLight();
}

pub fn getStyleColor(idx: Col) Vec4 {
    return ImPlot_GetStyleColorVec4(@intFromEnum(idx));
}

pub fn setStyleColor(idx: Col, color: Vec4) void {
    ImPlot_SetStyleColorVec4(@intFromEnum(idx), color.x, color.y, color.z, color.w);
}

pub fn getStyleColormap() Colormap {
    return @enumFromInt(ImPlot_GetStyleColormap());
}

pub fn setStyleColormap(cmap: Colormap) void {
    ImPlot_SetStyleColormap(@intFromEnum(cmap));
}
