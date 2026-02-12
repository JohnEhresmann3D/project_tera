local bit = require("bit")
local bxor = bit.bxor
local band = bit.band
local lshift = bit.lshift
local rshift = bit.rshift

local PRNG = {}
PRNG.__index = PRNG

function PRNG.new(seed)
    seed = seed or 1
    if seed == 0 then seed = 1 end
    return setmetatable({ state = band(seed, 0x7FFFFFFF) }, PRNG)
end

function PRNG:nextInt()
    local s = self.state
    s = bxor(s, lshift(s, 13))
    s = bxor(s, rshift(s, 17))
    s = bxor(s, lshift(s, 5))
    s = band(s, 0x7FFFFFFF)
    self.state = s
    return s
end

-- Returns float in [0, 1)
function PRNG:next()
    return self:nextInt() / 0x80000000
end

-- Returns integer in [min, max] inclusive
function PRNG:range(min, max)
    return min + (self:nextInt() % (max - min + 1))
end

return PRNG
