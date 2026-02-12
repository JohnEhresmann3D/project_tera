-- 3D first-person camera with mouse-look and matrix management
-- Depends on src.render3d.matrix for view/projection math

local Matrix = require("src.render3d.matrix")

local sin   = math.sin
local cos   = math.cos

-- Pitch limits in radians (89 degrees)
local PITCH_MAX =  1.553
local PITCH_MIN = -1.553

local function clampPitch(v)
    if v > PITCH_MAX then return PITCH_MAX end
    if v < PITCH_MIN then return PITCH_MIN end
    return v
end

local Camera3D = {}
Camera3D.__index = Camera3D

function Camera3D.new()
    local self = setmetatable({}, Camera3D)

    -- Position (X = right, Y = up, Z = forward)
    self.x = 0
    self.y = 5
    self.z = 0

    -- Orientation (radians)
    self.yaw   = 0   -- rotation around Y axis
    self.pitch = 0   -- rotation around X axis

    -- Projection parameters
    self.fov    = 70      -- degrees
    self.aspect = 16 / 9
    self.near   = 0.1
    self.far    = 200.0

    -- Input tuning
    self.sensitivity = 0.003

    -- Cached matrices
    self.view     = Matrix.identity()
    self.proj     = Matrix.identity()
    self.viewProj = Matrix.identity()

    return self
end

--- Set camera position directly.
function Camera3D:setPosition(x, y, z)
    self.x = x
    self.y = y
    self.z = z
end

--- Adjust yaw and pitch from raw mouse delta.
-- dx/dy are pixel deltas from love.mousemoved or similar.
-- dy is negated so that mouse-down produces negative pitch (look down).
function Camera3D:mouseLook(dx, dy)
    self.yaw   = self.yaw - dx * self.sensitivity
    self.pitch = clampPitch(self.pitch - dy * self.sensitivity)
end

--- Recompute view, projection, and combined viewProj matrices.
-- Call this once per frame after any position/orientation changes.
function Camera3D:updateMatrices()
    self.view     = Matrix.fpView(self.x, self.y, self.z, self.yaw, self.pitch)
    self.proj     = Matrix.perspective(self.fov, self.aspect, self.near, self.far)
    self.viewProj = Matrix.multiply(self.proj, self.view)
end

--- Update aspect ratio from window dimensions.
function Camera3D:resize(w, h)
    self.aspect = w / h
end

--- Returns dx, dz for horizontal (pitch-independent) forward movement.
-- Useful for WASD walking where vertical aim should not affect speed.
function Camera3D:getForwardFlat()
    local dx = -sin(self.yaw)
    local dz = -cos(self.yaw)
    return dx, dz
end

--- Returns dx, dz for strafing (rightward movement).
function Camera3D:getRight()
    local dx =  cos(self.yaw)
    local dz = -sin(self.yaw)
    return dx, dz
end

return Camera3D
