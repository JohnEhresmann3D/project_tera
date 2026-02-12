-- Main 3D rendering pipeline
-- Two-tier rendering: active radius for expensive mesh rebuilds,
-- full load radius for cheap cached mesh drawing.
--
-- Frame flow (high level):
-- 1) Update camera matrices + frustum planes.
-- 2) Gather visible chunks.
-- 3) Rebuild only a budgeted subset of dirty meshes (near player first).
-- 4) Draw cached meshes + rebuilt meshes.
-- 5) Blit internal render canvas to the window.

local Constants    = require("src.constants")
local Shader       = require("src.render3d.shader")
local MeshBuilder  = require("src.render3d.mesh_builder")
local Frustum      = require("src.render3d.frustum")
local Coord        = require("src.world.coordinate")
local Sky          = require("src.render3d.sky")

local CW = Constants.CHUNK_W
local CH = Constants.CHUNK_H
local ZL = Constants.Z_LEVELS
local floor = math.floor
local min   = math.min
local max   = math.max
local abs   = math.abs

local Renderer3D = {}

local shader
local canvas
local depthCanvas
local screenW, screenH
local renderScale = 1.0
local canvasW, canvasH

-- Pre-allocated neighbor offsets (avoid table creation per call)
local NEIGHBOR_OFFSETS = {{-1,0},{1,0},{0,-1},{0,1}}
local variantBuildOpts

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------

function Renderer3D.init()
    screenW = love.graphics.getWidth()
    screenH = love.graphics.getHeight()

    shader = Shader.compile()
    Sky.init()

    Renderer3D._createCanvases(screenW, screenH)
end

function Renderer3D._createCanvases(w, h)
    local sw = math.max(1, math.floor(w * renderScale + 0.5))
    local sh = math.max(1, math.floor(h * renderScale + 0.5))
    canvasW, canvasH = sw, sh
    canvas = love.graphics.newCanvas(sw, sh)
    depthCanvas = love.graphics.newCanvas(sw, sh, {format = "depth24"})
end

function Renderer3D.resize(w, h)
    screenW = w
    screenH = h
    Renderer3D._createCanvases(w, h)
end

function Renderer3D.setRenderScale(scale)
    local s = tonumber(scale) or 1.0
    if s < 0.5 then s = 0.5 end
    if s > 1.0 then s = 1.0 end
    if math.abs(s - renderScale) < 0.001 then
        return
    end
    renderScale = s
    if screenW and screenH then
        Renderer3D._createCanvases(screenW, screenH)
    end
end

function Renderer3D.getRenderScale()
    return renderScale
end

---------------------------------------------------------------------------
-- Mark neighbor meshes dirty when a chunk finishes generating
---------------------------------------------------------------------------

local function markNeighborsDirty(chunkManager, cx, cy)
    for _, off in ipairs(NEIGHBOR_OFFSETS) do
        local nc = chunkManager:getChunk(cx + off[1], cy + off[2])
        if nc and nc.generated then
            nc._mesh3dDirty = true
        end
    end
end

---------------------------------------------------------------------------
-- Cross-chunk neighbor block lookup (created once per frame)
---------------------------------------------------------------------------

local function createNeighborFunc(chunkManager)
    return function(wx, wy, wz)
        local cx, cy = Coord.worldToChunk(wx, wy)
        local chunk = chunkManager:getChunk(cx, cy)
        if not chunk or not chunk.generated then
            return Constants.BLOCK_AIR
        end
        local lx = wx - cx * CW
        local ly = wy - cy * CH
        return chunk:getBlock(lx, ly, wz)
    end
end

---------------------------------------------------------------------------
-- Ensure a chunk has an up-to-date 3D mesh
---------------------------------------------------------------------------

function Renderer3D.ensureMesh(chunk, chunkManager, neighborFunc, variantKey)
    variantKey = variantKey or "normal"
    local variantMatches = (chunk._mesh3dVariantKey == variantKey)
    if not chunk._mesh3dDirty and chunk._mesh3d and variantMatches then
        return chunk._mesh3d
    end

    local firstBuild = (chunk._mesh3d == nil)

    -- Release old mesh GPU object
    if chunk._mesh3d then
        chunk._mesh3d:release()
        chunk._mesh3d = nil
    end

    neighborFunc = neighborFunc or createNeighborFunc(chunkManager)
    chunk._mesh3d = MeshBuilder.build(chunk, neighborFunc, variantBuildOpts(variantKey))
    chunk._mesh3dDirty = false
    chunk._mesh3dVariantKey = variantKey

    if firstBuild then
        markNeighborsDirty(chunkManager, chunk.cx, chunk.cy)
    end

    return chunk._mesh3d
end

---------------------------------------------------------------------------
-- Main draw — two-tier rendering
--
-- Tier 1 (ACTIVE_RADIUS): mesh rebuilds + draws (expensive, small area)
-- Tier 2 (LOAD_RADIUS):   draw cached meshes only (cheap, large area)
--
-- Dirty chunks beyond ACTIVE_RADIUS only get first-builds (no mesh yet),
-- never re-builds. This keeps distant chunks visible with cached geometry
-- while focusing CPU budget on nearby chunks.
---------------------------------------------------------------------------

-- Reusable list for dirty chunk rebuild prioritization
local dirtyList = {}
local visibleList = {}
local rebuildList = {}
local rebuildSet = {}
local lastYaw = nil
local lastPitch = nil

local TURN_THROTTLE_THRESHOLD = 0.012
local TURN_REBUILD_SCALE = 0.5
local FIRST_BUILD_RADIUS_BONUS = 2
local MICRO_LOD_ENABLED = not not Constants.MICRO_VOXEL_SURFACE
local MICRO_NEAR_R = math.max(1, Constants.MICRO_VOXEL_NEAR_RADIUS or 3)
local MICRO_MID_R = math.max(MICRO_NEAR_R, Constants.MICRO_VOXEL_FAR_RADIUS or 5)
local MICRO_NEAR_SQ = MICRO_NEAR_R * MICRO_NEAR_R
local MICRO_MID_SQ = MICRO_MID_R * MICRO_MID_R
local MICRO_HYST_SQ = 1

local MICRO_NEAR_SUBDIV = math.max(1, Constants.MICRO_VOXEL_NEAR_SUBDIV or 3)
local MICRO_MID_SUBDIV = math.max(1, Constants.MICRO_VOXEL_MID_SUBDIV or 2)

local MICRO_REBUILD_NEAR = math.max(0, Constants.MICRO_VOXEL_REBUILD_NEAR or 3)
local MICRO_REBUILD_MID = math.max(0, Constants.MICRO_VOXEL_REBUILD_MID or 2)
local MICRO_REBUILD_FAR = math.max(0, Constants.MICRO_VOXEL_REBUILD_FAR or 1)

variantBuildOpts = function(variantKey)
    if variantKey == "micro_near" then
        return { microSurface = true, microSubdiv = MICRO_NEAR_SUBDIV }
    elseif variantKey == "micro_mid" then
        return { microSurface = true, microSubdiv = MICRO_MID_SUBDIV }
    end
    return { microSurface = false }
end

local function chooseSurfaceVariant(chunk, distSq)
    if not MICRO_LOD_ENABLED then
        return "normal", 3
    end

    -- Hysteresis around ring boundaries to reduce variant thrash.
    local current = chunk._mesh3dVariantKey
    if current == "micro_near" and distSq <= (MICRO_NEAR_SQ + MICRO_HYST_SQ) then
        return "micro_near", 1
    end
    if current == "micro_mid" and distSq <= (MICRO_MID_SQ + MICRO_HYST_SQ) and distSq > (MICRO_NEAR_SQ - MICRO_HYST_SQ) then
        return "micro_mid", 2
    end

    if distSq <= MICRO_NEAR_SQ then
        return "micro_near", 1
    elseif distSq <= MICRO_MID_SQ then
        return "micro_mid", 2
    end
    return "normal", 3
end

local function splitRebuildBudgets(totalBudget)
    local nearB = math.min(MICRO_REBUILD_NEAR, totalBudget)
    local left = totalBudget - nearB
    local midB = math.min(MICRO_REBUILD_MID, left)
    left = left - midB
    local farB = math.min(MICRO_REBUILD_FAR, left)
    left = left - farB
    nearB = nearB + left
    return nearB, midB, farB
end

function Renderer3D.draw(camera3d, chunkManager, player)
    -- Update camera matrices
    camera3d:updateMatrices()

    -- Extract frustum planes for culling (reuses pre-allocated tables)
    local planes = Frustum.extract(camera3d.viewProj)

    -- Get sky/fog colors from day/night cycle
    local skyR, skyG, skyB = Sky.getSkyColor()
    local fogR, fogG, fogB = Sky.getFogColor()
    local ambient = Sky.getAmbientLevel()

    -- Set up 3D rendering state
    love.graphics.setCanvas({canvas, depthstencil = depthCanvas})
    love.graphics.clear(skyR, skyG, skyB, 1, true, true)

    -- Draw celestial bodies onto canvas BEFORE terrain.
    -- They sit at depth=1.0 (cleared), so terrain drawn afterward
    -- naturally occludes them via depth testing.
    Sky.draw(canvasW or screenW, canvasH or screenH, camera3d)

    love.graphics.setShader(shader)
    love.graphics.setDepthMode("lequal", true)
    love.graphics.setMeshCullMode("back")

    shader:send("u_view", "column", camera3d.view)
    shader:send("u_proj", "column", camera3d.proj)
    shader:send("u_fogStart", Constants.FOG_START)
    shader:send("u_fogEnd", Constants.FOG_END)
    shader:send("u_fogColor", {fogR, fogG, fogB})

    -- Tint meshes by ambient light level (day/night dimming)
    love.graphics.setColor(ambient, ambient, ambient, 1)

    -- Radii
    local px, py = player:getWorldPos()
    local camCx = floor(px / CW)
    local camCy = floor(py / CH)

    local activeR   = chunkManager.activeRadius or Constants.ACTIVE_RADIUS
    local viewR     = chunkManager.loadRadius or Constants.LOAD_RADIUS
    local activeRSq = activeR * activeR
    local viewRSq   = viewR * viewR
    local buildR = activeR + FIRST_BUILD_RADIUS_BONUS
    local buildRSq = buildR * buildR

    local meshesDrawn = 0
    local meshesTotal = 0
    local meshRebuilds = 0
    local maxRebuilds = chunkManager.meshRebuildBudget or Constants.MAX_MESH_REBUILDS_PER_FRAME
    local nearVisible = 0
    local midVisible = 0
    local farVisible = 0
    local nearRebuilds = 0
    local midRebuilds = 0
    local farRebuilds = 0

    local turningFast = false
    if lastYaw then
        local yawDelta = abs(camera3d.yaw - lastYaw)
        if yawDelta > math.pi then
            yawDelta = 2 * math.pi - yawDelta
        end
        local pitchDelta = abs(camera3d.pitch - lastPitch)
        turningFast = (yawDelta + pitchDelta) > TURN_THROTTLE_THRESHOLD
    end
    lastYaw = camera3d.yaw
    lastPitch = camera3d.pitch
    if turningFast then
        maxRebuilds = max(1, floor(maxRebuilds * TURN_REBUILD_SCALE))
    end

    -- Create neighbor lookup once for all mesh rebuilds this frame
    local neighborFunc = createNeighborFunc(chunkManager)

    -- Collect dirty chunks for prioritized rebuilds.
    -- Learner note: this decouples "visibility" from "rebuild eligibility".
    local dirtyCount = 0
    local visibleCount = 0

    -- Iterate full view radius — drawing cached meshes is cheap
    for dy = -viewR, viewR do
        for dx = -viewR, viewR do
            local distSq = dx * dx + dy * dy
            if distSq <= viewRSq then
                local cx = camCx + dx
                local cy = camCy + dy
                local chunk = chunkManager:getChunk(cx, cy)

                if chunk and chunk.generated then
                    meshesTotal = meshesTotal + 1

                    -- Initialize mesh dirty fields if missing
                    if chunk._mesh3dDirty == nil then
                        chunk._mesh3dDirty = true
                        chunk._mesh3d = nil
                    end

                    -- Frustum cull: chunk AABB in 3D coords
                    local minX = cx * CW
                    local minY = 0
                    local minZ = cy * CH
                    local maxX = (cx + 1) * CW
                    local maxY = ZL
                    local maxZ = (cy + 1) * CH

                    if Frustum.testAABB(planes, minX, minY, minZ, maxX, maxY, maxZ) then
                        local wantVariant, ring = chooseSurfaceVariant(chunk, distSq)
                        if ring == 1 then
                            nearVisible = nearVisible + 1
                        elseif ring == 2 then
                            midVisible = midVisible + 1
                        else
                            farVisible = farVisible + 1
                        end

                        if chunk._mesh3d and chunk._mesh3dVariantKey ~= wantVariant then
                            chunk._mesh3dDirty = true
                        end
                        -- Draw cached mesh (always — this is cheap)
                        local mesh = chunk._mesh3d
                        visibleCount = visibleCount + 1
                        local v = visibleList[visibleCount]
                        if not v then
                            v = {}
                            visibleList[visibleCount] = v
                        end
                        v.chunk = chunk
                        v.mesh = mesh
                        v.wantVariant = wantVariant

                        -- Decide whether this chunk should be rebuilt:
                        --   Active zone: rebuild any dirty mesh
                        --   View zone:   only first-builds (no mesh exists yet)
                        if chunk._mesh3dDirty then
                            local inActiveZone = distSq <= activeRSq
                            local needsFirstBuild = chunk._mesh3d == nil
                            local inBuildZone = distSq <= buildRSq
                            if inActiveZone or (needsFirstBuild and inBuildZone) then
                                dirtyCount = dirtyCount + 1
                                local entry = dirtyList[dirtyCount]
                                if not entry then
                                    entry = {}
                                    dirtyList[dirtyCount] = entry
                                end
                                entry.chunk = chunk
                                entry.distSq = distSq
                                entry.ring = ring
                                entry.wantVariant = wantVariant
                            end
                        end
                    end
                end
            end
        end
    end

    -- Sort dirty chunks by distance (closest first) — insertion sort
    if dirtyCount > 1 then
        for i = 2, dirtyCount do
            local key = dirtyList[i]
            local keyDist = key.distSq
            local j = i - 1
            while j >= 1 and dirtyList[j].distSq > keyDist do
                dirtyList[j + 1] = dirtyList[j]
                j = j - 1
            end
            dirtyList[j + 1] = key
        end
    end

    -- Rebuild closest dirty chunks within budget.
    -- This is the key frame-time guardrail for CPU-side meshing.
    local rebuildsThisFrame = 0
    local nearBudget, midBudget, farBudget = splitRebuildBudgets(min(dirtyCount, maxRebuilds))
    for i = 1, dirtyCount do
        if rebuildsThisFrame >= maxRebuilds then break end
        local entry = dirtyList[i]
        local selected = false
        if entry.ring == 1 and nearBudget > 0 then
            nearBudget = nearBudget - 1
            nearRebuilds = nearRebuilds + 1
            selected = true
        elseif entry.ring == 2 and midBudget > 0 then
            midBudget = midBudget - 1
            midRebuilds = midRebuilds + 1
            selected = true
        elseif entry.ring == 3 and farBudget > 0 then
            farBudget = farBudget - 1
            farRebuilds = farRebuilds + 1
            selected = true
        end

        if selected then
            rebuildsThisFrame = rebuildsThisFrame + 1
            rebuildList[rebuildsThisFrame] = entry
            rebuildSet[entry.chunk] = true
        end
    end

    -- Draw cached meshes for chunks not being rebuilt this frame.
    for i = 1, visibleCount do
        local v = visibleList[i]
        if v.mesh and not rebuildSet[v.chunk] then
            love.graphics.draw(v.mesh)
            meshesDrawn = meshesDrawn + 1
        end
    end

    for i = 1, rebuildsThisFrame do
        local entry = rebuildList[i]
        local chunk = entry.chunk
        Renderer3D.ensureMesh(chunk, chunkManager, neighborFunc, entry.wantVariant)
        meshRebuilds = meshRebuilds + 1

        -- Draw the newly built mesh
        local mesh = chunk._mesh3d
        if mesh then
            love.graphics.draw(mesh)
            meshesDrawn = meshesDrawn + 1
        end
    end

    -- Clear references to avoid holding chunks across frames
    for i = 1, dirtyCount do
        rebuildSet[dirtyList[i].chunk] = nil
        dirtyList[i].chunk = nil
        dirtyList[i].wantVariant = nil
        dirtyList[i].ring = nil
    end
    for i = 1, rebuildsThisFrame do
        rebuildList[i] = nil
    end
    for i = 1, visibleCount do
        visibleList[i].chunk = nil
        visibleList[i].mesh = nil
        visibleList[i].wantVariant = nil
    end

    -- Restore state
    love.graphics.setMeshCullMode("none")
    love.graphics.setDepthMode("always", false)
    love.graphics.setShader()
    love.graphics.setCanvas()

    -- Blit 3D canvas to screen
    love.graphics.setColor(1, 1, 1, 1)
    local sx = screenW / (canvasW or screenW)
    local sy = screenH / (canvasH or screenH)
    love.graphics.draw(canvas, 0, 0, 0, sx, sy)

    -- Store stats for HUD
    Renderer3D._meshesDrawn = meshesDrawn
    Renderer3D._meshesTotal = meshesTotal
    Renderer3D._meshRebuilds = meshRebuilds
    Renderer3D._lodNearVisible = nearVisible
    Renderer3D._lodMidVisible = midVisible
    Renderer3D._lodFarVisible = farVisible
    Renderer3D._lodNearRebuilds = nearRebuilds
    Renderer3D._lodMidRebuilds = midRebuilds
    Renderer3D._lodFarRebuilds = farRebuilds
end

---------------------------------------------------------------------------
-- HUD (2D overlay, drawn after 3D scene)
---------------------------------------------------------------------------

function Renderer3D.drawHUD(player, camera3d, chunkManager)
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 4, 4, 500, 212, 4)

    love.graphics.setColor(1, 1, 1, 1)
    local tx, ty, tz = player:getTilePos()
    local cx = floor(tx / CW)
    local cy = floor(ty / CH)
    local fps = love.timer.getFPS()
    local loadedChunks = chunkManager:getLoadedCount()
    local worldSeed = chunkManager.worldSeed or 0
    local perf = chunkManager.getPerfStats and chunkManager:getPerfStats() or nil
    local tierName = chunkManager.perfTierName or "custom"

    local yawDeg = math.deg(camera3d.yaw) % 360
    local pitchDeg = math.deg(camera3d.pitch)

    love.graphics.print(string.format("FPS: %d  Chunks: %d", fps, loadedChunks), 10, 10)
    love.graphics.print(string.format("Pos: %d, %d, %d  Chunk: %d, %d", tx, ty, tz, cx, cy), 10, 28)
    love.graphics.print(string.format("Yaw: %.1f  Pitch: %.1f", yawDeg, pitchDeg), 10, 46)
    local mode = player.flying and "FLY" or (player.onGround and "GROUND" or "AIR")
    love.graphics.print(string.format("Mode: %s  Time: %s", mode, Sky.getTimeString()), 10, 64)
    love.graphics.print(string.format("Meshes: %d drawn / %d total  Rebuilds: %d",
        Renderer3D._meshesDrawn or 0, Renderer3D._meshesTotal or 0,
        Renderer3D._meshRebuilds or 0), 10, 82)
    love.graphics.print(string.format("Ambient: %.0f%%", Sky.getAmbientLevel() * 100), 10, 100)
    love.graphics.print(string.format("Seed: %d", worldSeed), 10, 118)
    love.graphics.print(string.format("Tier:%s RenderScale:%.2f", tierName, Renderer3D.getRenderScale()), 10, 136)
    if perf then
        love.graphics.print(string.format("ChunkQ:%d Gen:%d Evict:%d", perf.queue, perf.generated, perf.evicted), 10, 154)
    end
    love.graphics.print(string.format("LOD N/M/F: %d/%d/%d  Reb N/M/F: %d/%d/%d",
        Renderer3D._lodNearVisible or 0, Renderer3D._lodMidVisible or 0, Renderer3D._lodFarVisible or 0,
        Renderer3D._lodNearRebuilds or 0, Renderer3D._lodMidRebuilds or 0, Renderer3D._lodFarRebuilds or 0), 10, 172)
    love.graphics.print("WASD:move Shift:run Space:jump F:fly R:regen Tab:mouse F8:noise F9:tier F10/V:render", 10, 190)

    -- Crosshair
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()
    local cx2 = sw * 0.5
    local cy2 = sh * 0.5
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.setLineWidth(2)
    love.graphics.line(cx2 - 10, cy2, cx2 + 10, cy2)
    love.graphics.line(cx2, cy2 - 10, cx2, cy2 + 10)
    love.graphics.setLineWidth(1)
end

return Renderer3D

