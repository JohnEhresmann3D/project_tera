local Constants = require("src.constants")
local TerrainFields = require("src.gen.terrain_fields")
local Noise = require("src.util.noise")

-- Prebaked height/color atlas for VoxelSpace32 renderer.
-- Stores one compact terrain representation and samples it with wrap + bilinear filtering.
local floor = math.floor
local max = math.max
local min = math.min
local WATER_BAND_LEVELS = 5

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
    self.terrainHeights = {}
    self.waterDepths = {}
    self.colors = {}
    self.floorColors = {}

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
            local terrainSurf = surf

            local r, g, b
            if surf <= water then
                -- Deepen underwater terrain in VoxelSpace so oceans read as true basins.
                local basinN = (Noise.fbm2D(wx * 0.0018 + 1200, wy * 0.0018 + 1200, self.seed + 41000, 3, 0.5) + 1) * 0.5
                local trenchN = (Noise.fbm2D(wx * 0.0065 + 3500, wy * 0.0065 + 3500, self.seed + 42000, 2, 0.5) + 1) * 0.5
                local trench = max(0, trenchN - 0.58) / 0.42
                local rawDepth = (water - surf) + basinN * 8.0 + trench * trench * 16.0
                local floorZ = max(1, water - rawDepth)
                terrainSurf = floorZ
                local d = clamp01(rawDepth / max(1, water))
                local band = floor(d * WATER_BAND_LEVELS + 0.5) / WATER_BAND_LEVELS
                -- Layered, stepped water shades (shallows -> deep ocean).
                r = lerp(0.09, 0.03, band)
                g = lerp(0.26, 0.14, band)
                b = lerp(0.60, 0.44, band)
                local floorBand = clamp01((water - floorZ) / max(1, water))
                self.floorColors[i] = {
                    lerp(0.62, 0.28, floorBand),
                    lerp(0.58, 0.34, floorBand),
                    lerp(0.42, 0.28, floorBand),
                }
                self.heights[i] = floor(water * hScale + 0.5)
                self.terrainHeights[i] = floor(terrainSurf * hScale + 0.5)
                self.waterDepths[i] = water - floorZ
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
                self.floorColors[i] = { r, g, b }
                self.terrainHeights[i] = floor(terrainSurf * hScale + 0.5)
                self.heights[i] = self.terrainHeights[i]
                self.waterDepths[i] = 0
            end

            r, g, b = desaturate(clamp01(r), clamp01(g), clamp01(b), 0.22)
            self.colors[i] = { r, g, b }

            i = i + 1
        end
    end

    return self
end

local function sampleScalar(self, values, wx, wy)
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

    local h00 = values[i00]
    local h10 = values[i10]
    local h01 = values[i01]
    local h11 = values[i11]
    local hx0 = lerp(h00, h10, tx)
    local hx1 = lerp(h01, h11, tx)
    return lerp(hx0, hx1, ty), i00, i10, i01, i11, tx, ty
end

local function sampleColor(self, values, i00, i10, i01, i11, tx, ty)
    local c00 = values[i00]
    local c10 = values[i10]
    local c01 = values[i01]
    local c11 = values[i11]

    local r = lerp(lerp(c00[1], c10[1], tx), lerp(c01[1], c11[1], tx), ty)
    local g = lerp(lerp(c00[2], c10[2], tx), lerp(c01[2], c11[2], tx), ty)
    local b = lerp(lerp(c00[3], c10[3], tx), lerp(c01[3], c11[3], tx), ty)
    return r, g, b
end

function Map32:sampleColumn(wx, wy)
    local h, i00, i10, i01, i11, tx, ty = sampleScalar(self, self.heights, wx, wy)
    local floorH = sampleScalar(self, self.terrainHeights, wx, wy)
    local depth = sampleScalar(self, self.waterDepths, wx, wy)
    local wr, wg, wb = sampleColor(self, self.colors, i00, i10, i01, i11, tx, ty)
    local fr, fg, fb = sampleColor(self, self.floorColors, i00, i10, i01, i11, tx, ty)
    return h, wr, wg, wb, floorH, fr, fg, fb, depth
end

function Map32:sample(wx, wy)
    local h, r, g, b = self:sampleColumn(wx, wy)
    return h, r, g, b
end

function Map32:sampleTerrainHeight(wx, wy)
    return sampleScalar(self, self.terrainHeights, wx, wy)
end

function Map32:sampleWaterDepth(wx, wy)
    return sampleScalar(self, self.waterDepths, wx, wy)
end

return Map32
