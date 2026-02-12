local Constants = require("src.constants")
local Camera3D = require("src.render3d.camera3d")
local Renderer3D = require("src.render3d.renderer3d")
local Sky = require("src.render3d.sky")
local DebugOverlay = require("src.render.debug_overlay")
local Player3D = require("src.player.player3d")
local Input3D = require("src.player.input3d")
local ChunkManager = require("src.world.chunk_manager")
local Pipeline = require("src.gen.pipeline")
local Coord = require("src.world.coordinate")

-- Register generation stages in order
local StageTerrain    = require("src.gen.stage_terrain")
local StageCaves      = require("src.gen.stage_caves")
local StageResources  = require("src.gen.stage_resources")
local StageWater      = require("src.gen.stage_water")
local StageStructures = require("src.gen.stage_structures")
local StageDecoration = require("src.gen.stage_decoration")

Pipeline.registerStage(StageTerrain)
Pipeline.registerStage(StageCaves)
Pipeline.registerStage(StageResources)
Pipeline.registerStage(StageWater)
Pipeline.registerStage(StageStructures)
Pipeline.registerStage(StageDecoration)

-- Game state
local camera3d
local player
local chunkManager
local worldSeed

function love.load()
    love.window.setTitle("Terragen - 3D First Person")

    worldSeed = Constants.DEFAULT_SEED

    camera3d = Camera3D.new()
    camera3d:resize(love.graphics.getWidth(), love.graphics.getHeight())

    player = Player3D.new()
    chunkManager = ChunkManager.new(worldSeed)

    Renderer3D.init()
    Input3D.init(camera3d)

    -- Enable 3D mode for debug overlay (disables iso-dependent overlays)
    DebugOverlay.mode3d = true

    -- Generate initial chunks around spawn
    chunkManager:update(0, 0, 0)
end

function love.update(dt)
    -- Advance day/night cycle
    Sky.update(dt)

    -- Update player (also updates camera position)
    player:update(dt, camera3d, chunkManager)

    -- Update chunk streaming based on player world position
    local px, py = player:getWorldPos()
    chunkManager:update(px, py, dt)
end

function love.draw()
    -- Draw 3D world
    Renderer3D.draw(camera3d, chunkManager, player)

    -- Draw HUD (2D overlay)
    Renderer3D.drawHUD(player, camera3d, chunkManager)

    -- Draw debug overlays (screen-space only in 3D mode)
    DebugOverlay.draw(camera3d, chunkManager)

    -- Debug mode indicator
    if DebugOverlay.activeMode > 0 then
        love.graphics.setColor(1, 1, 0, 1)
        love.graphics.print("Debug: " .. DebugOverlay.getModeName(), 10, 128)
    end
end

function love.mousemoved(x, y, dx, dy)
    Input3D.mousemoved(dx, dy)
end

function love.keypressed(key)
    if key == "f" then
        player:toggleFlight()
    elseif key == "escape" then
        love.event.quit()
    elseif key == "tab" then
        Input3D.toggleCapture()
    elseif key == "f1" then
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
    elseif key == "r" then
        -- Regenerate with new seed
        worldSeed = worldSeed + 1
        chunkManager = ChunkManager.new(worldSeed)
        player = Player3D.new()
        -- Re-init camera position
        player:update(0, camera3d, chunkManager)
        love.window.setTitle("Terragen 3D - Seed: " .. worldSeed)
    end
end

function love.resize(w, h)
    camera3d:resize(w, h)
    Renderer3D.resize(w, h)
end
