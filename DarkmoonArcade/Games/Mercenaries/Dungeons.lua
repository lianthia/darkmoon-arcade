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

MC.DUNGEON_ORDER = { "deadmines", "wailing" }

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
