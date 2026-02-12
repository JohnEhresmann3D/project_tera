local requestChannelName, resultChannelName = ...

local Pipeline = require("src.gen.pipeline")
local Chunk = require("src.world.chunk")
local ChunkCodec = require("src.gen.chunk_codec")

local StageTerrain = require("src.gen.stage_terrain")
local StageCaves = require("src.gen.stage_caves")
local StageResources = require("src.gen.stage_resources")
local StageWater = require("src.gen.stage_water")
local StageStructures = require("src.gen.stage_structures")
local StageDecoration = require("src.gen.stage_decoration")

local requestChannel = love.thread.getChannel(requestChannelName)
local resultChannel = love.thread.getChannel(resultChannelName)

local function registerStagesOnce()
    if Pipeline.getStageCount() > 0 then
        return
    end
    Pipeline.registerStage(StageTerrain)
    Pipeline.registerStage(StageCaves)
    Pipeline.registerStage(StageResources)
    Pipeline.registerStage(StageWater)
    Pipeline.registerStage(StageStructures)
    Pipeline.registerStage(StageDecoration)
end

registerStagesOnce()

while true do
    local msg = requestChannel:demand()
    if type(msg) == "table" then
        if msg.cmd == "stop" then
            break
        elseif msg.cmd == "gen" then
            local chunk = Chunk.new(msg.cx, msg.cy)
            Pipeline.generate(chunk, msg.seed, nil)
            resultChannel:push({
                id = msg.id,
                cx = msg.cx,
                cy = msg.cy,
                payload = ChunkCodec.encodeChunk(chunk),
            })
        end
    end
end
