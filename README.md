# Terragen

Terragen is a Love2D voxel world prototype with procedural chunk generation, biome-driven terrain, caves/resources, and a first-person 3D renderer.

## Requirements

- [LOVE](https://love2d.org/) 11.5
- Windows/macOS/Linux capable of running Love2D 11.x

## Run

From the project root:

```bash
love .
```

## Current Controls

- `W/A/S/D`: Move
- `Mouse`: Look
- `Space`: Jump (or fly up while flying)
- `Shift`: Sprint (ground) / descend (flying)
- `F`: Toggle flight mode
- `Tab`: Toggle mouse capture
- `R`: Regenerate world with next seed
- `F1..F8`: Debug overlay modes (`F8` noise preview)
- `F9`: Cycle performance tier
- `F10` (or `V`): Toggle render mode (`mesh3d` / `voxelspace32`)
- `Esc`: Quit

## What Exists Today

- Procedural worldgen pipeline with ordered stages:
  - terrain
  - caves
  - resources
  - water
  - structures
  - decoration
- Chunk streaming and eviction with per-frame generation budget
- Threaded chunk generation worker + main-thread meshing
- On-disk chunk persistence (generated chunks are reused when revisiting)
- Mesh-cached chunk rendering with frustum culling
- Alternate VoxelSpace32 terrain renderer mode (terrain-only)
- Day/night sky + fog + ambient lighting
- Basic first-person movement/collision/flight

## Project Layout

- `main.lua`: App bootstrap, callbacks, stage registration
- `conf.lua`: Love2D window/runtime config
- `src/constants.lua`: Tunable world/render/player constants
- `src/gen/`: Generation pipeline and stages
- `src/world/`: Chunk data structures and streaming manager
- `src/render3d/`: 3D camera, mesh build, renderer, shader, sky
- `src/player/`: Player and input controllers
- `src/biomes/`: Biome catalog, selection, transitions/features
- `src/util/`: Hashing, PRNG, noise, math helpers
- `TODO.md`: Roadmap and known issues

## Tuning

Most runtime behavior is controlled in `src/constants.lua`, including:

- Chunk size and world height
- Load/cache radii
- Generation budget
- Fog distance and camera planes
- Mesh rebuild budget per frame

## Notes

- This repo tracks gameplay/render code only; local agent files are intentionally excluded from version control.
- See `TODO.md` for planned systems (state machine, save/load, inventory, audio, optimization).
