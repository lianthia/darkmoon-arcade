-- Dungeons: a fixed path where every boss must fall, trash fights between them and a spirit healer only
-- before the last boss, so they are harder than bounties. Dungeons are always open; a hidden boss waits
-- on a side branch that its task opens (store.unlocks) - before, the party walks past it. Every boss drops Classic's loot with
-- Classic's chances (ItemData.lua: MC.DungeonLoot) and now and then an enchanting formula.
--
-- A dungeon is kept with the zones (MC.Zones[id], dungeon = true) so runs, battles and the result page
-- work as for bounties; it is not in MC.ZONE_ORDER, so bounty lists and achievements leave it out.
--   region      the bounty zone whose map shows its entrance; spot: the entrance in that map (0..1)
--   encounters  in order: boss, adds, npcs (whose loot it drops), trash before it (elite = an elite
--               fight), healer before it, hidden = the unlock that reveals it, chance = a rare one that
--               shows up in that share of the runs (as Classic's rare spawns)
--   tier        the highest formula tier its bosses drop (heroic one more)

local _, ns = ...
local MC = ns.Mercenaries
local Bounty, Quests = MC.Bounty, MC.Quests
local Random = MC.Combat.Random

local Dungeons = {}
MC.Dungeons = Dungeons

MC.DUNGEON_ORDER = { "ragefire", "deadmines", "wailing", "shadowfang", "blackfathom", "stockade", "gnomeregan", "kraul" }

MC.Zones.deadmines = {
    id = "deadmines", dungeon = true, continent = "ek", region = "westfall", spot = { 0.42, 0.74 },
    min = 17, max = 26, boss = "vancleef", tier = 1,
    power = 0.1, heroicPower = 0.1, pool = {}, adds = {}, loot = {}, gear = {},
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
    min = 17, max = 24, boss = "verdan", tier = 1,
    power = 0.1, heroicPower = 0.1, pool = {}, adds = {}, loot = {}, gear = {},
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
    power = 0.1, heroicPower = 0.1, pool = {}, adds = {}, loot = {}, gear = {},
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
    power = 0.1, heroicPower = 0.1, pool = {}, adds = {}, loot = {}, gear = {},
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
    power = 0.1, heroicPower = 0.1, pool = {}, adds = {}, loot = {}, gear = {},
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
    min = 24, max = 32, boss = "bazil", tier = 2,
    power = 0.1, heroicPower = 0.1, pool = {}, adds = {}, loot = {}, gear = {},
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
    power = 0.1, heroicPower = 0.1, pool = {}, adds = {}, loot = {}, gear = {},
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
    min = 29, max = 38, boss = "charlga", tier = 2,
    power = 0.1, heroicPower = 0.1, pool = {}, adds = {}, loot = {}, gear = {},
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
        for _, boss in ipairs(MC.DungeonLoot[id] or {}) do
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
        if enc.trash then steps[#steps + 1] = { { kind = enc.elite and "elite" or "fight", pool = enc.trash } } end
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
