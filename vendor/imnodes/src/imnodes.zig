//---------------------------------------------
// Extern function declarations
//---------------------------------------------
extern fn imnodes_create_context() void;
extern fn imnodes_destroy_context() void;

extern fn imnodes_begin_node_editor() void;
extern fn imnodes_end_node_editor() void;

extern fn imnodes_begin_node(id: i32) void;
extern fn imnodes_end_node() void;

extern fn imnodes_begin_node_title_bar() void;
extern fn imnodes_end_node_title_bar() void;

extern fn imnodes_begin_input_attribute(id: i32) void;
extern fn imnodes_end_input_attribute() void;

extern fn imnodes_begin_output_attribute(id: i32) void;
extern fn imnodes_end_output_attribute() void;

extern fn imnodes_minimap() void;
extern fn imnodes_link(id: i32, start_id: i32, end_id: i32) void;

extern fn imnodes_is_editor_hovered() bool;

extern fn imnodes_push_color_style(item: ImNodesCol, color: u32) void;
extern fn imnodes_pop_color_style() void;

extern fn imnodes_is_link_created(start_attr: *i32, end_attr: *i32) bool;
extern fn imnodes_is_link_destroyed(link_id: *i32) bool;

// enums
pub const ImNodesCol = enum(c_int) {
    ImNodesCol_NodeBackground,
    ImNodesCol_NodeBackgroundHovered,
    ImNodesCol_NodeBackgroundSelected,
    ImNodesCol_NodeOutline,
    ImNodesCol_TitleBar,
    ImNodesCol_TitleBarHovered,
    ImNodesCol_TitleBarSelected,
    ImNodesCol_Link,
    ImNodesCol_LinkHovered,
    ImNodesCol_LinkSelected,
    ImNodesCol_Pin,
    ImNodesCol_PinHovered,
    ImNodesCol_BoxSelector,
    ImNodesCol_BoxSelectorOutline,
    ImNodesCol_GridBackground,
    ImNodesCol_GridLine,
    ImNodesCol_GridLinePrimary,
    ImNodesCol_MiniMapBackground,
    ImNodesCol_MiniMapBackgroundHovered,
    ImNodesCol_MiniMapOutline,
    ImNodesCol_MiniMapOutlineHovered,
    ImNodesCol_MiniMapNodeBackground,
    ImNodesCol_MiniMapNodeBackgroundHovered,
    ImNodesCol_MiniMapNodeBackgroundSelected,
    ImNodesCol_MiniMapNodeOutline,
    ImNodesCol_MiniMapLink,
    ImNodesCol_MiniMapLinkSelected,
    ImNodesCol_MiniMapCanvas,
    ImNodesCol_MiniMapCanvasOutline,
    ImNodesCol_COUNT,
};

// Zig API
pub fn createContext() void {
    imnodes_create_context();
}

pub fn destroyContext() void {
    imnodes_destroy_context();
}

pub fn beginNodeEditor() void {
    imnodes_begin_node_editor();
}

pub fn endNodeEditor() void {
    imnodes_end_node_editor();
}

pub fn beginNode(id: i32) void {
    imnodes_begin_node(id);
}

pub fn endNode() void {
    imnodes_end_node();
}

pub fn beginNodeTitleBar() void {
    imnodes_begin_node_title_bar();
}

pub fn endNodeTitleBar() void {
    imnodes_end_node_title_bar();
}

pub fn beginInputAttribute(id: i32) void {
    imnodes_begin_input_attribute(id);
}

pub fn endInputAttribute() void {
    imnodes_end_input_attribute();
}

pub fn beginOutputAttribute(id: i32) void {
    imnodes_begin_output_attribute(id);
}

pub fn endOutputAttribute() void {
    imnodes_end_output_attribute();
}

pub fn minimap() void {
    imnodes_minimap();
}

pub fn link(id: i32, start_attribute_id: i32, end_attribute_id: i32) void {
    imnodes_link(id, start_attribute_id, end_attribute_id);
}

pub fn isEditorHovered() bool {
    return imnodes_is_editor_hovered();
}

pub fn pushColorStyle(item: ImNodesCol, color: u32) void {
    return imnodes_push_color_style(item, color);
}

pub fn popColorStyle() void {
    return imnodes_pop_color_style();
}

pub fn isLinkCreated(start_attr: *i32, end_attr: *i32) bool {
    return imnodes_is_link_created(start_attr, end_attr);
}

pub fn isLinkDestroyed(link_id: *i32) bool {
    return imnodes_is_link_destroyed(link_id);
}
