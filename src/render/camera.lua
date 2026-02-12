local Constants = require("src.constants")
local Mth = require("src.util.math")

local Camera = {}
Camera.__index = Camera

-- Spring constants
local SPRING_K = 120
local SPRING_DAMP = 12
local LOOK_AHEAD = 2.0
local ZOOM_SPEED = 5.0

function Camera.new()
    local self = setmetatable({
        wx = 0,
        wy = 0,
        vx = 0,
        vy = 0,
        zoom = 1.0,
        zoomTarget = 1.0,
        screenCenterX = 0,
        screenCenterY = 0,
        viewZ = Constants.SURFACE_Z,
        minZoom = 0.25,
        maxZoom = 3.0,
    }, Camera)
    return self
end

function Camera:resize(w, h)
    self.screenCenterX = w * 0.5
    self.screenCenterY = h * 0.5
end

function Camera:update(dt, targetWx, targetWy, pvx, pvy)
    pvx = pvx or 0
    pvy = pvy or 0

    -- Look-ahead: offset target by player velocity
    local goalX = targetWx + pvx * LOOK_AHEAD / (self.zoom * 2)
    local goalY = targetWy + pvy * LOOK_AHEAD / (self.zoom * 2)

    -- Damped spring physics
    local dx = goalX - self.wx
    local dy = goalY - self.wy
    local ax = SPRING_K * dx - SPRING_DAMP * self.vx
    local ay = SPRING_K * dy - SPRING_DAMP * self.vy

    self.vx = self.vx + ax * dt
    self.vy = self.vy + ay * dt
    self.wx = self.wx + self.vx * dt
    self.wy = self.wy + self.vy * dt

    -- Smooth zoom interpolation
    self.zoom = self.zoom + (self.zoomTarget - self.zoom) * ZOOM_SPEED * dt
    self.zoom = Mth.clamp(self.zoom, self.minZoom, self.maxZoom)
end

function Camera:adjustZoom(delta)
    self.zoomTarget = Mth.clamp(self.zoomTarget + delta * 0.1, self.minZoom, self.maxZoom)
end

function Camera:setViewZ(z)
    self.viewZ = Mth.clamp(z, 0, Constants.Z_LEVELS - 1)
end

return Camera
