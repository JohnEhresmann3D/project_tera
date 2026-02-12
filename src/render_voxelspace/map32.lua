local Constants = require("src.constants")
local TerrainFields = require("src.gen.terrain_fields")

local floor = math.floor

local Map32 = {}
Map32.__index = Map32

local function wrap(v, size)
    local m = v % size
    if m < 0 then m = m + size end
    return m
end

function Map32.new(seed, size, spacing)
    local self = setmetatable({}, Map32)
    self.seed = seed or Constants.DEFAULT_SEED
    self.size = size or 256
    self.spacing = spacing or 2
    self.heights = {}
    self.colors = {}

    local water = Constants.WATER_LEVEL_Z
    local hScale = 255 / math.max(1, Constants.Z_LEVELS - 1)

    local i = 1
    for y = 0, self.size - 1 do
        for x = 0, self.size - 1 do
            local wx = x * self.spacing
            local wy = y * self.spacing
            local e, m, t = TerrainFields.sample(self.seed, wx, wy)
            local surf = TerrainFields.surfaceZFromElevation(e)
            self.heights[i] = floor(surf * hScale + 0.5)

            local r, g, b
            if surf <= water then
                local d = (water - surf) / math.max(1, water)
                r = floor(20 + d * 10)
                g = floor(70 + d * 30)
                b = floor(140 + d * 90)
            else
                -- quick biome-ish tint from moisture/temp
                r = floor(80 + t * 95)
                g = floor(95 + m * 120)
                b = floor(55 + (1 - m) * 60)
            end

            self.colors[i] = { r / 255, g / 255, b / 255 }
            i = i + 1
        end
    end

    return self
end

function Map32:sample(wx, wy)
    local fx = wrap(floor(wx / self.spacing), self.size)
    local fy = wrap(floor(wy / self.spacing), self.size)
    local idx = fy * self.size + fx + 1
    return self.heights[idx], self.colors[idx]
end

return Map32
