local Constants = require("src.constants")
local Sky = require("src.render3d.sky")
local Map32 = require("src.render_voxelspace.map32")

-- VoxelSpace32-style terrain renderer:
-- raymarches depth layers and paints vertical spans per screen column.
local max = math.max
local min = math.min
local sqrt = math.sqrt
local tan = math.tan
local floor = math.floor

local RendererVS = {}

local map
local screenW = 1280
local screenH = 720
local yBuffer = {}
local quality = {
    columnStep = 2,
    depthFar = 700,
    depthStep = 1.0,
    depthGrowth = 0.020,
    fov = math.rad(72),
    projScale = 360,
}

local MICRO_ENABLED = not not Constants.MICRO_VOXEL_SURFACE
local MICRO_NEAR_SUBDIV = max(1, Constants.MICRO_VOXEL_NEAR_SUBDIV or 3)
local MICRO_MID_SUBDIV = max(1, Constants.MICRO_VOXEL_MID_SUBDIV or 2)
local MICRO_NEAR_DEPTH = max(16, (Constants.MICRO_VOXEL_NEAR_RADIUS or 3) * Constants.CHUNK_W)
local MICRO_MID_DEPTH = max(MICRO_NEAR_DEPTH, (Constants.MICRO_VOXEL_FAR_RADIUS or 5) * Constants.CHUNK_W)

local function hash01(a, b)
    local n = a * 15731 + b * 789221 + 1376312589
    n = n % 2147483647
    if n < 0 then n = n + 2147483647 end
    return (n % 1024) / 1023
end

local function sampleMicro(wx, wy, subdiv)
    if subdiv <= 1 then
        return wx, wy, 1.0
    end

    -- Snap lookup to a tiny world grid so nearby terrain reads as "micro blocks"
    -- instead of a smooth interpolated ribbon.
    local cell = map.spacing / subdiv
    local sx = floor(wx / cell) * cell + cell * 0.5
    local sy = floor(wy / cell) * cell + cell * 0.5
    local shade = 0.94 + hash01(floor(sx * 10 + 0.5), floor(sy * 10 + 0.5)) * 0.12
    return sx, sy, shade
end

local function ensureYBuffer()
    -- Per-column "highest already drawn pixel" for hidden-surface removal.
    for x = 1, screenW do
        yBuffer[x] = screenH
    end
end


function RendererVS.init(seed)
    map = Map32.new(seed, 256, 2)
end

function RendererVS.resize(w, h)
    screenW = w
    screenH = h
end

function RendererVS.setQuality(q)
    if not q then return end
    if q.columnStep then quality.columnStep = max(1, q.columnStep) end
    if q.depthFar then quality.depthFar = max(120, q.depthFar) end
    if q.depthStep then quality.depthStep = max(0.5, q.depthStep) end
    if q.depthGrowth then quality.depthGrowth = max(0.0, q.depthGrowth) end
    if q.projScale then quality.projScale = max(120, q.projScale) end
    if q.fov then quality.fov = q.fov end
end

function RendererVS.getGroundHeight(wx, wy)
    if not map then
        RendererVS.init(Constants.DEFAULT_SEED)
    end
    local h8 = map:sampleTerrainHeight(wx, wy)
    -- Convert map height byte [0..255] back to world Z surface height.
    return (h8 / 255.0) * max(1, Constants.Z_LEVELS - 1)
end

function RendererVS.getWaterSurfaceHeight()
    return Constants.WATER_LEVEL_Z
end

function RendererVS.getWaterDepth(wx, wy)
    if not map then
        RendererVS.init(Constants.DEFAULT_SEED)
    end
    return map:sampleWaterDepth(wx, wy)
end

function RendererVS.draw(camera3d, player)
    if not map then
        RendererVS.init(Constants.DEFAULT_SEED)
    end

    local skyR, skyG, skyB = Sky.getSkyColor()
    local water8 = (Constants.WATER_LEVEL_Z / max(1, Constants.Z_LEVELS - 1)) * 255.0
    local camHeight = player.wz * 4.0 + 32
    local underDepth = max(0, water8 - camHeight)
    local underwater = underDepth > 0.01
    local underT = min(1.0, underDepth / 28.0)
    if underwater then
        -- Underwater palette shift so sky/horizon stop popping unnaturally.
        skyR = skyR * (0.30 + 0.20 * (1 - underT))
        skyG = skyG * (0.50 + 0.15 * (1 - underT))
        skyB = min(1.0, skyB * 0.75 + 0.20)
    end
    love.graphics.clear(skyR, skyG, skyB, 1)

    ensureYBuffer()

    local px, py = player:getWorldPos()
    local pitch = camera3d.pitch

    local horizon = screenH * 0.52 + pitch * 230
    -- Build left/right edge rays from camera basis + horizontal FOV.
    local fx, fy = camera3d:getForwardFlat()
    local rx, ry = camera3d:getRight()
    local halfSpan = tan(quality.fov * 0.5)

    local lxDirX = fx - rx * halfSpan
    local lxDirY = fy - ry * halfSpan
    local rxDirX = fx + rx * halfSpan
    local rxDirY = fy + ry * halfSpan

    local lLen = sqrt(lxDirX * lxDirX + lxDirY * lxDirY)
    local rLen = sqrt(rxDirX * rxDirX + rxDirY * rxDirY)
    if lLen > 0 then
        lxDirX, lxDirY = lxDirX / lLen, lxDirY / lLen
    end
    if rLen > 0 then
        rxDirX, rxDirY = rxDirX / rLen, rxDirY / rLen
    end

    -- March from near to far. Step grows with depth for performance.
    local z = 1.0
    local step = quality.depthStep
    local viewFar = quality.depthFar
    while z < viewFar do
        local startX = px + lxDirX * z
        local startY = py + lxDirY * z
        local endX = px + rxDirX * z
        local endY = py + rxDirY * z

        local spanX = endX - startX
        local spanY = endY - startY
        local fog = min(1.0, z / viewFar)

        for sx = 1, screenW, quality.columnStep do
            local t = (sx - 1) / max(1, screenW - 1)
            local wx = startX + spanX * t
            local wy = startY + spanY * t
            local sxWorld, syWorld, microShade = wx, wy, 1.0
            if MICRO_ENABLED and z <= MICRO_MID_DEPTH then
                local subdiv = (z <= MICRO_NEAR_DEPTH) and MICRO_NEAR_SUBDIV or MICRO_MID_SUBDIV
                sxWorld, syWorld, microShade = sampleMicro(wx, wy, subdiv)
            end
            local h8, cr, cg, cb, floorH8, fr, fg, fb, waterDepth = map:sampleColumn(sxWorld, syWorld)

            if microShade ~= 1.0 then
                -- Quantize heights in map-space units for visible stepped micro layers.
                local hStep = max(0.25, (255 / max(1, Constants.Z_LEVELS - 1)) / MICRO_MID_SUBDIV)
                h8 = floor(h8 / hStep + 0.5) * hStep
                floorH8 = floor(floorH8 / hStep + 0.5) * hStep
                cr, cg, cb = cr * microShade, cg * microShade, cb * microShade
                fr, fg, fb = fr * microShade, fg * microShade, fb * microShade
            end

            local projected = horizon - ((h8 - camHeight) * quality.projScale) / z
            local top = max(0, projected)
            local bot = yBuffer[sx]

            if top < bot then
                local fogMix = fog
                if underwater then
                    fogMix = min(1.0, fog + 0.10 + underT * 0.18)
                end
                if waterDepth > 0.25 then
                    local floorProjected = horizon - ((floorH8 - camHeight) * quality.projScale) / z
                    local floorTop = max(top, floorProjected)
                    if floorTop < bot then
                        local frFog = fr * (1 - fogMix) + skyR * fogMix
                        local fgFog = fg * (1 - fogMix) + skyG * fogMix
                        local fbFog = fb * (1 - fogMix) + skyB * fogMix
                        love.graphics.setColor(frFog, fgFog, fbFog, 1)
                        love.graphics.rectangle("fill", sx - 1, floorTop, quality.columnStep, bot - floorTop)
                    end

                    local wrFog = cr * (1 - fogMix) + skyR * fogMix
                    local wgFog = cg * (1 - fogMix) + skyG * fogMix
                    local wbFog = cb * (1 - fogMix) + skyB * fogMix
                    local depthAlpha = min(0.68, 0.12 + (waterDepth / 26.0) * 0.42)
                    if underwater then
                        depthAlpha = min(0.78, depthAlpha + 0.08 + underT * 0.06)
                    end
                    love.graphics.setColor(wrFog, wgFog, wbFog, depthAlpha)
                    love.graphics.rectangle("fill", sx - 1, top, quality.columnStep, bot - top)
                else
                    local r = cr * (1 - fogMix) + skyR * fogMix
                    local g = cg * (1 - fogMix) + skyG * fogMix
                    local b = cb * (1 - fogMix) + skyB * fogMix
                    love.graphics.setColor(r, g, b, 1)
                    love.graphics.rectangle("fill", sx - 1, top, quality.columnStep, bot - top)
                end
                local lastX = min(screenW, sx + quality.columnStep - 1)
                -- Fill all covered columns so stepped rendering still occludes correctly.
                for xi = sx, lastX do
                    yBuffer[xi] = top
                end
            end
        end

        z = z + step
        step = min(8.5, step + quality.depthGrowth)
    end

    if underwater then
        -- Final depth veil smooths banding and improves underwater readability.
        love.graphics.setColor(0.07, 0.20, 0.30, 0.10 + underT * 0.16)
        love.graphics.rectangle("fill", 0, 0, screenW, screenH)
    end

end

return RendererVS
