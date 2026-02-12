local Constants = require("src.constants")
local Selector = require("src.biomes.selector")
local TerrainFields = require("src.gen.terrain_fields")

local CW = Constants.CHUNK_W
local CH = Constants.CHUNK_H
local BLOCK_STONE = Constants.BLOCK_STONE

local StageTerrain = {}
StageTerrain.name = "terrain"

function StageTerrain.run(ctx)
    local seed = ctx.seed
    local cx, cy = ctx.cx, ctx.cy
    local chunk = ctx.chunk

    for ly = 0, CH - 1 do
        for lx = 0, CW - 1 do
            local wx = cx * CW + lx
            local wy = cy * CH + ly
            local colIdx = lx + ly * CW + 1
            local e, m, t = TerrainFields.sample(seed, wx, wy)

            ctx.elevation[colIdx] = e
            ctx.moisture[colIdx] = m
            ctx.temperature[colIdx] = t

            -- Select biome
            local biome = Selector.select(e, m, t)
            chunk:setBiome(lx, ly, biome.id)

            -- Convert elevation to surface Z-level
            -- Base height at ~38% of ZL, range from ~6% to ~75%
            -- e=0.0 -> Z≈4, e=0.5 -> Z≈24, e=1.0 -> Z≈48
            local surfaceZ = TerrainFields.surfaceZFromElevation(e)
            chunk:setHeight(lx, ly, surfaceZ)

            -- Fill column: stone below, subsoil near surface, biome surface on top
            for z = 0, surfaceZ do
                local blockId
                if z < surfaceZ - 1 then
                    blockId = BLOCK_STONE
                elseif z == surfaceZ - 1 then
                    blockId = biome.subsoilBlock
                else
                    blockId = biome.surfaceBlock
                end
                chunk:setBlock(lx, ly, z, blockId)
            end
        end
    end
end

return StageTerrain
