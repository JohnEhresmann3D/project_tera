local Constants = require("src.constants")

local CW = Constants.CHUNK_W
local CH = Constants.CHUNK_H
local ZL = Constants.Z_LEVELS
local BLOCK_COUNT = CW * CH * ZL
local COLUMN_COUNT = CW * CH
local MAGIC = "TGCC1"

local ChunkCodec = {}

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

function ChunkCodec.encodeChunk(chunk)
    return table.concat({
        MAGIC,
        encodeByteArray(chunk.blocks, BLOCK_COUNT),
        encodeByteArray(chunk.heightMap, COLUMN_COUNT),
        encodeByteArray(chunk.biomeMap, COLUMN_COUNT),
    })
end

function ChunkCodec.decodeIntoChunk(raw, chunk)
    if type(raw) ~= "string" then
        return false
    end
    local expectedLen = #MAGIC + BLOCK_COUNT + COLUMN_COUNT + COLUMN_COUNT
    if #raw ~= expectedLen then
        return false
    end
    if string.sub(raw, 1, #MAGIC) ~= MAGIC then
        return false
    end

    local pos = #MAGIC + 1
    decodeByteArray(raw, pos, BLOCK_COUNT, chunk.blocks)
    pos = pos + BLOCK_COUNT
    decodeByteArray(raw, pos, COLUMN_COUNT, chunk.heightMap)
    pos = pos + COLUMN_COUNT
    decodeByteArray(raw, pos, COLUMN_COUNT, chunk.biomeMap)

    return true
end

return ChunkCodec
