local Constants = require("src.constants")

local CW = Constants.CHUNK_W
local CH = Constants.CHUNK_H
local ZL = Constants.Z_LEVELS
local BLOCK_STONE = Constants.BLOCK_STONE
local lnoise = love.math.noise

local StageResources = {}
StageResources.name = "resources"

-- Ore definitions: { blockId, minZ, maxZ, noiseFreq, threshold }
local ores = {
    { id = Constants.BLOCK_COAL,    minZ = 0, maxZ = 3, freq = 0.06, threshold = 0.72 },
    { id = Constants.BLOCK_COPPER,  minZ = 0, maxZ = 3, freq = 0.05, threshold = 0.76 },
    { id = Constants.BLOCK_IRON,    minZ = 0, maxZ = 2, freq = 0.05, threshold = 0.78 },
    { id = Constants.BLOCK_SILVER,  minZ = 0, maxZ = 1, freq = 0.04, threshold = 0.82 },
    { id = Constants.BLOCK_GOLD,    minZ = 0, maxZ = 1, freq = 0.04, threshold = 0.86 },
    { id = Constants.BLOCK_OBSIDIAN,minZ = 0, maxZ = 0, freq = 0.03, threshold = 0.90 },
}

function StageResources.run(ctx)
    local seed = ctx.seed
    local chunk = ctx.chunk
    local cx, cy = ctx.cx, ctx.cy

    for _, ore in ipairs(ores) do
        local oreOffset = ore.id * 100 + seed * 0.001
        for lz = ore.minZ, ore.maxZ do
            if lz < ZL then
                for ly = 0, CH - 1 do
                    for lx = 0, CW - 1 do
                        if chunk:getBlock(lx, ly, lz) == BLOCK_STONE then
                            local wx = cx * CW + lx
                            local wy = cy * CH + ly
                            local n = lnoise(
                                wx * ore.freq + oreOffset,
                                wy * ore.freq + oreOffset,
                                lz * 0.2 + oreOffset * 0.5
                            )
                            if n > ore.threshold then
                                chunk:setBlock(lx, ly, lz, ore.id)
                            end
                        end
                    end
                end
            end
        end
    end
end

return StageResources
