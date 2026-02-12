local M = {}

local floor = math.floor
local sqrt = math.sqrt
local abs = math.abs

function M.clamp(x, lo, hi)
    if x < lo then return lo end
    if x > hi then return hi end
    return x
end

function M.lerp(a, b, t)
    return a + (b - a) * t
end

function M.inverseLerp(a, b, v)
    if a == b then return 0 end
    return (v - a) / (b - a)
end

function M.smoothstep(edge0, edge1, x)
    local t = M.clamp((x - edge0) / (edge1 - edge0), 0, 1)
    return t * t * (3 - 2 * t)
end

function M.remap(value, fromLo, fromHi, toLo, toHi)
    local t = M.inverseLerp(fromLo, fromHi, value)
    return M.lerp(toLo, toHi, t)
end

function M.sign(x)
    if x > 0 then return 1
    elseif x < 0 then return -1
    else return 0 end
end

function M.distance(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return sqrt(dx * dx + dy * dy)
end

return M
