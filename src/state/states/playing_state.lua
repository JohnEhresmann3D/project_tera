local Constants = require("src.constants")
local Camera3D = require("src.render3d.camera3d")
local Renderer3D = require("src.render3d.renderer3d")
local RendererVS = require("src.render_voxelspace.renderer")
local Sky = require("src.render3d.sky")
local DebugOverlay = require("src.render.debug_overlay")
local Player3D = require("src.player.player3d")
local Input3D = require("src.player.input3d")
local ChunkManager = require("src.world.chunk_manager")
local Pipeline = require("src.gen.pipeline")
local GameState = require("src.state.game_state")
local BlockRegistry = require("src.world.block_registry")

local StageTerrain = require("src.gen.stage_terrain")
local StageCaves = require("src.gen.stage_caves")
local StageResources = require("src.gen.stage_resources")
local StageWater = require("src.gen.stage_water")
local StageStructures = require("src.gen.stage_structures")
local StageDecoration = require("src.gen.stage_decoration")

local stagesRegistered = false

local PlayingState = {}
PlayingState.__index = PlayingState

-- Core runtime state.
-- Owns: player/camera, chunk streaming, render mode, and perf adaptation.
-- Tier table drives both simulation workload (chunk/gen budgets)
-- and renderer quality knobs. Lower tiers are mobile-safe defaults.
local PERF_TIERS = {
    { name = "ultra",  loadRadius = 12, activeRadius = 6, genBudgetMs = 6.0, meshRebuilds = 10, maxCached = 900, renderScale = 1.00 },
    { name = "high",   loadRadius = 10, activeRadius = 4, genBudgetMs = 4.5, meshRebuilds = 7,  maxCached = 650, renderScale = 1.00 },
    { name = "medium", loadRadius = 8,  activeRadius = 3, genBudgetMs = 3.0, meshRebuilds = 4,  maxCached = 450, renderScale = 0.85 },
    { name = "low",    loadRadius = 6,  activeRadius = 2, genBudgetMs = 2.0, meshRebuilds = 2,  maxCached = 300, renderScale = 0.72 },
    { name = "mobile", loadRadius = 4,  activeRadius = 1, genBudgetMs = 1.2, meshRebuilds = 1,  maxCached = 180, renderScale = 0.62 },
}

local function ensureChunkGenerated(chunkManager, seed, cx, cy)
    local chunk = chunkManager:getOrCreateChunk(cx, cy)
    if not chunk.generated then
        Pipeline.generate(chunk, seed)
    end
    return chunk
end

local function pickSafeSpawn(chunkManager, seed)
    -- Scan nearby generated chunks for a walkable spawn:
    -- solid ground and two air blocks for player headroom.
    local bestLand = nil
    local bestAny = nil
    local bestLandScore = -math.huge
    local bestAnyScore = -math.huge
    local isSolid = BlockRegistry.isSolid

    local searchChunkRadius = 3
    local step = 2

    for cy = -searchChunkRadius, searchChunkRadius do
        for cx = -searchChunkRadius, searchChunkRadius do
            local chunk = ensureChunkGenerated(chunkManager, seed, cx, cy)
            for ly = 0, Constants.CHUNK_H - 1, step do
                for lx = 0, Constants.CHUNK_W - 1, step do
                    local surfZ = chunk:getHeight(lx, ly)
                    local groundId = chunk:getBlock(lx, ly, surfZ)
                    local head1 = chunk:getBlock(lx, ly, surfZ + 1)
                    local head2 = chunk:getBlock(lx, ly, surfZ + 2)

                    if isSolid(groundId) and not isSolid(head1) and not isSolid(head2) then
                        local wx = cx * Constants.CHUNK_W + lx
                        local wy = cy * Constants.CHUNK_H + ly
                        local dist = math.sqrt(wx * wx + wy * wy)
                        local score = surfZ - dist * 0.03

                        if score > bestAnyScore then
                            bestAnyScore = score
                            bestAny = { wx = wx + 0.5, wy = wy + 0.5, wz = surfZ + 1.0 }
                        end

                        if surfZ > Constants.WATER_LEVEL_Z + 1 and score > bestLandScore then
                            bestLandScore = score
                            bestLand = { wx = wx + 0.5, wy = wy + 0.5, wz = surfZ + 1.0 }
                        end
                    end
                end
            end
        end
    end

    return bestLand or bestAny or { wx = 0.5, wy = 0.5, wz = Constants.SURFACE_Z + 2 }
end

local function registerStagesOnce()
    if stagesRegistered then
        return
    end
    -- Stage order is intentional; later stages assume prior data exists.
    Pipeline.registerStage(StageTerrain)
    Pipeline.registerStage(StageCaves)
    Pipeline.registerStage(StageResources)
    Pipeline.registerStage(StageWater)
    Pipeline.registerStage(StageStructures)
    Pipeline.registerStage(StageDecoration)
    stagesRegistered = true
end

function PlayingState.new(stateManager)
    return setmetatable({
        stateManager = stateManager,
        camera3d = nil,
        player = nil,
        chunkManager = nil,
        worldSeed = Constants.DEFAULT_SEED,
        perfTier = 2,
        renderMode = "mesh3d",
        fpsEma = 60,
        adaptiveTimer = 0,
        adaptiveCooldown = 0,
    }, PlayingState)
end

function PlayingState:_applyPerfTier(tierIndex)
    if not self.chunkManager then
        return
    end
    local idx = math.max(1, math.min(#PERF_TIERS, tierIndex))
    local tier = PERF_TIERS[idx]
    self.perfTier = idx

    self.chunkManager.loadRadius = tier.loadRadius
    self.chunkManager.activeRadius = tier.activeRadius
    self.chunkManager.genBudgetMs = tier.genBudgetMs
    self.chunkManager.meshRebuildBudget = tier.meshRebuilds
    self.chunkManager.maxCached = tier.maxCached
    self.chunkManager.cacheRadius = tier.loadRadius + 4
    self.chunkManager.perfTierName = tier.name

    Renderer3D.setRenderScale(tier.renderScale)

    -- VoxelSpace has its own quality model (column/depth stepping).
    local voxelQuality = {
        ultra =  { columnStep = 1, depthFar = 900, depthStep = 1.0, depthGrowth = 0.016, projScale = 390 },
        high =   { columnStep = 1, depthFar = 760, depthStep = 1.1, depthGrowth = 0.018, projScale = 370 },
        medium = { columnStep = 2, depthFar = 620, depthStep = 1.3, depthGrowth = 0.022, projScale = 350 },
        low =    { columnStep = 2, depthFar = 520, depthStep = 1.8, depthGrowth = 0.027, projScale = 330 },
        mobile = { columnStep = 3, depthFar = 420, depthStep = 2.2, depthGrowth = 0.030, projScale = 310 },
    }
    RendererVS.setQuality(voxelQuality[tier.name] or voxelQuality.medium)
end

function PlayingState:_initialPerfTier()
    local os = love.system.getOS and love.system.getOS() or ""
    if os == "iOS" or os == "Android" then
        return #PERF_TIERS
    end
    return 2 -- high by default on desktop
end

function PlayingState:_initWorld(seed)
    if self.chunkManager and self.chunkManager.shutdown then
        self.chunkManager:shutdown()
    end
    self.worldSeed = seed or self.worldSeed
    self.camera3d = Camera3D.new()
    self.camera3d:resize(love.graphics.getWidth(), love.graphics.getHeight())

    self.player = Player3D.new()
    self.chunkManager = ChunkManager.new(self.worldSeed)
    self:_applyPerfTier(self:_initialPerfTier())

    Renderer3D.init()
    RendererVS.init(self.worldSeed)
    RendererVS.resize(love.graphics.getWidth(), love.graphics.getHeight())
    Input3D.init(self.camera3d)
    DebugOverlay.mode3d = true

    -- Pick a deterministic safe spawn near origin, then force one manager
    -- update so surrounding chunks are queued immediately.
    local spawn = pickSafeSpawn(self.chunkManager, self.worldSeed)
    self.player.wx = spawn.wx
    self.player.wy = spawn.wy
    self.player.wz = spawn.wz

    self.chunkManager:update(self.player.wx, self.player.wy, 0)
    self.player:update(0, self.camera3d, self.chunkManager)
    love.window.setTitle("Terragen 3D - Seed: " .. self.worldSeed)
end

function PlayingState:onEnter(_, payload)
    registerStagesOnce()
    local seed = payload and payload.seed or self.worldSeed

    if not self.camera3d or (payload and payload.resetWorld) then
        self:_initWorld(seed)
    end
    Input3D.setCapture(true)
    love.mouse.setVisible(false)
end

function PlayingState:update(dt)
    -- Update order matters:
    -- 1) player movement/collision
    -- 2) chunk streaming around new player position
    -- 3) sky/time and adaptive performance
    self.player:update(dt, self.camera3d, self.chunkManager)
    local px, py = self.player:getWorldPos()
    self.chunkManager:update(px, py, dt)
    Sky.update(dt)

    -- Adaptive quality with hysteresis to avoid rapid tier oscillation.
    local fps = love.timer.getFPS()
    self.fpsEma = self.fpsEma * 0.9 + fps * 0.1
    self.adaptiveTimer = self.adaptiveTimer + dt
    self.adaptiveCooldown = math.max(0, self.adaptiveCooldown - dt)
    if self.adaptiveTimer >= 1.0 and self.adaptiveCooldown <= 0 then
        self.adaptiveTimer = 0
        if self.fpsEma < 50 and self.perfTier < #PERF_TIERS then
            self:_applyPerfTier(self.perfTier + 1)
            self.adaptiveCooldown = 1.5
        elseif self.fpsEma > 95 and self.perfTier > 1 then
            self:_applyPerfTier(self.perfTier - 1)
            self.adaptiveCooldown = 2.0
        end
    end
end

function PlayingState:draw()
    -- Render path is hot-swappable at runtime; HUD/debug stay shared.
    if self.renderMode == "voxelspace32" then
        RendererVS.draw(self.camera3d, self.player)
    else
        Renderer3D.draw(self.camera3d, self.chunkManager, self.player)
    end
    Renderer3D.drawHUD(self.player, self.camera3d, self.chunkManager)
    DebugOverlay.draw(self.camera3d, self.chunkManager, self.player)
    love.graphics.setColor(1, 0.9, 0.2, 1)
    love.graphics.print("Render: " .. self.renderMode .. " (F10 toggle)", 10, 210)

    if DebugOverlay.activeMode > 0 then
        love.graphics.setColor(1, 1, 0, 1)
        love.graphics.print("Debug: " .. DebugOverlay.getModeName(), 10, 128)
    end
end

function PlayingState:mousemoved(x, y, dx, dy)
    Input3D.mousemoved(dx, dy)
end

function PlayingState:keypressed(key)
    if key == "f" then
        self.player:toggleFlight()
        return
    end

    if key == "escape" then
        self.stateManager:switch(GameState.PAUSED, {
            previous = GameState.PLAYING,
            seed = self.worldSeed,
        })
        return
    end

    if key == "tab" then
        Input3D.toggleCapture()
        return
    end

    if key == "f1" then
        DebugOverlay.toggle(DebugOverlay.modes.chunks)
    elseif key == "f2" then
        DebugOverlay.toggle(DebugOverlay.modes.elevation)
    elseif key == "f3" then
        DebugOverlay.toggle(DebugOverlay.modes.moisture)
    elseif key == "f4" then
        DebugOverlay.toggle(DebugOverlay.modes.temperature)
    elseif key == "f5" then
        DebugOverlay.toggle(DebugOverlay.modes.biomes)
    elseif key == "f6" then
        DebugOverlay.toggle(DebugOverlay.modes.caves)
    elseif key == "f7" then
        DebugOverlay.toggle(DebugOverlay.modes.perf)
    elseif key == "f8" then
        DebugOverlay.toggle(DebugOverlay.modes.noise)
    elseif key == "f9" then
        local nextTier = self.perfTier + 1
        if nextTier > #PERF_TIERS then nextTier = 1 end
        self:_applyPerfTier(nextTier)
    elseif key == "f10" then
        -- Fast renderer A/B testing during gameplay.
        if self.renderMode == "mesh3d" then
            self.renderMode = "voxelspace32"
        else
            self.renderMode = "mesh3d"
        end
    elseif key == "r" then
        self:_initWorld(self.worldSeed + 1)
    end
end

function PlayingState:resize(w, h)
    if self.camera3d then
        self.camera3d:resize(w, h)
        Renderer3D.resize(w, h)
        RendererVS.resize(w, h)
    end
end

return PlayingState
