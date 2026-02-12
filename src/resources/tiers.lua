local C = require("src.constants")

local Tiers = {}

Tiers.early = {
    { id = C.BLOCK_COAL,   name = "coal",   depth = { min = 2, max = 20 }, density = 0.05 },
    { id = C.BLOCK_COPPER, name = "copper", depth = { min = 3, max = 15 }, density = 0.04 },
}

Tiers.mid = {
    { id = C.BLOCK_IRON,   name = "iron",   depth = { min = 10, max = 30 }, density = 0.025 },
    { id = C.BLOCK_SILVER, name = "silver", depth = { min = 15, max = 35 }, density = 0.012 },
}

Tiers.late = {
    { id = C.BLOCK_GOLD,     name = "gold",     depth = { min = 25, max = 50 }, density = 0.006 },
    { id = C.BLOCK_OBSIDIAN, name = "obsidian", depth = { min = 35, max = 50 }, density = 0.004 },
}

return Tiers
