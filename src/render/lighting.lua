local Constants = require("src.constants")

local CW = Constants.CHUNK_W
local CH = Constants.CHUNK_H
local ZL = Constants.Z_LEVELS

local sqrt = math.sqrt
local max = math.max
local min = math.min
local floor = math.floor

local Lighting = {}

-- Configurable features (all togglable)
Lighting.config = {
    enabled       = true,
    heightShading = true,
    slopeLighting = true,
    ambientOcclusion = true,
    cliffs        = true,
    shadows       = true,
    fog           = true,
    edges         = true,
}

-- Sun direction (normalized): light from upper-left, slightly above
local sunDirX = -0.667
local sunDirY = -0.667
local sunDirZ =  0.333
local sunLen = sqrt(sunDirX*sunDirX + sunDirY*sunDirY + sunDirZ*sunDirZ)
sunDirX = sunDirX / sunLen
sunDirY = sunDirY / sunLen
sunDirZ = sunDirZ / sunLen

-- Ambient/directional blend
local ambientWeight = 0.45
local directionalWeight = 0.55

-- Fog color (sky blue)
local fogR, fogG, fogB = 0.45, 0.65, 0.85

-- Get height at world position, using chunkManager for cross-chunk queries
local function getWorldHeight(chunkManager, wx, wy)
    if not chunkManager then return Constants.SURFACE_Z end
    return chunkManager:getSurfaceHeight(wx, wy)
end

--- Compute lighting cache for a chunk.
--- Called once when chunk.dirty is true. Stores result as chunk._lightCache.
--- @param chunk table The chunk to compute lighting for
--- @param chunkManager table The chunk manager for cross-chunk height queries
function Lighting.computeCache(chunk, chunkManager)
    if not Lighting.config.enabled then
        chunk._lightCache = nil
        return
    end

    local cache = chunk._lightCache
    if not cache then
        cache = {}
        for i = 1, CW * CH do
            cache[i] = {
                topMul = 1.0,
                leftMul = 0.55,
                rightMul = 0.82,
                cliffLeft = 0,
                cliffRight = 0,
                aoFactor = 1.0,
            }
        end
    end

    local cx, cy = chunk.cx, chunk.cy
    local baseWx = cx * CW
    local baseWy = cy * CH

    for ly = 0, CH - 1 do
        for lx = 0, CW - 1 do
            local idx = lx + ly * CW + 1
            local entry = cache[idx]

            local h = chunk:getHeight(lx, ly)

            -- Height shading: valleys dark, peaks bright
            local heightMul = 1.0
            if Lighting.config.heightShading then
                heightMul = 0.75 + (h / (ZL - 1)) * 0.35
            end

            -- Slope lighting via finite-difference surface normal
            local slopeMul = 1.0
            if Lighting.config.slopeLighting then
                local wx = baseWx + lx
                local wy = baseWy + ly

                -- Get heights of 4 cardinal neighbors
                local hN, hS, hE, hW
                -- Use chunk-local where possible, chunkManager at edges
                if ly > 0 then
                    hN = chunk:getHeight(lx, ly - 1)
                else
                    hN = getWorldHeight(chunkManager, wx, wy - 1)
                end
                if ly < CH - 1 then
                    hS = chunk:getHeight(lx, ly + 1)
                else
                    hS = getWorldHeight(chunkManager, wx, wy + 1)
                end
                if lx < CW - 1 then
                    hE = chunk:getHeight(lx + 1, ly)
                else
                    hE = getWorldHeight(chunkManager, wx + 1, wy)
                end
                if lx > 0 then
                    hW = chunk:getHeight(lx - 1, ly)
                else
                    hW = getWorldHeight(chunkManager, wx - 1, wy)
                end

                -- Finite-difference normal: cross product of tangent vectors
                -- tangent_x = (2, 0, hE - hW), tangent_y = (0, 2, hS - hN)
                -- normal = tangent_x cross tangent_y = (-2*(hE-hW), -2*(hS-hN), 4)
                -- Simplified: normal = (-(hE-hW), -(hS-hN), 2)
                local nx = -(hE - hW)
                local ny = -(hS - hN)
                local nz = 2.0
                local nLen = sqrt(nx*nx + ny*ny + nz*nz)
                if nLen > 0 then
                    nx = nx / nLen
                    ny = ny / nLen
                    nz = nz / nLen
                end

                -- Dot product with sun direction
                local dot = nx * sunDirX + ny * sunDirY + nz * sunDirZ
                dot = max(0, dot)  -- clamp negative (facing away from sun)

                slopeMul = ambientWeight + directionalWeight * dot
            end

            -- Ambient occlusion: count taller cardinal neighbors
            local aoMul = 1.0
            if Lighting.config.ambientOcclusion then
                local tallerCount = 0
                if ly > 0 and chunk:getHeight(lx, ly - 1) > h then
                    tallerCount = tallerCount + 1
                end
                if ly < CH - 1 and chunk:getHeight(lx, ly + 1) > h then
                    tallerCount = tallerCount + 1
                end
                if lx < CW - 1 and chunk:getHeight(lx + 1, ly) > h then
                    tallerCount = tallerCount + 1
                end
                if lx > 0 and chunk:getHeight(lx - 1, ly) > h then
                    tallerCount = tallerCount + 1
                end
                aoMul = 1.0 - tallerCount * 0.07
            end

            -- Combined top face multiplier
            entry.topMul = heightMul * slopeMul * aoMul

            -- Side face multipliers (darker sides + lighting)
            entry.leftMul = 0.55 * heightMul * aoMul
            entry.rightMul = 0.82 * heightMul * aoMul

            entry.aoFactor = aoMul

            -- Cliff detection: height difference with neighbors visible as side faces
            -- In isometric view, left face shows toward -x direction, right face toward -y direction
            if Lighting.config.cliffs then
                local wx = baseWx + lx
                local wy = baseWy + ly

                -- Left cliff: neighbor at (lx-1, ly) — but in iso view, left face
                -- corresponds to the +y direction neighbor
                local hPlusY
                if ly < CH - 1 then
                    hPlusY = chunk:getHeight(lx, ly + 1)
                else
                    hPlusY = getWorldHeight(chunkManager, wx, wy + 1)
                end
                entry.cliffLeft = max(0, h - hPlusY)

                -- Right cliff: neighbor in +x direction
                local hPlusX
                if lx < CW - 1 then
                    hPlusX = chunk:getHeight(lx + 1, ly)
                else
                    hPlusX = getWorldHeight(chunkManager, wx + 1, wy)
                end
                entry.cliffRight = max(0, h - hPlusX)
            else
                entry.cliffLeft = 0
                entry.cliffRight = 0
            end
        end
    end

    chunk._lightCache = cache
    chunk._lightCacheDirty = false
end

--- Apply distance fog to RGB values.
--- @param r number Red channel
--- @param g number Green channel
--- @param b number Blue channel
--- @param screenDistSq number Squared screen distance from center (in pixels)
--- @param maxDistSq number Squared max distance for full fog
--- @return number, number, number Fogged r, g, b
function Lighting.applyFog(r, g, b, screenDistSq, maxDistSq)
    if not Lighting.config.fog then
        return r, g, b
    end

    -- Fog factor: 0 at center, up to 0.55 at edges
    local fogFactor = min(0.55, (screenDistSq / maxDistSq) * 0.55)

    r = r + (fogR - r) * fogFactor
    g = g + (fogG - g) * fogFactor
    b = b + (fogB - b) * fogFactor

    return r, g, b
end

--- Toggle all lighting on/off
function Lighting.toggleAll()
    Lighting.config.enabled = not Lighting.config.enabled
end

--- Cycle through individual features
local featureOrder = {"cliffs", "shadows", "fog", "ambientOcclusion", "edges", "heightShading", "slopeLighting"}
local featureIndex = 0

function Lighting.cycleFeature()
    featureIndex = (featureIndex % #featureOrder) + 1
    local key = featureOrder[featureIndex]
    Lighting.config[key] = not Lighting.config[key]
    return key, Lighting.config[key]
end

--- Get current feature status string for HUD
function Lighting.getStatusString()
    if not Lighting.config.enabled then
        return "Lighting: OFF"
    end
    local parts = {}
    for _, key in ipairs(featureOrder) do
        local short = key:sub(1,3)
        if Lighting.config[key] then
            parts[#parts + 1] = short .. "+"
        else
            parts[#parts + 1] = short .. "-"
        end
    end
    return "Lighting: " .. table.concat(parts, " ")
end

return Lighting
