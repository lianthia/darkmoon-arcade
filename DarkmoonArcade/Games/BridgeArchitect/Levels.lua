-- Goblin Bridge Architect: the levels. The field is 920 x 496 px (one grid cell = 1 m = 20 px).
--   terrain  rocks the road runs on: { left, right, top } (each reaches down past the water)
--   anchors  fixed joints a bridge can start from
--   start    where the vehicle waits (on the left rock), goal: x it has to reach
--   budget   gold; star2/star3: share of the budget for two and three stars
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
}

local WATER = 440

BA.LEVELS = {
    {
        id = "gorge", zone = "barrens", vehicle = "strider", materials = { "road", "wood" },
        terrain = { { -40, 340, 300 }, { 580, 960, 300 } },
        anchors = { { 340, 300 }, { 580, 300 }, { 340, 360 }, { 580, 360 } },
        start = { 70, 300 }, goal = 820, water = WATER, budget = 1000,
    },
    {
        id = "wider", zone = "barrens", vehicle = "mule", materials = { "road", "wood" },
        terrain = { { -40, 300, 300 }, { 620, 960, 300 } },
        anchors = { { 300, 300 }, { 620, 300 }, { 300, 360 }, { 620, 360 } },
        start = { 70, 300 }, goal = 840, water = WATER, budget = 1800,
    },
    {
        id = "pillar", zone = "barrens", vehicle = "ram", materials = { "road", "wood" },
        terrain = { { -40, 200, 280 }, { 440, 480, 380 }, { 720, 960, 280 } },
        anchors = { { 200, 280 }, { 720, 280 }, { 200, 340 }, { 720, 340 }, { 440, 380 }, { 480, 380 } },
        start = { 60, 280 }, goal = 850, water = WATER, budget = 3000,
    },
    {
        id = "uneven", zone = "needles", vehicle = "strider", materials = { "road", "wood" },
        terrain = { { -40, 300, 240 }, { 580, 960, 300 } },
        anchors = { { 300, 240 }, { 300, 300 }, { 580, 300 }, { 580, 360 } },
        start = { 70, 240 }, goal = 840, water = WATER, budget = 1800,
    },
    {
        id = "steel", zone = "needles", vehicle = "shredder", materials = { "road", "wood", "steel" },
        terrain = { { -40, 260, 300 }, { 660, 960, 300 } },
        anchors = { { 260, 300 }, { 660, 300 }, { 260, 360 }, { 660, 360 } },
        start = { 70, 300 }, goal = 840, water = WATER, budget = 5600,
    },
    {
        id = "crane", zone = "needles", vehicle = "rocketcar", materials = { "road", "wood", "steel", "rope" },
        terrain = { { -40, 180, 300 }, { 740, 960, 300 } },
        anchors = { { 180, 300 }, { 740, 300 }, { 160, 120 }, { 760, 120 } },
        cranes = { { 160, 120 }, { 760, 120 } },
        start = { 60, 300 }, goal = 860, water = WATER, budget = 2200,
    },
    {
        id = "caravan", zone = "desolace", vehicle = "kodo", materials = { "road", "wood", "steel", "rope" },
        terrain = { { -40, 240, 300 }, { 440, 480, 400 }, { 680, 960, 300 } },
        anchors = { { 240, 300 }, { 680, 300 }, { 240, 360 }, { 680, 360 }, { 440, 400 }, { 480, 400 } },
        start = { 90, 300 }, goal = 830, water = WATER, budget = 4000,
    },
    {
        id = "thrifty", zone = "desolace", vehicle = "shredder", materials = { "road", "wood", "steel", "rope" },
        terrain = { { -40, 220, 280 }, { 700, 960, 280 } },
        anchors = { { 220, 280 }, { 700, 280 }, { 220, 340 }, { 700, 340 }, { 200, 140 }, { 720, 140 } },
        cranes = { { 200, 140 }, { 720, 140 } },
        start = { 70, 280 }, goal = 850, water = WATER, budget = 1700,
    },
}

for i, level in ipairs(BA.LEVELS) do level.index = i end
