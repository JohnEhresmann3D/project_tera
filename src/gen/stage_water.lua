local Constants = require("src.constants")
local Noise = require("src.util.noise")

local CW = Constants.CHUNK_W
local CH = Constants.CHUNK_H
local ZL = Constants.Z_LEVELS
local BLOCK_WATER = Constants.BLOCK_WATER
local BLOCK_AIR = Constants.BLOCK_AIR

local WATER_LEVEL_Z = 18  -- global water plane (~28% of ZL)

local StageWater = {}
StageWater.name = "water"

function StageWater.run(ctx)
    local seed = ctx.seed
    local chunk = ctx.chunk
    local cx, cy = ctx.cx, ctx.cy

    -- Pass 1: Ocean/lake fill
    for ly = 0, CH - 1 do
        for lx = 0, CW - 1 do
            local surfZ = chunk:getHeight(lx, ly)

            if surfZ < WATER_LEVEL_Z then
                for z = surfZ + 1, WATER_LEVEL_Z do
                    if z < ZL then
                        chunk:setBlock(lx, ly, z, BLOCK_WATER)
                    end
                end
            end
        end
    end

    -- Pass 2: River channels using ridged noise with domain warping
    for ly = 0, CH - 1 do
        for lx = 0, CW - 1 do
            local wx = cx * CW + lx
            local wy = cy * CH + ly

            -- Domain-warped ridged noise for meandering rivers
            local warpX = Noise.fbm2D(wx * 0.01 + 200, wy * 0.01 + 200, seed + 5555, 3, 0.5)
            local warpY = Noise.fbm2D(wx * 0.01 + 300, wy * 0.01 + 300, seed + 6666, 3, 0.5)

            local river = Noise.ridged2D(
                (wx + warpX * 8) * 0.008,
                (wy + warpY * 8) * 0.008,
                seed + 9999, 4, 0.5
            )

            if river > 0.85 then
                local surfZ = chunk:getHeight(lx, ly)

                -- Only place river on land above water level
                if surfZ > WATER_LEVEL_Z then
                    chunk:setBlock(lx, ly, surfZ, BLOCK_WATER)

                    -- Deeper rivers in center of channel
                    if river > 0.92 and surfZ > 1 then
                        chunk:setBlock(lx, ly, surfZ - 1, BLOCK_WATER)
                    end
                end
            end
        end
    end
end

return StageWater
