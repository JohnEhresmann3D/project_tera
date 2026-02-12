-- Structure templates for block-level stamping
-- Future expansion: load templates from data files

local C = require("src.constants")

local Templates = {}

-- Templates are defined as sparse block lists relative to anchor
-- Each entry: { dx, dy, dz, blockId }
-- dx, dy are offsets from anchor center, dz is offset from surface

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
    entranceBlock = C.BLOCK_CAVE_ENTRANCE,
}

return Templates
