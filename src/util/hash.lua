local bit = require("bit")
local bxor = bit.bxor
local band = bit.band
local rshift = bit.rshift

local Hash = {}

function Hash.hash2D(x, y, seed)
    local h = seed or 0
    h = bxor(h, x * 374761393)
    h = bxor(h, y * 668265263)
    h = h + 0x9e3779b9
    h = band(h, 0x7FFFFFFF)
    h = bxor(h, rshift(h, 15))
    h = h * 2654435769
    h = band(h, 0x7FFFFFFF)
    h = bxor(h, rshift(h, 13))
    h = h * 1274126177
    h = band(h, 0x7FFFFFFF)
    h = bxor(h, rshift(h, 16))
    return band(h, 0x7FFFFFFF)
end

function Hash.hash3D(x, y, z, seed)
    return Hash.hash2D(Hash.hash2D(x, y, seed), z, seed)
end

return Hash
