# Agent based pedestrian simulation using a social force model

To view the paper we have written on this subject: paper link
Go to the [backlog](#project-backlog) to see the (not) implemented features.

# Version support
⚠️ **This project currently supports Zig up to version 0.13.0.**  
Later Zig versions are not guaranteed to build correctly.

% Source - https://stackoverflow.com/a
% Posted by Juli, modified by community. See post 'Timeline' for change history
% Retrieved 2025-12-22, License - CC BY-SA 4.0

# Project backlog
- [x] Social force model for pedestrians
- [x] Basic UI for changing parameters
- [ ] Quadtree for collisions
- [ ] Node system

## Won't haves
- _Macroscoping modeling_
The scope of this project is microscopic agent-based modeling
- _Any type of scripting support_
The project should maximize development time and ease of use. Scripting is a fast turn-off for non-coders.
- _Others means of agent simulation, such as vehicles or industrial processes_
This would substantially increase the scope and complexity of the project, and should either be an add-on or a separate application altogether.

# How to run
```
./build.sh
```
or
```bash
zig build run
```
or
```bash
zigup run 0.13.0 build run
```
if you have [zigup](https://github.com/marler8997/zigup) installed.

This project uses the [zig-raylib-imgui-template](https://github.com/schmee/zig-raylib-imgui-template), and uses:
- `zig` (language)
- `raylib` (multimedia)
- `ImGui` (immediate mode UI)
- `raylib-zig` (zig bindings for raylib)
- `zgui` (zig bindings for ImGui)
- `rlImGui` (connection between raylib and ImGui pipeline)
- `imnodes` (node editor extension for ImGui)
