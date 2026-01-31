#include "implot.h"

// Minimal Zig bindings for ImPlot
extern "C" {

// Context management
void ImPlot_CreateContext() {
    ImPlot::CreateContext();
}

void ImPlot_DestroyContext() {
    ImPlot::DestroyContext(nullptr);
}

// Plot management
bool ImPlot_BeginPlot(const char* title_id, float width, float height, ImPlotFlags flags) {
    return ImPlot::BeginPlot(title_id, ImVec2(width, height), flags);
}

void ImPlot_EndPlot() {
    ImPlot::EndPlot();
}

// Setup
void ImPlot_SetupAxisLimits(ImAxis axis, double v_min, double v_max, ImPlotCond cond) {
    ImPlot::SetupAxisLimits(axis, v_min, v_max, cond);
}

// Plot functions
void ImPlot_PlotLineDoublePtr(const char* label_id, const double* xs, const double* ys, int count, ImPlotLineFlags flags, int offset, int stride) {
    ImPlot::PlotLine(label_id, xs, ys, count, flags, offset, stride);
}

void ImPlot_PlotLineFloatPtr(const char* label_id, const float* xs, const float* ys, int count, ImPlotLineFlags flags, int offset, int stride) {
    ImPlot::PlotLine(label_id, xs, ys, count, flags, offset, stride);
}

void ImPlot_PlotLineS32Ptr(const char* label_id, const int* xs, const int* ys, int count, ImPlotLineFlags flags, int offset, int stride) {
    ImPlot::PlotLine(label_id, xs, ys, count, flags, offset, stride);
}

} // extern "C"