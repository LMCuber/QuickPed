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

// Heatmap
void ImPlot_PlotHeatmapFloatPtr(const char* label_id, const float* values, int rows, int cols, double scale_min, double scale_max, const char* fmt, double bounds_min_x, double bounds_min_y, double bounds_max_x, double bounds_max_y, ImPlotHeatmapFlags flags) {
    ImPlot::PlotHeatmap(label_id, values, rows, cols, scale_min, scale_max, fmt, ImPlotPoint(bounds_min_x, bounds_min_y), ImPlotPoint(bounds_max_x, bounds_max_y), flags);
}

void ImPlot_PlotHeatmapDoublePtr(const char* label_id, const double* values, int rows, int cols, double scale_min, double scale_max, const char* fmt, double bounds_min_x, double bounds_min_y, double bounds_max_x, double bounds_max_y, ImPlotHeatmapFlags flags) {
    ImPlot::PlotHeatmap(label_id, values, rows, cols, scale_min, scale_max, fmt, ImPlotPoint(bounds_min_x, bounds_min_y), ImPlotPoint(bounds_max_x, bounds_max_y), flags);
}

void ImPlot_PlotHeatmapS32Ptr(const char* label_id, const int* values, int rows, int cols, double scale_min, double scale_max, const char* fmt, double bounds_min_x, double bounds_min_y, double bounds_max_x, double bounds_max_y, ImPlotHeatmapFlags flags) {
    ImPlot::PlotHeatmap(label_id, values, rows, cols, scale_min, scale_max, fmt, ImPlotPoint(bounds_min_x, bounds_min_y), ImPlotPoint(bounds_max_x, bounds_max_y), flags);
}

// Colormap management
ImPlotColormap ImPlot_AddColormapVec4(const char* name, const ImVec4* cols, int size, bool qual) {
    return ImPlot::AddColormap(name, cols, size, qual);
}

ImPlotColormap ImPlot_AddColormapU32(const char* name, const unsigned int* cols, int size, bool qual) {
    return ImPlot::AddColormap(name, cols, size, qual);
}

int ImPlot_GetColormapCount() {
    return ImPlot::GetColormapCount();
}

const char* ImPlot_GetColormapName(ImPlotColormap cmap) {
    return ImPlot::GetColormapName(cmap);
}

ImPlotColormap ImPlot_GetColormapIndex(const char* name) {
    return ImPlot::GetColormapIndex(name);
}

void ImPlot_PushColormap(ImPlotColormap cmap) {
    ImPlot::PushColormap(cmap);
}

void ImPlot_PushColormapName(const char* name) {
    ImPlot::PushColormap(name);
}

void ImPlot_PopColormap(int count) {
    ImPlot::PopColormap(count);
}

ImVec4 ImPlot_NextColormapColor() {
    return ImPlot::NextColormapColor();
}

int ImPlot_GetColormapSize(ImPlotColormap cmap) {
    return ImPlot::GetColormapSize(cmap);
}

ImVec4 ImPlot_GetColormapColor(int idx, ImPlotColormap cmap) {
    return ImPlot::GetColormapColor(idx, cmap);
}

ImVec4 ImPlot_SampleColormap(float t, ImPlotColormap cmap) {
    return ImPlot::SampleColormap(t, cmap);
}

void ImPlot_ColormapScale(const char* label, double scale_min, double scale_max, float width, float height, const char* format, ImPlotColormapScaleFlags flags, ImPlotColormap cmap) {
    ImPlot::ColormapScale(label, scale_min, scale_max, ImVec2(width, height), format, flags, cmap);
}

bool ImPlot_ColormapSlider(const char* label, float* t, ImVec4* out, const char* format, ImPlotColormap cmap) {
    return ImPlot::ColormapSlider(label, t, out, format, cmap);
}

bool ImPlot_ColormapButton(const char* label, float width, float height, ImPlotColormap cmap) {
    return ImPlot::ColormapButton(label, ImVec2(width, height), cmap);
}

void ImPlot_BustColorCache(const char* plot_title_id) {
    ImPlot::BustColorCache(plot_title_id);
}

// Style color management
void ImPlot_PushStyleColorU32(ImPlotCol idx, unsigned int col) {
    ImPlot::PushStyleColor(idx, col);
}

void ImPlot_PushStyleColorVec4(ImPlotCol idx, float r, float g, float b, float a) {
    ImPlot::PushStyleColor(idx, ImVec4(r, g, b, a));
}

void ImPlot_PopStyleColor(int count) {
    ImPlot::PopStyleColor(count);
}

// Style access
ImPlotStyle* ImPlot_GetStyle() {
    return &ImPlot::GetStyle();
}

void ImPlot_StyleColorsAuto() {
    ImPlot::StyleColorsAuto();
}

void ImPlot_StyleColorsClassic() {
    ImPlot::StyleColorsClassic();
}

void ImPlot_StyleColorsDark() {
    ImPlot::StyleColorsDark();
}

void ImPlot_StyleColorsLight() {
    ImPlot::StyleColorsLight();
}

// Style getters/setters
ImVec4 ImPlot_GetStyleColorVec4(ImPlotCol idx) {
    return ImPlot::GetStyle().Colors[idx];
}

void ImPlot_SetStyleColorVec4(ImPlotCol idx, float r, float g, float b, float a) {
    ImPlot::GetStyle().Colors[idx] = ImVec4(r, g, b, a);
}

int ImPlot_GetStyleColormap() {
    return ImPlot::GetStyle().Colormap;
}

void ImPlot_SetStyleColormap(ImPlotColormap cmap) {
    ImPlot::GetStyle().Colormap = cmap;
}

} // extern "C"