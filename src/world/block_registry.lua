local C = require("src.constants")

local BlockRegistry = {}

-- Block definitions: { name, solid, transparent, color {r,g,b,a} }
local blocks = {
    [C.BLOCK_AIR]          = { name = "air",          solid = false, transparent = true,  color = {0, 0, 0, 0} },
    [C.BLOCK_STONE]        = { name = "stone",        solid = true,  transparent = false, color = {0.50, 0.50, 0.50, 1} },
    [C.BLOCK_DIRT]         = { name = "dirt",          solid = true,  transparent = false, color = {0.55, 0.38, 0.22, 1} },
    [C.BLOCK_GRASS]        = { name = "grass",         solid = true,  transparent = false, color = {0.30, 0.65, 0.20, 1} },
    [C.BLOCK_SAND]         = { name = "sand",          solid = true,  transparent = false, color = {0.90, 0.85, 0.60, 1} },
    [C.BLOCK_WATER]        = { name = "water",         solid = false, transparent = true,  color = {0.20, 0.40, 0.75, 0.7} },
    [C.BLOCK_FOREST_FLOOR] = { name = "forest_floor",  solid = true,  transparent = false, color = {0.25, 0.40, 0.15, 1} },
    [C.BLOCK_MUD]          = { name = "mud",           solid = true,  transparent = false, color = {0.35, 0.28, 0.18, 1} },
    [C.BLOCK_FROZEN_GRASS] = { name = "frozen_grass",  solid = true,  transparent = false, color = {0.70, 0.78, 0.80, 1} },
    [C.BLOCK_BARE_STONE]   = { name = "bare_stone",    solid = true,  transparent = false, color = {0.58, 0.55, 0.52, 1} },
    [C.BLOCK_RED_CLAY]     = { name = "red_clay",      solid = true,  transparent = false, color = {0.75, 0.38, 0.22, 1} },
    [C.BLOCK_COAL]         = { name = "coal",          solid = true,  transparent = false, color = {0.20, 0.20, 0.20, 1} },
    [C.BLOCK_COPPER]       = { name = "copper",        solid = true,  transparent = false, color = {0.70, 0.45, 0.25, 1} },
    [C.BLOCK_IRON]         = { name = "iron",          solid = true,  transparent = false, color = {0.60, 0.55, 0.50, 1} },
    [C.BLOCK_SILVER]       = { name = "silver",        solid = true,  transparent = false, color = {0.78, 0.78, 0.82, 1} },
    [C.BLOCK_GOLD]         = { name = "gold",          solid = true,  transparent = false, color = {0.90, 0.75, 0.20, 1} },
    [C.BLOCK_OBSIDIAN]     = { name = "obsidian",      solid = true,  transparent = false, color = {0.10, 0.05, 0.15, 1} },
    [C.BLOCK_ICE]          = { name = "ice",           solid = true,  transparent = true,  color = {0.70, 0.85, 0.95, 0.8} },
    [C.BLOCK_SANDSTONE]    = { name = "sandstone",     solid = true,  transparent = false, color = {0.82, 0.72, 0.50, 1} },
    [C.BLOCK_GRANITE]      = { name = "granite",       solid = true,  transparent = false, color = {0.62, 0.55, 0.52, 1} },
    [C.BLOCK_PERMAFROST]   = { name = "permafrost",    solid = true,  transparent = false, color = {0.55, 0.60, 0.65, 1} },
    [C.BLOCK_HARDPAN]      = { name = "hardpan",       solid = true,  transparent = false, color = {0.65, 0.55, 0.40, 1} },
    [C.BLOCK_PEAT]         = { name = "peat",          solid = true,  transparent = false, color = {0.25, 0.20, 0.12, 1} },
    [C.BLOCK_RICH_DIRT]    = { name = "rich_dirt",      solid = true,  transparent = false, color = {0.40, 0.30, 0.15, 1} },
    [C.BLOCK_TERRACOTTA]   = { name = "terracotta",    solid = true,  transparent = false, color = {0.80, 0.50, 0.30, 1} },
    [C.BLOCK_WET_CLAY]     = { name = "wet_clay",      solid = true,  transparent = false, color = {0.45, 0.42, 0.38, 1} },
    [C.BLOCK_WOOD]         = { name = "wood",          solid = true,  transparent = false, color = {0.55, 0.35, 0.18, 1} },
    [C.BLOCK_LEAVES]       = { name = "leaves",        solid = false, transparent = true,  color = {0.20, 0.55, 0.15, 0.85} },
    [C.BLOCK_CAVE_ENTRANCE]= { name = "cave_entrance", solid = false, transparent = false, color = {0.08, 0.05, 0.05, 1} },
}

function BlockRegistry.get(id)
    return blocks[id] or blocks[C.BLOCK_AIR]
end

function BlockRegistry.isSolid(id)
    local b = blocks[id]
    return b and b.solid or false
end

function BlockRegistry.isTransparent(id)
    local b = blocks[id]
    return b and b.transparent or true
end

function BlockRegistry.getColor(id)
    local b = blocks[id]
    if b then return b.color end
    return {1, 0, 1, 1}  -- magenta for unknown
end

return BlockRegistry
