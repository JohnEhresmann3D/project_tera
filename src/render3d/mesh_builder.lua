-- mesh_builder.lua
-- Single-pass face-culled mesh builder for voxel chunks.
-- Emits 2-triangle quads per visible face with baked directional lighting.
--
-- Coordinate mapping (CRITICAL):
--   World:  (wx, wy) = ground plane, wz = height (up)
--   3D:     X = wx,  Y = wz (up),  Z = wy
--   So vertex position = (wx + dx, wz + dz, wy + dy)
--
-- Performance notes:
--   - Single pass (no counting pre-pass)
--   - Per-column Z bounds via heightMap (skips empty air above terrain)
--   - Uses flat reusable buffer + setVertex to avoid per-build table allocations

local Constants     = require("src.constants")
local BlockRegistry = require("src.world.block_registry")

local CW        = Constants.CHUNK_W       -- 32
local CH        = Constants.CHUNK_H       -- 32
local ZL        = Constants.Z_LEVELS      -- 64
local BLOCK_AIR = Constants.BLOCK_AIR     -- 0

-- Localize hot functions / math
local getColor       = BlockRegistry.getColor
local isTransparent  = BlockRegistry.isTransparent
local newMesh        = love.graphics.newMesh
local mathMin        = math.min

-- Vertex format: 3 floats position + 4 float color
local VERTEX_FORMAT = {
    {"VertexPosition", "float", 3},
    {"VertexColor",    "float", 4},
}

-- Directional brightness multipliers (baked ambient + directional)
local BRIGHT_TOP    = 1.00   -- +Z world / +Y 3D
local BRIGHT_BOTTOM = 0.40   -- -Z world / -Y 3D
local BRIGHT_EAST   = 0.82   -- +X world / +X 3D
local BRIGHT_WEST   = 0.65   -- -X world / -X 3D
local BRIGHT_SOUTH  = 0.70   -- +Y world / +Z 3D
local BRIGHT_NORTH  = 0.55   -- -Y world / -Z 3D

-- Max blocks above heightMap surface that structures/trees can reach.
-- Trees: trunk 3 + leaf 1 = 4.  Watchtower: 5 above surface.  Buffer: 8.
local STRUCTURE_BUFFER = 8

---------------------------------------------------------------------------
-- Module-level reusable flat vertex buffer
-- 7 floats per vertex (x, y, z, r, g, b, a), reused across builds
-- to avoid per-build table allocations and GC pressure.
---------------------------------------------------------------------------
local flatBuf = {}
local flatLen = 0

-- Only emit a face if it borders air, or a different transparent block type.
local function shouldEmitFace(blockId, neighborId)
    if neighborId == BLOCK_AIR then
        return true
    end
    if neighborId == blockId then
        return false
    end
    return isTransparent(neighborId)
end

-- Emit 6 vertices (2 triangles) for one face into the flat buffer.
local function emitFace(x0,y0,z0, x1,y1,z1, x2,y2,z2,
                        x3,y3,z3, x4,y4,z4, x5,y5,z5,
                        r, g, b, a)
    local i = flatLen
    flatBuf[i+ 1]=x0; flatBuf[i+ 2]=y0; flatBuf[i+ 3]=z0; flatBuf[i+ 4]=r; flatBuf[i+ 5]=g; flatBuf[i+ 6]=b; flatBuf[i+ 7]=a
    flatBuf[i+ 8]=x1; flatBuf[i+ 9]=y1; flatBuf[i+10]=z1; flatBuf[i+11]=r; flatBuf[i+12]=g; flatBuf[i+13]=b; flatBuf[i+14]=a
    flatBuf[i+15]=x2; flatBuf[i+16]=y2; flatBuf[i+17]=z2; flatBuf[i+18]=r; flatBuf[i+19]=g; flatBuf[i+20]=b; flatBuf[i+21]=a
    flatBuf[i+22]=x3; flatBuf[i+23]=y3; flatBuf[i+24]=z3; flatBuf[i+25]=r; flatBuf[i+26]=g; flatBuf[i+27]=b; flatBuf[i+28]=a
    flatBuf[i+29]=x4; flatBuf[i+30]=y4; flatBuf[i+31]=z4; flatBuf[i+32]=r; flatBuf[i+33]=g; flatBuf[i+34]=b; flatBuf[i+35]=a
    flatBuf[i+36]=x5; flatBuf[i+37]=y5; flatBuf[i+38]=z5; flatBuf[i+39]=r; flatBuf[i+40]=g; flatBuf[i+41]=b; flatBuf[i+42]=a
    flatLen = i + 42
end

---------------------------------------------------------------------------
-- Helper: resolve a block ID at world coords (wx, wy, wz).
---------------------------------------------------------------------------
local function makeBlockGetter(chunk, getNeighborBlock)
    local originX = chunk.cx * CW
    local originY = chunk.cy * CH
    local blocks  = chunk.blocks
    local CW_CH = CW * CH

    return function(wx, wy, wz)
        local lx = wx - originX
        local ly = wy - originY
        if lx >= 0 and lx < CW and ly >= 0 and ly < CH and wz >= 0 and wz < ZL then
            return blocks[lx + ly * CW + wz * CW_CH + 1]
        end
        if wz < 0 or wz >= ZL then
            return BLOCK_AIR
        end
        if getNeighborBlock then
            return getNeighborBlock(wx, wy, wz)
        end
        return BLOCK_AIR
    end
end

---------------------------------------------------------------------------
-- MeshBuilder.build(chunk, getNeighborBlock)
--   Returns a Love2D Mesh ("triangles", "static") or nil if no faces emitted.
---------------------------------------------------------------------------
local MeshBuilder = {}

function MeshBuilder.build(chunk, getNeighborBlock)
    local blockAt = makeBlockGetter(chunk, getNeighborBlock)

    local originX = chunk.cx * CW
    local originY = chunk.cy * CH
    local blocks  = chunk.blocks
    local heightMap = chunk.heightMap
    local CW_CH   = CW * CH

    -- Find highest occupied Z-level (chunk-wide cap for per-column bounds)
    local chunkMaxZ = -1
    for lz = ZL - 1, 0, -1 do
        local zBase = lz * CW_CH
        for i = 1, CW_CH do
            if blocks[zBase + i] ~= BLOCK_AIR then
                chunkMaxZ = lz
                break
            end
        end
        if chunkMaxZ >= 0 then break end
    end

    if chunkMaxZ < 0 then return nil end

    -- Reset flat buffer
    flatLen = 0

    -- Column-first iteration with per-column Z bounds.
    -- Each column only iterates up to heightMap[col] + STRUCTURE_BUFFER,
    -- capped at the chunk-wide max. Skips ~60% of empty air in typical chunks.
    --
    -- Optimization: Interior blocks (~85%) use direct array indexing for
    -- neighbor lookups instead of blockAt(), eliminating 6 function calls
    -- per block. Edge blocks fall back to blockAt() for cross-chunk queries.
    -- Additionally, BLOCK_AIR short-circuit avoids isTransparent() calls
    -- for ~90%+ of exposed-face checks since air is the most common neighbor.
    for ly = 0, CH - 1 do
        local yRow = ly * CW
        local isInteriorY = ly > 0 and ly < CH - 1
        for lx = 0, CW - 1 do
            local colIdx = lx + yRow + 1
            local surfZ = heightMap[colIdx]
            local colMaxZ = mathMin(surfZ + STRUCTURE_BUFFER, chunkMaxZ)
            local isInteriorXY = isInteriorY and lx > 0 and lx < CW - 1

            for lz = 0, colMaxZ do
                local idx = lx + yRow + lz * CW_CH + 1
                local blockId = blocks[idx]
                if blockId ~= BLOCK_AIR then
                    local color = getColor(blockId)
                    local cr = color[1]
                    local cg = color[2]
                    local cb = color[3]
                    local ca = color[4]

                    local wx = originX + lx
                    local wy = originY + ly
                    local wz = lz

                    -- 3D corners: cube from (wx, wz, wy) to (wx+1, wz+1, wy+1)
                    local x0 = wx
                    local x1 = wx + 1
                    local y0 = wz         -- 3D Y = world Z
                    local y1 = wz + 1
                    local z0 = wy         -- 3D Z = world Y
                    local z1 = wy + 1

                    -- Obtain all 6 neighbor block IDs.
                    -- Interior path: direct array indexing (no function calls).
                    -- Edge path: blockAt() handles bounds + cross-chunk lookups.
                    local nTop, nBot, nEast, nWest, nSouth, nNorth
                    if isInteriorXY and lz > 0 and lz < ZL - 1 then
                        -- INTERIOR: all 6 neighbors are within this chunk's blocks[]
                        nTop   = blocks[idx + CW_CH]   -- +Z
                        nBot   = blocks[idx - CW_CH]   -- -Z
                        nEast  = blocks[idx + 1]        -- +X
                        nWest  = blocks[idx - 1]        -- -X
                        nSouth = blocks[idx + CW]       -- +Y
                        nNorth = blocks[idx - CW]       -- -Y
                    else
                        -- EDGE: at least one axis is on chunk boundary
                        nTop   = blockAt(wx, wy, wz + 1)
                        nBot   = blockAt(wx, wy, wz - 1)
                        nEast  = blockAt(wx + 1, wy, wz)
                        nWest  = blockAt(wx - 1, wy, wz)
                        nSouth = blockAt(wx, wy + 1, wz)
                        nNorth = blockAt(wx, wy - 1, wz)
                    end

                    -- TOP face (+Z world / +Y in 3D)
                    if shouldEmitFace(blockId, nTop) then
                        local r = cr * BRIGHT_TOP
                        local g = cg * BRIGHT_TOP
                        local b = cb * BRIGHT_TOP
                        emitFace(
                            x0, y1, z0,   x0, y1, z1,   x1, y1, z1,
                            x0, y1, z0,   x1, y1, z1,   x1, y1, z0,
                            r, g, b, ca)
                    end

                    -- BOTTOM face (-Z world / -Y in 3D)
                    if shouldEmitFace(blockId, nBot) then
                        local r = cr * BRIGHT_BOTTOM
                        local g = cg * BRIGHT_BOTTOM
                        local b = cb * BRIGHT_BOTTOM
                        emitFace(
                            x0, y0, z0,   x1, y0, z0,   x1, y0, z1,
                            x0, y0, z0,   x1, y0, z1,   x0, y0, z1,
                            r, g, b, ca)
                    end

                    -- EAST face (+X world / +X in 3D)
                    if shouldEmitFace(blockId, nEast) then
                        local r = cr * BRIGHT_EAST
                        local g = cg * BRIGHT_EAST
                        local b = cb * BRIGHT_EAST
                        emitFace(
                            x1, y0, z0,   x1, y1, z0,   x1, y1, z1,
                            x1, y0, z0,   x1, y1, z1,   x1, y0, z1,
                            r, g, b, ca)
                    end

                    -- WEST face (-X world / -X in 3D)
                    if shouldEmitFace(blockId, nWest) then
                        local r = cr * BRIGHT_WEST
                        local g = cg * BRIGHT_WEST
                        local b = cb * BRIGHT_WEST
                        emitFace(
                            x0, y0, z1,   x0, y1, z1,   x0, y1, z0,
                            x0, y0, z1,   x0, y1, z0,   x0, y0, z0,
                            r, g, b, ca)
                    end

                    -- SOUTH face (+Y world / +Z in 3D)
                    if shouldEmitFace(blockId, nSouth) then
                        local r = cr * BRIGHT_SOUTH
                        local g = cg * BRIGHT_SOUTH
                        local b = cb * BRIGHT_SOUTH
                        emitFace(
                            x0, y0, z1,   x1, y0, z1,   x1, y1, z1,
                            x0, y0, z1,   x1, y1, z1,   x0, y1, z1,
                            r, g, b, ca)
                    end

                    -- NORTH face (-Y world / -Z in 3D)
                    if shouldEmitFace(blockId, nNorth) then
                        local r = cr * BRIGHT_NORTH
                        local g = cg * BRIGHT_NORTH
                        local b = cb * BRIGHT_NORTH
                        emitFace(
                            x1, y0, z0,   x0, y0, z0,   x0, y1, z0,
                            x1, y0, z0,   x0, y1, z0,   x1, y1, z0,
                            r, g, b, ca)
                    end
                end
            end
        end
    end

    local vertexCount = flatLen / 7
    if vertexCount == 0 then return nil end

    -- Create mesh and populate from flat buffer (no per-vertex table allocs)
    local mesh = newMesh(VERTEX_FORMAT, vertexCount, "triangles", "static")
    for i = 1, vertexCount do
        local base = (i - 1) * 7
        mesh:setVertex(i,
            flatBuf[base + 1], flatBuf[base + 2], flatBuf[base + 3],
            flatBuf[base + 4], flatBuf[base + 5], flatBuf[base + 6], flatBuf[base + 7])
    end

    return mesh
end

return MeshBuilder
