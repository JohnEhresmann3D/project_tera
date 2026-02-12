local Constants = require("src.constants")
local Coord = require("src.world.coordinate")
local BiomeCatalog = require("src.biomes.catalog")
local Profiler = require("src.debug.profiler")

local CW = Constants.CHUNK_W
local CH = Constants.CHUNK_H
local TW = Constants.TILE_W
local TH = Constants.TILE_H

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
    lighting = 8,
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

function DebugOverlay.draw(camera, chunkManager)
    local mode = DebugOverlay.activeMode

    if mode == DebugOverlay.modes.chunks then
        if not DebugOverlay.mode3d then
            DebugOverlay.drawChunkGrid(camera, chunkManager)
        end
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
