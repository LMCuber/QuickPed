# Agent based pedestrian simulation using a social force model

To view the paper we have written on this subject: [overleaf link](https://www.overleaf.com/project/66f667ffb591f8ff65cffdd8) (might be restricted; working on statically hosting on GitHub)

* Go to the [backlog](#project-backlog) to see the planned features.

# Preview
![main](previews/main.png "main")
![node editor](previews/node_editor.png "node editor")

# Version support
⚠️ **This project currently supports `zig` versions up to 0.13.0.**  
Later Zig versions are not guaranteed to build correctly.

# Project backlog
- [x] 🔴 Social force model for pedestrians
- [x] 🔴 Basic UI for changing parameters
- [x] 🔴 Placing environmental objects + persistence across runs
- [ ] 🔴 Node system (*WIP*)
- [ ] 🔴 Advanced environmental objects:
    - [ ] queues
    - [ ] revolving doors
- [ ] 🔴 *A\** pathfinding for the pedestrians
- [ ] 🟠 Statistics
- [ ] 🟠 Editing environmental objects after creation
- [ ] 🟠 Quadtree for collisions
- [ ] 🟡 Heatmap showing bottlenecks during simulation

## Won't haves
- **Macroscoping modeling**<br>
The scope of this project is microscopic agent-based modeling.
- **Any type of scripting support**
The project should maximize development time and ease of use. Scripting is a fast turn-off for non-coders and overcomplicates things.
- **Others means of agent simulation, such as vehicles or industrial processes**
This would substantially increase the scope and complexity of the project, and should either be an add-on or a separate application altogether.

# How to run
```
./run.sh
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
I have written `zig` bindings for some `imnodes` functions, so I may make `imnodes` a submodule to my `zig` `imnodes` port in the future.
