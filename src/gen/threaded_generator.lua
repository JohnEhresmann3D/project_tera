-- Thin wrapper around LOVE threads/channels for async chunk generation.
-- Main thread submits jobs; worker returns encoded chunk payloads.
local ThreadedGenerator = {}
ThreadedGenerator.__index = ThreadedGenerator

local function makeChannelNames(worldSeed)
    -- Unique channels per manager instance prevent cross-world collisions.
    local t = math.floor((love.timer.getTime() or 0) * 1000)
    local r = love.math.random(1, 1000000000)
    local suffix = string.format("%d_%d_%d", tonumber(worldSeed) or 0, t, r)
    return "tg_req_" .. suffix, "tg_res_" .. suffix
end

function ThreadedGenerator.new(worldSeed)
    if not love.thread or not love.thread.newThread then
        return nil
    end

    local reqName, resName = makeChannelNames(worldSeed)
    local requestChannel = love.thread.getChannel(reqName)
    local resultChannel = love.thread.getChannel(resName)

    -- Defensive clear in case channels were reused by a previous session.
    requestChannel:clear()
    resultChannel:clear()

    local thread = love.thread.newThread("src/gen/chunk_worker.lua")
    thread:start(reqName, resName)

    return setmetatable({
        thread = thread,
        requestChannel = requestChannel,
        resultChannel = resultChannel,
        nextJobId = 1,
        stopped = false,
    }, ThreadedGenerator)
end

function ThreadedGenerator:submit(cx, cy, seed)
    if self.stopped then
        return nil
    end
    local id = self.nextJobId
    self.nextJobId = self.nextJobId + 1
    self.requestChannel:push({
        cmd = "gen",
        id = id,
        cx = cx,
        cy = cy,
        seed = seed,
    })
    return id
end

function ThreadedGenerator:collect(maxItems)
    local out = {}
    local maxCount = maxItems or 8
    for _ = 1, maxCount do
        -- Non-blocking pop so frame time stays deterministic.
        local msg = self.resultChannel:pop()
        if not msg then
            break
        end
        out[#out + 1] = msg
    end
    return out
end

function ThreadedGenerator:stop()
    if self.stopped then
        return
    end
    self.stopped = true
    self.requestChannel:push({ cmd = "stop" })
end

return ThreadedGenerator
