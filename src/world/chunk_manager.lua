local Constants = require("src.constants")
local Chunk = require("src.world.chunk")
local Coord = require("src.world.coordinate")
local Pipeline = require("src.gen.pipeline")
local ChunkCodec = require("src.gen.chunk_codec")
local ThreadedGenerator = require("src.gen.threaded_generator")
local ChunkStore = require("src.persistence.chunk_store")

local floor = math.floor
local sqrt = math.sqrt
local max = math.max
local min = math.min

local ChunkManager = {}
ChunkManager.__index = ChunkManager

function ChunkManager.new(worldSeed)
    -- Owns chunk lifecycle:
    -- create/load -> queue generation -> apply results -> evict/persist.
    local self = setmetatable({
        chunks = {},
        loadQueue = {},
        loadQueueHead = 1,
        worldSeed = worldSeed or Constants.DEFAULT_SEED,
        frameCount = 0,
        loadRadius = Constants.LOAD_RADIUS,
        cacheRadius = Constants.CACHE_RADIUS,
        maxCached = Constants.MAX_CACHED,
        genBudgetMs = Constants.GEN_BUDGET_MS,
        cacheStaleFrames = Constants.CACHE_STALE_FRAMES or 1800,
        cacheHardEvictMargin = Constants.CACHE_HARD_EVICT_MARGIN or 6,
        cacheMaxForcedEvictPerFrame = Constants.CACHE_MAX_FORCED_EVICT_PER_FRAME or 8,
        loadedCount = 0,
        lastCamCx = nil,
        lastCamCy = nil,
        chunkStore = ChunkStore.new(worldSeed or Constants.DEFAULT_SEED),
        generatedThisFrame = 0,
        evictedThisFrame = 0,
        queueSizeThisFrame = 0,
        inFlightJobs = {},
        inFlightCount = 0,
        maxInFlightJobs = 3,
        maxDispatchPerFrame = 3,
        maxResultApplyPerFrame = 6,
        threadGenerator = ThreadedGenerator.new(worldSeed or Constants.DEFAULT_SEED),
    }, ChunkManager)
    return self
end

-- Integer key for chunk coords (avoids string alloc)
local function chunkKey(cx, cy)
    return cx * 0x100000 + cy
end

function ChunkManager:getChunk(cx, cy)
    local key = chunkKey(cx, cy)
    local chunk = self.chunks[key]
    if chunk then
        chunk.lastAccess = self.frameCount
    end
    return chunk
end

function ChunkManager:getOrCreateChunk(cx, cy)
    local key = chunkKey(cx, cy)
    local chunk = self.chunks[key]
    if not chunk then
        chunk = Chunk.new(cx, cy)
        if self.chunkStore then
            -- If persisted chunk exists, this marks it generated immediately.
            self.chunkStore:loadChunk(cx, cy, chunk)
        end
        self.chunks[key] = chunk
        self.loadedCount = self.loadedCount + 1
    end
    chunk.lastAccess = self.frameCount
    return chunk
end

function ChunkManager:removeChunk(cx, cy)
    local key = chunkKey(cx, cy)
    local chunk = self.chunks[key]
    if chunk then
        if self.chunkStore and chunk.generated then
            self.chunkStore:saveChunk(chunk)
        end
        self.chunks[key] = nil
        self.loadedCount = self.loadedCount - 1
    end
end

function ChunkManager:getLoadedCount()
    return self.loadedCount
end

-- Get surface height at a world tile position
function ChunkManager:getSurfaceHeight(wx, wy)
    local cx, cy = Coord.worldToChunk(wx, wy)
    local chunk = self:getChunk(cx, cy)
    if not chunk or not chunk.generated then
        return Constants.SURFACE_Z
    end
    local lx, ly = Coord.worldToLocal(wx, wy)
    return chunk:getHeight(lx, ly)
end

function ChunkManager:update(camWx, camWy, dt)
    self.frameCount = self.frameCount + 1
    self.generatedThisFrame = 0
    self.evictedThisFrame = 0
    -- Always apply async results first so new chunks are drawable this frame.
    self:collectThreadResults()

    local camCx = floor(camWx / Constants.CHUNK_W)
    local camCy = floor(camWy / Constants.CHUNK_H)

    -- Rebuild load queue if camera moved to a new chunk
    if camCx ~= self.lastCamCx or camCy ~= self.lastCamCy then
        self.lastCamCx = camCx
        self.lastCamCy = camCy
        self:rebuildLoadQueue(camCx, camCy)
    end

    -- Process generation queue under CPU and in-flight limits.
    self:processQueue()

    -- Evict distant chunks
    self:evictChunks(camCx, camCy)
    self.queueSizeThisFrame = (#self.loadQueue - self.loadQueueHead + 1) + self.inFlightCount
    if self.queueSizeThisFrame < 0 then
        self.queueSizeThisFrame = 0
    end
end

function ChunkManager:rebuildLoadQueue(camCx, camCy)
    self.loadQueue = {}
    self.loadQueueHead = 1
    local r = self.loadRadius

    -- Build a distance-sorted target set centered on current camera chunk.
    for dy = -r, r do
        for dx = -r, r do
            local cx = camCx + dx
            local cy = camCy + dy
            local dist = sqrt(dx * dx + dy * dy)
            if dist <= r then
                local chunk = self:getChunk(cx, cy)
                if not chunk or not chunk.generated then
                    self.loadQueue[#self.loadQueue + 1] = {
                        cx = cx, cy = cy, dist = dist
                    }
                end
            end
        end
    end

    -- Sort by distance (closest first)
    table.sort(self.loadQueue, function(a, b) return a.dist < b.dist end)
end

function ChunkManager:processQueue()
    if self.loadQueueHead > #self.loadQueue then return end

    if self.threadGenerator then
        local dispatched = 0
        while self.loadQueueHead <= #self.loadQueue do
            if dispatched >= self.maxDispatchPerFrame then break end
            if self.inFlightCount >= self.maxInFlightJobs then break end

            local entry = self.loadQueue[self.loadQueueHead]
            local chunk = self:getOrCreateChunk(entry.cx, entry.cy)
            local key = chunkKey(entry.cx, entry.cy)

            if chunk.generated then
                self.loadQueueHead = self.loadQueueHead + 1
            elseif self.inFlightJobs[key] then
                -- Already queued to worker, just advance.
                self.loadQueueHead = self.loadQueueHead + 1
            else
                local jobId = self.threadGenerator:submit(entry.cx, entry.cy, self.worldSeed)
                if not jobId then
                    break
                end
                self.inFlightJobs[key] = jobId
                self.inFlightCount = self.inFlightCount + 1
                chunk.generating = true
                self.loadQueueHead = self.loadQueueHead + 1
                dispatched = dispatched + 1
            end
        end
    else
        -- Single-thread fallback for targets without worker support.
        local startTime = love.timer.getTime()
        local budget = self.genBudgetMs

        while self.loadQueueHead <= #self.loadQueue do
            local entry = self.loadQueue[self.loadQueueHead]
            local chunk = self:getOrCreateChunk(entry.cx, entry.cy)

            if not chunk.generated then
                local remainingBudget = budget - (love.timer.getTime() - startTime) * 1000
                if remainingBudget <= 0 then break end

                local completed = Pipeline.generate(chunk, self.worldSeed, remainingBudget)
                if completed then
                    if self.chunkStore then
                        self.chunkStore:saveChunk(chunk)
                    end
                    self.generatedThisFrame = self.generatedThisFrame + 1
                    self.loadQueueHead = self.loadQueueHead + 1
                else
                    break  -- budget exhausted mid-stage
                end
            else
                self.loadQueueHead = self.loadQueueHead + 1
            end

            local elapsed = (love.timer.getTime() - startTime) * 1000
            if elapsed >= budget then break end
        end
    end

    if self.loadQueueHead > #self.loadQueue then
        self.loadQueue = {}
        self.loadQueueHead = 1
    elseif self.loadQueueHead > 64 and self.loadQueueHead > (#self.loadQueue * 0.5) then
        local compacted = {}
        for i = self.loadQueueHead, #self.loadQueue do
            compacted[#compacted + 1] = self.loadQueue[i]
        end
        self.loadQueue = compacted
        self.loadQueueHead = 1
    end
end

function ChunkManager:evictChunks(camCx, camCy)
    local softR = self.cacheRadius
    local hardR = softR + self.cacheHardEvictMargin
    local softRSq = softR * softR
    local hardRSq = hardR * hardR
    local staleThreshold = self.frameCount - self.cacheStaleFrames

    -- Forced evictions keep memory bounded even if cap is not exceeded.
    local forcedEvict = {}
    local optionalEvict = {}
    for key, chunk in pairs(self.chunks) do
        local dx = chunk.cx - camCx
        local dy = chunk.cy - camCy
        local distSq = dx * dx + dy * dy
        if chunk.lastAccess < staleThreshold then
            if distSq > hardRSq then
                forcedEvict[#forcedEvict + 1] = { key = key, distSq = distSq }
            elseif distSq > softRSq then
                optionalEvict[#optionalEvict + 1] = { key = key, distSq = distSq }
            end
        end
    end

    if #forcedEvict > 0 or #optionalEvict > 0 then
        table.sort(forcedEvict, function(a, b) return a.distSq > b.distSq end)
        table.sort(optionalEvict, function(a, b) return a.distSq > b.distSq end)

        local forcedCount = min(#forcedEvict, self.cacheMaxForcedEvictPerFrame)
        local needForCap = max(0, self.loadedCount - self.maxCached)
        local optionalCount = min(#optionalEvict, max(0, needForCap - forcedCount))

        local function evictByKey(key)
            -- Release GPU mesh before evicting to prevent memory leak
            local chunk = self.chunks[key]
            if self.inFlightJobs[key] then
                self.inFlightJobs[key] = nil
                self.inFlightCount = max(0, self.inFlightCount - 1)
            end
            if chunk and self.chunkStore and chunk.generated then
                self.chunkStore:saveChunk(chunk)
            end
            if chunk and chunk._mesh3d then
                chunk._mesh3d:release()
                chunk._mesh3d = nil
            end
            self.chunks[key] = nil
            self.loadedCount = self.loadedCount - 1
            self.evictedThisFrame = self.evictedThisFrame + 1
        end

        for i = 1, forcedCount do
            evictByKey(forcedEvict[i].key)
        end
        for i = 1, optionalCount do
            evictByKey(optionalEvict[i].key)
        end
    end
end

function ChunkManager:collectThreadResults()
    if not self.threadGenerator then
        return
    end
    local results = self.threadGenerator:collect(self.maxResultApplyPerFrame)
    for _, msg in ipairs(results) do
        local key = chunkKey(msg.cx, msg.cy)
        if self.inFlightJobs[key] then
            self.inFlightJobs[key] = nil
            self.inFlightCount = max(0, self.inFlightCount - 1)
        end

        local chunk = self.chunks[key]
        -- Decode directly into resident chunk; stale results are ignored.
        if chunk and (not chunk.generated) and ChunkCodec.decodeIntoChunk(msg.payload, chunk) then
            chunk.generated = true
            chunk.genStage = Pipeline.getStageCount()
            chunk.dirty = true
            chunk._mesh3dDirty = true
            chunk.generating = false
            if self.chunkStore then
                self.chunkStore:saveChunk(chunk)
            end
            self.generatedThisFrame = self.generatedThisFrame + 1
        end
    end
end

function ChunkManager:shutdown()
    if self.threadGenerator then
        self.threadGenerator:stop()
        self.threadGenerator = nil
    end
end

function ChunkManager:getPerfStats()
    return {
        queue = self.queueSizeThisFrame or 0,
        generated = self.generatedThisFrame or 0,
        evicted = self.evictedThisFrame or 0,
    }
end

return ChunkManager
