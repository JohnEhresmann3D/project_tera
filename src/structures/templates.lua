-- Structure templates for block-level stamping
-- Future expansion: load templates from data files

local C = require("src.constants")

local Templates = {}

-- Template params are intentionally compact:
-- stage_structures chooses placement and then interprets these fields
-- to stamp different structure types.
--
-- Think of this as "what to build"; stage_structures is "where and when".

Templates.cabin = {
    -- Floor (dz=0)
    material = C.BLOCK_WOOD,
    wallMaterial = C.BLOCK_WOOD,
    roofMaterial = C.BLOCK_WOOD,
}

Templates.ruin = {
    material = C.BLOCK_STONE,
    wallChance = 0.6,  -- 60% of wall blocks survive
}

Templates.camp = {
    material = C.BLOCK_STONE,
}

Templates.shrine = {
    material = C.BLOCK_STONE,
}

Templates.watchtower = {
    material = C.BLOCK_WOOD,
}

Templates.cave_entrance = {
    material = C.BLOCK_STONE,
    -- Special marker used by gameplay/visual systems to identify cave entry.
    entranceBlock = C.BLOCK_CAVE_ENTRANCE,
}

return Templates
