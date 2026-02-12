local Constants = require("src.constants")
local Sky = require("src.render3d.sky")
local Map32 = require("src.render_voxelspace.map32")

local sin = math.sin
local cos = math.cos
local max = math.max
local min = math.min

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

local function ensureYBuffer()
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

function RendererVS.draw(camera3d, player)
    if not map then
        RendererVS.init(Constants.DEFAULT_SEED)
    end

    local skyR, skyG, skyB = Sky.getSkyColor()
    love.graphics.clear(skyR, skyG, skyB, 1)

    ensureYBuffer()

    local px, py = player:getWorldPos()
    local yaw = camera3d.yaw
    local pitch = camera3d.pitch

    local horizon = screenH * 0.52 + pitch * 230
    local camHeight = player.wz * 4.0 + 32

    local fovHalf = quality.fov * 0.5
    local leftYaw = yaw - fovHalf
    local rightYaw = yaw + fovHalf
    local lxDirX, lxDirY = -sin(leftYaw), -cos(leftYaw)
    local rxDirX, rxDirY = -sin(rightYaw), -cos(rightYaw)

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
            local h8, color = map:sample(wx, wy)

            local projected = horizon - ((h8 - camHeight) * quality.projScale) / z
            local top = max(0, projected)
            local bot = yBuffer[sx]

            if top < bot then
                local r = color[1] * (1 - fog) + skyR * fog
                local g = color[2] * (1 - fog) + skyG * fog
                local b = color[3] * (1 - fog) + skyB * fog
                love.graphics.setColor(r, g, b, 1)
                love.graphics.rectangle("fill", sx - 1, top, quality.columnStep, bot - top)
                yBuffer[sx] = top
            end
        end

        z = z + step
        step = min(8.5, step + quality.depthGrowth)
    end
end

return RendererVS
