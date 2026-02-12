local Constants = require("src.constants")
local Hash = require("src.util.hash")
local PRNG = require("src.util.prng")
local BiomeCatalog = require("src.biomes.catalog")

local CW = Constants.CHUNK_W
local CH = Constants.CHUNK_H
local ZL = Constants.Z_LEVELS
local BLOCK_WOOD = Constants.BLOCK_WOOD
local BLOCK_STONE = Constants.BLOCK_STONE
local BLOCK_AIR = Constants.BLOCK_AIR
local floor = math.floor

local StageStructures = {}
StageStructures.name = "structures"

-- Structure definitions
local structures = {
    {
        name = "cabin",
        width = 5, depth = 5, height = 3,
        rarity = 0.015,
        gridSize = 24,
        biomes = { plains = true, forest = true, beach = true },
    },
    {
        name = "ruin",
        width = 5, depth = 5, height = 2,
        rarity = 0.02,
        gridSize = 20,
        biomes = { plains = true, forest = true, desert = true, mesa = true, swamp = true },
    },
    {
        name = "camp",
        width = 3, depth = 3, height = 2,
        rarity = 0.035,
        gridSize = 12,
        biomes = { plains = true, forest = true, desert = true, tundra = true, beach = true, mesa = true },
    },
    {
        name = "shrine",
        width = 3, depth = 3, height = 3,
        rarity = 0.008,
        gridSize = 40,
        biomes = { forest = true, mountains = true, tundra = true, mesa = true, swamp = true },
    },
    {
        name = "watchtower",
        width = 3, depth = 3, height = 4,
        rarity = 0.006,
        gridSize = 48,
        biomes = { plains = true, forest = true, mountains = true, mesa = true },
    },
    {
        name = "cave_entrance",
        width = 3, depth = 3, height = 2,
        rarity = 0.025,
        gridSize = 16,
        biomes = { mountains = true, forest = true, mesa = true, tundra = true },
    },
}

-- Stamp a simple structure template at the given position
local function stampStructure(chunk, lx, ly, surfZ, structDef, rng)
    local w = structDef.width
    local d = structDef.depth
    local h = structDef.height

    local halfW = floor(w / 2)
    local halfD = floor(d / 2)

    for dz = 0, h - 1 do
        for dy = -halfD, halfD do
            for dx = -halfW, halfW do
                local bx = lx + dx
                local by = ly + dy
                local bz = surfZ + 1 + dz

                if bx >= 0 and bx < CW and by >= 0 and by < CH and bz >= 0 and bz < ZL then
                    local isEdge = (dx == -halfW or dx == halfW or dy == -halfD or dy == halfD)
                    local isFloor = (dz == 0)
                    local isRoof = (dz == h - 1)

                    if structDef.name == "cabin" then
                        if isFloor then
                            chunk:setBlock(bx, by, bz, BLOCK_WOOD)
                        elseif isRoof then
                            chunk:setBlock(bx, by, bz, BLOCK_WOOD)
                        elseif isEdge then
                            chunk:setBlock(bx, by, bz, BLOCK_WOOD)
                        end
                    elseif structDef.name == "ruin" then
                        -- Partial walls (ruins)
                        if isEdge and rng:next() > 0.4 then
                            chunk:setBlock(bx, by, bz, BLOCK_STONE)
                        elseif isFloor then
                            chunk:setBlock(bx, by, bz, BLOCK_STONE)
                        end
                    elseif structDef.name == "camp" then
                        if isFloor then
                            chunk:setBlock(bx, by, bz, BLOCK_STONE)
                        end
                    elseif structDef.name == "shrine" then
                        if isFloor then
                            chunk:setBlock(bx, by, bz, BLOCK_STONE)
                        elseif dx == 0 and dy == 0 then
                            chunk:setBlock(bx, by, bz, BLOCK_STONE)
                        end
                    elseif structDef.name == "watchtower" then
                        if isEdge or isFloor then
                            chunk:setBlock(bx, by, bz, BLOCK_WOOD)
                        end
                    elseif structDef.name == "cave_entrance" then
                        if isFloor and isEdge then
                            chunk:setBlock(bx, by, bz, BLOCK_STONE)
                        elseif dx == 0 and dy == 0 and dz == 0 then
                            chunk:setBlock(bx, by, bz, Constants.BLOCK_CAVE_ENTRANCE)
                        end
                    end
                end
            end
        end
    end
end

function StageStructures.run(ctx)
    local seed = ctx.seed
    local chunk = ctx.chunk
    local cx, cy = ctx.cx, ctx.cy

    for structIdx, structDef in ipairs(structures) do
        local gs = structDef.gridSize

        -- Determine which structure grid cells overlap this chunk
        local minWx = cx * CW
        local minWy = cy * CH
        local maxWx = minWx + CW - 1
        local maxWy = minWy + CH - 1

        local cellSize = gs * CW  -- grid cells in world tiles
        local minSx = floor(minWx / cellSize)
        local minSy = floor(minWy / cellSize)
        local maxSx = floor(maxWx / cellSize)
        local maxSy = floor(maxWy / cellSize)

        for sy = minSy, maxSy do
            for sx = minSx, maxSx do
                local cellSeed = Hash.hash3D(sx, sy, structIdx + 100, seed)
                local rng = PRNG.new(cellSeed)

                -- Rarity check
                if rng:next() < structDef.rarity then
                    -- Determine anchor position in world
                    local anchorWx = sx * cellSize + rng:range(4, cellSize - 5)
                    local anchorWy = sy * cellSize + rng:range(4, cellSize - 5)

                    -- Check if anchor is in THIS chunk
                    if anchorWx >= minWx and anchorWx < minWx + CW and
                       anchorWy >= minWy and anchorWy < minWy + CH then

                        local lx = anchorWx - minWx
                        local ly = anchorWy - minWy
                        local surfZ = chunk:getHeight(lx, ly)

                        -- Check biome compatibility
                        local biomeId = chunk:getBiome(lx, ly)
                        local biome = BiomeCatalog.get(biomeId)
                        if biome and structDef.biomes[biome.name] then
                            -- Check footprint fits in chunk with margin
                            local halfW = floor(structDef.width / 2)
                            local halfD = floor(structDef.depth / 2)
                            if lx - halfW >= 0 and lx + halfW < CW and
                               ly - halfD >= 0 and ly + halfD < CH and
                               surfZ + structDef.height < ZL then
                                stampStructure(chunk, lx, ly, surfZ, structDef, rng)
                            end
                        end
                    end
                end
            end
        end
    end
end

return StageStructures
