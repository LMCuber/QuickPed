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

//---------------------------------------------
// Zig API
//---------------------------------------------
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
