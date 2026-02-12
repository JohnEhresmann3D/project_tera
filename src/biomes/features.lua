-- Per-biome feature definitions for future decoration expansion
-- Currently used as reference data; the actual placement is in stage_decoration.lua

local Features = {}

Features.biomes = {
    ocean = {
        flora = {
            { id = "kelp",      density = 12, sizeVariants = {1, 2, 3} },
            { id = "coral_fan", density = 4,  sizeVariants = {1, 2} },
            { id = "seagrass",  density = 20, sizeVariants = {1} },
        },
        fauna = {
            { id = "fish_school", spawnRate = 6,  behavior = "passive" },
            { id = "jellyfish",   spawnRate = 2,  behavior = "passive_hazard" },
        },
    },
    beach = {
        flora = {
            { id = "palm_tree",   density = 3,  sizeVariants = {2, 3} },
            { id = "beach_grass", density = 8,  sizeVariants = {1} },
        },
        fauna = {
            { id = "crab",    spawnRate = 4, behavior = "passive" },
            { id = "seagull", spawnRate = 3, behavior = "ambient" },
        },
    },
    plains = {
        flora = {
            { id = "oak_tree",    density = 3,  sizeVariants = {2, 3, 4} },
            { id = "tall_grass",  density = 30, sizeVariants = {1, 2} },
            { id = "wildflower",  density = 10, sizeVariants = {1} },
        },
        fauna = {
            { id = "rabbit", spawnRate = 5,   behavior = "passive" },
            { id = "deer",   spawnRate = 2,   behavior = "passive" },
            { id = "wolf",   spawnRate = 0.8, behavior = "hostile_night" },
        },
    },
    forest = {
        flora = {
            { id = "oak_tree",   density = 18, sizeVariants = {3, 4, 5} },
            { id = "birch_tree", density = 8,  sizeVariants = {3, 4} },
            { id = "fern",       density = 15, sizeVariants = {1, 2} },
            { id = "mushroom",   density = 6,  sizeVariants = {1} },
            { id = "berry_bush", density = 3,  sizeVariants = {1, 2} },
        },
        fauna = {
            { id = "deer",   spawnRate = 3,   behavior = "passive" },
            { id = "fox",    spawnRate = 2,   behavior = "passive" },
            { id = "bear",   spawnRate = 0.5, behavior = "neutral" },
            { id = "spider", spawnRate = 1.5, behavior = "hostile_night" },
        },
    },
    desert = {
        flora = {
            { id = "cactus",     density = 4, sizeVariants = {1, 2, 3} },
            { id = "dead_shrub", density = 6, sizeVariants = {1} },
        },
        fauna = {
            { id = "scorpion",    spawnRate = 3,   behavior = "hostile" },
            { id = "rattlesnake", spawnRate = 2,   behavior = "hostile" },
            { id = "vulture",     spawnRate = 1,   behavior = "ambient" },
        },
    },
    swamp = {
        flora = {
            { id = "swamp_tree", density = 10, sizeVariants = {3, 4, 5} },
            { id = "lily_pad",   density = 12, sizeVariants = {1} },
            { id = "cattail",    density = 8,  sizeVariants = {1, 2} },
            { id = "glowshroom", density = 3,  sizeVariants = {1, 2} },
        },
        fauna = {
            { id = "frog",       spawnRate = 6,   behavior = "passive" },
            { id = "leech",      spawnRate = 4,   behavior = "hostile" },
            { id = "bog_lurker", spawnRate = 1.0, behavior = "hostile" },
        },
    },
    tundra = {
        flora = {
            { id = "frost_shrub",  density = 5,  sizeVariants = {1, 2} },
            { id = "lichen_patch", density = 12, sizeVariants = {1} },
            { id = "snow_pine",    density = 2,  sizeVariants = {3, 4} },
        },
        fauna = {
            { id = "arctic_hare", spawnRate = 3,   behavior = "passive" },
            { id = "ice_wolf",    spawnRate = 1.0, behavior = "hostile" },
            { id = "mammoth",     spawnRate = 0.2, behavior = "neutral" },
        },
    },
    mountains = {
        flora = {
            { id = "mountain_grass", density = 6, sizeVariants = {1} },
            { id = "edelweiss",      density = 1, sizeVariants = {1} },
        },
        fauna = {
            { id = "mountain_goat",  spawnRate = 2,    behavior = "passive" },
            { id = "eagle",          spawnRate = 1,    behavior = "ambient" },
            { id = "rock_elemental", spawnRate = 0.5,  behavior = "hostile" },
            { id = "wyvern",         spawnRate = 0.15, behavior = "hostile" },
        },
    },
    mesa = {
        flora = {
            { id = "barrel_cactus", density = 3, sizeVariants = {1, 2} },
            { id = "tumbleweed",    density = 2, sizeVariants = {1} },
            { id = "red_sage",      density = 4, sizeVariants = {1} },
        },
        fauna = {
            { id = "roadrunner", spawnRate = 2,   behavior = "passive" },
            { id = "canyon_bat", spawnRate = 3,   behavior = "hostile_night" },
            { id = "dust_devil", spawnRate = 0.5, behavior = "passive_hazard" },
        },
    },
}

return Features
