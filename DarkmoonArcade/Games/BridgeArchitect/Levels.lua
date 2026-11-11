-- Goblin Bridge Architect: the levels. The field is 920 x 496 px (one grid cell = 1 m = 20 px).
--   terrain  rocks the road runs on: { left, right, top } (each reaches down past the water)
--   anchors  fixed joints a bridge can start from
--   start    where the vehicle waits (on the left rock), goal: x it has to reach
--   budget   gold; star2/star3: share of the budget for two and three stars. star3 sits just above the
--            cheapest bridge tools/optimize_bridges.py found (tests/bridge_best.lua), so three stars are possible
--   materials what may be built with, vehicle: who crosses, zone: the look

local _, ns = ...
local BA = ns.BridgeArchitect or {}
ns.BridgeArchitect = BA

-- The look of each zone: rock and ground from the client's tilesets, sky and water colours.
BA.ZONES = {
    barrens = { rock = 186919, top = 186908, tint = { 1, 0.92, 0.8 }, sky = { { 0.98, 0.78, 0.5 }, { 0.45, 0.62, 0.85 } },
        water = { 0.18, 0.42, 0.5 }, far = { 0.62, 0.45, 0.32 } },
    needles = { rock = 188937, top = 188929, tint = { 1, 0.9, 0.82 }, sky = { { 1, 0.7, 0.45 }, { 0.38, 0.5, 0.8 } },
        water = { 0.2, 0.38, 0.48 }, far = { 0.66, 0.42, 0.3 } },
    desolace = { rock = 187009, top = 187001, tint = { 0.9, 0.88, 0.85 }, sky = { { 0.72, 0.68, 0.6 }, { 0.32, 0.36, 0.45 } },
        water = { 0.2, 0.3, 0.26 }, far = { 0.4, 0.38, 0.36 } },
    stranglethorn = { rock = 188833, top = 188821, tint = { 0.85, 0.95, 0.8 }, sky = { { 0.85, 0.9, 0.7 }, { 0.3, 0.55, 0.65 } },
        water = { 0.16, 0.38, 0.3 }, far = { 0.25, 0.42, 0.28 } },
    duskwood = { rock = 187092, top = 187084, tint = { 0.7, 0.72, 0.85 }, sky = { { 0.3, 0.3, 0.48 }, { 0.04, 0.05, 0.14 } },
        water = { 0.08, 0.12, 0.2 }, far = { 0.12, 0.13, 0.22 }, stars = true },
    steppes = { rock = 186950, top = 186933, tint = { 0.85, 0.75, 0.7 }, sky = { { 0.85, 0.35, 0.15 }, { 0.2, 0.08, 0.08 } },
        water = { 1, 0.45, 0.1 }, far = { 0.3, 0.12, 0.08 }, lava = 186942 },
    winterspring = { rock = 189049, top = 189053, tint = { 0.92, 0.96, 1 }, sky = { { 0.85, 0.9, 1 }, { 0.4, 0.55, 0.85 } },
        water = { 0.55, 0.75, 0.88 }, far = { 0.75, 0.82, 0.92 } },
    tanaris = { rock = 188866, top = 188870, tint = { 1, 0.95, 0.85 }, sky = { { 1, 0.85, 0.55 }, { 0.35, 0.6, 0.95 } },
        water = { 0.15, 0.55, 0.6 }, far = { 0.85, 0.65, 0.4 } },
    ungoro = { rock = 188978, top = 188974, tint = { 0.9, 0.95, 0.85 }, sky = { { 0.9, 0.85, 0.65 }, { 0.45, 0.6, 0.55 } },
        water = { 0.2, 0.4, 0.3 }, far = { 0.35, 0.45, 0.32 } },
    feralas = { rock = 188509, top = 188505, tint = { 0.9, 0.95, 0.88 }, sky = { { 0.8, 0.85, 0.75 }, { 0.3, 0.45, 0.6 } },
        water = { 0.15, 0.32, 0.38 }, far = { 0.3, 0.4, 0.35 } },
}

-- The chapters of the campaign: eight contracts each.
BA.CHAPTERS = { "kalimdor", "kingdoms", "south" }

local WATER = 440

BA.LEVELS = {
    {
        id = "gorge", zone = "barrens", vehicle = "strider", materials = { "road", "wood" },
        terrain = { { -40, 340, 300 }, { 580, 960, 300 } },
        anchors = { { 340, 300 }, { 580, 300 }, { 340, 360 }, { 580, 360 } },
        start = { 70, 300 }, goal = 820, water = WATER, budget = 1000, star2 = 0.9, star3 = 0.79,
    },
    {
        id = "wider", zone = "barrens", vehicle = "mule", materials = { "road", "wood" },
        terrain = { { -40, 300, 300 }, { 620, 960, 300 } },
        anchors = { { 300, 300 }, { 620, 300 }, { 300, 360 }, { 620, 360 } },
        start = { 70, 300 }, goal = 840, water = WATER, budget = 1800, star2 = 0.87, star3 = 0.74,
    },
    {
        id = "pillar", zone = "barrens", vehicle = "ram", materials = { "road", "wood" },
        terrain = { { -40, 200, 280 }, { 440, 480, 380 }, { 720, 960, 280 } },
        anchors = { { 200, 280 }, { 720, 280 }, { 200, 340 }, { 720, 340 }, { 440, 380 }, { 480, 380 } },
        start = { 60, 280 }, goal = 850, water = WATER, budget = 3000, star2 = 0.89, star3 = 0.77,
    },
    {
        id = "uneven", zone = "needles", vehicle = "strider", materials = { "road", "wood" },
        terrain = { { -40, 300, 240 }, { 580, 960, 300 } },
        anchors = { { 300, 240 }, { 300, 300 }, { 580, 300 }, { 580, 360 } },
        start = { 70, 240 }, goal = 840, water = WATER, budget = 1800, star2 = 0.63, star3 = 0.26,
    },
    {
        id = "steel", zone = "needles", vehicle = "shredder", materials = { "road", "wood", "steel" },
        terrain = { { -40, 260, 300 }, { 660, 960, 300 } },
        anchors = { { 260, 300 }, { 660, 300 }, { 260, 360 }, { 660, 360 } },
        start = { 70, 300 }, goal = 840, water = WATER, budget = 5600, star2 = 0.72, star3 = 0.45,
    },
    {
        id = "crane", zone = "needles", vehicle = "rocketcar", materials = { "road", "wood", "steel", "rope" },
        terrain = { { -40, 180, 300 }, { 740, 960, 300 } },
        anchors = { { 180, 300 }, { 740, 300 }, { 160, 120 }, { 760, 120 } },
        cranes = { { 160, 120 }, { 760, 120 } },
        start = { 60, 300 }, goal = 860, water = WATER, budget = 2200, star2 = 0.85, star3 = 0.7,
    },
    {
        id = "caravan", zone = "desolace", vehicle = "kodo", materials = { "road", "wood", "steel", "rope" },
        terrain = { { -40, 240, 300 }, { 440, 480, 400 }, { 680, 960, 300 } },
        anchors = { { 240, 300 }, { 680, 300 }, { 240, 360 }, { 680, 360 }, { 440, 400 }, { 480, 400 } },
        start = { 90, 300 }, goal = 830, water = WATER, budget = 4000, star2 = 0.79, star3 = 0.59,
    },
    {
        id = "thrifty", zone = "desolace", vehicle = "shredder", materials = { "road", "wood", "steel", "rope" },
        terrain = { { -40, 220, 280 }, { 700, 960, 280 } },
        anchors = { { 220, 280 }, { 700, 280 }, { 220, 340 }, { 700, 340 }, { 200, 140 }, { 720, 140 } },
        cranes = { { 200, 140 }, { 720, 140 } },
        start = { 70, 280 }, goal = 850, water = WATER, budget = 1700, star2 = 0.88, star3 = 0.76,
    },

    -- Chapter 2: the Eastern Kingdoms.
    {
        id = "vines", zone = "stranglethorn", vehicle = "tallstrider", materials = { "road", "wood", "rope" },
        terrain = { { -40, 240, 300 }, { 680, 960, 300 } },
        anchors = { { 240, 300 }, { 680, 300 }, { 220, 140 }, { 700, 140 } },
        cranes = { { 220, 140 }, { 700, 140 } },
        start = { 70, 300 }, goal = 840, water = WATER, budget = 1750, star2 = 0.78, star3 = 0.57,
    },
    {
        id = "island", zone = "stranglethorn", vehicle = "wolf", materials = { "road", "wood" },
        terrain = { { -40, 260, 300 }, { 420, 520, 300 }, { 680, 960, 300 } },
        anchors = { { 260, 300 }, { 420, 300 }, { 520, 300 }, { 680, 300 }, { 260, 360 }, { 420, 360 }, { 520, 360 }, { 680, 360 } },
        start = { 70, 300 }, goal = 840, water = WATER, budget = 1400, star2 = 0.85, star3 = 0.71,
    },
    {
        id = "ruins", zone = "duskwood", vehicle = "nightmare", materials = { "road", "wood", "steel" },
        terrain = { { -40, 280, 300 }, { 600, 960, 300 } },
        anchors = { { 280, 300 }, { 600, 300 }, { 280, 360 }, { 600, 360 } },
        start = { 70, 300 }, goal = 840, water = WATER, budget = 1800, star2 = 0.9, star3 = 0.79,
    },
    {
        id = "drop", zone = "duskwood", vehicle = "wolf", materials = { "road", "wood", "steel" },
        terrain = { { -40, 300, 240 }, { 580, 960, 300 } },
        anchors = { { 300, 240 }, { 300, 300 }, { 580, 300 }, { 580, 360 } },
        start = { 70, 240 }, goal = 840, water = WATER, budget = 1750, star2 = 0.76, star3 = 0.52,
    },
    {
        id = "lava", zone = "steppes", vehicle = "shredder", materials = { "road", "wood", "steel" },
        terrain = { { -40, 260, 300 }, { 620, 960, 300 } },
        anchors = { { 260, 300 }, { 620, 300 }, { 260, 360 }, { 620, 360 } },
        start = { 70, 300 }, goal = 840, water = WATER, budget = 3550, star2 = 0.8, star3 = 0.61,
    },
    {
        id = "forge", zone = "steppes", vehicle = "spidertank", materials = { "road", "wood", "steel" },
        terrain = { { -40, 200, 300 }, { 360, 400, 380 }, { 520, 560, 380 }, { 720, 960, 300 } },
        anchors = { { 200, 300 }, { 720, 300 }, { 200, 360 }, { 720, 360 }, { 360, 380 }, { 400, 380 }, { 520, 380 }, { 560, 380 } },
        start = { 70, 300 }, goal = 850, water = WATER, budget = 4950, star2 = 0.8, star3 = 0.61,
    },
    {
        id = "glacier", zone = "winterspring", vehicle = "raptor", materials = { "road", "wood", "steel", "rope" },
        terrain = { { -40, 160, 300 }, { 760, 960, 300 } },
        anchors = { { 160, 300 }, { 760, 300 }, { 140, 100 }, { 780, 100 } },
        cranes = { { 140, 100 }, { 780, 100 } },
        start = { 50, 300 }, goal = 870, water = WATER, budget = 2550, star2 = 0.83, star3 = 0.66,
    },
    {
        id = "golem", zone = "winterspring", vehicle = "golem", materials = { "road", "wood", "steel" },
        terrain = { { -40, 280, 300 }, { 640, 960, 300 } },
        anchors = { { 280, 300 }, { 640, 300 }, { 280, 360 }, { 640, 360 } },
        start = { 70, 300 }, goal = 840, water = WATER, budget = 3650, star2 = 0.8, star3 = 0.61,
    },
    -- Chapter 3: the wild south of Kalimdor.
    {
        id = "dunes", zone = "tanaris", vehicle = "rocketcar", materials = { "road", "wood", "steel", "rope" },
        terrain = { { -40, 140, 300 }, { 780, 960, 300 } },
        anchors = { { 140, 300 }, { 780, 300 }, { 120, 80 }, { 800, 80 } },
        cranes = { { 120, 80 }, { 800, 80 } },
        start = { 50, 300 }, goal = 880, water = WATER, budget = 2650, star2 = 0.83, star3 = 0.66,
    },
    {
        id = "oasis", zone = "tanaris", vehicle = "horse", materials = { "road", "wood", "steel" },
        terrain = { { -40, 300, 300 }, { 620, 960, 300 } },
        anchors = { { 300, 300 }, { 620, 300 }, { 300, 360 }, { 620, 360 } },
        start = { 70, 300 }, goal = 840, water = WATER, budget = 1750, star2 = 0.9, star3 = 0.8,
    },
    {
        id = "crater", zone = "ungoro", vehicle = "kodo", materials = { "road", "wood", "steel", "rope" },
        terrain = { { -40, 220, 300 }, { 420, 460, 360 }, { 700, 960, 300 } },
        anchors = { { 220, 300 }, { 700, 300 }, { 220, 360 }, { 700, 360 }, { 420, 360 }, { 460, 360 } },
        start = { 90, 300 }, goal = 840, water = WATER, budget = 3850, star2 = 0.83, star3 = 0.66,
    },
    {
        id = "climb", zone = "ungoro", vehicle = "raptor", materials = { "road", "wood", "steel" },
        terrain = { { -40, 300, 300 }, { 580, 960, 240 } },
        anchors = { { 300, 300 }, { 300, 360 }, { 580, 240 }, { 580, 300 } },
        start = { 70, 300 }, goal = 840, water = WATER, budget = 2600, star2 = 0.7, star3 = 0.4,
    },
    {
        id = "giants", zone = "feralas", vehicle = "spidertank", materials = { "road", "wood", "steel", "rope" },
        terrain = { { -40, 200, 300 }, { 440, 480, 380 }, { 720, 960, 300 } },
        anchors = { { 200, 300 }, { 720, 300 }, { 200, 360 }, { 720, 360 }, { 440, 380 }, { 480, 380 }, { 180, 120 }, { 740, 120 } },
        cranes = { { 180, 120 }, { 740, 120 } },
        start = { 70, 300 }, goal = 850, water = WATER, budget = 5100, star2 = 0.83, star3 = 0.66,
    },
    {
        id = "deep", zone = "feralas", vehicle = "wolf", materials = { "road", "wood", "steel" },
        terrain = { { -40, 240, 300 }, { 680, 960, 300 } },
        anchors = { { 240, 300 }, { 680, 300 } },
        start = { 70, 300 }, goal = 840, water = WATER, budget = 4300, star2 = 0.8, star3 = 0.61,
    },
    {
        id = "gadgetzan", zone = "tanaris", vehicle = "kodo", materials = { "road", "wood", "steel", "rope" },
        terrain = { { -40, 180, 300 }, { 740, 960, 300 } },
        anchors = { { 180, 300 }, { 740, 300 }, { 160, 100 }, { 760, 100 } },
        cranes = { { 160, 100 }, { 760, 100 } },
        start = { 80, 300 }, goal = 860, water = WATER, budget = 4850, star2 = 0.68, star3 = 0.36,
    },
    {
        id = "grand", zone = "ungoro", vehicle = "spidertank", materials = { "road", "wood", "steel", "rope" },
        terrain = { { -40, 160, 300 }, { 440, 480, 400 }, { 760, 960, 300 } },
        anchors = { { 160, 300 }, { 760, 300 }, { 160, 360 }, { 760, 360 }, { 440, 400 }, { 480, 400 }, { 140, 100 }, { 780, 100 } },
        cranes = { { 140, 100 }, { 780, 100 } },
        start = { 60, 300 }, goal = 870, water = WATER, budget = 6250, star2 = 0.83, star3 = 0.67,
    },
}

for i, level in ipairs(BA.LEVELS) do
    level.index = i
    level.chapter = math.floor((i - 1) / 8) + 1
end
