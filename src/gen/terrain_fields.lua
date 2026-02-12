local Constants = require("src.constants")
local Noise = require("src.util.noise")
local Mth = require("src.util.math")
local Hash = require("src.util.hash")

local floor = math.floor
local clamp = Mth.clamp
local max = math.max
local min = math.min

local TerrainFields = {}

function TerrainFields.sample(seed, wx, wy)
    local ox = (Hash.hash2D(seed, 101, seed) % 200000 - 100000) * 0.01
    local oy = (Hash.hash2D(seed, 211, seed) % 200000 - 100000) * 0.01

    local sx = wx + ox
    local sy = wy + oy

    local continent = Noise.fbm2D(sx * 0.0012, sy * 0.0012, seed + 12000, 4, 0.52)
    continent = clamp((continent + 1) * 0.5, 0, 1)
    continent = continent * continent * (3 - 2 * continent)

    local detail = Noise.fbm2D(sx * 0.006, sy * 0.006, seed + 14000, 6, 0.5)
    detail = clamp((detail + 1) * 0.5, 0, 1)

    local elevation = 0.16 + continent * 0.70 + (detail - 0.5) * 0.28
    elevation = clamp(elevation, 0, 1)

    local moisture = Noise.fbm2D(sx * 0.008 + 1000, sy * 0.008 + 1000, seed + 16000, 4, 0.5)
    local temperature = Noise.fbm2D(sx * 0.003 + 5000, sy * 0.003 + 5000, seed + 18000, 3, 0.6)
    moisture = clamp((moisture + 1) * 0.5, 0, 1)
    temperature = clamp((temperature + 1) * 0.5, 0, 1)

    return elevation, moisture, temperature, continent, detail
end

function TerrainFields.surfaceZFromElevation(elevation)
    local surfaceZ = floor(elevation * (Constants.Z_LEVELS * 0.7) + Constants.Z_LEVELS * 0.06)
    surfaceZ = clamp(surfaceZ, 1, Constants.Z_LEVELS - 2)
    if surfaceZ < 14 then
        surfaceZ = 14 + floor((surfaceZ - 14) * 0.5)
        surfaceZ = max(8, min(surfaceZ, Constants.Z_LEVELS - 2))
    end
    return surfaceZ
end

return TerrainFields
