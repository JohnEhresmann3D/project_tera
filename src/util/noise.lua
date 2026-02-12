local lnoise = love.math.noise
local abs = math.abs
local exp = math.exp
local floor = math.floor

local Noise = {}

-- Keep seed-derived coordinate offsets in a numerically stable range.
-- Very large raw seeds can cause precision loss in noise inputs and flatten variation.
local function normalizeSeed(seed)
    local s = tonumber(seed) or 0
    s = floor(s)
    if s < 0 then s = -s end
    return s % 2147483647
end

local function seedOffsets2D(seed)
    local s = normalizeSeed(seed)
    local ox = ((s * 1103515245 + 12345) % 1000003) * 0.001
    local oy = ((s * 69069 + 1) % 1000003) * 0.001
    return ox, oy
end

local function seedOffsets3D(seed)
    local s = normalizeSeed(seed)
    local ox = ((s * 1103515245 + 12345) % 1000003) * 0.001
    local oy = ((s * 69069 + 1) % 1000003) * 0.001
    local oz = ((s * 214013 + 2531011) % 1000003) * 0.001
    return ox, oy, oz
end

-- Remap love.math.noise from [0,1] to [-1,1]
local function noise2D(x, y)
    return lnoise(x, y) * 2 - 1
end

local function noise3D(x, y, z)
    return lnoise(x, y, z) * 2 - 1
end

Noise.noise2D = noise2D
Noise.noise3D = noise3D

-- Fractal Brownian Motion
function Noise.fbm2D(x, y, seed, octaves, persistence, lacunarity)
    lacunarity = lacunarity or 2.0
    local total = 0
    local amplitude = 1.0
    local frequency = 1.0
    local maxVal = 0

    local ox, oy = seedOffsets2D(seed)

    for i = 1, octaves do
        total = total + noise2D(x * frequency + ox, y * frequency + oy) * amplitude
        maxVal = maxVal + amplitude
        amplitude = amplitude * persistence
        frequency = frequency * lacunarity
        ox = ox + 31.7
        oy = oy + 47.3
    end

    return total / maxVal
end

-- Fractal Brownian Motion 3D
function Noise.fbm3D(x, y, z, seed, octaves, persistence, lacunarity)
    lacunarity = lacunarity or 2.0
    local total = 0
    local amplitude = 1.0
    local frequency = 1.0
    local maxVal = 0

    local ox, oy, oz = seedOffsets3D(seed)

    for i = 1, octaves do
        total = total + noise3D(x * frequency + ox, y * frequency + oy, z * frequency + oz) * amplitude
        maxVal = maxVal + amplitude
        amplitude = amplitude * persistence
        frequency = frequency * lacunarity
        ox = ox + 31.7
        oy = oy + 47.3
        oz = oz + 59.1
    end

    return total / maxVal
end

-- Ridged multifractal (for mountain ridges, river valleys)
function Noise.ridged2D(x, y, seed, octaves, persistence, lacunarity)
    lacunarity = lacunarity or 2.0
    local total = 0
    local amplitude = 1.0
    local frequency = 1.0
    local maxVal = 0
    local ox, oy = seedOffsets2D(seed)

    for i = 1, octaves do
        local n = noise2D(x * frequency + ox, y * frequency + oy)
        n = 1.0 - abs(n)
        n = n * n
        total = total + n * amplitude
        maxVal = maxVal + amplitude
        amplitude = amplitude * persistence
        frequency = frequency * lacunarity
        ox = ox + 31.7
        oy = oy + 47.3
    end

    return total / maxVal
end

-- Domain warping
function Noise.warped2D(x, y, seed, octaves, persistence, warpStrength)
    warpStrength = warpStrength or 0.3
    local warpX = Noise.fbm2D(x + 5.2, y + 1.3, seed + 1, 3, 0.5)
    local warpY = Noise.fbm2D(x + 9.7, y + 6.8, seed + 2, 3, 0.5)
    return Noise.fbm2D(
        x + warpX * warpStrength,
        y + warpY * warpStrength,
        seed, octaves, persistence
    )
end

return Noise
