local BiomeCatalog = require("src.biomes.catalog")

local abs = math.abs
local exp = math.exp

local Selector = {}

-- Gaussian-like fitness on a single axis
-- Returns 1.0 at ideal, falls off toward range edges, 0.0 outside range
local function axisScore(value, min, max, ideal)
    if value < min or value > max then
        return 0.0
    end
    local halfRange = (max - min) * 0.5
    if halfRange <= 0 then return 1.0 end
    local distance = abs(value - ideal) / halfRange
    return exp(-2.0 * distance * distance)
end

-- Composite score: geometric mean of axis scores
local function biomeScore(biome, e, m, t)
    local eScore = axisScore(e, biome.elevation.min, biome.elevation.max, biome.elevation.ideal)
    local mScore = axisScore(m, biome.moisture.min, biome.moisture.max, biome.moisture.ideal)
    local tScore = axisScore(t, biome.temperature.min, biome.temperature.max, biome.temperature.ideal)

    if eScore <= 0 or mScore <= 0 or tScore <= 0 then
        return 0.0
    end

    return (eScore * mScore * tScore) ^ (1.0 / 3.0)
end

-- Select best biome for given field values
-- Returns biome table and score
function Selector.select(e, m, t)
    local bestBiome = nil
    local bestScore = -1.0

    for _, biome in ipairs(BiomeCatalog.biomes) do
        local score = biomeScore(biome, e, m, t)
        if score > bestScore then
            bestScore = score
            bestBiome = biome
        elseif score == bestScore and biome.id < (bestBiome and bestBiome.id or 999) then
            bestBiome = biome
        end
    end

    -- Fallback to plains
    if not bestBiome or bestScore <= 0 then
        bestBiome = BiomeCatalog.get(3)
        bestScore = 0.01
    end

    return bestBiome, bestScore
end

return Selector
