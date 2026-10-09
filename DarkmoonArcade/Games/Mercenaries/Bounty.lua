-- Bounties and progress: a zone is a bounty, a path of stops that ends at its boss. This file owns
-- the run (map, party, treasures, rewards) and the collection (levels, coins, ranks, equipment).
-- Everything lives in plain tables inside the game's saved settings.

local _, ns = ...
ns.Mercenaries = ns.Mercenaries or {}
local MC = ns.Mercenaries

local Combat = MC.Combat
local Random = Combat.Random

local Bounty = {}
MC.Bounty = Bounty

Bounty.PARTY_SIZE = 6
Bounty.HEROIC_LEVEL = 60
Bounty.RECRUIT_COST = 50
Bounty.RANK_COST = { [2] = 30, [3] = 80 }
Bounty.NODE_WEIGHTS = { { "fight", 50 }, { "elite", 14 }, { "healer", 9 }, { "boon", 12 }, { "mystery", 15 } }
Bounty.MYSTERIES = { "stranger", "sabotage", "portal", "cursed", "bonus", "recruit" }
Bounty.ROLES = { "protector", "fighter", "caster" }

local function Copy(list)
    local out = {}
    for i, v in ipairs(list) do out[i] = v end
    return out
end

local function AddMods(target, mods)
    for k, v in pairs(mods) do
        if type(v) == "boolean" then
            target[k] = target[k] or v
        else
            target[k] = (target[k] or 0) + v
        end
    end
end
Bounty.AddMods = AddMods

-- Collection ------------------------------------------------------------------------------------

function Bounty.NewEntry(owned)
    return { owned = owned, level = 1, xp = 0, coins = 0, ranks = { 1, 1, 1 }, gear = 1, gears = { true, false, false } }
end

function Bounty.Entry(store, id)
    local entry = store.mercs[id]
    if not entry then
        entry = Bounty.NewEntry(false)
        store.mercs[id] = entry
    end
    return entry
end

-- Fills in a fresh collection and repairs a party that lost members.
function Bounty.Init(store)
    store.mercs = store.mercs or {}
    store.zones = store.zones or {}
    for _, id in ipairs(MC.STARTERS) do
        local entry = Bounty.Entry(store, id)
        entry.owned = true
    end
    local party, seen = {}, {}
    for _, id in ipairs(store.party or MC.STARTERS) do
        if MC.Mercs[id] and store.mercs[id] and store.mercs[id].owned and not seen[id] and #party < Bounty.PARTY_SIZE then
            party[#party + 1] = id
            seen[id] = true
        end
    end
    for _, id in ipairs(MC.MERC_ORDER) do
        if #party >= Bounty.PARTY_SIZE then break end
        if store.mercs[id] and store.mercs[id].owned and not seen[id] then
            party[#party + 1] = id
            seen[id] = true
        end
    end
    store.party = party
end

function Bounty.XPNeeded(level)
    return math.floor(40 * level ^ 1.35 + 0.5)
end

-- Returns how many levels were gained.
function Bounty.AddXP(entry, xp)
    if entry.level >= MC.MAX_LEVEL then return 0 end
    entry.xp = entry.xp + math.floor(xp + 0.5)
    local gained = 0
    while entry.level < MC.MAX_LEVEL and entry.xp >= Bounty.XPNeeded(entry.level) do
        entry.xp = entry.xp - Bounty.XPNeeded(entry.level)
        entry.level = entry.level + 1
        gained = gained + 1
    end
    if entry.level >= MC.MAX_LEVEL then entry.xp = 0 end
    return gained
end

function Bounty.UnlockedAbilities(level)
    local n = 0
    for i, need in ipairs(MC.ABILITY_LEVELS) do
        if level >= need then n = i end
    end
    return n
end

function Bounty.CanRecruit(store, id)
    local entry = store.mercs[id]
    return entry ~= nil and not entry.owned and entry.coins >= Bounty.RECRUIT_COST
end

function Bounty.Recruit(store, id)
    if not Bounty.CanRecruit(store, id) then return false end
    local entry = store.mercs[id]
    entry.coins = entry.coins - Bounty.RECRUIT_COST
    entry.owned = true
    return true
end

function Bounty.RankCost(entry, slot)
    return Bounty.RANK_COST[(entry.ranks[slot] or 1) + 1]
end

function Bounty.CanRankUp(store, id, slot)
    local entry = store.mercs[id]
    if not entry or not entry.owned or Bounty.UnlockedAbilities(entry.level) < slot then return false end
    local cost = Bounty.RankCost(entry, slot)
    return cost ~= nil and entry.coins >= cost
end

function Bounty.RankUp(store, id, slot)
    if not Bounty.CanRankUp(store, id, slot) then return false end
    local entry = store.mercs[id]
    entry.coins = entry.coins - Bounty.RankCost(entry, slot)
    entry.ranks[slot] = entry.ranks[slot] + 1
    return true
end

function Bounty.SetGear(store, id, index)
    local entry = store.mercs[id]
    if not entry or not entry.gears[index] then return false end
    entry.gear = index
    return true
end

-- Swaps a party slot; returns false for mercenaries not owned or already in the party.
function Bounty.SetPartySlot(store, slot, id)
    local entry = store.mercs[id]
    if not entry or not entry.owned or store.run then return false end
    for i, other in ipairs(store.party) do
        if other == id then
            store.party[i] = store.party[slot]
            store.party[slot] = id
            return true
        end
    end
    store.party[slot] = id
    return true
end

-- The progress entry behind a party member: the collection's, or a guest's own for this run.
function Bounty.MemberEntry(store, member)
    return member.guest or store.mercs[member.id]
end

function Bounty.PartyLevel(store)
    local sum = 0
    for _, id in ipairs(store.party) do sum = sum + store.mercs[id].level end
    return #store.party > 0 and sum / #store.party or 1
end

-- Units for combat --------------------------------------------------------------------------------

function Bounty.MercSpec(store, id, member, run)
    local def = MC.Mercs[id]
    local entry = member and member.guest or store.mercs[id]
    local mods = {}
    local gear = def.gear[entry.gear or 1]
    if gear then AddMods(mods, gear.mods) end
    if member then
        for _, t in ipairs(member.treasures) do AddMods(mods, MC.Treasures[t].mods) end
    end
    if run then
        local tier = run.boons[def.role] or 0
        if tier > 0 then AddMods(mods, { atkPct = 0.1 * tier, hpPct = 0.1 * tier }) end
        if (run.curse or 0) > 0 then AddMods(mods, { hpPct = -MC.CURSE_HEALTH * run.curse }) end
    end
    local abilities = {}
    for i = 1, Bounty.UnlockedAbilities(entry.level) do
        abilities[i] = { id = def.abilities[i], rank = entry.ranks[i] or 1 }
    end
    return {
        id = id, kind = "merc", role = def.role, race = def.race, level = entry.level,
        atk = def.atk, hp = def.hp, abilities = abilities, mods = mods,
    }
end

-- Overall strength of the foes, tuned with tools/balance_mercenaries.py.
-- Zones add their own `power` on top, so every bounty is about as hard at its boss level.
Bounty.ENEMY_MODS = { hpPct = 0.3, atkPct = 0.2 }
Bounty.BOSS_MODS = { hpPct = 0.3, atkPct = 0.2 }
Bounty.HEROIC_MODS = { hpPct = 0, atkPct = 0 }

-- opts: elite, heroic, sabotage, power
function Bounty.EnemySpec(id, level, opts)
    local def = MC.Enemies[id]
    opts = opts or {}
    local mods = {}
    AddMods(mods, Bounty.ENEMY_MODS)
    if opts.power then AddMods(mods, { hpPct = opts.power, atkPct = opts.power * 0.6 }) end
    if def.boss then AddMods(mods, Bounty.BOSS_MODS) end
    if opts.heroic then AddMods(mods, Bounty.HEROIC_MODS) end
    if opts.elite and not def.boss then AddMods(mods, { hpPct = 0.35, atkPct = 0.2 }) end
    if opts.sabotage then AddMods(mods, { hpPct = -0.3 }) end
    local abilities = {}
    for i, aid in ipairs(def.abilities) do abilities[i] = { id = aid, rank = 1 } end
    if opts.heroic and def.heroic then abilities[#abilities + 1] = { id = def.heroic, rank = 1 } end
    local kind = def.boss and "boss" or (opts.elite and "elite" or "enemy")
    return {
        id = id, kind = kind, role = def.role, race = def.race, level = level,
        atk = def.atk, hp = def.hp, abilities = abilities, mods = mods,
    }
end

-- The map ----------------------------------------------------------------------------------------------

function Bounty.LayerCount(zone, heroic)
    if heroic then return 9 end
    if zone.max <= 12 then return 5 end
    if zone.min < 45 then return 7 end
    return 9
end

-- Foes climb from the zone's lowest level to its boss, who stands a little past the middle of the
-- range: a party that levelled through the zone's lower half is ready for it.
Bounty.BOSS_SHARE = 0.6

function Bounty.BossLevel(zone, heroic)
    if heroic then return Bounty.HEROIC_LEVEL end
    return math.floor(zone.min + (zone.max - zone.min) * Bounty.BOSS_SHARE + 0.5)
end

function Bounty.LayerLevel(zone, heroic, layer, layers)
    if heroic then return Bounty.HEROIC_LEVEL end
    local top = Bounty.BossLevel(zone, heroic)
    return math.floor(zone.min + (top - zone.min) * (layer - 1) / (layers - 1) + 0.5)
end

local function Weighted(rng, list)
    local total = 0
    for _, entry in ipairs(list) do total = total + entry[2] end
    local roll = Random(rng) * total
    for _, entry in ipairs(list) do
        roll = roll - entry[2]
        if roll <= 0 then return entry[1] end
    end
    return list[#list][1]
end

local function RollEnemies(rng, zone, count)
    local pool, out = Copy(zone.pool), {}
    for i = 1, count do
        if #pool == 0 then pool = Copy(zone.pool) end
        out[i] = table.remove(pool, Random(rng, #pool))
    end
    return out
end

local function BossParty(zone, heroic)
    local adds = zone.adds or {}
    local out = {}
    if adds[1] then out[#out + 1] = adds[1] end
    out[#out + 1] = zone.boss
    if adds[2] then out[#out + 1] = adds[2] end
    if heroic and (adds[3] or adds[1]) then out[#out + 1] = adds[3] or adds[1] end
    return out
end

local function NewNode(rng, zone, heroic, kind, level)
    local node = { type = kind, level = level, links = {} }
    if kind == "fight" then
        node.enemies = RollEnemies(rng, zone, 3)
    elseif kind == "elite" then
        node.level = math.min(level + 1, Bounty.BossLevel(zone, heroic))
        node.enemies = RollEnemies(rng, zone, 4)
    elseif kind == "boss" then
        node.enemies = BossParty(zone, heroic)
    elseif kind == "boon" then
        node.role = Bounty.ROLES[Random(rng, 3)]
    elseif kind == "mystery" then
        node.mystery = Bounty.MYSTERIES[Random(rng, #Bounty.MYSTERIES)]
    end
    return node
end

-- Layers of two or three stops, each linked to its neighbours above; the last layer is the boss.
function Bounty.GenerateMap(rng, zone, heroic)
    local count = Bounty.LayerCount(zone, heroic)
    local layers = {}
    for l = 1, count do
        local level = Bounty.LayerLevel(zone, heroic, l, count)
        local row = {}
        if l == count then
            row[1] = NewNode(rng, zone, heroic, "boss", level)
        else
            local width = Random(rng, 2) + 1
            for i = 1, width do
                local kind = l == 1 and "fight" or Weighted(rng, Bounty.NODE_WEIGHTS)
                row[i] = NewNode(rng, zone, heroic, kind, level)
            end
            -- A spirit healer waits right before the boss.
            if l == count - 1 and width > 1 then
                row[Random(rng, width)] = NewNode(rng, zone, heroic, "healer", level)
            end
        end
        layers[l] = row
    end
    for l = 1, count - 1 do
        local row, nextRow = layers[l], layers[l + 1]
        local incoming = {}
        for i, node in ipairs(row) do
            local j = #row == 1 and 1 or math.floor((i - 1) * (#nextRow - 1) / (#row - 1) + 0.5) + 1
            node.links[#node.links + 1] = j
            incoming[j] = true
            local extra = j + (Random(rng) < 0.5 and -1 or 1)
            if nextRow[extra] and Random(rng) < 0.45 then
                node.links[#node.links + 1] = extra
                incoming[extra] = true
            end
        end
        for j = 1, #nextRow do
            if not incoming[j] then
                local i = math.max(1, math.min(#row, math.floor((j - 1) * (#row - 1) / math.max(1, #nextRow - 1) + 0.5) + 1))
                row[i].links[#row[i].links + 1] = j
            end
        end
        for _, node in ipairs(row) do table.sort(node.links) end
    end
    return { layers = layers }
end

-- Runs ---------------------------------------------------------------------------------------------------

function Bounty.ZoneState(store, zoneId)
    store.zones[zoneId] = store.zones[zoneId] or { normal = 0, heroic = 0 }
    return store.zones[zoneId]
end

function Bounty.HeroicUnlocked(store, zoneId)
    return Bounty.ZoneState(store, zoneId).normal > 0
end

function Bounty.NewRun(store, zoneId, heroic, seed)
    local zone = MC.Zones[zoneId]
    if not zone or (heroic and not Bounty.HeroicUnlocked(store, zoneId)) then return nil end
    local run = {
        zone = zoneId, heroic = heroic or false, rng = Combat.Seed(seed),
        layer = 0, index = nil, phase = "map",
        party = {}, boons = {}, curse = 0, fights = 0, score = 0, xp = 0, visited = {},
    }
    -- Levels at the start, so the result can show every level gained on the way.
    run.startLevels = {}
    for _, id in ipairs(store.party) do
        run.party[#run.party + 1] = { id = id, dead = false, treasures = {} }
        run.startLevels[id] = Bounty.Entry(store, id).level
    end
    run.map = Bounty.GenerateMap(run, zone, heroic)
    store.run = run
    return run
end

function Bounty.Node(run, layer, index)
    local row = run.map.layers[layer or run.layer]
    return row and row[index or run.index]
end

-- The stops the party may travel to next.
function Bounty.Choices(run)
    local out = {}
    if run.phase ~= "map" then return out end
    local layers = run.map.layers
    if run.layer == 0 or run.portal then
        local target = run.portal and math.min(run.layer + 2, #layers) or 1
        for i = 1, #layers[target] do out[#out + 1] = { layer = target, index = i } end
        return out
    end
    for _, j in ipairs(Bounty.Node(run).links) do out[#out + 1] = { layer = run.layer + 1, index = j } end
    return out
end

function Bounty.AliveMembers(run)
    local list = {}
    for i, member in ipairs(run.party) do
        if not member.dead then list[#list + 1] = i end
    end
    return list
end

function Bounty.DeadMembers(run)
    local list = {}
    for i, member in ipairs(run.party) do
        if member.dead then list[#list + 1] = i end
    end
    return list
end

local function StartBattle(store, run, node)
    local allies = {}
    for idx, member in ipairs(run.party) do
        if not member.dead then
            local spec = Bounty.MercSpec(store, member.id, member, run)
            spec.pidx = idx
            allies[#allies + 1] = spec
        end
    end
    local enemies = {}
    local zone = MC.Zones[run.zone]
    local power = run.heroic and zone.heroicPower or zone.power
    local opts = { elite = node.type == "elite", heroic = run.heroic, sabotage = run.sabotage, power = power }
    for i, id in ipairs(node.enemies) do enemies[i] = Bounty.EnemySpec(id, node.level, opts) end
    run.sabotage = nil
    run.battle = Combat.New(allies, enemies, Random(run, 1000000000))
    run.phase = "battle"
end

local function GiveTreasure(store, run, memberIdx, id)
    local member = run.party[memberIdx]
    member.treasures[#member.treasures + 1] = id
end

-- Whether a treasure would do anything for this mercenary.
function Bounty.TreasureFits(store, treasure, mercId, member)
    local need = treasure.needs
    if not need then return true end
    local def, entry = MC.Mercs[mercId], member and member.guest or store.mercs[mercId]
    local unlocked = Bounty.UnlockedAbilities(entry.level)
    if type(need) == "number" then return unlocked >= need end
    for i = 1, unlocked do
        local ability = MC.Abilities[def.abilities[i]]
        for _, e in ipairs(ability.effects) do
            local kind = e[1]
            if need == "attack" and kind == "attack" then return true end
            if need == "damage" and (kind == "attack" or kind == "damage" or kind == "dot") then return true end
            if need == "heal" and (kind == "heal" or kind == "hot") then return true end
            if (kind == "damage" or kind == "dot") and (e.school or ability.school) == need then return true end
            if need == "physical" and kind == "attack" then return true end
        end
        if need == "cooldown" and (ability.cd or 0) > 0 then return true end
    end
    return false
end

function Bounty.RollTreasures(store, run, memberIdx, elite, count)
    local mercId = run.party[memberIdx].id
    local pool = {}
    for _, id in ipairs(MC.TREASURE_ORDER) do
        local t = MC.Treasures[id]
        if not t.cursed and (t.elite or false) == (elite or false) and Bounty.TreasureFits(store, t, mercId, run.party[memberIdx]) then
            pool[#pool + 1] = id
        end
    end
    local out = {}
    for i = 1, count do
        if #pool == 0 then break end
        out[i] = table.remove(pool, Random(run, #pool))
    end
    -- Elite pools are small; top them up from the regular treasures.
    if elite and #out < count then
        local more = Bounty.RollTreasures(store, run, memberIdx, false, count - #out)
        for _, id in ipairs(more) do out[#out + 1] = id end
    end
    return out
end

local function OfferTreasure(store, run, elite, kind)
    local alive = Bounty.AliveMembers(run)
    if #alive == 0 then
        run.phase = "map"
        return
    end
    local memberIdx = alive[Random(run, #alive)]
    local options
    if kind == "cursed" then
        options = { "cursedblade", "cursedmail", "cursedrelic" }
    else
        options = Bounty.RollTreasures(store, run, memberIdx, elite, 3)
    end
    run.offer = { kind = kind or "treasure", member = memberIdx, options = options }
    run.phase = "treasure"
end

function Bounty.BoonTier(run)
    local zone = MC.Zones[run.zone]
    local level = run.heroic and Bounty.HEROIC_LEVEL or zone.max
    if level <= 10 then return 1 end
    if level <= 20 then return 2 end
    return 3
end

local function Visit(store, run, node)
    run.visited[#run.visited + 1] = run.layer .. ":" .. run.index
    local kind = node.type
    if kind == "fight" or kind == "elite" or kind == "boss" then
        StartBattle(store, run, node)
    elseif kind == "healer" then
        run.phase = #Bounty.DeadMembers(run) > 0 and "healer" or "map"
    elseif kind == "boon" then
        run.boons[node.role] = (run.boons[node.role] or 0) + Bounty.BoonTier(run)
        run.phase = "map"
    elseif kind == "mystery" then
        local m = node.mystery
        if m == "stranger" then
            if #Bounty.StrangerOptions(run) > 0 then
                run.phase = "stranger"
            else
                OfferTreasure(store, run, false)
            end
        elseif m == "sabotage" then
            run.sabotage = true
            run.phase = "map"
        elseif m == "portal" then
            run.portal = true
            run.phase = "map"
        elseif m == "cursed" then
            OfferTreasure(store, run, false, "cursed")
        elseif m == "recruit" then
            run.guestJoined = Bounty.AddGuest(store, run)
            run.phase = "map"
        else
            run.bonusLoot = true
            run.phase = "map"
        end
    end
end

-- A mercenary from outside the party joins for the rest of this bounty, at the party's level.
-- Mercenaries not yet recruited come first, so the guest is a chance to try one. One guest per run.
function Bounty.AddGuest(store, run)
    for _, member in ipairs(run.party) do
        if member.guest then return nil end
    end
    local taken = {}
    for _, member in ipairs(run.party) do taken[member.id] = true end
    local fresh, known = {}, {}
    for _, id in ipairs(MC.MERC_ORDER) do
        if not taken[id] then
            local entry = store.mercs[id]
            if entry and entry.owned then known[#known + 1] = id else fresh[#fresh + 1] = id end
        end
    end
    local pool = #fresh > 0 and fresh or known
    if #pool == 0 then return nil end
    local id = pool[Random(run, #pool)]
    local level = math.max(1, math.floor(Bounty.PartyLevel(store) + 0.5))
    run.party[#run.party + 1] = { id = id, dead = false, treasures = {},
        guest = { level = level, gear = 1, ranks = { 1, 1, 1 }, gears = { true, false, false } } }
    return id
end

function Bounty.Travel(store, run, layer, index)
    for _, choice in ipairs(Bounty.Choices(run)) do
        if choice.layer == layer and choice.index == index then
            run.layer, run.index, run.portal = layer, index, nil
            Visit(store, run, Bounty.Node(run))
            return true
        end
    end
    return false
end

-- Experience for a won fight: higher foes give more, foes far below give next to nothing.
function Bounty.FightXP(node, level)
    local base = 20 + 12 * node.level
    if node.type == "elite" then base = base * 1.5 end
    if node.type == "boss" then base = base * 3 end
    local over = level - node.level
    if over > 10 then return 0 end
    if over > 5 then return base * 0.25 end
    return base
end

function Bounty.FightScore(run, node)
    local score = node.level * 10
    if node.type == "elite" then score = score * 1.5 end
    if node.type == "boss" then score = score * 3 end
    if run.heroic then score = score * 2 end
    return math.floor(score)
end

local function Complete(store, run)
    local zone = MC.Zones[run.zone]
    local key = run.heroic and "heroic" or "normal"
    local state = Bounty.ZoneState(store, run.zone)
    local first = state[key] == 0
    state[key] = state[key] + 1
    local rewards = { coins = {}, first = first }
    local function Give(id, amount)
        amount = math.floor(amount * (run.bonusLoot and 1.5 or 1) + 0.5)
        Bounty.Entry(store, id).coins = Bounty.Entry(store, id).coins + amount
        rewards.coins[id] = (rewards.coins[id] or 0) + amount
    end
    for _, member in ipairs(run.party) do
        if not member.guest then Give(member.id, run.heroic and 10 or 5) end
    end
    for _, id in ipairs(zone.loot) do Give(id, (run.heroic and 25 or 12) * (first and 2 or 1)) end
    local gearMerc = zone.gear and zone.gear[key]
    if gearMerc then
        local entry = Bounty.Entry(store, gearMerc)
        local slot = run.heroic and 3 or 2
        if not entry.gears[slot] then
            entry.gears[slot] = true
            rewards.gear = { merc = gearMerc, slot = slot }
        end
    end
    run.rewards = rewards
    run.phase = "complete"
end

-- Called once the battle reached "won" or "lost".
function Bounty.AfterBattle(store, run)
    local b = run.battle
    if not b or (b.phase ~= "won" and b.phase ~= "lost") then return false end
    for _, u in pairs(b.units) do
        if u.side == "ally" and u.pidx then run.party[u.pidx].dead = u.dead end
    end
    run.battle = nil
    local node = Bounty.Node(run)
    if b.phase == "lost" then
        run.phase = "lost"
        return true
    end
    run.fights = run.fights + 1
    run.score = run.score + Bounty.FightScore(run, node)
    run.levelUps = {}
    for _, member in ipairs(run.party) do
        if not member.guest then
            local entry = store.mercs[member.id]
            local xp = Bounty.FightXP(node, entry.level)
            run.xp = run.xp + xp
            if Bounty.AddXP(entry, xp) > 0 then run.levelUps[#run.levelUps + 1] = member.id end
            entry.coins = entry.coins + 1
        end
    end
    if node.type == "boss" then
        Complete(store, run)
    else
        OfferTreasure(store, run, node.type == "elite")
    end
    return true
end

-- `choice` is the index into the offer; nil declines (allowed for cursed offers only).
function Bounty.ChooseTreasure(store, run, choice)
    local offer = run.offer
    if run.phase ~= "treasure" or not offer then return false end
    if choice then
        local id = offer.options[choice]
        if not id then return false end
        GiveTreasure(store, run, offer.member, id)
        if offer.kind == "cursed" then run.curse = run.curse + 1 end
    elseif offer.kind ~= "cursed" then
        return false
    end
    run.offer = nil
    run.phase = "map"
    return true
end

function Bounty.Revive(run, memberIdx)
    if run.phase ~= "healer" then return false end
    local member = memberIdx and run.party[memberIdx]
    if member then
        if not member.dead then return false end
        member.dead = false
    elseif #Bounty.DeadMembers(run) > 0 then
        return false -- someone has to be brought back
    end
    run.phase = "map"
    return true
end

-- The stranger copies one treasure a mercenary already carries.
function Bounty.StrangerOptions(run)
    local out = {}
    for i, member in ipairs(run.party) do
        if not member.dead then
            for j, t in ipairs(member.treasures) do out[#out + 1] = { member = i, treasure = t, slot = j } end
        end
    end
    return out
end

function Bounty.Stranger(run, option)
    if run.phase ~= "stranger" then return false end
    local pick = Bounty.StrangerOptions(run)[option]
    if pick then
        local member = run.party[pick.member]
        member.treasures[#member.treasures + 1] = pick.treasure
    end
    run.phase = "map"
    return true
end

function Bounty.Abandon(store, run)
    run.phase = "lost"
    run.battle = nil
end

-- Clears the finished run from the store.
function Bounty.EndRun(store)
    store.run = nil
end
