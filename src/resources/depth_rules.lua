local abs = math.abs
local exp = math.exp

local DepthRules = {}

-- Bell-shaped depth curve: peak at midpoint, falls off toward edges
function DepthRules.depthCurve(depth, minDepth, maxDepth)
    if depth < minDepth or depth > maxDepth then
        return 0.0
    end
    local range = maxDepth - minDepth
    local peak = (minDepth + maxDepth) * 0.5
    local distance = abs(depth - peak) / (range * 0.5)
    return exp(-2.0 * distance * distance)
end

-- Biome density modifiers
DepthRules.biomeModifiers = {
    mountains = { iron = 1.5, gold = 1.3, copper = 0.8 },
    mesa      = { iron = 1.2, gold = 1.5 },
    tundra    = { silver = 1.4 },
    forest    = { copper = 1.2 },
    swamp     = { coal = 1.5, copper = 1.1 },
}

-- Distance from spawn bonus (near-spawn generosity)
function DepthRules.spawnProximityBonus(distFromSpawn)
    if distFromSpawn < 200 then
        return 1.0 + 0.3 * (1.0 - distFromSpawn / 200.0)
    end
    return 1.0
end

return DepthRules
