// imnodes_zig.cpp
#include "imnodes.h"

extern "C" {

// Context
void imnodes_create_context() {
    ImNodes::CreateContext();
}
void imnodes_destroy_context() {
    ImNodes::DestroyContext();
}

// Node editor
void imnodes_begin_node_editor() {
    ImNodes::BeginNodeEditor();
}
void imnodes_end_node_editor() {
    ImNodes::EndNodeEditor();
}

// Node
void imnodes_begin_node(int id) {
    ImNodes::BeginNode(id);
}
void imnodes_end_node() {
    ImNodes::EndNode();
}

void imnodes_begin_node_title_bar() {
    ImNodes::BeginNodeTitleBar();
}

void imnodes_end_node_title_bar() {
    ImNodes::EndNodeTitleBar();
}

void imnodes_begin_input_attribute(int id) {
    ImNodes::BeginInputAttribute(id);
}

void imnodes_end_input_attribute() {
    ImNodes::EndInputAttribute();
}

void imnodes_begin_output_attribute(int id) {
    ImNodes::BeginOutputAttribute(id);
}

void imnodes_end_output_attribute() {
    ImNodes::EndOutputAttribute();
}

void imnodes_minimap() {
    ImNodes::MiniMap();
}

void imnodes_link(int id, int start_attribute_id, int end_attribute_id) {
    ImNodes::Link(id, start_attribute_id, end_attribute_id);
}

}