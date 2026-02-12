local lnoise = love.math.noise
local abs = math.abs
local exp = math.exp

local Noise = {}

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

    local ox = seed * 1.31
    local oy = seed * 1.77

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

    local ox = seed * 1.31
    local oy = seed * 1.77
    local oz = seed * 2.13

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
    local ox = seed * 1.31
    local oy = seed * 1.77

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
