-- The bounty zones with their level ranges from Classic and WoW: Forever. Every zone has one
-- boss; `loot` names the three mercenaries whose coins the boss drops, `gear` the mercenary
-- whose second (normal) or third (heroic) piece of equipment the first clear unlocks.

local _, ns = ...
ns.Mercenaries = ns.Mercenaries or {}
local MC = ns.Mercenaries

local function Z(id, continent, min, max, boss, pool, adds, loot, gearNormal, gearHeroic)
    return {
        id = id, continent = continent, min = min, max = max, boss = boss, pool = pool, adds = adds,
        loot = loot, gear = { normal = gearNormal, heroic = gearHeroic },
    }
end

MC.Zones = {
    elwynn = Z("elwynn", "ek", 1, 10, "hogger",
        { "kobold_vermin", "kobold_tunneler", "riverpaw_outrunner", "defias_thug", "murloc_streamrunner", "prowler" },
        { "riverpaw_gnoll", "riverpaw_outrunner", "prowler" }, { "renzik", "bolvar", "tirion" }, "bolvar", "renzik"),
    dunmorogh = Z("dunmorogh", "ek", 1, 10, "thermaplugg",
        { "frostmane_whelp", "frostmane_seer", "rockjaw_trogg", "leper_gnome", "ice_claw_bear" },
        { "leper_gnome", "leper_gnome", "leper_gnome" }, { "magni", "jaina", "cairne" }, "magni", "cairne"),
    tirisfal = Z("tirisfal", "ek", 1, 10, "whitemane",
        { "rattlecage_skeleton", "mindless_zombie", "scarlet_convert", "scarlet_missionary", "darkhound" },
        { "scarlet_monk", "scarlet_monk", "scarlet_missionary" }, { "sylvanas", "taelan", "benedictus" }, "sylvanas", "taelan"),
    teldrassil = Z("teldrassil", "kal", 1, 10, "melenas",
        { "grellkin", "timberling", "gnarlpine_ursa", "webwood_spider", "nightsaber" },
        { "grellkin", "grellkin", "timberling" }, { "tyrande", "shandris", "hamuul" }, "tyrande", "shandris"),
    durotar = Z("durotar", "kal", 1, 10, "zalazane",
        { "vile_familiar", "mottled_boar", "scorpid_worker", "kul_tiras_sailor", "durotar_tiger" },
        { "voodoo_troll", "voodoo_troll", "durotar_tiger" }, { "thrall", "voljin", "mankrik" }, "voljin", "thrall"),
    mulgore = Z("mulgore", "kal", 1, 10, "arrachea",
        { "plainstrider", "bristleback_quilboar", "palemane_tanner", "venture_laborer", "prairie_wolf" },
        { "prairie_wolf", "plainstrider", "prairie_wolf" }, { "magatha", "cairne", "hamuul" }, "hamuul", "magatha"),
    zephras = Z("zephras", "zephras", 1, 12, "lorthuna",
        { "shadowgale_shrieker", "shadowgale_shriekling", "shadowgale_ursera", "shadowgale_manticore", "drowned_skyborne" },
        { "shadowgale_ursera", "drowned_skyborne", "shadowgale_manticore" }, { "jaina", "tyrande", "shandris" }, "shandris", "jaina"),
    westfall = Z("westfall", "ek", 10, 20, "vancleef",
        { "defias_pillager", "defias_trapper", "harvest_golem", "riverpaw_gnoll", "fleshripper" },
        { "defias_blackguard", "defias_pillager", "defias_trapper" }, { "renzik", "eitrigg", "bolvar" }, "renzik", "bolvar"),
    lochmodan = Z("lochmodan", "ek", 10, 20, "galgosh",
        { "stonesplinter_trogg", "stonesplinter_seer", "mogrosh_ogre", "tunnel_rat", "dark_iron_dwarf", "mountain_buzzard" },
        { "stonesplinter_trogg", "stonesplinter_seer", "stonesplinter_trogg" }, { "magni", "eitrigg", "tirion" }, "eitrigg", "magni"),
    silverpine = Z("silverpine", "ek", 10, 20, "arugal",
        { "moonrage_whitescalp", "dalaran_apprentice", "rot_hide_gnoll", "shadowfang_moonwalker" },
        { "son_of_arugal", "shadowfang_moonwalker", "son_of_arugal" }, { "sylvanas", "jaina", "voljin" }, "jaina", "sylvanas"),
    darkshore = Z("darkshore", "kal", 10, 20, "murkdeep",
        { "greymist_coastrunner", "greymist_seer", "blackwood_pathfinder", "darkshore_thresher", "moonstalker" },
        { "greymist_coastrunner", "greymist_seer", "greymist_coastrunner" }, { "tyrande", "rexxar", "benedictus" }, "benedictus", "tyrande"),
    barrens = Z("barrens", "kal", 10, 25, "kodobane",
        { "razormane_thornweaver", "kolkar_wrangler", "witchwing_harpy", "venture_peon", "savannah_huntress", "kolkar_stormer" },
        { "kolkar_wrangler", "kolkar_stormer", "kolkar_wrangler" }, { "mankrik", "rexxar", "thrall" }, "mankrik", "rexxar"),
    redridge = Z("redridge", "ek", 15, 25, "gathilzogg",
        { "redridge_mongrel", "redridge_mystic", "blackrock_grunt", "blackrock_shadowcaster", "shadowhide_brute" },
        { "blackrock_grunt", "blackrock_shadowcaster", "blackrock_grunt" }, { "taelan", "eitrigg", "bolvar" }, "taelan", "eitrigg"),
    stonetalon = Z("stonetalon", "kal", 15, 27, "gerenzo",
        { "venture_logger", "venture_operator", "deepmoss_webspinner", "bloodfury_harpy", "grimtotem_ruffian" },
        { "venture_operator", "venture_logger", "venture_operator" }, { "magatha", "rexxar", "voljin" }, "magatha", "hamuul"),
    ashenvale = Z("ashenvale", "kal", 18, 30, "akumai",
        { "foulweald_warrior", "bleakheart_satyr", "blackfathom_tide_priestess", "blackfathom_myrmidon", "twilight_acolyte" },
        { "blackfathom_myrmidon", "twilight_acolyte", "blackfathom_tide_priestess" }, { "tyrande", "hamuul", "shandris" }, "rexxar", "voljin"),
    duskwood = Z("duskwood", "ek", 18, 30, "stitches",
        { "skeletal_warrior", "nightbane_shadow_weaver", "venom_web_spider", "bone_chewer", "plague_spreader" },
        { "plague_spreader", "skeletal_warrior", "bone_chewer" }, { "tirion", "taelan", "renzik" }, "tirion", "benedictus"),
    wetlands = Z("wetlands", "ek", 20, 30, "nekrosh",
        { "dragonmaw_grunt", "dragonmaw_shadowwarder", "mottled_raptor", "mosshide_gnoll", "bluegill_murloc" },
        { "dragonmaw_grunt", "dragonmaw_shadowwarder", "dragonmaw_grunt" }, { "magni", "thrall", "eitrigg" }, "thrall", "mankrik"),
    hillsbrad = Z("hillsbrad", "ek", 20, 30, "burnside",
        { "hillsbrad_footman", "hillsbrad_farmer", "syndicate_thief", "torn_fin_tidehunter", "gray_bear" },
        { "hillsbrad_councilman", "hillsbrad_footman", "hillsbrad_councilman" }, { "sylvanas", "jaina", "taelan" }, "cairne", "tirion"),
}

-- Travel order: by level, starting zones first.
MC.ZONE_ORDER = {
    "elwynn", "dunmorogh", "tirisfal", "teldrassil", "durotar", "mulgore", "zephras",
    "westfall", "lochmodan", "silverpine", "darkshore", "barrens", "redridge", "stonetalon",
    "ashenvale", "duskwood", "wetlands", "hillsbrad",
}

-- Extra strength of each bounty's foes, so a party one level below the boss wins about 60 % of
-- the time against the bot's play (heroic: 40 % at level 59 without ranks or gear).
-- Tuned with tools/balance_mercenaries.py --tune (--heroic).
local POWER = {
    elwynn = -0.20, dunmorogh = 0.02, tirisfal = 0.11, teldrassil = 0.01, durotar = 0.24, mulgore = -0.03,
    zephras = 0.18, westfall = 0.03, lochmodan = 0.43, silverpine = 0.22, darkshore = 0.25, barrens = 0.24,
    redridge = 0.09, stonetalon = 0.61, ashenvale = 0.18, duskwood = 0.13, wetlands = 0.00, hillsbrad = 0.47,
}
local HEROIC_POWER = {
    elwynn = -0.02, dunmorogh = 0.30, tirisfal = 0.11, teldrassil = 0.30, durotar = 0.12, mulgore = 0.14,
    zephras = 0.09, westfall = 0.08, lochmodan = 0.20, silverpine = -0.09, darkshore = 0.16, barrens = 0.06,
    redridge = 0.09, stonetalon = 0.40, ashenvale = 0.09, duskwood = 0.03, wetlands = -0.08, hillsbrad = 0.20,
}
for id, zone in pairs(MC.Zones) do
    zone.power, zone.heroicPower = POWER[id] or 0, HEROIC_POWER[id] or 0
end
