-- Frustum plane extraction and AABB visibility testing.
-- Uses Gribb/Hartmann method to extract 6 clip planes from a combined
-- view-projection matrix (column-major flat table of 16 floats, matching
-- the convention in matrix.lua).
--
-- Performance: plane tables are pre-allocated and reused each frame
-- to avoid 7 table allocations per frame.

local sqrt = math.sqrt

local Frustum = {}

---------------------------------------------------------------------------
-- Pre-allocated plane storage (reused each frame)
---------------------------------------------------------------------------
local _planes = {
    {0, 0, 0, 0}, {0, 0, 0, 0}, {0, 0, 0, 0},
    {0, 0, 0, 0}, {0, 0, 0, 0}, {0, 0, 0, 0},
}

---------------------------------------------------------------------------
-- Plane extraction
---------------------------------------------------------------------------

--- Extract 6 frustum planes from a column-major viewProj matrix.
--- Planes point inward (positive half-space is inside the frustum).
--- Returns the same pre-allocated table each call (do NOT store across frames).
---
--- @param  m  table  Flat 16-element column-major matrix (indices 1..16).
--- @return table  Array of 6 planes: {left, right, bottom, top, near, far}.
function Frustum.extract(m)
    local planes = _planes
    local p

    -- Left:   row3 + row0
    p = planes[1]
    p[1] = m[4]+m[1]; p[2] = m[8]+m[5]; p[3] = m[12]+m[9]; p[4] = m[16]+m[13]
    -- Right:  row3 - row0
    p = planes[2]
    p[1] = m[4]-m[1]; p[2] = m[8]-m[5]; p[3] = m[12]-m[9]; p[4] = m[16]-m[13]
    -- Bottom: row3 + row1
    p = planes[3]
    p[1] = m[4]+m[2]; p[2] = m[8]+m[6]; p[3] = m[12]+m[10]; p[4] = m[16]+m[14]
    -- Top:    row3 - row1
    p = planes[4]
    p[1] = m[4]-m[2]; p[2] = m[8]-m[6]; p[3] = m[12]-m[10]; p[4] = m[16]-m[14]
    -- Near:   row3 + row2
    p = planes[5]
    p[1] = m[4]+m[3]; p[2] = m[8]+m[7]; p[3] = m[12]+m[11]; p[4] = m[16]+m[15]
    -- Far:    row3 - row2
    p = planes[6]
    p[1] = m[4]-m[3]; p[2] = m[8]-m[7]; p[3] = m[12]-m[11]; p[4] = m[16]-m[15]

    -- Normalise each plane so (a,b,c) is unit length
    for i = 1, 6 do
        p = planes[i]
        local len = sqrt(p[1] * p[1] + p[2] * p[2] + p[3] * p[3])
        if len > 1e-12 then
            local inv = 1.0 / len
            p[1] = p[1] * inv
            p[2] = p[2] * inv
            p[3] = p[3] * inv
            p[4] = p[4] * inv
        end
    end

    return planes
end

---------------------------------------------------------------------------
-- AABB test
---------------------------------------------------------------------------

--- Test whether an axis-aligned bounding box is potentially visible.
--- @param  planes  table   Array of 6 normalised planes from Frustum.extract.
--- @param  minX    number  AABB minimum X.
--- @param  minY    number  AABB minimum Y.
--- @param  minZ    number  AABB minimum Z.
--- @param  maxX    number  AABB maximum X.
--- @param  maxY    number  AABB maximum Y.
--- @param  maxZ    number  AABB maximum Z.
--- @return boolean  true if the AABB is potentially visible.
function Frustum.testAABB(planes, minX, minY, minZ, maxX, maxY, maxZ)
    for i = 1, 6 do
        local p = planes[i]
        local a, b, c, d = p[1], p[2], p[3], p[4]

        local px = a >= 0 and maxX or minX
        local py = b >= 0 and maxY or minY
        local pz = c >= 0 and maxZ or minZ

        if a * px + b * py + c * pz + d < 0 then
            return false
        end
    end

    return true
end

return Frustum
