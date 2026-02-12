local Constants = require("src.constants")
local Input = require("src.player.input")
local Mth = require("src.util.math")

local floor = math.floor

local Player = {}
Player.__index = Player

function Player.new()
    local self = setmetatable({
        wx = 0.0,
        wy = 0.0,
        wz = Constants.SURFACE_Z,
        speed = Constants.PLAYER_SPEED,
        flying = false,
        vx = 0.0,
        vy = 0.0,
    }, Player)
    return self
end

function Player:update(dt, chunkManager)
    local dx, dy = Input.getMovementVector()
    self.vx = dx * self.speed
    self.vy = dy * self.speed
    self.wx = self.wx + self.vx * dt
    self.wy = self.wy + self.vy * dt

    if self.flying then
        -- Vertical movement in flight mode
        if love.keyboard.isDown("space") then
            self.wz = Mth.clamp(self.wz + 4 * dt, 0, Constants.Z_LEVELS - 1)
        end
        if love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift") then
            self.wz = Mth.clamp(self.wz - 4 * dt, 0, Constants.Z_LEVELS - 1)
        end
    else
        -- Ground mode: snap to surface height
        if chunkManager then
            local surfZ = chunkManager:getSurfaceHeight(floor(self.wx), floor(self.wy))
            if surfZ then
                self.wz = surfZ
            end
        end
    end
end

function Player:toggleFlight()
    self.flying = not self.flying
end

function Player:getWorldPos()
    return self.wx, self.wy, self.wz
end

function Player:getTilePos()
    return floor(self.wx), floor(self.wy), floor(self.wz)
end

function Player:getVelocity()
    return self.vx, self.vy
end

return Player
