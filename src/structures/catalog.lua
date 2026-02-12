-- Structure catalog: definitions for procedural structure placement
-- See stage_structures.lua for the actual placement implementation

local StructureCatalog = {}

StructureCatalog.structures = {
    {
        name = "cabin",
        description = "Small wooden dwelling in temperate biomes",
        width = 5, depth = 5, height = 3,
        rarity = 0.015,
        gridSize = 24,
        biomes = { "plains", "forest", "beach" },
    },
    {
        name = "ruin",
        description = "Crumbling stone walls of a former building",
        width = 5, depth = 5, height = 2,
        rarity = 0.02,
        gridSize = 20,
        biomes = { "plains", "forest", "desert", "mesa", "swamp" },
    },
    {
        name = "camp",
        description = "Remnants of a traveler's camp",
        width = 3, depth = 3, height = 2,
        rarity = 0.035,
        gridSize = 12,
        biomes = { "plains", "forest", "desert", "tundra", "beach", "mesa" },
    },
    {
        name = "shrine",
        description = "Small sacred stone structure",
        width = 3, depth = 3, height = 3,
        rarity = 0.008,
        gridSize = 40,
        biomes = { "forest", "mountains", "tundra", "mesa", "swamp" },
    },
    {
        name = "watchtower",
        description = "Tall wooden tower at an elevated vantage point",
        width = 3, depth = 3, height = 4,
        rarity = 0.006,
        gridSize = 48,
        biomes = { "plains", "forest", "mountains", "mesa" },
    },
    {
        name = "cave_entrance",
        description = "Visible opening leading to underground caves",
        width = 3, depth = 3, height = 2,
        rarity = 0.025,
        gridSize = 16,
        biomes = { "mountains", "forest", "mesa", "tundra" },
    },
    {
        name = "dungeon_entrance",
        description = "Imposing gateway to a multi-room underground dungeon",
        width = 7, depth = 7, height = 3,
        rarity = 0.002,
        gridSize = 96,
        biomes = { "mountains", "mesa", "swamp", "tundra" },
    },
}

return StructureCatalog
