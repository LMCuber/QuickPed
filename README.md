# Agent based pedestrian simulation using a social force model

To view the paper we have written on this subject: [overleaf link](https://www.overleaf.com/project/66f667ffb591f8ff65cffdd8) (broken)

* Go to the [backlog](#project-backlog) to see the planned features.
* Go to [my previous Python implementation](github.com/lmcuber/agentbasedmodel) without a node editor for some spaghetti code

# Preview
![main](previews/main.png "main")
![node editor](previews/node_editor.png "node editor")

# Version support
⚠️ **This project currently supports `zig` versions up to 0.13.0.**  
Later Zig versions are not guaranteed to build correctly.

# Planned features
- [x] Social force model for pedestrians
- [x] A functioning Node system
- [ ] Statistics
    - [x] Showing number of (waiting) pedestrians
    - [ ] Heatmap showing bottlenecks during simulation
- [ ] Advanced environmental objects
    - [ ] queues
    - [ ] revolving doors
- [ ] *A\** pathfinding for the pedestrians
- [ ] Quadtree for collisions

## Won't haves
- _**Any type of scripting support**_<br>
The project should maximize development time and ease of use. I might implement it later when I see that the base nodes in the editor aren't enough to express complex interactions that are complex enough.
- _**Others means of agent simulation, such as vehicles or industrial processes**_<br>
This refers to other businesses, such as transport systems and factory pipelines. Those are currently way beyond the scope of the project.

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

## Disclaimer

This project uses the [zig-raylib-imgui-template](https://github.com/schmee/zig-raylib-imgui-template), and uses:
- `zig`
- `raylib`
- `ImGui`
- `raylib-zig`
- `zgui`
- `rlImGui`
- `imnodes`
- `implot`
