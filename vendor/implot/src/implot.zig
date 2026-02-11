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
