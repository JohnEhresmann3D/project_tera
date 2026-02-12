-- Sky rendering: day/night cycle with sun, moon, and stars
-- 24-hour cycle completes in 1 real-time hour (3600 seconds)
-- Sun, moon, and stars are world-space 3D objects projected through the camera.

local sin = math.sin
local cos = math.cos
local pi  = math.pi
local floor = math.floor
local min = math.min
local max = math.max
local random = math.random

local Sky = {}

-- Cycle timing: 24 game-hours in 3600 real seconds
local CYCLE_DURATION = 3600  -- seconds for a full day
local gameTime = 6.0         -- start at 6:00 AM (sunrise)

-- Distance to place celestial bodies from camera (within FAR_PLANE=350)
local CELESTIAL_DISTANCE = 300

-- Star field (generated once)
local stars = nil
local NUM_STARS = 200

local function generateStars()
    stars = {}
    -- Use fixed seed for consistent star field
    local rng = love.math.newRandomGenerator(12345)
    for i = 1, NUM_STARS do
        local theta = rng:random() * 2 * pi  -- azimuth around sky dome
        local phi   = rng:random() * 1.2 + 0.08 -- elevation: 0.08 to 1.28 rad (~5 to ~73 deg above horizon)
        stars[i] = {
            angle = theta,                         -- kept for compatibility
            height = rng:random() * 0.6 + 0.1,    -- kept for compatibility
            brightness = rng:random() * 0.5 + 0.5, -- 0.5 to 1.0
            size = rng:random() < 0.15 and 2 or 1, -- occasional bigger stars
            theta = theta,                          -- azimuth (radians)
            phi   = phi,                            -- elevation above horizon (radians)
        }
    end
end

-- Smooth interpolation between sky colors based on time of day
local function getSkyColor(hour)
    -- Key times and their colors
    -- night (0-5):    dark blue
    -- dawn (5-7):     orange-pink horizon
    -- day (7-17):     bright blue
    -- dusk (17-19):   orange-pink
    -- night (19-24):  dark blue

    local r, g, b

    if hour < 5 then
        -- Deep night
        r, g, b = 0.02, 0.02, 0.08
    elseif hour < 6 then
        -- Pre-dawn
        local t = hour - 5
        r = 0.02 + t * 0.15
        g = 0.02 + t * 0.08
        b = 0.08 + t * 0.10
    elseif hour < 7.5 then
        -- Dawn/sunrise
        local t = (hour - 6) / 1.5
        r = 0.17 + t * 0.28
        g = 0.10 + t * 0.55
        b = 0.18 + t * 0.67
    elseif hour < 17 then
        -- Full day
        r, g, b = 0.45, 0.65, 0.85
    elseif hour < 18.5 then
        -- Dusk/sunset
        local t = (hour - 17) / 1.5
        r = 0.45 - t * 0.28
        g = 0.65 - t * 0.55
        b = 0.85 - t * 0.67
    elseif hour < 19.5 then
        -- Post-dusk
        local t = (hour - 18.5)
        r = 0.17 - t * 0.15
        g = 0.10 - t * 0.08
        b = 0.18 - t * 0.10
    else
        -- Night
        r, g, b = 0.02, 0.02, 0.08
    end

    return r, g, b
end

-- Get fog color (tinted version of sky color)
local function getFogColor(hour)
    local r, g, b = getSkyColor(hour)
    -- Fog is slightly brighter/hazier than sky
    r = min(r * 1.1 + 0.02, 1.0)
    g = min(g * 1.1 + 0.02, 1.0)
    b = min(b * 1.1 + 0.02, 1.0)
    return r, g, b
end

-- Ambient light multiplier for mesh colors
local function getAmbientLevel(hour)
    if hour < 5 then
        return 0.15
    elseif hour < 7 then
        local t = (hour - 5) / 2
        return 0.15 + t * 0.85
    elseif hour < 17 then
        return 1.0
    elseif hour < 19 then
        local t = (hour - 17) / 2
        return 1.0 - t * 0.85
    else
        return 0.15
    end
end

---------------------------------------------------------------------------
-- 3D projection helper
---------------------------------------------------------------------------
-- Projects a 3D world-space point through the viewProj matrix to 2D screen.
-- Returns screenX, screenY or nil if behind camera.
--
-- The perspective matrix negates Y for Love2D screen coords, so we use
-- (ndcY + 1) * 0.5 * screenH  (same convention as X, no extra flip).
local function projectToScreen(viewProj, wx, wy, wz, screenW, screenH)
    local m = viewProj
    local clipX = m[1]*wx + m[5]*wy + m[9]*wz  + m[13]
    local clipY = m[2]*wx + m[6]*wy + m[10]*wz + m[14]
    local clipW = m[4]*wx + m[8]*wy + m[12]*wz + m[16]
    if clipW <= 0 then return nil end  -- behind camera
    local ndcX = clipX / clipW
    local ndcY = clipY / clipW
    local sx = (ndcX + 1) * 0.5 * screenW
    local sy = (ndcY + 1) * 0.5 * screenH
    return sx, sy
end

---------------------------------------------------------------------------
-- Module API (unchanged)
---------------------------------------------------------------------------

function Sky.init()
    generateStars()
end

function Sky.update(dt)
    -- Advance game time: 24 hours in CYCLE_DURATION seconds
    gameTime = gameTime + (dt * 24.0 / CYCLE_DURATION)
    if gameTime >= 24 then
        gameTime = gameTime - 24
    end
end

function Sky.getTime()
    return gameTime
end

function Sky.getTimeString()
    local h = floor(gameTime)
    local m = floor((gameTime - h) * 60)
    return string.format("%02d:%02d", h, m)
end

function Sky.getSkyColor()
    return getSkyColor(gameTime)
end

function Sky.getFogColor()
    return getFogColor(gameTime)
end

function Sky.getAmbientLevel()
    return getAmbientLevel(gameTime)
end

---------------------------------------------------------------------------
-- Drawing helpers (glow layers)
---------------------------------------------------------------------------

-- Draw concentric glow circles for a celestial body at (sx, sy)
local function drawGlow(sx, sy, layers)
    for _, layer in ipairs(layers) do
        love.graphics.setColor(layer[1], layer[2], layer[3], layer[4])
        love.graphics.circle("fill", sx, sy, layer[5])
    end
end

---------------------------------------------------------------------------
-- Sky.draw  -- world-space celestial bodies projected through the camera
---------------------------------------------------------------------------
function Sky.draw(screenW, screenH, camera3d)
    local hour = gameTime
    local sr, sg, sb = getSkyColor(hour)

    -- Camera position (world space)
    local camX = camera3d.x
    local camY = camera3d.y
    local camZ = camera3d.z
    local viewProj = camera3d.viewProj

    -- Nighttime opacity for stars/moon (0 during day, 1 at night)
    local nightAlpha = 0
    if hour < 5.5 then
        nightAlpha = 1.0
    elseif hour < 7 then
        nightAlpha = 1.0 - (hour - 5.5) / 1.5
    elseif hour < 17.5 then
        nightAlpha = 0
    elseif hour < 19 then
        nightAlpha = (hour - 17.5) / 1.5
    else
        nightAlpha = 1.0
    end

    -------------------------------------------------------------------
    -- Stars (projected through camera)
    -------------------------------------------------------------------
    if nightAlpha > 0 and stars then
        for _, star in ipairs(stars) do
            -- Spherical to Cartesian direction
            -- theta rotates slowly with time for a gentle sky-wheel effect
            local theta = star.theta + hour * 0.05
            local phi   = star.phi
            local dirX = cos(theta) * cos(phi)
            local dirY = sin(phi)
            local dirZ = sin(theta) * cos(phi)

            -- Place at camera + direction * distance
            local wx = camX + dirX * CELESTIAL_DISTANCE
            local wy = camY + dirY * CELESTIAL_DISTANCE
            local wz = camZ + dirZ * CELESTIAL_DISTANCE

            local sx, sy = projectToScreen(viewProj, wx, wy, wz, screenW, screenH)
            if sx then
                -- Clip to screen bounds with small margin
                if sx > -10 and sx < screenW + 10 and sy > -10 and sy < screenH + 10 then
                    local bright = star.brightness * nightAlpha
                    love.graphics.setColor(bright, bright, bright * 0.95, nightAlpha)

                    if star.size > 1 then
                        love.graphics.rectangle("fill", sx - 1, sy - 1, 2, 2)
                    else
                        love.graphics.points(sx, sy)
                    end
                end
            end
        end
    end

    -------------------------------------------------------------------
    -- Sun (3D world-space object)
    -------------------------------------------------------------------
    -- sunAngle: 0 at 6am (rise east), pi/2 at noon (zenith), pi at 6pm (set west)
    local sunAngle = (hour - 6) / 12 * pi
    if sunAngle > -0.1 and sunAngle < pi + 0.1 then
        local sunAlpha = 1.0 - nightAlpha

        -- Smooth fade near horizon edges
        if sunAngle < 0.15 then
            sunAlpha = sunAlpha * (sunAngle + 0.1) / 0.25
        elseif sunAngle > pi - 0.15 then
            sunAlpha = sunAlpha * (pi + 0.1 - sunAngle) / 0.25
        end

        if sunAlpha > 0.01 then
            -- 3D direction: rises in +X, arcs over +Y, sets in -X
            local dirX = cos(sunAngle)
            local dirY = sin(sunAngle)
            local dirZ = 0

            local wx = camX + dirX * CELESTIAL_DISTANCE
            local wy = camY + dirY * CELESTIAL_DISTANCE
            local wz = camZ + dirZ * CELESTIAL_DISTANCE

            local sx, sy = projectToScreen(viewProj, wx, wy, wz, screenW, screenH)
            if sx then
                -- Multi-layered glow: large, warm, light-emitting appearance
                -- Outer glow (very wide, barely visible warmth)
                drawGlow(sx, sy, {
                    { 1.0, 0.90, 0.50, sunAlpha * 0.04, 80 },  -- outer haze
                    { 1.0, 0.92, 0.55, sunAlpha * 0.08, 50 },  -- middle glow
                    { 1.0, 0.94, 0.60, sunAlpha * 0.15, 30 },  -- inner glow
                    { 1.0, 0.95, 0.70, sunAlpha * 0.90, 16 },  -- body
                    { 1.0, 1.00, 0.90, sunAlpha * 1.00, 12 },  -- bright core
                })
            end
        end
    end

    -------------------------------------------------------------------
    -- Moon (3D world-space object)
    -------------------------------------------------------------------
    -- moonAngle: 0 at 18:00 (rise), pi/2 at midnight (zenith), pi at 06:00 (set)
    local moonAngle = ((hour - 18 + 24) % 24) / 12 * pi

    if moonAngle > -0.1 and moonAngle < pi + 0.1 then
        local moonAlpha = nightAlpha

        -- Smooth fade near horizon edges
        if moonAngle < 0.15 then
            moonAlpha = moonAlpha * (moonAngle + 0.1) / 0.25
        elseif moonAngle > pi - 0.15 then
            moonAlpha = moonAlpha * (pi + 0.1 - moonAngle) / 0.25
        end

        if moonAlpha > 0.01 then
            -- Same arc direction as sun (rises +X, arcs +Y, sets -X)
            local dirX = cos(moonAngle)
            local dirY = sin(moonAngle)
            local dirZ = 0

            local wx = camX + dirX * CELESTIAL_DISTANCE
            local wy = camY + dirY * CELESTIAL_DISTANCE
            local wz = camZ + dirZ * CELESTIAL_DISTANCE

            local sx, sy = projectToScreen(viewProj, wx, wy, wz, screenW, screenH)
            if sx then
                -- Cool blue-white glow layers (large, prominent moon)
                drawGlow(sx, sy, {
                    { 0.60, 0.65, 0.92, moonAlpha * 0.03, 100 }, -- wide haze
                    { 0.65, 0.70, 0.95, moonAlpha * 0.06,  65 }, -- outer glow
                    { 0.70, 0.75, 0.95, moonAlpha * 0.12,  40 }, -- middle glow
                    { 0.80, 0.83, 0.95, moonAlpha * 0.25,  28 }, -- inner glow
                    { 0.85, 0.88, 0.95, moonAlpha * 0.90,  20 }, -- body
                    { 0.92, 0.94, 1.00, moonAlpha * 1.00,  15 }, -- bright core
                })

                -- Crescent shadow (dark circle offset to simulate phase)
                love.graphics.setColor(sr, sg, sb, moonAlpha * 0.85)
                love.graphics.circle("fill", sx + 7, sy - 4, 17)
            end
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return Sky
