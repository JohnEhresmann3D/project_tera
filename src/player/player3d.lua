-- 3D first-person player controller
-- WASD + camera-relative movement, jump, sprint, flight, voxel collision.

local Constants     = require("src.constants")
local BlockRegistry = require("src.world.block_registry")

local floor = math.floor
local sqrt  = math.sqrt

local CW = Constants.CHUNK_W
local CH = Constants.CHUNK_H
local ZL = Constants.Z_LEVELS

local GRAVITY      = 20.0   -- blocks/s²
local JUMP_VEL     = 8.5    -- initial upward velocity
local SPRINT_MULT  = 1.8    -- speed multiplier when holding shift
local HALF_W       = 0.3    -- player half-width (0.6 total)
local PLAYER_H     = 1.7    -- height from feet to top of head
local STEP_HEIGHT  = 0.6    -- auto-step up ledges this high

local isSolid = BlockRegistry.isSolid

local Player3D = {}
Player3D.__index = Player3D

function Player3D.new()
    return setmetatable({
        wx = 0.0, wy = 0.0, wz = Constants.SURFACE_Z + 2,
        vz = 0.0,
        onGround = false,
        speed    = Constants.PLAYER_SPEED,
        flying   = false,
    }, Player3D)
end

---------------------------------------------------------------------------
-- Collision helpers
---------------------------------------------------------------------------

-- Is the block at integer world coords solid?
local function isSolidAt(cm, bx, by, bz)
    if bz < 0 then return true end
    if bz >= ZL then return false end
    local cx = floor(bx / CW)
    local cy = floor(by / CH)
    local c = cm:getChunk(cx, cy)
    if not c or not c.generated then return true end
    return isSolid(c:getBlock(bx - cx * CW, by - cy * CH, bz))
end

-- Does the player AABB at feet=(px,py,pz) overlap any solid block?
local function collidesAt(cm, px, py, pz)
    local x0 = floor(px - HALF_W)
    local x1 = floor(px + HALF_W - 0.001)
    local y0 = floor(py - HALF_W)
    local y1 = floor(py + HALF_W - 0.001)
    local z0 = floor(pz)
    local z1 = floor(pz + PLAYER_H - 0.001)
    for bz = z0, z1 do
        for by = y0, y1 do
            for bx = x0, x1 do
                if isSolidAt(cm, bx, by, bz) then return true end
            end
        end
    end
    return false
end

---------------------------------------------------------------------------
-- Update
---------------------------------------------------------------------------

function Player3D:update(dt, camera3d, chunkManager)
    -- Camera forward/right on the horizontal plane
    local fdx, fdz = camera3d:getForwardFlat()
    local fwx, fwy = fdx, fdz
    local rdx, rdz = camera3d:getRight()
    local rwx, rwy = rdx, rdz

    -- Accumulate movement direction
    local mx, my = 0, 0
    if love.keyboard.isDown("w") then mx = mx + fwx; my = my + fwy end
    if love.keyboard.isDown("s") then mx = mx - fwx; my = my - fwy end
    if love.keyboard.isDown("d") then mx = mx + rwx; my = my + rwy end
    if love.keyboard.isDown("a") then mx = mx - rwx; my = my - rwy end

    -- Normalize diagonal movement
    local len = sqrt(mx * mx + my * my)
    if len > 0 then mx = mx / len; my = my / len end

    -- Sprint (ground mode only)
    local moveSpeed = self.speed
    if not self.flying and (love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")) then
        moveSpeed = moveSpeed * SPRINT_MULT
    end

    if not chunkManager then
        -- No collision world (VoxelSpace mode): free movement only.
        self.wx = self.wx + mx * moveSpeed * dt
        self.wy = self.wy + my * moveSpeed * dt
        local dz = 0
        if love.keyboard.isDown("space") then
            dz = dz + moveSpeed * dt
        end
        -- Keep shift descend when flight is active; ctrl always descends.
        if self.flying and (love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")) then
            dz = dz - moveSpeed * dt
        end
        if love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl") then
            dz = dz - moveSpeed * dt
        end
        self.wz = self.wz + dz
        if self.wz < 1 then self.wz = 1 end
        if self.wz > ZL - 3 then self.wz = ZL - 3 end
        self.vz = 0
        self.onGround = false
        camera3d:setPosition(self.wx, self.wz + Constants.EYE_HEIGHT, self.wy)
        return
    end

    -- === Horizontal movement (axis-separated with auto-step) ===
    local dx = mx * moveSpeed * dt
    local dy = my * moveSpeed * dt

    if dx ~= 0 then
        local newX = self.wx + dx
        if not collidesAt(chunkManager, newX, self.wy, self.wz) then
            self.wx = newX
        elseif self.onGround and not collidesAt(chunkManager, newX, self.wy, self.wz + STEP_HEIGHT) then
            self.wx = newX
            self.wz = self.wz + STEP_HEIGHT
        end
    end

    if dy ~= 0 then
        local newY = self.wy + dy
        if not collidesAt(chunkManager, self.wx, newY, self.wz) then
            self.wy = newY
        elseif self.onGround and not collidesAt(chunkManager, self.wx, newY, self.wz + STEP_HEIGHT) then
            self.wy = newY
            self.wz = self.wz + STEP_HEIGHT
        end
    end

    -- === Vertical movement ===
    if self.flying then
        local vspeed = moveSpeed
        local dz = 0
        if love.keyboard.isDown("space") then dz = dz + vspeed * dt end
        if love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift") then
            dz = dz - vspeed * dt
        end
        if dz ~= 0 then
            local newZ = self.wz + dz
            if not collidesAt(chunkManager, self.wx, self.wy, newZ) then
                self.wz = newZ
            end
        end
        self.vz = 0
        self.onGround = false
    else
        -- Ground contact check
        if self.onGround then
            if not collidesAt(chunkManager, self.wx, self.wy, self.wz - 0.05) then
                self.onGround = false  -- walked off edge
            end
        end

        -- Jump or idle
        if self.onGround then
            if love.keyboard.isDown("space") then
                self.vz = JUMP_VEL
                self.onGround = false
            else
                self.vz = 0
            end
        else
            self.vz = self.vz - GRAVITY * dt
        end

        -- Apply vertical velocity
        if self.vz ~= 0 then
            local newZ = self.wz + self.vz * dt
            if collidesAt(chunkManager, self.wx, self.wy, newZ) then
                if self.vz < 0 then
                    -- Landing: snap feet to top of solid block
                    local snapZ = floor(newZ) + 1.0
                    for _ = 1, 5 do
                        if not collidesAt(chunkManager, self.wx, self.wy, snapZ) then
                            self.wz = snapZ
                            break
                        end
                        snapZ = snapZ + 1.0
                    end
                    self.onGround = true
                end
                self.vz = 0
            else
                self.wz = newZ
            end
        end
    end

    -- World bounds
    if self.wz < 1 then self.wz = 1; self.vz = 0; self.onGround = true end
    if self.wz > ZL - 3 then self.wz = ZL - 3 end

    -- Update camera (world -> 3D coord swap: Y<->Z)
    camera3d:setPosition(self.wx, self.wz + Constants.EYE_HEIGHT, self.wy)
end

function Player3D:toggleFlight()
    self.flying = not self.flying
    if self.flying then
        self.vz = 0
    end
end

function Player3D:getWorldPos()
    return self.wx, self.wy, self.wz
end

function Player3D:getTilePos()
    return floor(self.wx), floor(self.wy), floor(self.wz)
end

return Player3D
