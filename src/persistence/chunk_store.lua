local Constants = require("src.constants")

local CW = Constants.CHUNK_W
local CH = Constants.CHUNK_H
local ZL = Constants.Z_LEVELS
local BLOCK_COUNT = CW * CH * ZL
local COLUMN_COUNT = CW * CH

local MAGIC = "TGCH1"

local ChunkStore = {}
ChunkStore.__index = ChunkStore

local function chunkPath(root, cx, cy)
    return string.format("%s/c_%d_%d.bin", root, cx, cy)
end

local function encodeByteArray(values, count)
    local out = {}
    for i = 1, count do
        out[i] = string.char(values[i] or 0)
    end
    return table.concat(out)
end

local function decodeByteArray(raw, startIndex, count, dest)
    for i = 1, count do
        dest[i] = string.byte(raw, startIndex + i - 1) or 0
    end
end

function ChunkStore.new(worldSeed)
    local root = string.format("worlds/%d/chunks", tonumber(worldSeed) or 0)
    love.filesystem.createDirectory(root)
    return setmetatable({
        root = root,
    }, ChunkStore)
end

function ChunkStore:loadChunk(cx, cy, chunk)
    local path = chunkPath(self.root, cx, cy)
    if not love.filesystem.getInfo(path) then
        return false
    end

    local raw = love.filesystem.read(path)
    if not raw then
        return false
    end

    local expectedLen = #MAGIC + BLOCK_COUNT + COLUMN_COUNT + COLUMN_COUNT
    if #raw ~= expectedLen or string.sub(raw, 1, #MAGIC) ~= MAGIC then
        return false
    end

    local pos = #MAGIC + 1
    decodeByteArray(raw, pos, BLOCK_COUNT, chunk.blocks)
    pos = pos + BLOCK_COUNT
    decodeByteArray(raw, pos, COLUMN_COUNT, chunk.heightMap)
    pos = pos + COLUMN_COUNT
    decodeByteArray(raw, pos, COLUMN_COUNT, chunk.biomeMap)

    chunk.generated = true
    chunk.genStage = 0
    chunk.dirty = true
    chunk._mesh3dDirty = true
    return true
end

function ChunkStore:saveChunk(chunk)
    if not chunk or not chunk.generated then
        return false
    end

    local path = chunkPath(self.root, chunk.cx, chunk.cy)
    local raw = table.concat({
        MAGIC,
        encodeByteArray(chunk.blocks, BLOCK_COUNT),
        encodeByteArray(chunk.heightMap, COLUMN_COUNT),
        encodeByteArray(chunk.biomeMap, COLUMN_COUNT),
    })
    return love.filesystem.write(path, raw)
end

return ChunkStore
