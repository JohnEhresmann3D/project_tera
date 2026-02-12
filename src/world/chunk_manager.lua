local Constants = require("src.constants")
local Chunk = require("src.world.chunk")
local Coord = require("src.world.coordinate")
local Pipeline = require("src.gen.pipeline")

local floor = math.floor
local sqrt = math.sqrt

local ChunkManager = {}
ChunkManager.__index = ChunkManager

function ChunkManager.new(worldSeed)
    local self = setmetatable({
        chunks = {},
        loadQueue = {},
        worldSeed = worldSeed or Constants.DEFAULT_SEED,
        frameCount = 0,
        loadRadius = Constants.LOAD_RADIUS,
        cacheRadius = Constants.CACHE_RADIUS,
        maxCached = Constants.MAX_CACHED,
        genBudgetMs = Constants.GEN_BUDGET_MS,
        loadedCount = 0,
        lastCamCx = nil,
        lastCamCy = nil,
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
        self.chunks[key] = chunk
        self.loadedCount = self.loadedCount + 1
    end
    chunk.lastAccess = self.frameCount
    return chunk
end

function ChunkManager:removeChunk(cx, cy)
    local key = chunkKey(cx, cy)
    if self.chunks[key] then
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

    local camCx = floor(camWx / Constants.CHUNK_W)
    local camCy = floor(camWy / Constants.CHUNK_H)

    -- Rebuild load queue if camera moved to a new chunk
    if camCx ~= self.lastCamCx or camCy ~= self.lastCamCy then
        self.lastCamCx = camCx
        self.lastCamCy = camCy
        self:rebuildLoadQueue(camCx, camCy)
    end

    -- Process generation queue within budget
    self:processQueue()

    -- Evict distant chunks
    self:evictChunks(camCx, camCy)
end

function ChunkManager:rebuildLoadQueue(camCx, camCy)
    self.loadQueue = {}
    local r = self.loadRadius

    -- Spiral outward from camera for prioritized loading
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
    if #self.loadQueue == 0 then return end

    local startTime = love.timer.getTime()
    local budget = self.genBudgetMs

    while #self.loadQueue > 0 do
        local entry = self.loadQueue[1]
        local chunk = self:getOrCreateChunk(entry.cx, entry.cy)

        if not chunk.generated then
            local remainingBudget = budget - (love.timer.getTime() - startTime) * 1000
            if remainingBudget <= 0 then break end

            local completed = Pipeline.generate(chunk, self.worldSeed, remainingBudget)
            if completed then
                table.remove(self.loadQueue, 1)
            else
                break  -- budget exhausted mid-stage
            end
        else
            table.remove(self.loadQueue, 1)
        end

        local elapsed = (love.timer.getTime() - startTime) * 1000
        if elapsed >= budget then break end
    end
end

function ChunkManager:evictChunks(camCx, camCy)
    local r = self.cacheRadius
    local staleThreshold = self.frameCount - 300

    local toEvict = {}
    for key, chunk in pairs(self.chunks) do
        local dx = chunk.cx - camCx
        local dy = chunk.cy - camCy
        local dist = sqrt(dx * dx + dy * dy)
        if dist > r and chunk.lastAccess < staleThreshold then
            toEvict[#toEvict + 1] = { key = key, dist = dist }
        end
    end

    -- Evict farthest first
    if #toEvict > 0 then
        table.sort(toEvict, function(a, b) return a.dist > b.dist end)
        local maxEvict = self.loadedCount - self.maxCached
        if maxEvict < 0 then maxEvict = 0 end
        -- Always evict those beyond cache radius, up to reasonable limit
        local count = math.min(#toEvict, math.max(maxEvict, 4))
        for i = 1, count do
            local key = toEvict[i].key
            -- Release GPU mesh before evicting to prevent memory leak
            local chunk = self.chunks[key]
            if chunk and chunk._mesh3d then
                chunk._mesh3d:release()
                chunk._mesh3d = nil
            end
            self.chunks[key] = nil
            self.loadedCount = self.loadedCount - 1
        end
    end
end

return ChunkManager
