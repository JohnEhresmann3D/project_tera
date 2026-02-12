local Constants = require("src.constants")
local Coord = require("src.world.coordinate")
local BiomeCatalog = require("src.biomes.catalog")
local Profiler = require("src.debug.profiler")
local TerrainFields = require("src.gen.terrain_fields")

local CW = Constants.CHUNK_W
local CH = Constants.CHUNK_H
local TW = Constants.TILE_W
local TH = Constants.TILE_H
local floor = math.floor
local abs = math.abs
local max = math.max

local DebugOverlay = {}
DebugOverlay.modes = {
    none = 0,
    chunks = 1,
    elevation = 2,
    moisture = 3,
    temperature = 4,
    biomes = 5,
    caves = 6,
    perf = 7,
    noise = 8,
    lighting = 9,
}

DebugOverlay.activeMode = 0

-- Biome colors for biome overlay
local biomeColors = {
    [1] = {0.15, 0.35, 0.65},  -- ocean
    [2] = {0.92, 0.87, 0.70},  -- beach
    [3] = {0.45, 0.70, 0.30},  -- plains
    [4] = {0.20, 0.45, 0.15},  -- forest
    [5] = {0.90, 0.78, 0.50},  -- desert
    [6] = {0.30, 0.38, 0.20},  -- swamp
    [7] = {0.70, 0.75, 0.78},  -- tundra
    [8] = {0.55, 0.52, 0.50},  -- mountains
    [9] = {0.75, 0.40, 0.25},  -- mesa
}

function DebugOverlay.toggle(mode)
    if DebugOverlay.activeMode == mode then
        DebugOverlay.activeMode = 0  -- toggle off
    else
        DebugOverlay.activeMode = mode
    end
end

-- Set to true when using 3D renderer (disables iso-dependent overlays)
DebugOverlay.mode3d = false

local noisePreview = {
    image = nil,
    centerX = 0,
    centerY = 0,
    seed = 0,
    lastUpdate = 0,
    landRatio = 0,
    avgElevation = 0,
    avgContinent = 0,
    size = 160,
    sampleStep = 2,
}

local function rebuildNoisePreview(centerX, centerY, seed)
    local size = noisePreview.size
    local half = floor(size * 0.5)
    local step = noisePreview.sampleStep
    local waterLevel = Constants.WATER_LEVEL_Z
    local imageData = love.image.newImageData(size, size)

    local landCount = 0
    local total = 0
    local sumElevation = 0
    local sumContinent = 0

    for py = 0, size - 1 do
        for px = 0, size - 1 do
            local wx = centerX + floor((px - half) * step)
            local wy = centerY + floor((py - half) * step)
            local e, _, _, continent = TerrainFields.sample(seed, wx, wy)
            local surfaceZ = TerrainFields.surfaceZFromElevation(e)

            local r, g, b
            if surfaceZ <= waterLevel then
                local depth = (waterLevel - surfaceZ) / max(1, waterLevel)
                r = 0.04 + continent * 0.06
                g = 0.20 - depth * 0.07
                b = 0.55 + depth * 0.35
            else
                local h = (surfaceZ - waterLevel) / max(1, (Constants.Z_LEVELS - 1 - waterLevel))
                r = 0.18 + h * 0.30
                g = 0.30 + h * 0.45
                b = 0.14 + (1 - h) * 0.12
                landCount = landCount + 1
            end

            imageData:setPixel(px, py, r, g, b, 1)
            sumElevation = sumElevation + e
            sumContinent = sumContinent + continent
            total = total + 1
        end
    end

    local image = love.graphics.newImage(imageData)
    image:setFilter("nearest", "nearest")

    noisePreview.image = image
    noisePreview.centerX = centerX
    noisePreview.centerY = centerY
    noisePreview.seed = seed
    noisePreview.lastUpdate = love.timer.getTime()
    noisePreview.landRatio = landCount / max(1, total)
    noisePreview.avgElevation = sumElevation / max(1, total)
    noisePreview.avgContinent = sumContinent / max(1, total)
end

function DebugOverlay.draw(camera, chunkManager, player)
    local mode = DebugOverlay.activeMode

    if mode == DebugOverlay.modes.chunks then
        if not DebugOverlay.mode3d then
            DebugOverlay.drawChunkGrid(camera, chunkManager)
        end
    elseif mode == DebugOverlay.modes.noise then
        DebugOverlay.drawNoisePreview(chunkManager, player)
    elseif mode == DebugOverlay.modes.biomes then
        DebugOverlay.drawBiomeOverlay(camera, chunkManager)
    elseif mode == DebugOverlay.modes.perf then
        Profiler.draw(10, 140)
    elseif mode == DebugOverlay.modes.lighting then
        if not DebugOverlay.mode3d then
            DebugOverlay.drawLightingOverlay(camera, chunkManager)
        end
    end
end

function DebugOverlay.drawNoisePreview(chunkManager, player)
    local px, py = 0, 0
    if player and player.getTilePos then
        px, py = player:getTilePos()
    end

    local seed = chunkManager and chunkManager.worldSeed or Constants.DEFAULT_SEED
    local now = love.timer.getTime()
    local movedFar = abs(px - noisePreview.centerX) > 6 or abs(py - noisePreview.centerY) > 6
    local stale = (now - noisePreview.lastUpdate) > 0.25
    local seedChanged = seed ~= noisePreview.seed
    if not noisePreview.image or movedFar or stale or seedChanged then
        rebuildNoisePreview(px, py, seed)
    end

    local x = 8
    local y = 140
    local pad = 8
    local mapSize = noisePreview.size
    local panelW = mapSize + pad * 2
    local panelH = mapSize + 84

    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", x, y, panelW, panelH, 4)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Noise Preview (around player)", x + pad, y + 6)

    if noisePreview.image then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(noisePreview.image, x + pad, y + 24)
    end

    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.print(string.format("Seed: %d  Step: %d", seed, noisePreview.sampleStep), x + pad, y + mapSize + 30)
    love.graphics.print(string.format("Land: %.1f%%", noisePreview.landRatio * 100), x + pad, y + mapSize + 46)
    love.graphics.print(string.format("Avg E: %.3f  Avg C: %.3f", noisePreview.avgElevation, noisePreview.avgContinent), x + pad, y + mapSize + 62)

    love.graphics.setColor(0.07, 0.22, 0.78, 1)
    love.graphics.rectangle("fill", x + panelW - 58, y + mapSize + 44, 10, 10)
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.print("water", x + panelW - 44, y + mapSize + 42)
    love.graphics.setColor(0.30, 0.68, 0.22, 1)
    love.graphics.rectangle("fill", x + panelW - 58, y + mapSize + 60, 10, 10)
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.print("land", x + panelW - 44, y + mapSize + 58)
end

function DebugOverlay.drawChunkGrid(camera, chunkManager)
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()
    local minCx, minCy, maxCx, maxCy = Coord.getVisibleChunkRange(camera, screenW, screenH)

    love.graphics.setColor(1, 1, 0, 0.3)
    love.graphics.setLineWidth(1)

    for cy = minCy, maxCy do
        for cx = minCx, maxCx do
            -- Draw chunk boundary corners as iso lines
            local x0, y0 = Coord.worldToScreen(cx * CW, cy * CH, Constants.SURFACE_Z, camera)
            local x1, y1 = Coord.worldToScreen((cx + 1) * CW, cy * CH, Constants.SURFACE_Z, camera)
            local x2, y2 = Coord.worldToScreen((cx + 1) * CW, (cy + 1) * CH, Constants.SURFACE_Z, camera)
            local x3, y3 = Coord.worldToScreen(cx * CW, (cy + 1) * CH, Constants.SURFACE_Z, camera)

            love.graphics.line(x0, y0, x1, y1, x2, y2, x3, y3, x0, y0)

            -- Chunk coord label
            love.graphics.setColor(1, 1, 0, 0.7)
            local labelX = (x0 + x2) * 0.5
            local labelY = (y0 + y2) * 0.5
            love.graphics.print(string.format("%d,%d", cx, cy), labelX - 12, labelY - 6)
            love.graphics.setColor(1, 1, 0, 0.3)
        end
    end
end

function DebugOverlay.drawBiomeOverlay(camera, chunkManager)
    -- Draw biome legend
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 4, 120, 140, 20 * 9 + 10, 4)

    for id = 1, 9 do
        local biome = BiomeCatalog.get(id)
        local color = biomeColors[id] or {1, 0, 1}
        local y = 126 + (id - 1) * 20

        love.graphics.setColor(color[1], color[2], color[3], 1)
        love.graphics.rectangle("fill", 10, y, 14, 14)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(biome.name, 30, y)
    end
end

function DebugOverlay.drawLightingOverlay(camera, chunkManager)
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()
    local minCx, minCy, maxCx, maxCy = Coord.getVisibleChunkRange(camera, screenW, screenH)

    local zoom = camera.zoom
    local hw = (TW * 0.5) * zoom
    local hh = (TH * 0.5) * zoom

    for cy = minCy, maxCy do
        for cx = minCx, maxCx do
            local chunk = chunkManager:getChunk(cx, cy)
            if chunk and chunk.generated and chunk._lightCache then
                local lightCache = chunk._lightCache
                for ly = 0, CH - 1 do
                    for lx = 0, CW - 1 do
                        local idx = lx + ly * CW + 1
                        local entry = lightCache[idx]
                        local h = chunk:getHeight(lx, ly)
                        local wx = cx * CW + lx
                        local wy = cy * CH + ly
                        local sx, sy = Coord.worldToScreen(wx, wy, h, camera)

                        -- Draw grayscale diamond showing topMul
                        local v = entry.topMul
                        if v > 1 then v = 1 end
                        if v < 0 then v = 0 end
                        love.graphics.setColor(v, v, v, 0.7)
                        love.graphics.polygon("fill",
                            sx,      sy,
                            sx + hw, sy + hh,
                            sx,      sy + hh * 2,
                            sx - hw, sy + hh
                        )
                    end
                end
            end
        end
    end

    -- Legend
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 4, 140, 160, 50, 4)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Lighting: topMul", 10, 146)
    love.graphics.setColor(0.3, 0.3, 0.3, 1)
    love.graphics.rectangle("fill", 10, 166, 20, 14)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("dark", 34, 166)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 80, 166, 20, 14)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.print("bright", 104, 166)
end

function DebugOverlay.getModeName()
    for name, mode in pairs(DebugOverlay.modes) do
        if mode == DebugOverlay.activeMode then
            return name
        end
    end
    return "none"
end

return DebugOverlay
