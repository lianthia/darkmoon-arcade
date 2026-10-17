-- Dungeons: a fixed path where every boss must fall, trash fights between them and a spirit healer only
-- before the last boss, so they are harder than bounties. Dungeons are always open; a hidden boss waits
-- on a side branch that its task opens (store.unlocks) - before, the party walks past it. Every boss drops Classic's loot with
-- Classic's chances (ItemData.lua: MC.DungeonLoot) and now and then an enchanting formula.
--
-- A dungeon is kept with the zones (MC.Zones[id], dungeon = true) so runs, battles and the result page
-- work as for bounties; it is not in MC.ZONE_ORDER, so bounty lists and achievements leave it out.
--   region      the bounty zone whose map shows its entrance; spot: the entrance in that map (0..1)
--   encounters  in order: boss, adds, npcs (whose loot it drops), trash before it (elite = an elite
--               fight, the last of `waves` fights), healer before it, hidden = the unlock that reveals it, chance = a rare one that
--               shows up in that share of the runs (as Classic's rare spawns)
--   tier        the highest formula tier its bosses drop (heroic one more)
--   group       wings of one place (the Scarlet Monastery): one portal on the map, the wings picked in
--               its panel
--   lootFrom    the loot table it shares (both halves of Stratholme)
--   power       extra strength of its foes: a fresh party one level below the last boss wins about 47 %
--               (heroicPower: a geared party at level 60 about 40 %); tools/balance_mercenaries.py
--               --tune --dungeons (--heroic)

local _, ns = ...
local MC = ns.Mercenaries
local Bounty, Quests = MC.Bounty, MC.Quests
local Random = MC.Combat.Random

local Dungeons = {}
MC.Dungeons = Dungeons

MC.DUNGEON_ORDER = { "ragefire", "thanes", "ruins_lordaeron", "deadmines", "wailing", "shadowfang", "blackfathom",
    "stockade", "excavation", "gnomeregan", "kraul", "dalaran",
    "sm_graveyard", "sm_library", "sm_armory", "sm_cathedral", "downs", "uldaman",
    "zulfarrak", "mara_foulspore", "mara_grotto", "mara_earthsong", "sunken", "brd", "lbrs", "dm_east", "dm_west", "dm_north", "scholomance", "strat_live",
    "strat_undead" }

MC.Zones.deadmines = {
    id = "deadmines", dungeon = true, continent = "ek", region = "westfall", spot = { 0.42, 0.74 },
    min = 18, max = 23, boss = "vancleef", tier = 1,
    power = -0.5, heroicPower = -0.09, pool = {}, adds = {}, loot = {}, gear = {},
    encounters = {
        { boss = "rhahkzor", adds = { "defias_miner", "defias_overseer" }, npcs = { 644 },
            trash = { "defias_miner", "defias_overseer", "defias_taskmaster" } },
        { boss = "minerjohnson", adds = { "defias_miner", "defias_miner" }, npcs = { 3586 }, hidden = "deadmines_johnson" },
        { boss = "sneed", adds = { "goblin_sneed", "goblin_craftsman" }, npcs = { 642, 643 },
            trash = { "goblin_engineer", "goblin_craftsman", "defias_taskmaster", "defias_evoker" } },
        { boss = "gilnid", adds = { "goblin_engineer", "goblin_craftsman" }, npcs = { 1763 } },
        { boss = "smite", adds = { "defias_pirate", "defias_pirate" }, npcs = { 646 },
            trash = { "defias_pirate", "defias_squallshaper", "defias_evoker" }, elite = true },
        { boss = "greenskin", adds = { "defias_squallshaper", "defias_pirate" }, npcs = { 647 } },
        { boss = "cookie", adds = { "defias_pirate" }, npcs = { 645 } },
        { boss = "vancleef", adds = { "defias_pirate", "defias_blackguard", "defias_squallshaper" }, npcs = { 639 },
            trash = { "defias_pirate", "defias_squallshaper", "defias_blackguard" }, healer = true },
    },
}
-- The four Fanglords, Kresh and Skum, Verdan where Naralex sleeps; Mutanus wakes on a side branch once
-- Naralex's dream is followed (Hamuul's tasks). The Deviate Faerie Dragon roams now and then.
MC.Zones.wailing = {
    id = "wailing", dungeon = true, continent = "kal", region = "barrens", spot = { 0.46, 0.36 },
    min = 15, max = 25, boss = "verdan", tier = 1,
    power = -0.12, heroicPower = -0.15, pool = {}, adds = {}, loot = {}, gear = {},
    encounters = {
        { boss = "anacondra", adds = { "druid_of_the_fang", "deviate_adder" }, npcs = { 3671 },
            trash = { "druid_of_the_fang", "deviate_ravager", "deviate_stinglash", "deviate_adder" } },
        { boss = "pythas", adds = { "druid_of_the_fang", "deviate_stinglash" }, npcs = { 3670 } },
        { boss = "cobrahn", adds = { "druid_of_the_fang", "deviate_adder" }, npcs = { 3669 } },
        { boss = "kresh", adds = { "deviate_guardian" }, npcs = { 3653 },
            trash = { "deviate_guardian", "evolving_ectoplasm", "deviate_venomwing", "druid_of_the_fang" } },
        { boss = "skum", adds = { "deviate_stinglash", "deviate_venomwing" }, npcs = { 3674 } },
        { boss = "faeriedragon", adds = { "deviate_venomwing" }, npcs = { 5912 }, chance = 0.35 },
        { boss = "serpentis", adds = { "druid_of_the_fang", "druid_of_the_fang", "deviate_guardian" }, npcs = { 3673 },
            trash = { "deviate_lasher", "deviate_guardian", "deviate_ravager", "evolving_ectoplasm" }, elite = true },
        { boss = "mutanus", adds = { "deviate_ravager", "deviate_ravager" }, npcs = { 3654 }, hidden = "wailing_mutanus" },
        { boss = "verdan", adds = { "deviate_lasher", "deviate_lasher", "deviate_lasher" }, npcs = { 5775 }, healer = true },
    },
}

-- Ragefire Chasm beneath Orgrimmar: troggs and the Searing Blade cult.
MC.Zones.ragefire = {
    id = "ragefire", dungeon = true, continent = "kal", region = "durotar", spot = { 0.45, 0.12 },
    min = 13, max = 18, boss = "bazzalan", tier = 1,
    power = -0.41, heroicPower = -0.1, pool = {}, adds = {}, loot = {}, gear = {},
    encounters = {
        { boss = "oggleflint", adds = { "ragefire_trogg", "ragefire_shaman" }, npcs = { 11517 },
            trash = { "ragefire_trogg", "ragefire_shaman", "earthborer", "molten_elemental" } },
        { boss = "taragaman", adds = { "molten_elemental", "searing_blade_cultist" }, npcs = { 11520 },
            trash = { "searing_blade_cultist", "searing_blade_enforcer", "molten_elemental" }, elite = true },
        { boss = "jergosh", adds = { "searing_blade_cultist", "searing_blade_enforcer" }, npcs = { 11518 } },
        { boss = "bazzalan", adds = { "searing_blade_enforcer", "searing_blade_cultist", "searing_blade_enforcer" }, npcs = { 11519 },
            trash = { "searing_blade_cultist", "searing_blade_enforcer", "earthborer" }, healer = true },
    },
}

-- Shadowfang Keep: Arugal's worgen in the Silverpine keep of Baron Silverlaine.
MC.Zones.shadowfang = {
    id = "shadowfang", dungeon = true, continent = "ek", region = "silverpine", spot = { 0.45, 0.68 },
    min = 22, max = 30, boss = "arugal", tier = 2,
    power = -0.39, heroicPower = -0.19, pool = {}, adds = {}, loot = {}, gear = {},
    encounters = {
        { boss = "rethilgore", adds = { "shadowfang_ragetooth", "bleak_worg" }, npcs = { 3914 },
            trash = { "shadowfang_ragetooth", "bleak_worg", "shadowfang_darksoul", "haunted_servitor" } },
        { boss = "razorclaw", adds = { "shadowfang_wolfguard", "haunted_servitor" }, npcs = { 3886 } },
        { boss = "silverlaine", adds = { "wailing_guardsman", "haunted_servitor" }, npcs = { 3887 },
            trash = { "wailing_guardsman", "haunted_servitor", "shadowfang_darksoul" } },
        { boss = "springvale", adds = { "wailing_guardsman", "wailing_guardsman" }, npcs = { 4278 } },
        { boss = "deathsworn", adds = { "wailing_guardsman", "haunted_servitor" }, npcs = { 3872 }, chance = 0.35 },
        { boss = "odo", adds = { "bleak_worg", "bleak_worg" }, npcs = { 4279 },
            trash = { "lupine_horror", "shadowfang_wolfguard", "shadowfang_ragetooth" }, elite = true },
        { boss = "fenrus", adds = { "lupine_horror", "bleak_worg" }, npcs = { 4274 } },
        { boss = "nandos", adds = { "lupine_horror", "lupine_horror" }, npcs = { 3927 } },
        { boss = "arugal", adds = { "shadowfang_darksoul", "shadowfang_moonwalker", "shadowfang_darksoul" }, npcs = { 4275 },
            healer = true },
    },
}

-- Blackfathom Deeps: the naga and the Twilight's Hammer around Aku'mai's temple; Baron Aquanis rises
-- from the water once Shandris's task is done.
MC.Zones.blackfathom = {
    id = "blackfathom", dungeon = true, continent = "kal", region = "ashenvale", spot = { 0.14, 0.14 },
    min = 24, max = 32, boss = "akumai", tier = 2,
    power = -0.33, heroicPower = -0.18, pool = {}, adds = {}, loot = {}, gear = {},
    encounters = {
        { boss = "ghamoora", adds = { "akumai_snapjaw" }, npcs = { 4887 },
            trash = { "blackfathom_myrmidon", "blackfathom_oracle", "akumai_snapjaw" } },
        { boss = "sarevess", adds = { "blackfathom_myrmidon", "blackfathom_tide_priestess" }, npcs = { 4831 } },
        { boss = "gelihast", adds = { "blackfathom_myrmidon", "akumai_snapjaw" }, npcs = { 6243 },
            trash = { "blackfathom_tide_priestess", "blackfathom_oracle", "akumai_snapjaw" } },
        { boss = "aquanis", adds = { "blackfathom_oracle", "blackfathom_tide_priestess" }, npcs = { 12876 }, hidden = "blackfathom_aquanis" },
        { boss = "kelris", adds = { "twilight_acolyte", "twilight_reaver", "twilight_acolyte" }, npcs = { 4832 },
            trash = { "twilight_acolyte", "twilight_reaver" }, elite = true },
        { boss = "serrakis", adds = { "akumai_snapjaw", "akumai_snapjaw" }, npcs = { 4830 } },
        { boss = "akumai", adds = { "akumai_snapjaw", "blackfathom_myrmidon", "akumai_snapjaw" }, npcs = { 4829 }, healer = true },
    },
}

-- The Stockade: the prisoners of Stormwind's jail in open riot.
MC.Zones.stockade = {
    id = "stockade", dungeon = true, continent = "ek", region = "elwynn", spot = { 0.3, 0.12 },
    min = 22, max = 30, boss = "bazil", tier = 2,
    power = -0.28, heroicPower = -0.06, pool = {}, adds = {}, loot = {}, gear = {},
    encounters = {
        { boss = "targorr", adds = { "defias_prisoner", "defias_convict" }, npcs = { 1696 },
            trash = { "defias_prisoner", "defias_convict", "defias_captive" } },
        { boss = "kam", adds = { "defias_inmate", "defias_prisoner" }, npcs = { 1666 } },
        { boss = "hamhock", adds = { "defias_convict", "defias_inmate" }, npcs = { 1717 },
            trash = { "defias_inmate", "defias_insurgent", "defias_captive" }, elite = true },
        { boss = "bruegal", adds = { "defias_inmate", "defias_insurgent" }, npcs = { 1720 }, chance = 0.35 },
        { boss = "dextren", adds = { "defias_captive", "defias_insurgent" }, npcs = { 1663 } },
        { boss = "bazil", adds = { "defias_insurgent", "defias_convict", "defias_insurgent" }, npcs = { 1716 }, healer = true },
    },
}

-- Gnomeregan: the irradiated city of the gnomes, held by troggs and Dark Irons.
MC.Zones.gnomeregan = {
    id = "gnomeregan", dungeon = true, continent = "ek", region = "dunmorogh", spot = { 0.24, 0.38 },
    min = 29, max = 38, boss = "thermaplugg", tier = 2,
    power = -0.04, heroicPower = -0.04, pool = {}, adds = {}, loot = {}, gear = {},
    encounters = {
        { boss = "techbot", adds = { "mechanized_sentry" }, npcs = { 6231 } },
        { boss = "grubbis", adds = { "caverndeep_ambusher", "irradiated_pillager" }, npcs = { 7361 },
            trash = { "irradiated_pillager", "caverndeep_ambusher", "irradiated_slime" } },
        { boss = "viscous", adds = { "irradiated_slime", "irradiated_slime" }, npcs = { 7079 } },
        { boss = "electrocutioner", adds = { "mechanized_sentry", "mechano_tank" }, npcs = { 6235 },
            trash = { "mechano_tank", "mechanized_sentry", "dark_iron_agent" }, elite = true },
        { boss = "ambassador", adds = { "dark_iron_agent", "dark_iron_agent" }, npcs = { 6228 }, chance = 0.35 },
        { boss = "pummeler", adds = { "mechano_tank" }, npcs = { 6229 } },
        { boss = "thermaplugg", adds = { "mechanized_sentry", "mechano_tank", "mechanized_sentry" }, npcs = { 7800 }, healer = true },
    },
}

-- Razorfen Kraul: the quilboar's thorn maze in the southern Barrens.
MC.Zones.kraul = {
    id = "kraul", dungeon = true, continent = "kal", region = "barrens", spot = { 0.42, 0.9 },
    min = 30, max = 40, boss = "charlga", tier = 2,
    power = -0.07, heroicPower = -0.25, pool = {}, adds = {}, loot = {}, gear = {},
    encounters = {
        { boss = "aggem", adds = { "deaths_head_acolyte", "razorfen_defender" }, npcs = { 4424 },
            trash = { "razorfen_defender", "razorfen_warrior", "kraul_bat", "deaths_head_acolyte" } },
        { boss = "jargba", adds = { "deaths_head_acolyte", "razorfen_warrior" }, npcs = { 4428 } },
        { boss = "halmgar", adds = { "razorfen_geomancer", "razorfen_totemic" }, npcs = { 4842 }, chance = 0.35 },
        { boss = "ramtusk", adds = { "razorfen_defender", "razorfen_warrior" }, npcs = { 4420 },
            trash = { "razorfen_geomancer", "razorfen_totemic", "razorfen_warrior" } },
        { boss = "spearhide", adds = { "razorfen_warrior", "kraul_bat" }, npcs = { 4438 } },
        { boss = "blindhunter", adds = { "kraul_bat", "kraul_bat" }, npcs = { 4425 }, chance = 0.35 },
        { boss = "agathelos", adds = { "razorfen_defender", "kraul_bat" }, npcs = { 4422 },
            trash = { "razorfen_defender", "razorfen_geomancer", "kraul_bat" }, elite = true },
        { boss = "charlga", adds = { "razorfen_geomancer", "razorfen_totemic", "razorfen_defender" }, npcs = { 4421 }, healer = true },
    },
}

-- The Scarlet Monastery in Tirisfal: four wings, each its own run, as in Classic.
MC.Zones.sm_graveyard = {
    id = "sm_graveyard", dungeon = true, group = "sm", continent = "ek", region = "tirisfal", spot = { 0.84, 0.3 },
    min = 28, max = 38, boss = "thalnos", tier = 2,
    power = 0.64, heroicPower = 0.09, pool = {}, adds = {}, loot = {}, gear = {},
    encounters = {
        { boss = "vishas", adds = { "scarlet_torturer", "scarlet_sentry" }, npcs = { 3983 },
            trash = { "scarlet_torturer", "scarlet_sentry", "scarlet_scryer" }, waves = 2 },
        { boss = "ironspine", adds = { "anguished_dead" }, npcs = { 6489 }, chance = 0.35 },
        { boss = "azshir", adds = { "haunting_phantasm" }, npcs = { 6490 }, chance = 0.35 },
        { boss = "fallenchampion", adds = { "anguished_dead" }, npcs = { 6488 }, chance = 0.35 },
        { boss = "thalnos", adds = { "haunting_phantasm", "unfettered_spirit", "anguished_dead" }, npcs = { 4543 },
            trash = { "haunting_phantasm", "anguished_dead", "unfettered_spirit" }, elite = true, healer = true },
    },
}

MC.Zones.sm_library = {
    id = "sm_library", dungeon = true, group = "sm", continent = "ek", region = "tirisfal", spot = { 0.84, 0.3 },
    min = 29, max = 39, boss = "doan", tier = 3,
    power = 0.85, heroicPower = 0.16, pool = {}, adds = {}, loot = {}, gear = {},
    encounters = {
        { boss = "loksey", adds = { "scarlet_tracking_hound", "scarlet_tracking_hound", "scarlet_beastmaster" }, npcs = { 3974 },
            trash = { "scarlet_adept", "scarlet_gallant", "scarlet_monk", "scarlet_beastmaster" }, waves = 2 },
        { boss = "doan", adds = { "scarlet_adept", "scarlet_diviner", "scarlet_chaplain" }, npcs = { 6487 },
            trash = { "scarlet_gallant", "scarlet_chaplain", "scarlet_diviner", "scarlet_adept" }, waves = 2, elite = true,
            healer = true },
    },
}

MC.Zones.sm_armory = {
    id = "sm_armory", dungeon = true, group = "sm", continent = "ek", region = "tirisfal", spot = { 0.84, 0.3 },
    min = 32, max = 42, boss = "herod", tier = 3,
    power = -0.04, heroicPower = 0.32, pool = {}, adds = {}, loot = {}, gear = {},
    encounters = {
        { boss = "herod", adds = { "scarlet_trainee", "scarlet_trainee", "scarlet_trainee" }, npcs = { 3975 },
            trash = { "scarlet_defender", "scarlet_myrmidon", "scarlet_guardsman", "scarlet_protector", "scarlet_evoker" },
            waves = 3, elite = true, healer = true },
    },
}

MC.Zones.sm_cathedral = {
    id = "sm_cathedral", dungeon = true, group = "sm", continent = "ek", region = "tirisfal", spot = { 0.84, 0.3 },
    min = 35, max = 45, boss = "whitemane", tier = 3,
    power = 0.48, heroicPower = 0.21, pool = {}, adds = {}, loot = {}, gear = {},
    encounters = {
        { boss = "fairbanks", adds = { "scarlet_chaplain", "scarlet_abbot" }, npcs = { 4542 },
            trash = { "scarlet_monk", "scarlet_chaplain", "scarlet_abbot", "scarlet_wizard" } },
        { boss = "mograine", adds = { "scarlet_champion", "scarlet_centurion" }, npcs = { 3976 },
            trash = { "scarlet_centurion", "scarlet_champion", "scarlet_wizard", "scarlet_abbot" }, waves = 2, elite = true },
        { boss = "whitemane", adds = { "scarlet_abbot", "scarlet_champion", "scarlet_abbot" }, npcs = { 3977 }, healer = true },
    },
}

-- Razorfen Downs: the quilboar's barrows, where the lich Amnennar raises the Scourge.
MC.Zones.downs = {
    id = "downs", dungeon = true, continent = "kal", region = "barrens", spot = { 0.56, 0.88 },
    min = 40, max = 50, boss = "amnennar", tier = 3,
    power = 0.12, heroicPower = -0.02, pool = {}, adds = {}, loot = {}, gear = {},
    encounters = {
        { boss = "tutenkash", adds = { "tomb_fiend", "tomb_fiend" }, npcs = { 7355 },
            trash = { "razorfen_battleguard", "deaths_head_cultist", "splinterbone_skeleton", "tomb_fiend" } },
        { boss = "plaguemaw", adds = { "tomb_reaver" }, npcs = { 7356 } },
        { boss = "mordresh", adds = { "splinterbone_warrior", "deaths_head_necromancer" }, npcs = { 7357 },
            trash = { "splinterbone_warrior", "splinterbone_skeleton", "deaths_head_necromancer" } },
        { boss = "glutton", adds = { "splinterbone_centurion" }, npcs = { 8567 } },
        { boss = "ragglesnout", adds = { "deaths_head_necromancer" }, npcs = { 7354 }, chance = 0.35 },
        { boss = "amnennar", adds = { "frozen_soul", "splinterbone_centurion", "frozen_soul" }, npcs = { 7358 },
            trash = { "tomb_reaver", "splinterbone_centurion", "frozen_soul" }, elite = true, healer = true },
    },
}

-- Uldaman: the titans' vault in the Badlands, dug open by troggs and the Shadowforge dwarves.
MC.Zones.uldaman = {
    id = "uldaman", dungeon = true, continent = "ek", region = "badlands", spot = { 0.44, 0.12 },
    min = 42, max = 52, boss = "archaedas", tier = 3,
    power = -0.12, heroicPower = -0.215, pool = {}, adds = {}, loot = {}, gear = {},
    encounters = {
        { boss = "baelog", adds = { "eric_swift", "olaf" }, npcs = { 6906, 6907, 6908 },
            trash = { "stonevault_ambusher", "stonevault_oracle", "shadowforge_ruffian", "shadowforge_darkweaver" } },
        { boss = "revelosh", adds = { "stonevault_geomancer", "stonevault_oracle" }, npcs = { 6910 },
            trash = { "stonevault_brawler", "stonevault_geomancer", "stonevault_oracle" } },
        { boss = "ironaya", adds = { "earthen_guardian" }, npcs = { 7228 },
            trash = { "earthen_rocksmasher", "earthen_guardian", "stone_steward" }, elite = true },
        { boss = "obsidian", adds = { "stone_steward" }, npcs = { 7023 } },
        { boss = "stonekeeper", adds = { "stone_steward", "earthen_guardian" }, npcs = { 7206 } },
        { boss = "galgann", adds = { "shadowforge_ruffian", "shadowforge_darkweaver" }, npcs = { 7291 },
            trash = { "shadowforge_ruffian", "shadowforge_darkweaver", "jadespine_basilisk", "venomlash_scorpid" } },
        { boss = "grimlok", adds = { "stonevault_brawler", "stonevault_geomancer" }, npcs = { 4854 },
            trash = { "stonevault_brawler", "venomlash_scorpid", "jadespine_basilisk" } },
        { boss = "archaedas", adds = { "earthen_guardian", "stone_steward", "earthen_guardian" }, npcs = { 2748 },
            trash = { "earthen_guardian", "earthen_rocksmasher", "stone_steward" }, elite = true, healer = true },
    },
}

-- Zul'Farrak: the Sandfury trolls' city in Tanaris, where Gahz'rilla sleeps in the sacred pool.
MC.Zones.zulfarrak = {
    id = "zulfarrak", dungeon = true, continent = "kal", region = "tanaris", spot = { 0.39, 0.21 },
    min = 44, max = 54, boss = "ukorz", tier = 3,
    power = 0.16, heroicPower = -0.252, pool = {}, adds = {}, loot = {}, gear = {},
    encounters = {
        { boss = "antusul", adds = { "sandfury_shadowcaster", "sandfury_witch_doctor" }, npcs = { 8127 },
            trash = { "sandfury_axe_thrower", "sandfury_cretin", "sandfury_shadowcaster", "scarab" } },
        { boss = "zerillis", adds = { "scarab" }, npcs = { 10082 }, chance = 0.35 },
        { boss = "theka", adds = { "scarab", "scarab" }, npcs = { 7272 } },
        { boss = "sandarr", adds = { "sandfury_axe_thrower" }, npcs = { 10080 }, chance = 0.35 },
        { boss = "zumrah", adds = { "zulfarrak_zombie", "zulfarrak_dead_hero", "zulfarrak_zombie" }, npcs = { 7271 },
            trash = { "zulfarrak_zombie", "zulfarrak_dead_hero", "sandfury_witch_doctor" } },
        { boss = "dustwraith", adds = { "scarab" }, npcs = { 10081 }, chance = 0.35 },
        { boss = "sezzziz", adds = { "sandfury_shadowcaster", "sandfury_soul_eater" }, npcs = { 7275 },
            trash = { "sandfury_blood_drinker", "sandfury_soul_eater", "sandfury_shadowhunter" }, waves = 2, elite = true },
        { boss = "bly", adds = { "sandfury_shadowhunter", "sandfury_axe_thrower" }, npcs = { 7604 } },
        { boss = "velratha", adds = { "sandfury_witch_doctor", "sandfury_soul_eater" }, npcs = { 7795 } },
        { boss = "gahzrilla", adds = { "scarab" }, npcs = { 7273 } },
        { boss = "ukorz", adds = { "sandfury_blood_drinker", "sandfury_shadowhunter", "sandfury_blood_drinker" }, npcs = { 7267 },
            trash = { "sandfury_blood_drinker", "sandfury_axe_thrower", "sandfury_shadowhunter" }, healer = true },
    },
}

-- Maraudon: the satyr-poisoned caves of Desolace, three wings as in Forever (one loot table).
-- Foulspore Cavern, the orange caves: Noxxion and the lasher Razorlash.
MC.Zones.mara_foulspore = {
    id = "mara_foulspore", dungeon = true, group = "maraudon", continent = "kal", region = "desolace", spot = { 0.29, 0.62 },
    min = 45, max = 53, boss = "razorlash", tier = 3, lootFrom = "maraudon",
    power = 0.08, heroicPower = 0.2, pool = {}, adds = {}, loot = {}, gear = {},
    encounters = {
        { boss = "noxxion", adds = { "creeping_sludge", "creeping_sludge" }, npcs = { 13282 },
            trash = { "putridus_satyr", "putridus_trickster", "creeping_sludge", "barbed_lasher" }, waves = 2 },
        { boss = "razorlash", adds = { "barbed_lasher", "deeprot_tangler", "barbed_lasher" }, npcs = { 12258 },
            trash = { "deeprot_stomper", "deeprot_tangler", "barbed_lasher" }, waves = 2, elite = true, healer = true },
    },
}

-- The Wicked Grotto, the purple caves: the satyrs around Lord Vyletongue.
MC.Zones.mara_grotto = {
    id = "mara_grotto", dungeon = true, group = "maraudon", continent = "kal", region = "desolace", spot = { 0.29, 0.62 },
    min = 45, max = 53, boss = "vyletongue", tier = 3, lootFrom = "maraudon",
    power = 0.28, heroicPower = 0.21, pool = {}, adds = {}, loot = {}, gear = {},
    encounters = {
        { boss = "meshlok", adds = { "deeprot_stomper" }, npcs = { 12237 },
            trash = { "deeprot_stomper", "deeprot_tangler", "putridus_satyr" }, chance = 0.35 },
        { boss = "vyletongue", adds = { "putridus_trickster", "putridus_shadowstalker", "putridus_satyr" }, npcs = { 12236 },
            trash = { "putridus_satyr", "putridus_shadowstalker", "putridus_trickster" }, waves = 3, elite = true,
            healer = true },
    },
}

-- Earth Song Falls, the heart of Maraudon, down to Princess Theradras.
MC.Zones.mara_earthsong = {
    id = "mara_earthsong", dungeon = true, group = "maraudon", continent = "kal", region = "desolace", spot = { 0.29, 0.62 },
    min = 48, max = 57, boss = "theradras", tier = 3, lootFrom = "maraudon",
    power = 0.38, heroicPower = -0.12, pool = {}, adds = {}, loot = {}, gear = {},
    encounters = {
        { boss = "celebras", adds = { "celebrian_dryad", "deeprot_tangler" }, npcs = { 12225 },
            trash = { "celebrian_dryad", "deeprot_stomper", "subterranean_diemetradon" }, elite = true },
        { boss = "landslide", adds = { "theradrim_shardling", "theradrim_shardling" }, npcs = { 12203 },
            trash = { "theradrim_guardian", "theradrim_shardling", "primordial_behemoth" } },
        { boss = "gizlock", adds = { "theradrim_shardling" }, npcs = { 13601 } },
        { boss = "rotgrip", adds = { "subterranean_diemetradon" }, npcs = { 13596 },
            trash = { "subterranean_diemetradon", "primordial_behemoth" } },
        { boss = "theradras", adds = { "theradrim_guardian", "primordial_behemoth", "theradrim_guardian" }, npcs = { 12201 },
            trash = { "theradrim_guardian", "primordial_behemoth", "theradrim_shardling" }, healer = true },
    },
}

-- The Sunken Temple: the Atal'ai serve Hakkar, the green dragons guard Eranikus's nightmare; the
-- Avatar of Hakkar waits on a side branch until Vol'jin's task is done.
MC.Zones.sunken = {
    id = "sunken", dungeon = true, continent = "ek", region = "swampofsorrows", spot = { 0.7, 0.54 },
    min = 50, max = 60, boss = "eranikus", tier = 4,
    power = 0.07, heroicPower = -0.17, pool = {}, adds = {}, loot = {}, gear = {},
    encounters = {
        { boss = "atalalarion", adds = { "atalai_warrior", "atalai_warrior" }, npcs = { 8580 },
            trash = { "atalai_warrior", "atalai_witch_doctor", "mummified_atalai", "murk_worm" } },
        { boss = "jammalan", adds = { "atalai_priest", "atalai_witch_doctor" }, npcs = { 5710, 5711 },
            trash = { "atalai_priest", "atalai_corpse_eater", "atalai_deathwalker", "saturated_ooze" }, waves = 2 },
        { boss = "avatar", adds = { "atalai_priest", "hakkari_frostwing" }, npcs = { 8443 }, hidden = "sunken_avatar" },
        { boss = "dreamscythe", adds = { "nightmare_whelp", "nightmare_scalebane" }, npcs = { 5721 },
            trash = { "nightmare_scalebane", "nightmare_wyrmkin", "nightmare_whelp" }, elite = true },
        { boss = "weaver", adds = { "nightmare_wyrmkin", "nightmare_whelp" }, npcs = { 5720 } },
        { boss = "morphaz", adds = { "nightmare_scalebane", "nightmare_wyrmkin" }, npcs = { 5719 },
            trash = { "nightmare_scalebane", "nightmare_wyrmkin", "deep_lurker" } },
        { boss = "hazzas", adds = { "nightmare_whelp", "nightmare_scalebane" }, npcs = { 5722 } },
        { boss = "eranikus", adds = { "nightmare_wyrmkin", "nightmare_scalebane", "nightmare_wyrmkin" }, npcs = { 5709 },
            trash = { "nightmare_wyrmkin", "nightmare_scalebane", "hakkari_frostwing" }, healer = true },
    },
}

-- Blackrock Mountain: the Dark Iron city in its depths and the orcs' spire above share one portal.
MC.Zones.brd = {
    id = "brd", dungeon = true, group = "blackrock", continent = "ek", region = "searinggorge", spot = { 0.35, 0.85 },
    min = 52, max = 60, boss = "thaurissan", tier = 4,
    power = -0.04, heroicPower = -0.252, pool = {}, adds = {}, loot = {}, gear = {},
    encounters = {
        { boss = "roccor", adds = { "fireguard" }, npcs = { 9025 },
            trash = { "anvilrage_guardsman", "anvilrage_warden", "bloodhound" } },
        { boss = "gerstahn", adds = { "anvilrage_warden", "anvilrage_guardsman" }, npcs = { 9018 },
            trash = { "anvilrage_warden", "anvilrage_guardsman", "anvilrage_soldier" } },
        { boss = "grebmar", adds = { "bloodhound", "bloodhound", "bloodhound" }, npcs = { 9319 } },
        { boss = "grizzle", adds = { "anvilrage_soldier" }, npcs = { 9028 }, chance = 0.35 },
        { boss = "okthor", adds = { "anvilrage_soldier" }, npcs = { 9030 }, chance = 0.35 },
        { boss = "loregrain", adds = { "blazing_fireguard", "fireguard" }, npcs = { 9024 }, chance = 0.35 },
        { boss = "fineous", adds = { "anvilrage_officer", "doomforge_craftsman" }, npcs = { 9056 },
            trash = { "anvilrage_officer", "anvilrage_medic", "doomforge_craftsman" }, waves = 2 },
        { boss = "incendius", adds = { "fireguard", "fireguard_destroyer" }, npcs = { 9017 },
            trash = { "fireguard", "fireguard_destroyer", "blazing_fireguard" }, elite = true },
        { boss = "angerforge", adds = { "anvilrage_officer", "anvilrage_medic" }, npcs = { 9033 },
            trash = { "anvilrage_soldier", "anvilrage_medic", "anvilrage_officer" } },
        { boss = "argelmach", adds = { "ragereaver_golem", "warbringer_construct" }, npcs = { 8983 },
            trash = { "ragereaver_golem", "warbringer_construct", "molten_war_golem" } },
        { boss = "panzor", adds = { "molten_war_golem" }, npcs = { 8923 }, chance = 0.35 },
        { boss = "flamelash", adds = { "blazing_fireguard", "fireguard_destroyer" }, npcs = { 9156 },
            trash = { "fireguard", "blazing_fireguard", "molten_war_golem" } },
        { boss = "magmus", adds = { "fireguard_destroyer" }, npcs = { 9938 },
            trash = { "shadowforge_senator", "anvilrage_guardsman", "fireguard_destroyer" }, waves = 2, elite = true },
        { boss = "thaurissan", adds = { "shadowforge_senator", "anvilrage_guardsman", "shadowforge_senator" }, npcs = { 9019, 8929 }, healer = true },
    },
}

-- Lower Blackrock Spire: ogres, trolls and the Blackrock orcs under Overlord Wyrmthalak.
MC.Zones.lbrs = {
    id = "lbrs", dungeon = true, group = "blackrock", continent = "ek", region = "searinggorge", spot = { 0.35, 0.85 },
    min = 55, max = 60, boss = "wyrmthalak", tier = 4,
    power = -0.21, heroicPower = -0.2, pool = {}, adds = {}, loot = {}, gear = {},
    encounters = {
        { boss = "omokk", adds = { "spirestone_enforcer", "spirestone_mystic" }, npcs = { 9196 },
            trash = { "spirestone_enforcer", "spirestone_mystic", "spirestone_reaver" } },
        { boss = "ghok", adds = { "spirestone_reaver" }, npcs = { 9718 }, chance = 0.35 },
        { boss = "voshgajin", adds = { "smolderthorn_mystic", "smolderthorn_seer" }, npcs = { 9236 },
            trash = { "smolderthorn_axe_thrower", "smolderthorn_mystic", "smolderthorn_berserker" } },
        { boss = "voone", adds = { "smolderthorn_berserker", "smolderthorn_axe_thrower" }, npcs = { 9237 },
            trash = { "smolderthorn_seer", "smolderthorn_berserker", "smolderthorn_axe_thrower" } },
        { boss = "smolderweb", adds = { "spire_spider", "spire_spider" }, npcs = { 10596 },
            trash = { "spire_spider", "spirestone_reaver" } },
        { boss = "crystalfang", adds = { "spire_spider" }, npcs = { 10376 }, chance = 0.35 },
        { boss = "bannok", adds = { "firebrand_grunt" }, npcs = { 9596 }, chance = 0.35 },
        { boss = "urok", adds = { "spirestone_warlord", "spirestone_reaver" }, npcs = { 10584 } },
        { boss = "zigris", adds = { "firebrand_grunt", "firebrand_legionnaire" }, npcs = { 9736 },
            trash = { "firebrand_grunt", "firebrand_legionnaire", "firebrand_invoker", "scarshield_raider" }, waves = 2 },
        { boss = "halycon", adds = { "bloodaxe_worg", "bloodaxe_worg" }, npcs = { 10220 },
            trash = { "bloodaxe_raider", "bloodaxe_worg" } },
        { boss = "gizrul", adds = { "bloodaxe_worg" }, npcs = { 10268 } },
        { boss = "wyrmthalak", adds = { "rage_talon_dragonspawn", "firebrand_pyromancer", "rage_talon_dragonspawn" }, npcs = { 9568 },
            trash = { "rage_talon_dragonspawn", "firebrand_pyromancer", "scarshield_spellbinder" }, elite = true, healer = true },
    },
}

-- Dire Maul, the ruined city of Eldre'Thalas in Feralas: three wings, one portal. East: the satyrs
-- of the Warpwood.
MC.Zones.dm_east = {
    id = "dm_east", dungeon = true, group = "diremaul", continent = "kal", region = "feralas", spot = { 0.59, 0.43 },
    min = 58, max = 60, boss = "alzzin", tier = 4,
    power = -0.43, heroicPower = -0.05, pool = {}, adds = {}, loot = {}, gear = {},
    encounters = {
        { boss = "pusillin", adds = { "wildspawn_trickster" }, npcs = { 14354 },
            trash = { "warpwood_treant", "warpwood_tangler", "phase_lasher" } },
        { boss = "zevrim", adds = { "wildspawn_felsworn", "wildspawn_hellcaller" }, npcs = { 11490 },
            trash = { "wildspawn_rogue", "wildspawn_shadowstalker", "wildspawn_felsworn", "wildspawn_hellcaller" }, waves = 2 },
        { boss = "hydrospawn", adds = { "phase_lasher" }, npcs = { 13280 } },
        { boss = "lethtendris", adds = { "wildspawn_hellcaller", "wildspawn_trickster" }, npcs = { 14327 } },
        { boss = "alzzin", adds = { "warpwood_crusher", "warpwood_stomper", "warpwood_crusher" }, npcs = { 11492 },
            trash = { "warpwood_crusher", "warpwood_stomper", "wildspawn_trickster" }, elite = true, healer = true },
    },
}

-- Dire Maul West: the last Highborne and the demon they bound.
MC.Zones.dm_west = {
    id = "dm_west", dungeon = true, group = "diremaul", continent = "kal", region = "feralas", spot = { 0.59, 0.43 },
    min = 58, max = 60, boss = "tortheldrin", tier = 4,
    power = -0.42, heroicPower = -0.04, pool = {}, adds = {}, loot = {}, gear = {},
    encounters = {
        { boss = "tendris", adds = { "petrified_treant", "petrified_guardian" }, npcs = { 11489 },
            trash = { "petrified_treant", "petrified_guardian", "warpwood_treant" } },
        { boss = "illyanna", adds = { "skeletal_highborne" }, npcs = { 11488 },
            trash = { "skeletal_highborne", "rotting_highborne", "eldreth_spectre" } },
        { boss = "tsuzee", adds = { "eldreth_spectre" }, npcs = { 11467 }, chance = 0.35 },
        { boss = "kalendris", adds = { "eldreth_sorcerer" }, npcs = { 11487 },
            trash = { "eldreth_sorcerer", "eldreth_apparition" } },
        { boss = "immolthar", adds = { "arcane_aberration", "mana_remnant" }, npcs = { 11496 },
            trash = { "arcane_aberration", "mana_remnant", "residual_monstrosity" }, waves = 2, elite = true },
        { boss = "tortheldrin", adds = { "highborne_summoner", "eldreth_sorcerer", "highborne_summoner" }, npcs = { 11486 },
            trash = { "highborne_summoner", "residual_monstrosity" }, healer = true },
    },
}

-- Dire Maul North: the Gordok ogres and their king.
MC.Zones.dm_north = {
    id = "dm_north", dungeon = true, group = "diremaul", continent = "kal", region = "feralas", spot = { 0.59, 0.43 },
    min = 58, max = 60, boss = "gordok", tier = 4,
    power = -0.48, heroicPower = -0.12, pool = {}, adds = {}, loot = {}, gear = {},
    encounters = {
        { boss = "moldar", adds = { "gordok_mastiff", "gordok_brute" }, npcs = { 14326, 14322 },
            trash = { "gordok_brute", "gordok_mastiff", "gordok_reaver" } },
        { boss = "fengus", adds = { "gordok_brute", "gordok_reaver" }, npcs = { 14321 },
            trash = { "gordok_reaver", "gordok_warlock", "gordok_mage_lord" } },
        { boss = "slipkik", adds = { "gordok_warlock", "gordok_mage_lord" }, npcs = { 14323 } },
        { boss = "kromcrush", adds = { "gordok_captain", "gordok_reaver" }, npcs = { 14325 },
            trash = { "gordok_captain", "gordok_brute", "gordok_mage_lord" }, elite = true },
        { boss = "gordok", adds = { "gordok_captain", "gordok_mage_lord", "gordok_captain" }, npcs = { 11501, 14324 }, healer = true },
    },
}

-- Scholomance: the Cult of the Damned's school on Caer Darrow; Death Knight Darkreaver rises on a
-- side branch once Tirion's task is done.
MC.Zones.scholomance = {
    id = "scholomance", dungeon = true, continent = "ek", region = "westernplaguelands", spot = { 0.69, 0.73 },
    min = 58, max = 60, boss = "gandling", tier = 4,
    power = -0.52, heroicPower = -0.18, pool = {}, adds = {}, loot = {}, gear = {},
    encounters = {
        { boss = "kirtonos", adds = { "scholomance_acolyte", "scholomance_neophyte" }, npcs = { 10506 },
            trash = { "scholomance_acolyte", "scholomance_neophyte", "scholomance_necrolyte", "risen_guard" } },
        { boss = "jandice", adds = { "spectral_tutor", "spectral_tutor" }, npcs = { 10503 },
            trash = { "spectral_tutor", "spectral_researcher", "scholomance_adept" } },
        { boss = "rattlegore", adds = { "splintered_skeleton", "risen_construct" }, npcs = { 11622, 10433, 10432 },
            trash = { "risen_construct", "splintered_skeleton", "reanimated_corpse" }, waves = 2, elite = true },
        { boss = "darkreaver", adds = { "risen_guard", "bone_minion" }, npcs = { 14516 }, hidden = "scholo_darkreaver" },
        { boss = "ras", adds = { "scholomance_necromancer", "bone_minion" }, npcs = { 10508 },
            trash = { "scholomance_necromancer", "diseased_ghoul", "unstable_corpse" } },
        { boss = "malicia", adds = { "scholomance_dark_summoner", "scholomance_necrolyte" }, npcs = { 10505 } },
        { boss = "theolen", adds = { "plagued_hatchling", "scholomance_adept" }, npcs = { 11261 },
            trash = { "plagued_hatchling", "necrofiend", "scholomance_occultist" } },
        { boss = "polkelt", adds = { "diseased_ghoul", "unstable_corpse" }, npcs = { 10901 } },
        { boss = "ravenian", adds = { "risen_guard", "reanimated_corpse" }, npcs = { 10507 } },
        { boss = "alexei", adds = { "scholomance_occultist", "risen_guard" }, npcs = { 10504 },
            trash = { "aspect_of_banality", "aspect_of_corruption", "aspect_of_shadow" } },
        { boss = "illucia", adds = { "aspect_of_shadow" }, npcs = { 10502 } },
        { boss = "gandling", adds = { "risen_guard", "scholomance_dark_summoner", "risen_guard" }, npcs = { 1853 },
            trash = { "scholomance_necromancer", "scholomance_occultist", "risen_construct" }, elite = true, healer = true },
    },
}

-- Stratholme, the burnt city: two halves, one portal. The main gate: the Scarlet Crusade's
-- bastion under Balnazzar in Dathrohan's guise.
MC.Zones.strat_live = {
    id = "strat_live", dungeon = true, group = "strat", continent = "ek", region = "easternplaguelands", spot = { 0.27, 0.12 },
    min = 58, max = 60, boss = "balnazzar", tier = 4, lootFrom = "stratholme",
    power = -0.49, heroicPower = -0.19, pool = {}, adds = {}, loot = {}, gear = {},
    encounters = {
        { boss = "skul", adds = { "skeletal_guardian" }, npcs = { 10393 }, chance = 0.35 },
        { boss = "unforgiven", adds = { "spectral_citizen", "ghostly_citizen" }, npcs = { 10516 },
            trash = { "ghostly_citizen", "spectral_citizen", "wailing_banshee", "plague_ghoul" } },
        { boss = "forresten", adds = { "ghostly_citizen" }, npcs = { 10558 }, chance = 0.35 },
        { boss = "timmy", adds = { "plague_ghoul", "ghoul_ravener" }, npcs = { 10808 },
            trash = { "plague_ghoul", "ghoul_ravener", "skeletal_guardian" } },
        { boss = "malor", adds = { "crimson_monk", "crimson_initiate" }, npcs = { 11032 },
            trash = { "crimson_conjuror", "crimson_defender", "crimson_gallant", "crimson_guardsman", "crimson_initiate" } },
        { boss = "willey", adds = { "crimson_rifleman", "crimson_rifleman" }, npcs = { 10997 },
            trash = { "crimson_rifleman", "crimson_guardsman", "crimson_battle_mage" }, waves = 2 },
        { boss = "galford", adds = { "crimson_sorcerer", "crimson_priest" }, npcs = { 10811 },
            trash = { "crimson_sorcerer", "crimson_inquisitor", "crimson_priest" }, elite = true },
        { boss = "balnazzar", adds = { "crimson_inquisitor", "crimson_battle_mage", "crimson_monk" }, npcs = { 10812, 10813 },
            trash = { "crimson_monk", "crimson_inquisitor", "crimson_battle_mage" }, healer = true },
    },
}

-- Stratholme's service entrance: the Scourge's ziggurats and Baron Rivendare.
MC.Zones.strat_undead = {
    id = "strat_undead", dungeon = true, group = "strat", continent = "ek", region = "easternplaguelands", spot = { 0.27, 0.12 },
    min = 58, max = 60, boss = "rivendare", tier = 4, lootFrom = "stratholme",
    power = -0.64, heroicPower = -0.27, pool = {}, adds = {}, loot = {}, gear = {},
    encounters = {
        { boss = "barthilas", adds = { "crypt_crawler", "undead_scarab" }, npcs = { 10435 },
            trash = { "crypt_crawler", "crypt_beast", "undead_scarab", "eye_of_naxxramas" } },
        { boss = "stonespine", adds = { "crypt_beast" }, npcs = { 10809 }, chance = 0.35 },
        { boss = "anastari", adds = { "wailing_banshee", "spiteful_phantom" }, npcs = { 10436 },
            trash = { "vengeful_phantom", "spiteful_phantom", "wrath_phantom" } },
        { boss = "nerubenkan", adds = { "crypt_crawler", "crypt_beast" }, npcs = { 10437 },
            trash = { "crypt_crawler", "crypt_beast", "undead_scarab" } },
        { boss = "maleki", adds = { "thuzadin_shadowcaster", "thuzadin_acolyte" }, npcs = { 10438 },
            trash = { "thuzadin_shadowcaster", "thuzadin_necromancer", "thuzadin_acolyte" }, elite = true },
        { boss = "ramstein", adds = { "mangled_cadaver", "broken_cadaver" }, npcs = { 10439 },
            trash = { "bile_spewer", "venom_belcher", "mangled_cadaver", "ravaged_cadaver" }, waves = 2 },
        { boss = "rivendare", adds = { "black_guard_sentry", "thuzadin_necromancer", "black_guard_sentry" }, npcs = { 10440 },
            trash = { "black_guard_sentry", "thuzadin_necromancer" }, elite = true, healer = true },
    },
}

-- WoW: Forever's own dungeons (the beta's first four).
-- The Hall of Thanes beneath Ironforge: restless thanes and Dark Iron looters.
MC.Zones.thanes = {
    id = "thanes", dungeon = true, continent = "ek", region = "dunmorogh", spot = { 0.52, 0.34 },
    min = 13, max = 18, boss = "durgen", tier = 1,
    power = -0.39, heroicPower = 0.11, pool = {}, adds = {}, loot = {}, gear = {},
    encounters = {
        { boss = "faldrim", adds = { "ghostly_attendant", "tormented_soul" }, npcs = { 261306 },
            trash = { "enraged_apparition", "tormented_soul", "ghostly_attendant" } },
        { boss = "magmatus", adds = { "dark_iron_summoner" }, npcs = { 261316 },
            trash = { "dark_iron_looter", "dark_iron_engineer", "dark_iron_summoner" } },
        { boss = "plunder", adds = { "lesser_stone_golem" }, npcs = { 261311 } },
        { boss = "durgen", adds = { "lesser_stone_golem", "lesser_stone_golem", "dark_iron_looter" }, npcs = { 261319 },
            trash = { "dark_iron_looter", "lesser_stone_golem", "dark_iron_summoner" }, elite = true, healer = true },
    },
}

-- The Ruins of Lordaeron above the Undercity, still crawling with the Scourge.
MC.Zones.ruins_lordaeron = {
    id = "ruins_lordaeron", dungeon = true, continent = "ek", region = "tirisfal", spot = { 0.62, 0.72 },
    min = 15, max = 20, boss = "rathmael", tier = 1,
    power = -0.39, heroicPower = -0.08, pool = {}, adds = {}, loot = {}, gear = {},
    encounters = {
        { boss = "witherfang", adds = { "spider", "venom_lurker" }, npcs = { 250483 },
            trash = { "venom_lurker", "spider", "tarantula" } },
        { boss = "thebaron", adds = { "skeletal_soldier", "shrieking_banshee" }, npcs = { 250660 },
            trash = { "skeletal_soldier", "shrieking_banshee", "skeletal_soldier" } },
        { boss = "viktor", adds = { "ghoul", "ragged_ghoul" }, npcs = { 256035 },
            trash = { "ghoul", "ragged_ghoul", "flesh_golem" }, waves = 2 },
        { boss = "abandoned", adds = { "ghoul", "shrieking_banshee" }, npcs = { 250631 },
            trash = { "ragged_ghoul", "shrieking_banshee", "skeletal_soldier" }, elite = true },
        { boss = "lordaeroncaptain", adds = { "skeletal_soldier" }, npcs = { 255699 }, chance = 0.35 },
        { boss = "bjork", adds = { "flesh_golem" }, npcs = { 256097 } },
        { boss = "rathmael", adds = { "skeletal_soldier", "shrieking_banshee", "skeletal_soldier" }, npcs = { 250657 },
            trash = { "flesh_golem", "ghoul", "shrieking_banshee" }, healer = true },
    },
}

-- Excavation Site: Wetlands, Whelgar's dig: raptors in the tall grass, a guardian among the relics.
MC.Zones.excavation = {
    id = "excavation", dungeon = true, continent = "ek", region = "wetlands", spot = { 0.38, 0.5 },
    min = 24, max = 29, boss = "relicguardian", tier = 2,
    power = -0.17, heroicPower = -0.02, pool = {}, adds = {}, loot = {}, gear = {},
    encounters = {
        { boss = "saltspine", adds = { "thicket_lurker" }, npcs = { 260322 },
            trash = { "thicket_lurker", "thicket_matriarch" } },
        { boss = "shadetooth", adds = { "thicket_hunter", "thicket_hunter" }, npcs = { 260325 },
            trash = { "thicket_lurker", "thicket_matriarch", "thicket_hunter" }, waves = 2, elite = true },
        { boss = "highlandhorror", adds = { "thicket_lurker" }, npcs = { 260808 }, chance = 0.35 },
        { boss = "relicguardian", adds = { "thicket_hunter", "thicket_matriarch", "thicket_hunter" }, npcs = { 260326 },
            trash = { "thicket_hunter", "thicket_matriarch" }, healer = true },
    },
}

-- The City of Dalaran: its barrier has fallen, the restored city is not yet under control. Lyn the
-- Ignored waits in the sewers until the Black Tome from Shadowfang Keep calls him (Jaina's task).
MC.Zones.dalaran = {
    id = "dalaran", dungeon = true, continent = "ek", region = "alterac", spot = { 0.18, 0.75 },
    min = 28, max = 33, boss = "archmageshade", tier = 2,
    power = -0.18, heroicPower = 0.06, pool = {}, adds = {}, loot = {}, gear = {},
    encounters = {
        { boss = "atrexis", adds = { "skeletal_warrior", "skeletal_warrior" }, npcs = { 247126 },
            trash = { "saturated_remnant", "mana_phantom", "arcane_manaling" } },
        { boss = "lyn", adds = { "skeletal_warrior", "skeletal_warrior" }, npcs = { 247032 }, hidden = "dalaran_lyn" },
        { boss = "anomaly", adds = { "arcane_manaling", "arcane_manaling" }, npcs = { 245999 },
            trash = { "saturated_remnant", "mana_phantom", "arcane_manaling" } },
        { boss = "enigma", adds = { "mana_phantom", "mana_phantom", "arcane_manaling" }, npcs = { 246016 } },
        { boss = "sentinel", adds = { "angry_tome", "angry_tome" }, npcs = { 246017 },
            trash = { "angry_tome", "saturated_remnant", "mana_wraith" } },
        { boss = "devourer", adds = { "saturated_remnant", "mana_phantom" }, npcs = { 246008 },
            trash = { "saturated_remnant", "mana_wraith", "mana_phantom" }, waves = 2, elite = true },
        { boss = "felancient", adds = { "saturated_remnant" }, npcs = { 246003 } },
        { boss = "archmageshade", adds = { "mana_wraith", "mana_phantom", "mana_wraith" }, npcs = { 246020 },
            trash = { "mana_wraith", "saturated_remnant" }, healer = true },
    },
}

for _, id in ipairs(MC.DUNGEON_ORDER) do
    local zone = MC.Zones[id]
    -- Every creature of the dungeon, for lists that want the zone's foes.
    local seen = {}
    for _, enc in ipairs(zone.encounters) do
        for _, eid in ipairs(enc.trash or {}) do
            if not seen[eid] then
                seen[eid] = true
                zone.pool[#zone.pool + 1] = eid
            end
        end
    end
end

-- How often a boss teaches an unknown formula.
Dungeons.FORMULA_CHANCE = { normal = 0.12, heroic = 0.25 }

-- Dungeons are always open (tasks only reveal hidden bosses).
function Dungeons.IsOpen(store, id)
    local zone = MC.Zones[id]
    return zone ~= nil and zone.dungeon == true
end

-- The encounters on the path: hidden ones only once revealed.
function Dungeons.Encounters(store, id)
    local out = {}
    for i, enc in ipairs(MC.Zones[id].encounters) do
        if not enc.hidden or Quests.Unlocked(store, enc.hidden) then out[#out + 1] = i end
    end
    return out
end

-- The loot of one encounter: { item, chance in % } from the Classic tables of its creatures.
function Dungeons.LootOf(id, encounter)
    local enc = MC.Zones[id].encounters[encounter]
    local out = {}
    for _, npc in ipairs(enc.npcs) do
        for _, boss in ipairs(MC.DungeonLoot[MC.Zones[id].lootFrom or id] or {}) do
            if boss.npc == npc then
                for _, drop in ipairs(boss.drops) do
                    if MC.Items[drop[1]] then out[#out + 1] = { drop[1], drop[2] or 0 } end
                end
            end
        end
    end
    return out
end

local function Roll(rng, pool, count)
    local out = {}
    for i = 1, count do out[i] = pool[Random(rng, #pool)] end
    return out
end

-- The path: one stop per layer, linked straight on.
-- The path: one stop per layer, linked straight on. A hidden boss is a side branch beside a passage:
-- open once its task is done (optional then), locked before - the party walks past it.
-- The wings of a dungeon's group in order (just the dungeon when it has none).
function Dungeons.Wings(id)
    local group = MC.Zones[id].group
    if not group then return { id } end
    local out = {}
    for _, did in ipairs(MC.DUNGEON_ORDER) do
        if MC.Zones[did].group == group then out[#out + 1] = did end
    end
    return out
end

function Dungeons.GenerateMap(rng, store, zone, heroic)
    -- A rare encounter shows up in its share of the runs only.
    local present = {}
    for i, enc in ipairs(zone.encounters) do
        if not enc.chance or Random(rng) < enc.chance then present[#present + 1] = i end
    end
    local last
    for _, i in ipairs(present) do
        if not zone.encounters[i].hidden then last = i end
    end
    local steps = {}
    for _, i in ipairs(present) do
        local enc = zone.encounters[i]
        local waves = enc.trash and (enc.waves or 1) or 0
        for w = 1, waves do
            steps[#steps + 1] = { { kind = enc.elite and w == waves and "elite" or "fight", pool = enc.trash } }
        end
        if enc.healer then steps[#steps + 1] = { { kind = "healer" } } end
        if enc.hidden then
            steps[#steps + 1] = { { kind = "pass" }, { kind = "boss", encounter = i, hidden = enc.hidden } }
        else
            steps[#steps + 1] = { { kind = "boss", encounter = i, final = i == last } }
        end
    end
    local layers = {}
    for l, row in ipairs(steps) do
        local level = Bounty.LayerLevel(zone, heroic, l, #steps)
        layers[l] = {}
        for k, step in ipairs(row) do
            local links = {}
            if steps[l + 1] then
                for j = 1, #steps[l + 1] do links[j] = j end
            end
            local node = { type = step.kind, level = level, links = links }
            if step.kind == "fight" then
                node.enemies = Roll(rng, step.pool, heroic and 4 or 3)
            elseif step.kind == "elite" then
                node.level = math.min(level + 1, Bounty.BossLevel(zone, heroic))
                node.enemies = Roll(rng, step.pool, 4)
            elseif step.kind == "boss" then
                local enc = zone.encounters[step.encounter]
                node.boss, node.encounter, node.final = enc.boss, step.encounter, step.final == true
                node.hidden = step.hidden
                node.locked = step.hidden ~= nil and not Quests.Unlocked(store, step.hidden) or nil
                node.enemies = {}
                if enc.adds[1] then node.enemies[#node.enemies + 1] = enc.adds[1] end
                node.enemies[#node.enemies + 1] = enc.boss
                if enc.adds[2] then node.enemies[#node.enemies + 1] = enc.adds[2] end
                if heroic and enc.adds[3] then node.enemies[#node.enemies + 1] = enc.adds[3] end
            end
            layers[l][k] = node
        end
    end
    return { layers = layers }
end

-- After a boss of a dungeon fell: its loot waits for an owner (store.pendingItems), a formula may be
-- learnt. Both are listed on the run for the result page.
function Dungeons.Loot(store, run, node)
    run.itemsFound = run.itemsFound or {}
    run.recipesFound = run.recipesFound or {}
    for _, drop in ipairs(Dungeons.LootOf(run.zone, node.encounter)) do
        if Random(run) * 100 < drop[2] then
            Bounty.QueueItem(store, drop[1])
            run.itemsFound[#run.itemsFound + 1] = drop[1]
        end
    end
    local zone = MC.Zones[run.zone]
    if Random(run) < Dungeons.FORMULA_CHANCE[run.heroic and "heroic" or "normal"] then
        local unknown = MC.UnknownRecipes(store, (zone.tier or 1) + (run.heroic and 1 or 0))
        if #unknown > 0 then
            local id = unknown[Random(run, #unknown)]
            Bounty.LearnRecipe(store, id)
            run.recipesFound[#run.recipesFound + 1] = id
        end
    end
end
