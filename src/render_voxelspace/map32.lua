local Constants = require("src.constants")
local TerrainFields = require("src.gen.terrain_fields")
local Noise = require("src.util.noise")

-- Prebaked height/color atlas for VoxelSpace32 renderer.
-- Stores one compact terrain representation and samples it with wrap + bilinear filtering.
local floor = math.floor
local max = math.max
local min = math.min

local Map32 = {}
Map32.__index = Map32

local function wrap(v, size)
    local m = v % size
    if m < 0 then m = m + size end
    return m
end

local function clamp01(v)
    if v < 0 then return 0 end
    if v > 1 then return 1 end
    return v
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function desaturate(r, g, b, amount)
    local l = r * 0.299 + g * 0.587 + b * 0.114
    return lerp(r, l, amount), lerp(g, l, amount), lerp(b, l, amount)
end

local function sampleSmoothedElevation(seed, wx, wy, tap)
    -- Low-pass filter to avoid noisy "perlin mountain" artifacts in VoxelSpace mode.
    local e0 = TerrainFields.sample(seed, wx, wy)
    local e1 = TerrainFields.sample(seed, wx + tap, wy)
    local e2 = TerrainFields.sample(seed, wx - tap, wy)
    local e3 = TerrainFields.sample(seed, wx, wy + tap)
    local e4 = TerrainFields.sample(seed, wx, wy - tap)
    local e5 = TerrainFields.sample(seed, wx + tap, wy + tap)
    local e6 = TerrainFields.sample(seed, wx - tap, wy + tap)
    local e7 = TerrainFields.sample(seed, wx + tap, wy - tap)
    local e8 = TerrainFields.sample(seed, wx - tap, wy - tap)
    return (e0 * 4 + e1 + e2 + e3 + e4 + e5 + e6 + e7 + e8) / 12
end

function Map32.new(seed, size, spacing)
    local self = setmetatable({}, Map32)
    self.seed = seed or Constants.DEFAULT_SEED
    self.size = size or 256
    self.spacing = spacing or 2
    self.worldSize = self.size * self.spacing
    self.heights = {}
    self.colors = {}

    local water = Constants.WATER_LEVEL_Z
    local hScale = 255 / math.max(1, Constants.Z_LEVELS - 1)

    local i = 1
    for y = 0, self.size - 1 do
        for x = 0, self.size - 1 do
            local wx = x * self.spacing
            local wy = y * self.spacing
            local _, m, t = TerrainFields.sample(self.seed, wx, wy)
            -- VoxelSpace visually benefits from smoothed elevation;
            -- raw terrain noise can look too jagged at distance.
            local eSmooth = sampleSmoothedElevation(self.seed, wx, wy, self.spacing * 3)
            local surf = TerrainFields.surfaceZFromElevation(eSmooth)
            self.heights[i] = floor(surf * hScale + 0.5)

            local r, g, b
            if surf <= water then
                local d = clamp01((water - surf) / max(1, water))
                -- calm deep-to-shallow water ramp
                r = lerp(0.07, 0.15, 1 - d)
                g = lerp(0.18, 0.34, 1 - d)
                b = lerp(0.33, 0.62, 1 - d)
            else
                local landH = clamp01((surf - water) / max(1, (Constants.Z_LEVELS - water)))
                if surf < water + 3 then
                    -- beach
                    r, g, b = 0.66, 0.62, 0.46
                elseif landH < 0.30 then
                    -- lowland
                    r, g, b = lerp(0.24, 0.32, t), lerp(0.40, 0.54, m), lerp(0.18, 0.22, 1 - m)
                elseif landH < 0.62 then
                    -- upland
                    r, g, b = lerp(0.32, 0.42, t), lerp(0.46, 0.54, m), lerp(0.22, 0.28, 1 - m)
                else
                    -- highland / rock
                    local rock = lerp(0.46, 0.64, landH)
                    r, g, b = rock, rock * 0.97, rock * 0.92
                end

                -- subtle directional tint from moisture/temperature (much less psychedelic)
                r = r + (t - 0.5) * 0.06
                g = g + (m - 0.5) * 0.08
                b = b - (t - 0.5) * 0.04

                -- Keep slight forest tint in terrain color so vegetated zones read
                -- even in terrain-only VoxelSpace mode.
                if surf > water + 1 and landH < 0.72 and m > 0.40 then
                    local patchN = Noise.fbm2D(wx * 0.010 + 900, wy * 0.010 + 900, self.seed + 27000, 2, 0.5)
                    local localN = Noise.fbm2D(wx * 0.060 + 2100, wy * 0.060 + 2100, self.seed + 28000, 2, 0.5)
                    local patch = (patchN + 1) * 0.5
                    local localMask = (localN + 1) * 0.5
                    local density = 0.60 + m * 0.14 - t * 0.06
                    if patch > 0.52 and localMask > density then
                        r = r * 0.90
                        g = min(1, g * 1.06)
                        b = b * 0.90
                    end
                end
            end

            r, g, b = desaturate(clamp01(r), clamp01(g), clamp01(b), 0.22)
            self.colors[i] = { r, g, b }

            i = i + 1
        end
    end

    return self
end

function Map32:sample(wx, wy)
    -- Continuous sample from discrete map via bilinear interpolation.
    local gx = wx / self.spacing
    local gy = wy / self.spacing

    local x0 = floor(gx)
    local y0 = floor(gy)
    local x1 = x0 + 1
    local y1 = y0 + 1
    local tx = gx - x0
    local ty = gy - y0

    x0 = wrap(x0, self.size)
    y0 = wrap(y0, self.size)
    x1 = wrap(x1, self.size)
    y1 = wrap(y1, self.size)

    local i00 = y0 * self.size + x0 + 1
    local i10 = y0 * self.size + x1 + 1
    local i01 = y1 * self.size + x0 + 1
    local i11 = y1 * self.size + x1 + 1

    local h00 = self.heights[i00]
    local h10 = self.heights[i10]
    local h01 = self.heights[i01]
    local h11 = self.heights[i11]
    local hx0 = lerp(h00, h10, tx)
    local hx1 = lerp(h01, h11, tx)
    local h = lerp(hx0, hx1, ty)

    local c00 = self.colors[i00]
    local c10 = self.colors[i10]
    local c01 = self.colors[i01]
    local c11 = self.colors[i11]

    local r = lerp(lerp(c00[1], c10[1], tx), lerp(c01[1], c11[1], tx), ty)
    local g = lerp(lerp(c00[2], c10[2], tx), lerp(c01[2], c11[2], tx), ty)
    local b = lerp(lerp(c00[3], c10[3], tx), lerp(c01[3], c11[3], tx), ty)

    return h, r, g, b
end

return Map32
