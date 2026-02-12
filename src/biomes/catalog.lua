local C = require("src.constants")

local BiomeCatalog = {}

BiomeCatalog.biomes = {
    {
        id = 1, name = "ocean",
        elevation    = { min = 0.00, max = 0.20, ideal = 0.10 },
        moisture     = { min = 0.70, max = 1.00, ideal = 0.90 },
        temperature  = { min = 0.20, max = 0.80, ideal = 0.50 },
        surfaceBlock = C.BLOCK_SAND,
        subsoilBlock = C.BLOCK_WET_CLAY,
        stoneDepth   = 6,
        palette      = {0.15, 0.35, 0.65},
    },
    {
        id = 2, name = "beach",
        elevation    = { min = 0.18, max = 0.28, ideal = 0.22 },
        moisture     = { min = 0.40, max = 0.80, ideal = 0.60 },
        temperature  = { min = 0.30, max = 0.80, ideal = 0.55 },
        surfaceBlock = C.BLOCK_SAND,
        subsoilBlock = C.BLOCK_SANDSTONE,
        stoneDepth   = 4,
        palette      = {0.92, 0.87, 0.70},
    },
    {
        id = 3, name = "plains",
        elevation    = { min = 0.25, max = 0.50, ideal = 0.35 },
        moisture     = { min = 0.30, max = 0.60, ideal = 0.45 },
        temperature  = { min = 0.35, max = 0.65, ideal = 0.50 },
        surfaceBlock = C.BLOCK_GRASS,
        subsoilBlock = C.BLOCK_DIRT,
        stoneDepth   = 5,
        palette      = {0.45, 0.70, 0.30},
    },
    {
        id = 4, name = "forest",
        elevation    = { min = 0.25, max = 0.55, ideal = 0.40 },
        moisture     = { min = 0.50, max = 0.80, ideal = 0.65 },
        temperature  = { min = 0.30, max = 0.65, ideal = 0.48 },
        surfaceBlock = C.BLOCK_FOREST_FLOOR,
        subsoilBlock = C.BLOCK_RICH_DIRT,
        stoneDepth   = 6,
        palette      = {0.20, 0.45, 0.15},
    },
    {
        id = 5, name = "desert",
        elevation    = { min = 0.25, max = 0.50, ideal = 0.35 },
        moisture     = { min = 0.00, max = 0.20, ideal = 0.10 },
        temperature  = { min = 0.70, max = 1.00, ideal = 0.85 },
        surfaceBlock = C.BLOCK_SAND,
        subsoilBlock = C.BLOCK_HARDPAN,
        stoneDepth   = 3,
        palette      = {0.90, 0.78, 0.50},
    },
    {
        id = 6, name = "swamp",
        elevation    = { min = 0.20, max = 0.35, ideal = 0.27 },
        moisture     = { min = 0.75, max = 1.00, ideal = 0.90 },
        temperature  = { min = 0.45, max = 0.75, ideal = 0.60 },
        surfaceBlock = C.BLOCK_MUD,
        subsoilBlock = C.BLOCK_PEAT,
        stoneDepth   = 8,
        palette      = {0.30, 0.38, 0.20},
    },
    {
        id = 7, name = "tundra",
        elevation    = { min = 0.30, max = 0.55, ideal = 0.42 },
        moisture     = { min = 0.20, max = 0.50, ideal = 0.35 },
        temperature  = { min = 0.00, max = 0.25, ideal = 0.12 },
        surfaceBlock = C.BLOCK_FROZEN_GRASS,
        subsoilBlock = C.BLOCK_PERMAFROST,
        stoneDepth   = 4,
        palette      = {0.70, 0.75, 0.78},
    },
    {
        id = 8, name = "mountains",
        elevation    = { min = 0.65, max = 1.00, ideal = 0.82 },
        moisture     = { min = 0.10, max = 0.50, ideal = 0.30 },
        temperature  = { min = 0.05, max = 0.40, ideal = 0.22 },
        surfaceBlock = C.BLOCK_BARE_STONE,
        subsoilBlock = C.BLOCK_GRANITE,
        stoneDepth   = 1,
        palette      = {0.55, 0.52, 0.50},
    },
    {
        id = 9, name = "mesa",
        elevation    = { min = 0.55, max = 0.80, ideal = 0.68 },
        moisture     = { min = 0.00, max = 0.20, ideal = 0.10 },
        temperature  = { min = 0.55, max = 0.90, ideal = 0.72 },
        surfaceBlock = C.BLOCK_RED_CLAY,
        subsoilBlock = C.BLOCK_TERRACOTTA,
        stoneDepth   = 2,
        palette      = {0.75, 0.40, 0.25},
    },
}

-- Quick lookup by ID
BiomeCatalog.byId = {}
for _, b in ipairs(BiomeCatalog.biomes) do
    BiomeCatalog.byId[b.id] = b
end

function BiomeCatalog.get(id)
    return BiomeCatalog.byId[id] or BiomeCatalog.byId[3]  -- fallback to plains
end

return BiomeCatalog
