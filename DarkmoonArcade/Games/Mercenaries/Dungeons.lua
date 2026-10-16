-- Dungeons: a fixed path where every boss must fall, trash fights between them and a spirit healer only
-- before the last boss, so they are harder than bounties. A task opens each dungeon (store.unlocks);
-- hidden bosses join the path once their own task is done. Every boss drops Classic's loot with
-- Classic's chances (ItemData.lua: MC.DungeonLoot) and now and then an enchanting formula.
--
-- A dungeon is kept with the zones (MC.Zones[id], dungeon = true) so runs, battles and the result page
-- work as for bounties; it is not in MC.ZONE_ORDER, so bounty lists and achievements leave it out.
--   region      the bounty zone whose map shows its entrance; spot: the entrance in that map (0..1)
--   unlock      the store.unlocks key that opens it
--   encounters  in order: boss, adds, npcs (whose loot it drops), trash before it (elite = an elite
--               fight), healer before it, hidden = the unlock that reveals it
--   tier        the highest formula tier its bosses drop (heroic one more)

local _, ns = ...
local MC = ns.Mercenaries
local Bounty, Quests = MC.Bounty, MC.Quests
local Random = MC.Combat.Random

local Dungeons = {}
MC.Dungeons = Dungeons

MC.DUNGEON_ORDER = { "deadmines" }

MC.Zones.deadmines = {
    id = "deadmines", dungeon = true, continent = "ek", region = "westfall", spot = { 0.42, 0.74 },
    min = 17, max = 26, boss = "vancleef", unlock = "deadmines", tier = 1,
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

function Dungeons.IsOpen(store, id)
    local zone = MC.Zones[id]
    return zone ~= nil and zone.dungeon == true and Quests.Unlocked(store, zone.unlock)
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
function Dungeons.GenerateMap(rng, store, zone, heroic)
    local steps = {}
    local shown = Dungeons.Encounters(store, zone.id)
    for n, i in ipairs(shown) do
        local enc = zone.encounters[i]
        if enc.trash then steps[#steps + 1] = { kind = enc.elite and "elite" or "fight", pool = enc.trash } end
        if enc.healer then steps[#steps + 1] = { kind = "healer" } end
        steps[#steps + 1] = { kind = "boss", encounter = i, final = n == #shown }
    end
    local layers = {}
    for l, step in ipairs(steps) do
        local level = Bounty.LayerLevel(zone, heroic, l, #steps)
        local node = { type = step.kind, level = level, links = l < #steps and { 1 } or {} }
        if step.kind == "fight" then
            node.enemies = Roll(rng, step.pool, heroic and 4 or 3)
        elseif step.kind == "elite" then
            node.level = math.min(level + 1, Bounty.BossLevel(zone, heroic))
            node.enemies = Roll(rng, step.pool, 4)
        elseif step.kind == "boss" then
            local enc = zone.encounters[step.encounter]
            node.boss, node.encounter, node.final = enc.boss, step.encounter, step.final
            node.enemies = {}
            if enc.adds[1] then node.enemies[#node.enemies + 1] = enc.adds[1] end
            node.enemies[#node.enemies + 1] = enc.boss
            if enc.adds[2] then node.enemies[#node.enemies + 1] = enc.adds[2] end
            if heroic and enc.adds[3] then node.enemies[#node.enemies + 1] = enc.adds[3] end
        end
        layers[l] = { node }
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
