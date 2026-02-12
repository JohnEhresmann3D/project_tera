-- Feature placement utilities (Poisson-disk approximation)
-- Currently a placeholder for expanded feature placement in future phases

local FeaturePlacement = {}

-- Minimum spacing between features of the same type (tiles)
FeaturePlacement.minSpacing = {
    tree      = 3,
    bush      = 2,
    grass     = 1,
    fauna     = 5,
    rareFinal = 16,
}

-- Maximum placement attempts before giving up
FeaturePlacement.maxAttempts = 20

-- Priority order for placement
FeaturePlacement.priority = {
    "structure",
    "tree",
    "ground_flora",
    "fauna",
}

return FeaturePlacement
