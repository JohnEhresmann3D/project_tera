local Constants = require("src.constants")

local CW = Constants.CHUNK_W
local CH = Constants.CHUNK_H
local ZL = Constants.Z_LEVELS
local BLOCK_AIR = Constants.BLOCK_AIR
local BLOCK_SIZE = CW * CH * ZL

local Chunk = {}
Chunk.__index = Chunk

function Chunk.new(cx, cy)
    local blocks = {}
    for i = 1, BLOCK_SIZE do
        blocks[i] = BLOCK_AIR
    end

    local biomeMap = {}
    local heightMap = {}
    for i = 1, CW * CH do
        biomeMap[i] = 0
        heightMap[i] = Constants.SURFACE_Z
    end

    local self = setmetatable({
        cx = cx,
        cy = cy,
        blocks = blocks,
        biomeMap = biomeMap,
        heightMap = heightMap,
        generated = false,
        genStage = 0,
        lastAccess = 0,
        dirty = true,
        -- 3D mesh cache
        _mesh3d = nil,
        _mesh3dDirty = true,
    }, Chunk)

    return self
end

-- 1-based index into flat blocks array
-- lx, ly: 0-based local coords (0..CW-1, 0..CH-1)
-- lz: 0-based Z-level (0..ZL-1)
local function blockIndex(lx, ly, lz)
    return lx + ly * CW + lz * CW * CH + 1
end

function Chunk:getBlock(lx, ly, lz)
    if lx < 0 or lx >= CW or ly < 0 or ly >= CH or lz < 0 or lz >= ZL then
        return BLOCK_AIR
    end
    return self.blocks[blockIndex(lx, ly, lz)]
end

function Chunk:setBlock(lx, ly, lz, blockId)
    if lx < 0 or lx >= CW or ly < 0 or ly >= CH or lz < 0 or lz >= ZL then
        return
    end
    self.blocks[blockIndex(lx, ly, lz)] = blockId
    self.dirty = true
    self._mesh3dDirty = true
end

function Chunk:getHeight(lx, ly)
    if lx < 0 or lx >= CW or ly < 0 or ly >= CH then
        return Constants.SURFACE_Z
    end
    return self.heightMap[lx + ly * CW + 1]
end

function Chunk:setHeight(lx, ly, h)
    if lx < 0 or lx >= CW or ly < 0 or ly >= CH then return end
    self.heightMap[lx + ly * CW + 1] = h
end

function Chunk:getBiome(lx, ly)
    if lx < 0 or lx >= CW or ly < 0 or ly >= CH then return 0 end
    return self.biomeMap[lx + ly * CW + 1]
end

function Chunk:setBiome(lx, ly, biomeId)
    if lx < 0 or lx >= CW or ly < 0 or ly >= CH then return end
    self.biomeMap[lx + ly * CW + 1] = biomeId
end

-- Column index (1-based) from local coords
function Chunk:colIndex(lx, ly)
    return lx + ly * CW + 1
end

return Chunk
