local Constants = require("src.constants")
local Noise = require("src.util.noise")
local Selector = require("src.biomes.selector")
local Mth = require("src.util.math")

local CW = Constants.CHUNK_W
local CH = Constants.CHUNK_H
local ZL = Constants.Z_LEVELS
local BLOCK_STONE = Constants.BLOCK_STONE
local floor = math.floor
local clamp = Mth.clamp

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

            -- Sample global noise fields
            local e = Noise.fbm2D(wx * 0.005, wy * 0.005, seed, 6, 0.5)
            local m = Noise.fbm2D(wx * 0.008 + 1000, wy * 0.008 + 1000, seed, 4, 0.5)
            local t = Noise.fbm2D(wx * 0.003 + 5000, wy * 0.003 + 5000, seed, 3, 0.6)

            -- Normalize from [-1,1] to [0,1]
            e = clamp((e + 1) * 0.5, 0, 1)
            m = clamp((m + 1) * 0.5, 0, 1)
            t = clamp((t + 1) * 0.5, 0, 1)

            ctx.elevation[colIdx] = e
            ctx.moisture[colIdx] = m
            ctx.temperature[colIdx] = t

            -- Select biome
            local biome = Selector.select(e, m, t)
            chunk:setBiome(lx, ly, biome.id)

            -- Convert elevation to surface Z-level
            -- Base height at ~38% of ZL, range from ~6% to ~75%
            -- e=0.0 -> Z≈4, e=0.5 -> Z≈24, e=1.0 -> Z≈48
            local surfaceZ = floor(e * (ZL * 0.7) + ZL * 0.06)
            surfaceZ = clamp(surfaceZ, 1, ZL - 2)
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
