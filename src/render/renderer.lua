local Constants = require("src.constants")
local Coord = require("src.world.coordinate")
local BlockRegistry = require("src.world.block_registry")
local Lighting = require("src.render.lighting")

local CW = Constants.CHUNK_W
local CH = Constants.CHUNK_H
local ZL = Constants.Z_LEVELS
local TW = Constants.TILE_W
local TH = Constants.TILE_H
local TD = Constants.TILE_D
local BLOCK_AIR = Constants.BLOCK_AIR

local setColor = love.graphics.setColor
local polygon = love.graphics.polygon
local setLineWidth = love.graphics.setLineWidth
local line = love.graphics.line

local min = math.min
local max = math.max
local floor = math.floor

local Renderer = {}

------------------------------------------------------------------------
-- Draw helpers: pre-colored (no internal multiplier)
------------------------------------------------------------------------

-- Top face diamond, pre-lit color
local function drawDiamondTopColored(sx, sy, r, g, b, a, zoom)
    local hw = (TW * 0.5) * zoom
    local hh = (TH * 0.5) * zoom
    setColor(r, g, b, a)
    polygon("fill",
        sx,      sy,
        sx + hw, sy + hh,
        sx,      sy + hh * 2,
        sx - hw, sy + hh
    )
end

-- Left face, pre-lit color
local function drawDiamondLeftColored(sx, sy, r, g, b, a, zoom, depth)
    local hw = (TW * 0.5) * zoom
    local hh = (TH * 0.5) * zoom
    local d = depth * zoom
    setColor(r, g, b, a)
    polygon("fill",
        sx - hw, sy + hh,
        sx,      sy + hh * 2,
        sx,      sy + hh * 2 + d,
        sx - hw, sy + hh + d
    )
end

-- Right face, pre-lit color
local function drawDiamondRightColored(sx, sy, r, g, b, a, zoom, depth)
    local hw = (TW * 0.5) * zoom
    local hh = (TH * 0.5) * zoom
    local d = depth * zoom
    setColor(r, g, b, a)
    polygon("fill",
        sx + hw, sy + hh,
        sx,      sy + hh * 2,
        sx,      sy + hh * 2 + d,
        sx + hw, sy + hh + d
    )
end

-- Cliff face left: one Z-level segment of a cliff wall on the left side
-- yOffset: pixel offset from top of this tile (for stacking segments)
-- segHeight: pixel height of this segment
local function drawCliffFaceLeft(sx, sy, r, g, b, a, zoom, yOffset, segHeight)
    local hw = (TW * 0.5) * zoom
    local hh = (TH * 0.5) * zoom
    local yo = yOffset * zoom
    local sh = segHeight * zoom
    setColor(r, g, b, a)
    polygon("fill",
        sx - hw, sy + hh + yo,
        sx,      sy + hh * 2 + yo,
        sx,      sy + hh * 2 + yo + sh,
        sx - hw, sy + hh + yo + sh
    )
end

-- Cliff face right: one Z-level segment on the right side
local function drawCliffFaceRight(sx, sy, r, g, b, a, zoom, yOffset, segHeight)
    local hw = (TW * 0.5) * zoom
    local hh = (TH * 0.5) * zoom
    local yo = yOffset * zoom
    local sh = segHeight * zoom
    setColor(r, g, b, a)
    polygon("fill",
        sx + hw, sy + hh + yo,
        sx,      sy + hh * 2 + yo,
        sx,      sy + hh * 2 + yo + sh,
        sx + hw, sy + hh + yo + sh
    )
end

-- Shadow diamond: dark semi-transparent overlay
local function drawShadowDiamond(sx, sy, alpha, zoom)
    local hw = (TW * 0.5) * zoom
    local hh = (TH * 0.5) * zoom
    setColor(0, 0, 0, alpha)
    polygon("fill",
        sx,      sy,
        sx + hw, sy + hh,
        sx,      sy + hh * 2,
        sx - hw, sy + hh
    )
end

------------------------------------------------------------------------
-- Legacy draw (for sub-surface blocks without full lighting)
------------------------------------------------------------------------

local function drawBlockSimple(sx, sy, r, g, b, a, zoom, brightness)
    local depth = TD * 0.5
    local br = brightness or 1.0
    drawDiamondLeftColored(sx, sy, r * 0.55 * br, g * 0.55 * br, b * 0.55 * br, a, zoom, depth)
    drawDiamondRightColored(sx, sy, r * 0.82 * br, g * 0.82 * br, b * 0.82 * br, a, zoom, depth)
    drawDiamondTopColored(sx, sy, r * br, g * br, b * br, a, zoom)
end

------------------------------------------------------------------------
-- Main draw
------------------------------------------------------------------------

function Renderer.draw(camera, chunkManager, player)
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()

    local minCx, minCy, maxCx, maxCy = Coord.getVisibleChunkRange(camera, screenW, screenH)
    local viewZ = math.floor(camera.viewZ)

    -- Precompute fog max distance squared (half diagonal of screen)
    local halfW = screenW * 0.5
    local halfH = screenH * 0.5
    local maxDistSq = halfW * halfW + halfH * halfH

    -- Collect visible chunks and sort by draw order (cx + cy ascending = back to front)
    local visibleChunks = {}
    for cy = minCy, maxCy do
        for cx = minCx, maxCx do
            local chunk = chunkManager:getChunk(cx, cy)
            if chunk and chunk.generated then
                -- Compute lighting cache if needed
                if chunk.dirty or not chunk._lightCache then
                    Lighting.computeCache(chunk, chunkManager)
                    chunk.dirty = false
                end
                visibleChunks[#visibleChunks + 1] = chunk
            end
        end
    end

    table.sort(visibleChunks, function(a, b)
        local sa = a.cx + a.cy
        local sb = b.cx + b.cy
        if sa ~= sb then return sa < sb end
        return a.cx < b.cx
    end)

    -- Draw chunks back-to-front
    for _, chunk in ipairs(visibleChunks) do
        Renderer.drawChunk(chunk, camera, viewZ, chunkManager, maxDistSq)
    end

    -- Draw player marker
    if player then
        Renderer.drawPlayer(player, camera)
    end
end

function Renderer.drawChunk(chunk, camera, viewZ, chunkManager, maxDistSq)
    local cx, cy = chunk.cx, chunk.cy
    local lightCache = chunk._lightCache
    local lightingEnabled = Lighting.config.enabled and lightCache

    -- Screen center for fog distance calculation
    local centerX = camera.screenCenterX
    local centerY = camera.screenCenterY

    local minZ = 0
    local maxZ = viewZ + 1
    if maxZ >= ZL then maxZ = ZL - 1 end

    local depth = TD * 0.5

    for z = minZ, maxZ do
        local layerAlpha = 1.0
        if z > viewZ then
            layerAlpha = 0.15
        end

        -- Anti-diagonal sweep: iterate by (lx + ly) ascending for back-to-front
        for diag = 0, CW + CH - 2 do
            local startX = 0
            if diag >= CH then startX = diag - CH + 1 end
            local endX = diag
            if endX >= CW then endX = CW - 1 end

            for lx = startX, endX do
                local ly = diag - lx
                local blockId = chunk:getBlock(lx, ly, z)

                if blockId ~= BLOCK_AIR then
                    -- Check if the block above is solid (occlusion)
                    local aboveId = BLOCK_AIR
                    if z < ZL - 1 then
                        aboveId = chunk:getBlock(lx, ly, z + 1)
                    end

                    if aboveId == BLOCK_AIR or BlockRegistry.isTransparent(aboveId) then
                        local wx = cx * CW + lx
                        local wy = cy * CH + ly
                        local sx, sy = Coord.worldToScreen(wx, wy, z, camera)

                        local color = BlockRegistry.getColor(blockId)
                        local r, g, b, a = color[1], color[2], color[3], color[4]
                        a = a * layerAlpha

                        -- Is this the surface block for this column?
                        local surfH = chunk:getHeight(lx, ly)
                        local isSurface = (z == surfH) and lightingEnabled

                        if isSurface then
                            local cacheIdx = lx + ly * CW + 1
                            local entry = lightCache[cacheIdx]

                            -- Compute lit colors for each face
                            local topR = r * entry.topMul
                            local topG = g * entry.topMul
                            local topB = b * entry.topMul

                            local leftR = r * entry.leftMul
                            local leftG = g * entry.leftMul
                            local leftB = b * entry.leftMul

                            local rightR = r * entry.rightMul
                            local rightG = g * entry.rightMul
                            local rightB = b * entry.rightMul

                            -- Apply distance fog
                            local dxs = sx - centerX
                            local dys = sy - centerY
                            local screenDistSq = dxs * dxs + dys * dys

                            topR, topG, topB = Lighting.applyFog(topR, topG, topB, screenDistSq, maxDistSq)
                            leftR, leftG, leftB = Lighting.applyFog(leftR, leftG, leftB, screenDistSq, maxDistSq)
                            rightR, rightG, rightB = Lighting.applyFog(rightR, rightG, rightB, screenDistSq, maxDistSq)

                            -- 1. Drop shadow (offset to lower-right)
                            if Lighting.config.shadows then
                                local shadowOffX = 6 * camera.zoom
                                local shadowOffY = 4 * camera.zoom
                                drawShadowDiamond(sx + shadowOffX, sy + shadowOffY, 0.12 * layerAlpha, camera.zoom)
                            end

                            -- 2. Cliff walls
                            if Lighting.config.cliffs then
                                local cliffL = entry.cliffLeft
                                local cliffR = entry.cliffRight

                                if cliffL > 0 then
                                    local segH = TD * 0.5  -- pixel height per Z-level segment
                                    for ci = 0, cliffL - 1 do
                                        local cliffZ = z - ci - 1
                                        if cliffZ >= 0 then
                                            local cliffBlockId = chunk:getBlock(lx, ly, cliffZ)
                                            local cliffColor = BlockRegistry.getColor(cliffBlockId)
                                            local cr, cg, cb = cliffColor[1], cliffColor[2], cliffColor[3]
                                            -- Darken cliff faces progressively
                                            local cliffBr = 0.45 - ci * 0.05
                                            if cliffBr < 0.25 then cliffBr = 0.25 end
                                            cr, cg, cb = cr * cliffBr, cg * cliffBr, cb * cliffBr
                                            -- Apply fog to cliff faces too
                                            cr, cg, cb = Lighting.applyFog(cr, cg, cb, screenDistSq, maxDistSq)
                                            local yOff = depth + ci * segH
                                            drawCliffFaceLeft(sx, sy, cr, cg, cb, a, camera.zoom, yOff, segH)
                                        end
                                    end
                                end

                                if cliffR > 0 then
                                    local segH = TD * 0.5
                                    for ci = 0, cliffR - 1 do
                                        local cliffZ = z - ci - 1
                                        if cliffZ >= 0 then
                                            local cliffBlockId = chunk:getBlock(lx, ly, cliffZ)
                                            local cliffColor = BlockRegistry.getColor(cliffBlockId)
                                            local cr, cg, cb = cliffColor[1], cliffColor[2], cliffColor[3]
                                            local cliffBr = 0.55 - ci * 0.05
                                            if cliffBr < 0.30 then cliffBr = 0.30 end
                                            cr, cg, cb = cr * cliffBr, cg * cliffBr, cb * cliffBr
                                            cr, cg, cb = Lighting.applyFog(cr, cg, cb, screenDistSq, maxDistSq)
                                            local yOff = depth + ci * segH
                                            drawCliffFaceRight(sx, sy, cr, cg, cb, a, camera.zoom, yOff, segH)
                                        end
                                    end
                                end
                            end

                            -- 3. Normal left/right faces
                            drawDiamondLeftColored(sx, sy, leftR, leftG, leftB, a, camera.zoom, depth)
                            drawDiamondRightColored(sx, sy, rightR, rightG, rightB, a, camera.zoom, depth)

                            -- 4. Top face
                            drawDiamondTopColored(sx, sy, topR, topG, topB, a, camera.zoom)

                            -- 5. Edge highlights along height transitions
                            if Lighting.config.edges then
                                local hw = (TW * 0.5) * camera.zoom
                                local hh = (TH * 0.5) * camera.zoom

                                -- Check height differences with visible-face neighbors
                                local hHere = surfH
                                -- +x neighbor (right edge)
                                local hPlusX
                                if lx < CW - 1 then
                                    hPlusX = chunk:getHeight(lx + 1, ly)
                                else
                                    hPlusX = chunkManager:getSurfaceHeight(wx + 1, wy)
                                end
                                -- +y neighbor (left edge)
                                local hPlusY
                                if ly < CH - 1 then
                                    hPlusY = chunk:getHeight(lx, ly + 1)
                                else
                                    hPlusY = chunkManager:getSurfaceHeight(wx, wy + 1)
                                end

                                setColor(0, 0, 0, 0.35 * layerAlpha)
                                setLineWidth(1)
                                -- Right edge (toward +x neighbor)
                                if hPlusX ~= hHere then
                                    line(
                                        sx + hw, sy + hh,
                                        sx,      sy + hh * 2
                                    )
                                end
                                -- Left edge (toward +y neighbor)
                                if hPlusY ~= hHere then
                                    line(
                                        sx - hw, sy + hh,
                                        sx,      sy + hh * 2
                                    )
                                end
                            end
                        else
                            -- Sub-surface or non-lit block: simple height-based brightness
                            local brightness
                            if lightingEnabled then
                                brightness = 0.65 + (z / (ZL - 1)) * 0.20
                                -- Apply fog for sub-surface too
                                local dxs = sx - centerX
                                local dys = sy - centerY
                                local screenDistSq = dxs * dxs + dys * dys
                                local br, bg, bb = r * brightness, g * brightness, b * brightness
                                br, bg, bb = Lighting.applyFog(br, bg, bb, screenDistSq, maxDistSq)
                                drawBlockSimple(sx, sy, br, bg, bb, a, camera.zoom, 1.0)
                            else
                                drawBlockSimple(sx, sy, r, g, b, a, camera.zoom, 1.0)
                            end
                        end
                    end
                end
            end
        end
    end
end

function Renderer.drawPlayer(player, camera)
    local wx, wy, wz = player:getWorldPos()
    local sx, sy = Coord.worldToScreen(wx, wy, wz, camera)

    -- Simple colored diamond for the player
    local zoom = camera.zoom
    local hw = 12 * zoom
    local hh = 6 * zoom

    -- Shadow
    setColor(0, 0, 0, 0.3)
    polygon("fill",
        sx, sy + 4 * zoom,
        sx + hw, sy + hh + 4 * zoom,
        sx, sy + hh * 2 + 4 * zoom,
        sx - hw, sy + hh + 4 * zoom
    )

    -- Player body (bright cyan)
    setColor(0, 0.9, 0.9, 1)
    polygon("fill",
        sx, sy,
        sx + hw, sy + hh,
        sx, sy + hh * 2,
        sx - hw, sy + hh
    )

    -- Outline
    setColor(1, 1, 1, 0.8)
    setLineWidth(2)
    polygon("line",
        sx, sy,
        sx + hw, sy + hh,
        sx, sy + hh * 2,
        sx - hw, sy + hh
    )
    setLineWidth(1)
end

function Renderer.drawHUD(player, camera, chunkManager)
    setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 4, 4, 320, 120, 4)

    setColor(1, 1, 1, 1)
    local tx, ty, tz = player:getTilePos()
    local cx, cy = Coord.worldToChunk(tx, ty)
    local fps = love.timer.getFPS()
    local loadedChunks = chunkManager:getLoadedCount()

    love.graphics.print(string.format("FPS: %d  Chunks: %d", fps, loadedChunks), 10, 10)
    love.graphics.print(string.format("Pos: %d, %d, %d  Chunk: %d, %d", tx, ty, tz, cx, cy), 10, 28)
    love.graphics.print(string.format("Zoom: %.1fx  ViewZ: %d", camera.zoom, math.floor(camera.viewZ)), 10, 46)
    love.graphics.print(string.format("Mode: %s", player.flying and "FLYING" or "GROUND"), 10, 64)
    love.graphics.print(Lighting.getStatusString(), 10, 82)
    love.graphics.print("WASD:move F:fly Scroll:zoom Space/Shift:up/dn F8:light F9:cycle", 10, 100)
end

return Renderer
