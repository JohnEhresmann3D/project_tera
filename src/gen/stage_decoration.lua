local Constants = require("src.constants")
local Hash = require("src.util.hash")
local PRNG = require("src.util.prng")
local BiomeCatalog = require("src.biomes.catalog")

local CW = Constants.CHUNK_W
local CH = Constants.CHUNK_H
local ZL = Constants.Z_LEVELS
local BLOCK_AIR = Constants.BLOCK_AIR
local BLOCK_WATER = Constants.BLOCK_WATER
local BLOCK_WOOD = Constants.BLOCK_WOOD
local BLOCK_LEAVES = Constants.BLOCK_LEAVES

-- Per-biome flora definitions: { blockId, density (per chunk) }
local biomeFlora = {
    -- Plains
    [3] = {
        { block = BLOCK_WOOD,   density = 0.003, isTree = true },   -- sparse trees
    },
    -- Forest
    [4] = {
        { block = BLOCK_WOOD,   density = 0.018, isTree = true },   -- dense trees
    },
    -- Desert
    [5] = {
        -- cacti represented as wood blocks for now
        { block = BLOCK_WOOD,   density = 0.004, isTree = false },
    },
    -- Swamp
    [6] = {
        { block = BLOCK_WOOD,   density = 0.010, isTree = true },   -- swamp trees
    },
    -- Tundra
    [7] = {
        { block = BLOCK_WOOD,   density = 0.002, isTree = true },   -- very sparse
    },
    -- Mountains
    [8] = {
        -- almost no vegetation
    },
    -- Mesa
    [9] = {
        { block = BLOCK_WOOD,   density = 0.003, isTree = false },  -- barrel cacti
    },
}

local function placeTree(chunk, lx, ly, surfZ, rng)
    -- Simple tree: trunk (1-3 blocks) + leaves on top
    local trunkHeight = rng:range(2, 3)
    for dz = 1, trunkHeight do
        local z = surfZ + dz
        if z < ZL then
            chunk:setBlock(lx, ly, z, BLOCK_WOOD)
        end
    end

    -- Leaves on top and around top of trunk
    local leafZ = surfZ + trunkHeight + 1
    if leafZ < ZL then
        chunk:setBlock(lx, ly, leafZ, BLOCK_LEAVES)
    end
    -- Adjacent leaves
    local neighbors = {{-1,0},{1,0},{0,-1},{0,1}}
    for _, n in ipairs(neighbors) do
        local nx = lx + n[1]
        local ny = ly + n[2]
        local nz = surfZ + trunkHeight
        if nx >= 0 and nx < CW and ny >= 0 and ny < CH and nz < ZL then
            if chunk:getBlock(nx, ny, nz) == BLOCK_AIR then
                chunk:setBlock(nx, ny, nz, BLOCK_LEAVES)
            end
        end
    end
end

local StageDecoration = {}
StageDecoration.name = "decoration"

function StageDecoration.run(ctx)
    local seed = ctx.seed
    local chunk = ctx.chunk
    local cx, cy = ctx.cx, ctx.cy

    local rng = PRNG.new(Hash.hash3D(cx, cy, 6, seed))

    for ly = 0, CH - 1 do
        for lx = 0, CW - 1 do
            local surfZ = chunk:getHeight(lx, ly)
            local biomeId = chunk:getBiome(lx, ly)

            -- Check that surface is the biome's surface block (not water, not a structure)
            local surfBlock = chunk:getBlock(lx, ly, surfZ)
            local biome = BiomeCatalog.get(biomeId)

            if surfBlock == biome.surfaceBlock then
                local flora = biomeFlora[biomeId]
                if flora then
                    for _, f in ipairs(flora) do
                        if rng:next() < f.density then
                            if f.isTree then
                                -- Check enough space above
                                if surfZ + 4 < ZL and
                                   chunk:getBlock(lx, ly, surfZ + 1) == BLOCK_AIR then
                                    placeTree(chunk, lx, ly, surfZ, rng)
                                end
                            else
                                -- Simple single-block decoration
                                if surfZ + 1 < ZL and
                                   chunk:getBlock(lx, ly, surfZ + 1) == BLOCK_AIR then
                                    chunk:setBlock(lx, ly, surfZ + 1, f.block)
                                end
                            end
                            break  -- one decoration per column
                        end
                    end
                end
            end
        end
    end
end

return StageDecoration
