//
// C bindings for ImNodesEz library (includes both ImNodes and ImNodesEz APIs)
//
#ifndef IMGUI_DEFINE_MATH_OPERATORS
#   define IMGUI_DEFINE_MATH_OPERATORS
#endif

#include "ImNodes.h"
#include "ImNodesEz.h"
#include <imgui.h>

// Thread-local storage for current node position (fixes the pointer lifetime issue)
struct NodePosData {
    ImVec2 pos;
    float* out_x;
    float* out_y;
};

static thread_local NodePosData g_current_node_pos = {};

extern "C" {

//=============================================================================
// ImNodesEz::Context API
//=============================================================================

void* ImNodesEz_CreateContext()
{
    return ImNodes::Ez::CreateContext();
}

void ImNodesEz_FreeContext(void* ctx)
{
    ImNodes::Ez::FreeContext(static_cast<ImNodes::Ez::Context*>(ctx));
}

void ImNodesEz_SetContext(void* ctx)
{
    ImNodes::Ez::SetContext(static_cast<ImNodes::Ez::Context*>(ctx));
}

ImNodes::CanvasState* ImNodesEz_GetState()
{
    return &ImNodes::Ez::GetState();
}

//=============================================================================
// ImNodesEz Canvas API
//=============================================================================

void ImNodesEz_BeginCanvas()
{
    ImNodes::Ez::BeginCanvas();
}

void ImNodesEz_EndCanvas()
{
    ImNodes::Ez::EndCanvas();
}

//=============================================================================
// ImNodesEz Node API
//=============================================================================

bool ImNodesEz_BeginNode(void* node_id, const char* title, float* pos_x, float* pos_y, bool* selected)
{
    // Store position in thread-local storage
    g_current_node_pos.pos.x = *pos_x;
    g_current_node_pos.pos.y = *pos_y;
    g_current_node_pos.out_x = pos_x;
    g_current_node_pos.out_y = pos_y;
    
    // Pass thread-local pointer to library
    return ImNodes::Ez::BeginNode(node_id, title, &g_current_node_pos.pos, selected);
}

void ImNodesEz_EndNode()
{
    ImNodes::Ez::EndNode();
    
    // Write back the potentially modified position
    if (g_current_node_pos.out_x && g_current_node_pos.out_y) {
        *g_current_node_pos.out_x = g_current_node_pos.pos.x;
        *g_current_node_pos.out_y = g_current_node_pos.pos.y;
    }
}

//=============================================================================
// ImNodesEz Slot API
//=============================================================================

void ImNodesEz_InputSlots(const ImNodes::Ez::SlotInfo* slots, int snum)
{
    ImNodes::Ez::InputSlots(slots, snum);
}

void ImNodesEz_OutputSlots(const ImNodes::Ez::SlotInfo* slots, int snum)
{
    ImNodes::Ez::OutputSlots(slots, snum);
}

//=============================================================================
// ImNodesEz Connection API
//=============================================================================

bool ImNodesEz_Connection(void* input_node, const char* input_slot, void* output_node, const char* output_slot)
{
    return ImNodes::Ez::Connection(input_node, input_slot, output_node, output_slot);
}

//=============================================================================
// ImNodesEz Style API
//=============================================================================

void ImNodesEz_PushStyleVarFloat(int idx, float val)
{
    ImNodes::Ez::PushStyleVar(static_cast<ImNodesStyleVar>(idx), val);
}

void ImNodesEz_PushStyleVarVec2(int idx, float x, float y)
{
    ImNodes::Ez::PushStyleVar(static_cast<ImNodesStyleVar>(idx), ImVec2(x, y));
}

void ImNodesEz_PopStyleVar(int count)
{
    ImNodes::Ez::PopStyleVar(count);
}

void ImNodesEz_PushStyleColorU32(int idx, unsigned int col)
{
    ImNodes::Ez::PushStyleColor(static_cast<ImNodesStyleCol>(idx), col);
}

void ImNodesEz_PushStyleColorVec4(int idx, float r, float g, float b, float a)
{
    ImNodes::Ez::PushStyleColor(static_cast<ImNodesStyleCol>(idx), ImVec4(r, g, b, a));
}

void ImNodesEz_PopStyleColor(int count)
{
    ImNodes::Ez::PopStyleColor(count);
}

//=============================================================================
// ImNodes Base Canvas API
//=============================================================================

ImNodes::CanvasState* ImNodes_CreateCanvasState()
{
    return new ImNodes::CanvasState();
}

void ImNodes_DeleteCanvasState(ImNodes::CanvasState* state)
{
    delete state;
}

void ImNodes_BeginCanvas(ImNodes::CanvasState* canvas)
{
    ImNodes::BeginCanvas(canvas);
}

void ImNodes_EndCanvas()
{
    ImNodes::EndCanvas();
}

ImNodes::CanvasState* ImNodes_GetCurrentCanvas()
{
    return ImNodes::GetCurrentCanvas();
}

//=============================================================================
// ImNodes Base Node API
//=============================================================================

bool ImNodes_BeginNode(void* node_id, float* pos_x, float* pos_y, bool* selected)
{
    // Store position in thread-local storage
    g_current_node_pos.pos.x = *pos_x;
    g_current_node_pos.pos.y = *pos_y;
    g_current_node_pos.out_x = pos_x;
    g_current_node_pos.out_y = pos_y;
    
    // Pass thread-local pointer to library
    return ImNodes::BeginNode(node_id, &g_current_node_pos.pos, selected);
}

void ImNodes_EndNode()
{
    ImNodes::EndNode();
    
    // Write back the potentially modified position
    if (g_current_node_pos.out_x && g_current_node_pos.out_y) {
        *g_current_node_pos.out_x = g_current_node_pos.pos.x;
        *g_current_node_pos.out_y = g_current_node_pos.pos.y;
    }
}

bool ImNodes_IsNodeHovered()
{
    return ImNodes::IsNodeHovered();
}

void ImNodes_AutoPositionNode(void* node_id)
{
    ImNodes::AutoPositionNode(node_id);
}

//=============================================================================
// ImNodes Base Slot API
//=============================================================================

bool ImNodes_BeginSlot(const char* title, int kind)
{
    return ImNodes::BeginSlot(title, kind);
}

void ImNodes_EndSlot()
{
    ImNodes::EndSlot();
}

bool ImNodes_IsSlotCurveHovered()
{
    return ImNodes::IsSlotCurveHovered();
}

bool ImNodes_IsConnectingCompatibleSlot()
{
    return ImNodes::IsConnectingCompatibleSlot();
}

//=============================================================================
// ImNodes Base Connection API
//=============================================================================

bool ImNodes_GetNewConnection(void** input_node, const char** input_slot_title, void** output_node, const char** output_slot_title)
{
    return ImNodes::GetNewConnection(input_node, input_slot_title, output_node, output_slot_title);
}

bool ImNodes_GetPendingConnection(void** node_id, const char** slot_title, int* slot_kind)
{
    return ImNodes::GetPendingConnection(node_id, slot_title, slot_kind);
}

bool ImNodes_Connection(void* input_node, const char* input_slot, void* output_node, const char* output_slot)
{
    return ImNodes::Connection(input_node, input_slot, output_node, output_slot);
}

//=============================================================================
// CanvasState property accessors
//=============================================================================

float ImNodes_CanvasState_GetZoom(ImNodes::CanvasState* state)
{
    return state->Zoom;
}

void ImNodes_CanvasState_SetZoom(ImNodes::CanvasState* state, float zoom)
{
    state->Zoom = zoom;
}

void ImNodes_CanvasState_GetOffset(ImNodes::CanvasState* state, float* x, float* y)
{
    *x = state->Offset.x;
    *y = state->Offset.y;
}

void ImNodes_CanvasState_SetOffset(ImNodes::CanvasState* state, float x, float y)
{
    state->Offset.x = x;
    state->Offset.y = y;
}

} // extern "C"