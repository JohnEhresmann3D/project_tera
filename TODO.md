# Terragen TODO

## Phase 1: Start Menu & Game State Machine

### Game State System
- [ ] Create `src/state/game_state.lua` — state enum (MENU, PLAYING, PAUSED) with enter/exit hooks
- [ ] Create `src/state/state_manager.lua` — manages transitions, routes love callbacks per state
- [ ] Refactor `main.lua` to delegate update/draw/keypressed to current state handler
- [ ] Add pause menu (Escape toggles pause, shows resume/quit/settings)

### Start Menu
- [ ] Create `src/ui/main_menu.lua` — title screen with options
- [ ] Seed input field: type a number or string (hashed to numeric seed)
- [ ] "Random Seed" button — generates a random seed and previews it
- [ ] "Play" button — transitions to PLAYING state with chosen seed
- [ ] Display seed on HUD during gameplay for sharing
- [ ] Seed history: show last 5 seeds used (persist to file)

### UI Foundation
- [ ] Create `src/ui/ui.lua` — basic UI framework (buttons, text input, panels)
- [ ] Mouse cursor management: show cursor in menus, hide in gameplay
- [ ] Screen resolution / fullscreen toggle in settings

---

## Phase 2: Modularity & Architecture Cleanup

### Decouple main.lua
- [ ] Move love callback routing into state manager (love.update → stateManager:update)
- [ ] Extract keybind definitions into `src/config/keybinds.lua` (data-driven, not hardcoded if/elseif)
- [ ] Move debug overlay toggle logic out of main.lua keypressed

### Rendering Abstraction
- [ ] Create `src/render3d/render_settings.lua` — runtime-adjustable settings (FOV, draw distance, fog, mesh budget)
- [ ] Make FOG_START/FOG_END/FAR_PLANE adjustable at runtime (settings menu)
- [ ] Make ACTIVE_RADIUS/LOAD_RADIUS tunable (quality presets: Low/Med/High)
- [ ] Extract HUD into `src/ui/hud.lua` — separate from renderer3d.lua

### Player System
- [ ] Split player3d.lua into sub-modules:
  - `src/player/movement.lua` — horizontal movement + sprint logic
  - `src/player/physics.lua` — gravity, collision, jump, auto-step
  - `src/player/flight.lua` — flight mode logic
- [ ] Make collision constants (HALF_W, PLAYER_H, STEP_HEIGHT) configurable
- [ ] Add player spawn logic: find safe spawn point (not inside solid blocks)

### World System
- [ ] Add `chunkManager:getBlock(wx, wy, wz)` convenience method (avoids manual coord math)
- [ ] Add `chunkManager:setBlock(wx, wy, wz, id)` with auto dirty-marking + neighbor propagation
- [ ] Add chunk serialization/deserialization for save/load
- [ ] Event system: on_chunk_generated, on_chunk_evicted hooks

### Block Registry
- [ ] Move block definitions to a data file (`data/blocks.lua` or JSON)
- [ ] Add block properties: hardness, drop item, break sound, place sound
- [ ] Add block categories/tags for gameplay logic (stone-tier, organic, ore, etc.)

### Clean Up Legacy Code
- [ ] Decide: keep or remove old iso renderer (`src/render/renderer.lua`, `camera.lua`, `lighting.lua`)
- [ ] Decide: keep or remove old 2D player (`src/player/player.lua`, `input.lua`)
- [ ] If keeping: gate behind a toggle; if removing: delete files

---

## Phase 3: Gameplay Foundation

### Block Interaction (Mine/Place)
- [ ] Raycast from camera: find targeted block face (max ~6 block reach)
- [ ] Block highlight: outline the targeted block
- [ ] Left click: break block (instant for now, timed break later)
- [ ] Right click: place block on targeted face
- [ ] Block drops: spawned item entities (or direct to inventory)
- [ ] Break particles (optional: small colored squares fly off)

### Inventory System
- [ ] Create `src/gameplay/inventory.lua` — fixed-size slot array with stacking
- [ ] Hotbar (bottom of screen): 9 slots, number keys 1-9 to select
- [ ] Active slot determines placement block type
- [ ] Pickup: walking over dropped blocks auto-collects
- [ ] Basic inventory UI: press E/I to open grid view

### Tool System (Basic)
- [ ] Hand (default): slow break speed
- [ ] Tool tiers: wood → stone → iron → gold → diamond (data-driven)
- [ ] Tool-block affinity: pickaxe for stone, axe for wood, shovel for dirt
- [ ] Durability (optional, can defer)

### Crafting (Basic)
- [ ] Create `src/gameplay/crafting.lua` — recipe registry
- [ ] Shapeless recipes: ingredients → output (no grid needed initially)
- [ ] Basic recipes: wood→planks, planks→sticks, sticks+stone→pickaxe
- [ ] Crafting UI: simple list of available recipes based on inventory contents

### Entity System
- [ ] Create `src/gameplay/entity.lua` — lightweight entity base (pos, vel, update, draw)
- [ ] Dropped items: block entities that float and bob, auto-pickup on proximity
- [ ] Entity manager: update/draw loop, spatial queries

### Player Stats
- [ ] Health system (hearts): 10 hearts, fall damage, drowning
- [ ] Hunger (optional, can defer for later)
- [ ] Death → respawn at spawn point

---

## Phase 4: World Polish & Features

### Terrain Improvements
- [ ] Water rendering: semi-transparent, animated surface (vertex wave or UV scroll)
- [ ] Leaves rendering: slight transparency, maybe wind sway
- [ ] Cave lighting: darker ambient in enclosed spaces (local AO or light propagation)
- [ ] Biome-specific ambient tinting (desert = warm, tundra = cool)

### Day/Night Gameplay
- [ ] Hostile mobs at night (basic: zombie that walks toward player)
- [ ] Torches/light sources: placeable blocks that emit light
- [ ] Light propagation: BFS flood-fill from light sources, bake into mesh vertex colors
- [ ] Campfire block with particle effect

### World Persistence
- [ ] Save world to disk: chunk data + player state + seed
- [ ] Load world from disk
- [ ] World selection screen (list saved worlds)
- [ ] Auto-save on quit

### Audio
- [ ] Background music: ambient loops (day vs night)
- [ ] Block break/place sounds
- [ ] Footstep sounds (surface-dependent: grass, stone, sand)
- [ ] Ambient sounds: wind, water, cave drips

---

## Phase 5: Performance & Polish

### Rendering Performance
- [ ] Profile mesh_builder: benchmark interior fast path improvement
- [ ] Consider mesh:setVertices(bytedata) for zero-copy vertex upload
- [ ] LOD: simpler meshes for distant chunks (skip small features)
- [ ] Texture atlas: replace vertex colors with textured blocks
- [ ] Greedy meshing: merge adjacent same-block faces into larger quads

### Chunk Management
- [ ] Background thread for chunk generation (love.thread)
- [ ] Priority queue for mesh rebuilds (camera-facing chunks first)
- [ ] Chunk dirty cascade: only rebuild affected faces, not full mesh

### Visual Polish
- [ ] SSAO approximation (screen-space ambient occlusion)
- [ ] Block edge outlines (toon-style, per shader_artist agent spec)
- [ ] Animated sky gradient transitions (smoother dawn/dusk)
- [ ] Cloud layer (2D scrolling texture at fixed Y height)
- [ ] Underwater fog tint (blue-green when camera below water level)

---

## Known Issues / Bugs
- [ ] Player can spawn inside terrain after world regeneration (R key)
- [ ] Performance still "chuggy" — needs profiling to identify bottleneck (mesh build vs draw calls vs generation)
- [ ] Debug overlays F1-F6 are iso-dependent and don't work in 3D mode
- [ ] No mouse cursor visible in menus (relative mode always on)
- [ ] Window resize may not update all render targets correctly

---

## Agent Assignments (from .agents/)

| Agent | Scope |
|-------|-------|
| **Rendering Engineer** (`rendering.md`) | Mesh pipeline, GPU perf, texture atlas, greedy meshing, LOD |
| **Shader Artist** (`shader_artist.md`) | Toon shading, outlines, water shader, visual style |
| **Rendering Illusionist** (`lighting_rendering_camera_engineer.md`) | Lighting, sky polish, atmosphere, camera feel |
| **Gameplay Engineer** (`gameplay_engineer.md`) | Player controller, block interaction, inventory, crafting, entities |
| **PCG World Engineer** (`pcgn_world_engineer.md`) | Chunk streaming, generation pipeline, new biome stages |
| **Biome Designer** (`biom_designer.md`) | New biomes, feature placement, transitions, decoration |
