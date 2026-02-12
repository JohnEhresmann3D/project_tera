local Transitions = {}

-- Default blend width in tiles
Transitions.defaultBlendWidth = 6

-- Per-pair overrides (keyed by sorted biome name pair)
Transitions.pairOverrides = {
    ["beach_ocean"]       = { blendWidth = 3 },
    ["desert_forest"]     = { blendWidth = 10 },
    ["desert_plains"]     = { blendWidth = 8 },
    ["forest_plains"]     = { blendWidth = 8 },
    ["mountains_tundra"]  = { blendWidth = 5 },
    ["forest_mountains"]  = { blendWidth = 7 },
    ["plains_swamp"]      = { blendWidth = 8 },
    ["desert_mesa"]       = { blendWidth = 6 },
    ["ocean_swamp"]       = { blendWidth = 4 },
}

function Transitions.getBlendWidth(biomeA, biomeB)
    -- Sort names to create consistent key
    local a, b = biomeA, biomeB
    if a > b then a, b = b, a end
    local key = a .. "_" .. b

    local override = Transitions.pairOverrides[key]
    if override then
        return override.blendWidth
    end
    return Transitions.defaultBlendWidth
end

-- Compute blend weight between two biome scores
function Transitions.blendWeight(scorePrimary, scoreSecondary)
    local total = scorePrimary + scoreSecondary
    if total <= 0 then return 0.5 end
    return scorePrimary / total
end

return Transitions
