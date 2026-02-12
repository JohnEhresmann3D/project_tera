local Constants = require("src.constants")

local CW = Constants.CHUNK_W
local CH = Constants.CHUNK_H
local TW = Constants.TILE_W
local TH = Constants.TILE_H
local TD = Constants.TILE_D
local floor = math.floor

local Coord = {}

-- World tile -> Chunk coordinate
function Coord.worldToChunk(wx, wy)
    return floor(wx / CW), floor(wy / CH)
end

-- World tile -> Local tile within chunk (0-based)
function Coord.worldToLocal(wx, wy)
    return wx % CW, wy % CH
end

-- Chunk + Local -> World
function Coord.chunkLocalToWorld(cx, cy, lx, ly)
    return cx * CW + lx, cy * CH + ly
end

-- World tile -> Isometric screen position
-- Returns the top-center of the diamond tile
function Coord.worldToScreen(wx, wy, wz, camera)
    local rx = wx - camera.wx
    local ry = wy - camera.wy
    local sx = (rx - ry) * (TW * 0.5)
    local sy = (rx + ry) * (TH * 0.5) - wz * TD
    sx = sx * camera.zoom + camera.screenCenterX
    sy = sy * camera.zoom + camera.screenCenterY
    return sx, sy
end

-- Screen pixel -> World tile (at a given Z-level)
function Coord.screenToWorld(sx, sy, wz, camera)
    local px = (sx - camera.screenCenterX) / camera.zoom
    local py = (sy - camera.screenCenterY) / camera.zoom + wz * TD
    local wx = px / TW + py / TH + camera.wx
    local wy = py / TH - px / TW + camera.wy
    return floor(wx), floor(wy)
end

-- Get visible chunk range for the current camera view
function Coord.getVisibleChunkRange(camera, screenW, screenH)
    -- Sample the four screen corners at Z=0 and expand
    local corners = {
        {0, 0}, {screenW, 0}, {0, screenH}, {screenW, screenH}
    }
    local minCx, minCy = math.huge, math.huge
    local maxCx, maxCy = -math.huge, -math.huge

    for _, c in ipairs(corners) do
        -- Check at both Z=0 and Z=Z_LEVELS for full coverage
        for z = 0, Constants.Z_LEVELS - 1, Constants.Z_LEVELS - 1 do
            local wx, wy = Coord.screenToWorld(c[1], c[2], z, camera)
            local cx, cy = Coord.worldToChunk(wx, wy)
            if cx < minCx then minCx = cx end
            if cy < minCy then minCy = cy end
            if cx > maxCx then maxCx = cx end
            if cy > maxCy then maxCy = cy end
        end
    end

    -- Expand by 1 chunk for safety
    return minCx - 1, minCy - 1, maxCx + 1, maxCy + 1
end

return Coord
