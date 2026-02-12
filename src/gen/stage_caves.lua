local Constants = require("src.constants")
local Noise = require("src.util.noise")

local CW = Constants.CHUNK_W
local CH = Constants.CHUNK_H
local ZL = Constants.Z_LEVELS
local BLOCK_AIR = Constants.BLOCK_AIR
local BLOCK_STONE = Constants.BLOCK_STONE
local abs = math.abs
local lnoise = love.math.noise

local StageCaves = {}
StageCaves.name = "caves"

function StageCaves.run(ctx)
    local seed = ctx.seed
    local chunk = ctx.chunk
    local cx, cy = ctx.cx, ctx.cy

    local seedOx = seed * 0.001
    local seedOy = seed * 0.0013
    local seedOz = seed * 0.0017

    for ly = 0, CH - 1 do
        for lx = 0, CW - 1 do
            local surfZ = chunk:getHeight(lx, ly)

            for lz = 0, surfZ - 1 do  -- only iterate below surface
                    local wx = cx * CW + lx
                    local wy = cy * CH + ly

                    -- 3D noise for cave density
                    local n = lnoise(
                        wx * 0.04 + seedOx,
                        wy * 0.04 + seedOy,
                        lz * 0.06 + seedOz
                    )
                    -- Remap from [0,1] to [-1,1]
                    n = n * 2 - 1

                    -- Cave threshold: carve if |n| < threshold
                    local threshold = 0.12

                    -- Wider caves at mid-depths, thinner near surface
                    local depthFromSurface = surfZ - lz
                    local surfaceGuard = 1.0
                    if depthFromSurface <= 2 then
                        surfaceGuard = 0.2  -- much less likely near surface
                    elseif depthFromSurface <= 5 then
                        surfaceGuard = 0.6
                    end
                    threshold = threshold * surfaceGuard

                    -- Wider caves at mid underground levels
                    local midZ = surfZ * 0.4
                    local midBonus = 1.0 - abs(lz - midZ) / (surfZ * 0.6 + 1)
                    if midBonus < 0 then midBonus = 0 end
                    threshold = threshold * (0.5 + midBonus * 0.5)

                    if abs(n) < threshold then
                        chunk:setBlock(lx, ly, lz, BLOCK_AIR)
                    end
            end
        end
    end
end

return StageCaves
