const std = @import("std");

//=============================================================================
// Common Types
//=============================================================================

pub const Vec2 = extern struct {
    x: f32,
    y: f32,

    pub fn init(x: f32, y: f32) Vec2 {
        return .{ .x = x, .y = y };
    }
};

//=============================================================================
// ImNodes (Base API) - Low-level node graph - GLOBAL NAMESPACE
//=============================================================================

/// Opaque canvas state pointer
pub const CanvasState = opaque {};

// External C functions
extern "c" fn ImNodes_CreateCanvasState() *CanvasState;
extern "c" fn ImNodes_DeleteCanvasState(state: *CanvasState) void;
extern "c" fn ImNodes_BeginCanvas(canvas: *CanvasState) void;
extern "c" fn ImNodes_EndCanvas() void;
extern "c" fn ImNodes_GetCurrentCanvas() ?*CanvasState;
extern "c" fn ImNodes_BeginNode(node_id: *anyopaque, pos_x: *f32, pos_y: *f32, selected: *bool) bool;
extern "c" fn ImNodes_EndNode() void;
extern "c" fn ImNodes_IsNodeHovered() bool;
extern "c" fn ImNodes_AutoPositionNode(node_id: *anyopaque) void;
extern "c" fn ImNodes_BeginSlot(title: [*c]const u8, kind: c_int) bool;
extern "c" fn ImNodes_EndSlot() void;
extern "c" fn ImNodes_IsSlotCurveHovered() bool;
extern "c" fn ImNodes_IsConnectingCompatibleSlot() bool;
extern "c" fn ImNodes_GetNewConnection(input_node: *?*anyopaque, input_slot_title: *[*c]const u8, output_node: *?*anyopaque, output_slot_title: *[*c]const u8) bool;
extern "c" fn ImNodes_GetPendingConnection(node_id: *?*anyopaque, slot_title: *[*c]const u8, slot_kind: *c_int) bool;
extern "c" fn ImNodes_Connection(input_node: *anyopaque, input_slot: [*c]const u8, output_node: *anyopaque, output_slot: [*c]const u8) bool;
extern "c" fn ImNodes_CanvasState_GetZoom(state: *CanvasState) f32;
extern "c" fn ImNodes_CanvasState_SetZoom(state: *CanvasState, zoom: f32) void;
extern "c" fn ImNodes_CanvasState_GetOffset(state: *CanvasState, x: *f32, y: *f32) void;
extern "c" fn ImNodes_CanvasState_SetOffset(state: *CanvasState, x: f32, y: f32) void;

// Wrapper functions - Global namespace
pub fn createCanvasState() *CanvasState {
    return ImNodes_CreateCanvasState();
}

pub fn deleteCanvasState(state: *CanvasState) void {
    ImNodes_DeleteCanvasState(state);
}

pub fn beginCanvas(canvas: *CanvasState) void {
    ImNodes_BeginCanvas(canvas);
}

pub fn endCanvas() void {
    ImNodes_EndCanvas();
}

pub fn getCurrentCanvas() ?*CanvasState {
    return ImNodes_GetCurrentCanvas();
}

pub fn beginNode(node_id: *anyopaque, pos: *Vec2, selected: *bool) bool {
    return ImNodes_BeginNode(node_id, &pos.x, &pos.y, selected);
}

pub fn endNode() void {
    ImNodes_EndNode();
}

pub fn isNodeHovered() bool {
    return ImNodes_IsNodeHovered();
}

pub fn autoPositionNode(node_id: *anyopaque) void {
    ImNodes_AutoPositionNode(node_id);
}

pub fn beginSlot(title: [*c]const u8, kind: c_int) bool {
    return ImNodes_BeginSlot(title, kind);
}

pub fn endSlot() void {
    ImNodes_EndSlot();
}

pub fn isSlotCurveHovered() bool {
    return ImNodes_IsSlotCurveHovered();
}

pub fn isConnectingCompatibleSlot() bool {
    return ImNodes_IsConnectingCompatibleSlot();
}

pub fn getNewConnection(input_node: *?*anyopaque, input_slot_title: *[*c]const u8, output_node: *?*anyopaque, output_slot_title: *[*c]const u8) bool {
    return ImNodes_GetNewConnection(input_node, input_slot_title, output_node, output_slot_title);
}

pub fn getPendingConnection(node_id: *?*anyopaque, slot_title: *[*c]const u8, slot_kind: *c_int) bool {
    return ImNodes_GetPendingConnection(node_id, slot_title, slot_kind);
}

pub fn connection(input_node: *anyopaque, input_slot: [*c]const u8, output_node: *anyopaque, output_slot: [*c]const u8) bool {
    return ImNodes_Connection(input_node, input_slot, output_node, output_slot);
}

// CanvasState utilities
pub fn getZoom(state: *CanvasState) f32 {
    return ImNodes_CanvasState_GetZoom(state);
}

pub fn setZoom(state: *CanvasState, zoom: f32) void {
    ImNodes_CanvasState_SetZoom(state, zoom);
}

pub fn getOffset(state: *CanvasState) Vec2 {
    var result: Vec2 = undefined;
    ImNodes_CanvasState_GetOffset(state, &result.x, &result.y);
    return result;
}

pub fn setOffset(state: *CanvasState, offset: Vec2) void {
    ImNodes_CanvasState_SetOffset(state, offset.x, offset.y);
}

// Slot kind helpers
pub fn inputSlotKind(kind: c_int) c_int {
    return if (kind > 0) -kind else kind;
}

pub fn outputSlotKind(kind: c_int) c_int {
    return if (kind < 0) -kind else kind;
}

pub fn isInputSlotKind(kind: c_int) bool {
    return kind < 0;
}

pub fn isOutputSlotKind(kind: c_int) bool {
    return kind > 0;
}

//=============================================================================
// ImNodesEz (Easy API) - High-level node graph - EZ NAMESPACE
//=============================================================================

pub const ez = struct {
    /// Opaque context pointer
    pub const Context = opaque {};

    /// SlotInfo struct for defining slots
    pub const SlotInfo = extern struct {
        title: [*c]const u8,
        kind: c_int,

        pub fn init(title: [*c]const u8, kind: c_int) SlotInfo {
            return .{ .title = title, .kind = kind };
        }
    };

    /// Style variable types
    pub const StyleVar = enum(c_int) {
        grid_spacing = 0,
        curve_thickness = 1,
        curve_strength = 2,
        slot_radius = 3,
        node_rounding = 4,
        node_spacing = 5,
        item_spacing = 6,
    };

    /// Style color types
    pub const StyleCol = enum(c_int) {
        grid_lines = 0,
        node_body_bg = 1,
        node_body_bg_hovered = 2,
        node_body_bg_active = 3,
        node_border = 4,
        connection = 5,
        connection_active = 6,
        select_bg = 7,
        select_border = 8,
        node_title_bar_bg = 9,
        node_title_bar_bg_hovered = 10,
        node_title_bar_bg_active = 11,
    };

    // External C functions
    extern "c" fn ImNodesEz_CreateContext() ?*Context;
    extern "c" fn ImNodesEz_FreeContext(ctx: *Context) void;
    extern "c" fn ImNodesEz_SetContext(ctx: *Context) void;
    extern "c" fn ImNodesEz_GetState() *CanvasState;
    extern "c" fn ImNodesEz_BeginCanvas() void;
    extern "c" fn ImNodesEz_EndCanvas() void;
    extern "c" fn ImNodesEz_BeginNode(node_id: *anyopaque, title: [*c]const u8, pos_x: *f32, pos_y: *f32, selected: *bool) bool;
    extern "c" fn ImNodesEz_EndNode() void;
    extern "c" fn ImNodesEz_InputSlots(slots: [*c]const SlotInfo, snum: c_int) void;
    extern "c" fn ImNodesEz_OutputSlots(slots: [*c]const SlotInfo, snum: c_int) void;
    extern "c" fn ImNodesEz_Connection(input_node: *anyopaque, input_slot: [*c]const u8, output_node: *anyopaque, output_slot: [*c]const u8) bool;
    extern "c" fn ImNodesEz_PushStyleVarFloat(idx: c_int, val: f32) void;
    extern "c" fn ImNodesEz_PushStyleVarVec2(idx: c_int, x: f32, y: f32) void;
    extern "c" fn ImNodesEz_PopStyleVar(count: c_int) void;
    extern "c" fn ImNodesEz_PushStyleColorU32(idx: c_int, col: u32) void;
    extern "c" fn ImNodesEz_PushStyleColorVec4(idx: c_int, r: f32, g: f32, b: f32, a: f32) void;
    extern "c" fn ImNodesEz_PopStyleColor(count: c_int) void;

    // Wrapper functions
    pub fn createContext() ?*Context {
        return ImNodesEz_CreateContext();
    }

    pub fn freeContext(ctx: *Context) void {
        ImNodesEz_FreeContext(ctx);
    }

    pub fn setContext(ctx: *Context) void {
        ImNodesEz_SetContext(ctx);
    }

    pub fn getState() *CanvasState {
        return ImNodesEz_GetState();
    }

    pub fn beginCanvas() void {
        ImNodesEz_BeginCanvas();
    }

    pub fn endCanvas() void {
        ImNodesEz_EndCanvas();
    }

    pub fn beginNode(node_id: *anyopaque, title: [*c]const u8, pos: *Vec2, selected: *bool) bool {
        return ImNodesEz_BeginNode(node_id, title, &pos.x, &pos.y, selected);
    }

    pub fn endNode() void {
        ImNodesEz_EndNode();
    }

    pub fn inputSlots(slots: []const SlotInfo) void {
        ImNodesEz_InputSlots(slots.ptr, @intCast(slots.len));
    }

    pub fn outputSlots(slots: []const SlotInfo) void {
        ImNodesEz_OutputSlots(slots.ptr, @intCast(slots.len));
    }

    pub fn connection(input_node: *anyopaque, input_slot: [*c]const u8, output_node: *anyopaque, output_slot: [*c]const u8) bool {
        return ImNodesEz_Connection(input_node, input_slot, output_node, output_slot);
    }

    pub fn pushStyleVar(idx: StyleVar, val: f32) void {
        ImNodesEz_PushStyleVarFloat(@intFromEnum(idx), val);
    }

    pub fn pushStyleVarVec2(idx: StyleVar, vec: Vec2) void {
        ImNodesEz_PushStyleVarVec2(@intFromEnum(idx), vec.x, vec.y);
    }

    pub fn popStyleVar(count: c_int) void {
        ImNodesEz_PopStyleVar(count);
    }

    pub fn pushStyleColor(idx: StyleCol, col: u32) void {
        ImNodesEz_PushStyleColorU32(@intFromEnum(idx), col);
    }

    pub fn pushStyleColorVec4(idx: StyleCol, r: f32, g: f32, b: f32, a: f32) void {
        ImNodesEz_PushStyleColorVec4(@intFromEnum(idx), r, g, b, a);
    }

    pub fn popStyleColor(count: c_int) void {
        ImNodesEz_PopStyleColor(count);
    }
};
