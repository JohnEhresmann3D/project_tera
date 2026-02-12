local Constants = {}

-- Chunk dimensions
Constants.CHUNK_W = 32
Constants.CHUNK_H = 32
Constants.Z_LEVELS = 64
Constants.SURFACE_Z = 24
Constants.WATER_LEVEL_Z = 18

-- Isometric tile dimensions (pixels)
Constants.TILE_W = 64
Constants.TILE_H = 32
Constants.TILE_D = 32  -- vertical height per Z-level

-- Block IDs
Constants.BLOCK_AIR          = 0
Constants.BLOCK_STONE        = 1
Constants.BLOCK_DIRT         = 2
Constants.BLOCK_GRASS        = 3
Constants.BLOCK_SAND         = 4
Constants.BLOCK_WATER        = 5
Constants.BLOCK_FOREST_FLOOR = 6
Constants.BLOCK_MUD          = 7
Constants.BLOCK_FROZEN_GRASS = 8
Constants.BLOCK_BARE_STONE   = 9
Constants.BLOCK_RED_CLAY     = 10
Constants.BLOCK_COAL         = 11
Constants.BLOCK_COPPER       = 12
Constants.BLOCK_IRON         = 13
Constants.BLOCK_SILVER       = 14
Constants.BLOCK_GOLD         = 15
Constants.BLOCK_OBSIDIAN     = 16
Constants.BLOCK_ICE          = 17
Constants.BLOCK_SANDSTONE    = 18
Constants.BLOCK_GRANITE      = 19
Constants.BLOCK_PERMAFROST   = 20
Constants.BLOCK_HARDPAN      = 21
Constants.BLOCK_PEAT         = 22
Constants.BLOCK_RICH_DIRT    = 23
Constants.BLOCK_TERRACOTTA   = 24
Constants.BLOCK_WET_CLAY     = 25
Constants.BLOCK_WOOD         = 26
Constants.BLOCK_LEAVES       = 27
Constants.BLOCK_CAVE_ENTRANCE = 28

-- Streaming radii (in chunks)
--   ACTIVE_RADIUS: expensive mesh rebuilds happen here (small = fast)
--   LOAD_RADIUS:   chunk generation + cached mesh drawing (medium)
--   CACHE_RADIUS:  keep chunks in memory for quick turn-around (large)
Constants.ACTIVE_RADIUS = 4
Constants.LOAD_RADIUS = 10
Constants.CACHE_RADIUS = 14
Constants.MAX_CACHED = 500
Constants.GEN_BUDGET_MS = 4.0
Constants.CACHE_STALE_FRAMES = 1800
Constants.CACHE_HARD_EVICT_MARGIN = 6
Constants.CACHE_MAX_FORCED_EVICT_PER_FRAME = 8

-- Player
Constants.PLAYER_SPEED = 7.5
Constants.EYE_HEIGHT = 1.6
Constants.MOUSE_SENS = 0.003

-- 3D Rendering
Constants.FOV_Y = 70
Constants.NEAR_PLANE = 0.1
Constants.FAR_PLANE = 350.0
Constants.FOG_START = 120.0
Constants.FOG_END = 280.0
Constants.MAX_MESH_REBUILDS_PER_FRAME = 6

-- Experimental micro-voxel terrain styling (mesh3d).
-- Splits exposed top faces into tiny raised sub-cubes without changing world data.
Constants.MICRO_VOXEL_SURFACE = true
Constants.MICRO_VOXEL_SUBDIV = 2
Constants.MICRO_VOXEL_GAP = 0.16
Constants.MICRO_VOXEL_HEIGHT = 0.28
Constants.MICRO_VOXEL_NEAR_RADIUS = 3
Constants.MICRO_VOXEL_FAR_RADIUS = 5
Constants.MICRO_VOXEL_NEAR_SUBDIV = 3
Constants.MICRO_VOXEL_MID_SUBDIV = 2
Constants.MICRO_VOXEL_REBUILD_NEAR = 3
Constants.MICRO_VOXEL_REBUILD_MID = 2
Constants.MICRO_VOXEL_REBUILD_FAR = 1

-- World seed (default)
Constants.DEFAULT_SEED = 42

return Constants
