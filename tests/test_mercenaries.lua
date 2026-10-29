local MC = ns.Mercenaries
local Combat, Bounty = MC.Combat, MC.Bounty
local passed, failed = 0, 0

local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
    else
        failed = failed + 1
        print("FAIL " .. name .. ": " .. tostring(err))
    end
end

local function eq(a, b, msg)
    if a ~= b then error((msg or "") .. " expected " .. tostring(b) .. ", got " .. tostring(a), 2) end
end

local function DeepEqual(a, b, path)
    path = path or "root"
    if type(a) ~= type(b) then error(path .. ": " .. type(a) .. " vs " .. type(b), 0) end
    if type(a) ~= "table" then
        if a ~= b then error(path .. ": " .. tostring(a) .. " vs " .. tostring(b), 0) end
        return
    end
    for k, v in pairs(a) do DeepEqual(v, b[k], path .. "." .. tostring(k)) end
    for k in pairs(b) do
        if a[k] == nil then error(path .. "." .. tostring(k) .. " missing", 0) end
    end
end

local function Copy(t)
    if type(t) ~= "table" then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = Copy(v) end
    return out
end

local function Spec(id, role, level, abilities, extra)
    local spec = { id = id, role = role, level = level or 10, atk = 10, hp = 100, abilities = abilities or { { id = "e_strike" } }, mods = {} }
    for k, v in pairs(extra or {}) do spec[k] = v end
    return spec
end

local function NewStore()
    local store = {}
    Bounty.Init(store)
    return store
end

-- Lets the bot play a battle out: deploys the first mercenaries and picks like the enemy does.
local function AutoBattle(b)
    local guard = 0
    while (b.phase == "deploy" or b.phase == "replace" or b.phase == "command") and guard < 200 do
        guard = guard + 1
        if b.phase == "command" then
            Combat.AutoChoose(b)
            Combat.Resolve(b)
        else
            Combat.Deploy(b, b.bench.ally[1])
        end
    end
    return b.phase
end

test("data references resolve", function()
    for id, merc in pairs(MC.Mercs) do
        for i, aid in ipairs(merc.abilities) do assert(MC.Abilities[aid], id .. " ability " .. i) end
        eq(#merc.gear, 3, id .. " gear")
        assert(merc.display and merc.display > 0, id .. " display")
    end
    for id, enemy in pairs(MC.Enemies) do
        for _, aid in ipairs(enemy.abilities) do assert(MC.Abilities[aid], id .. " " .. aid) end
        if enemy.heroic then assert(MC.Abilities[enemy.heroic], id .. " heroic") end
    end
    local normalGear, heroicGear = {}, {}
    for _, zid in ipairs(MC.ZONE_ORDER) do
        local zone = MC.Zones[zid]
        assert(zone, zid)
        assert(MC.Enemies[zone.boss] and MC.Enemies[zone.boss].boss, zid .. " boss")
        for _, e in ipairs(zone.pool) do assert(MC.Enemies[e], zid .. " pool " .. e) end
        for _, e in ipairs(zone.adds) do assert(MC.Enemies[e], zid .. " add " .. e) end
        for _, m in ipairs(zone.loot) do assert(MC.Mercs[m], zid .. " loot " .. m) end
        -- Not every zone drops equipment; those that do drop each piece only once.
        local gn, gh = zone.gear.normal, zone.gear.heroic
        if gn then
            assert(not normalGear[gn], "normal gear twice: " .. gn)
            normalGear[gn] = true
        end
        if gh then
            assert(not heroicGear[gh], "heroic gear twice: " .. gh)
            heroicGear[gh] = true
        end
    end
    for id in pairs(MC.Mercs) do
        assert(normalGear[id] and heroicGear[id], id .. " has no gear drop")
    end
    for _, effectList in pairs(MC.Abilities) do
        for _, e in ipairs(effectList.effects) do assert(Combat.EFFECTS[e[1]], "unknown effect " .. tostring(e[1])) end
    end
end)

test("first abilities never have a cooldown", function()
    for id, merc in pairs(MC.Mercs) do eq(MC.Abilities[merc.abilities[1]].cd, 0, id) end
end)

test("random numbers are reproducible", function()
    local a, b = { rng = Combat.Seed(42) }, { rng = Combat.Seed(42) }
    for _ = 1, 20 do eq(Combat.Random(a, 100), Combat.Random(b, 100)) end
    local c = { rng = Combat.Seed(7) }
    for _ = 1, 1000 do
        local r = Combat.Random(c)
        assert(r >= 0 and r < 1, "range")
    end
end)

test("role advantage doubles damage", function()
    local b = Combat.New({ Spec("a", "protector") }, { Spec("f", "fighter"), Spec("c", "caster") }, 3)
    local a = b.units[b.bench.ally[1]]
    local f, c = b.units[b.board.enemy[1]], b.units[b.board.enemy[2]]
    local d1 = Combat.Damage({ b = b }, a, f, 10, "physical")
    local d2 = Combat.Damage({ b = b }, a, c, 10, "physical")
    eq(d1, 20, "vs fighter")
    eq(d2, 10, "vs caster")
end)

test("higher targets dodge and shrug off hits", function()
    local low = { level = 10 }
    eq(Combat.MissChance(low, { level = 10 }), 0)
    assert(Combat.MissChance(low, { level = 15 }) > 0.3, "5 levels")
    assert(Combat.MissChance(low, { level = 25 }) >= 0.85, "15 levels")
end)

test("divine shield absorbs one hit", function()
    local b = Combat.New({ Spec("a", "neutral") }, { Spec("e", "neutral") }, 5)
    local a, e = b.units[b.bench.ally[1]], b.units[b.board.enemy[1]]
    e.st.shield = true
    eq(Combat.Damage({ b = b }, a, e, 10, "fire"), 0)
    assert(not e.st.shield, "shield gone")
    eq(Combat.Damage({ b = b }, a, e, 10, "fire"), 10)
end)

test("taunt forces single targets, stealth hides", function()
    local b = Combat.New({ Spec("a", "neutral") }, { Spec("e1", "neutral"), Spec("e2", "neutral"), Spec("e3", "neutral") }, 9)
    local e1, e2, e3 = b.units[b.board.enemy[1]], b.units[b.board.enemy[2]], b.units[b.board.enemy[3]]
    eq(#Combat.Targetable(b, "enemy"), 3)
    e2.st.stealth = true
    eq(#Combat.Targetable(b, "enemy"), 2)
    e3.st.taunt = 1
    local list = Combat.Targetable(b, "enemy")
    eq(#list, 1)
    eq(list[1], e3)
    assert(e1, "unused")
end)

test("abilities resolve by speed, lowest first", function()
    local fast = { { id = "renzik_1" } } -- speed 3
    local slow = { { id = "sylvanas_1" } } -- speed 7
    local b = Combat.New({ Spec("slow", "neutral", 10, slow), Spec("fast", "neutral", 10, fast) }, { Spec("e", "neutral", 10, { { id = "e_slam" } }) }, 11)
    Combat.Deploy(b, b.bench.ally[1])
    Combat.Deploy(b, b.bench.ally[1])
    eq(b.phase, "command")
    local enemy = b.board.enemy[1]
    for _, uid in ipairs(b.board.ally) do assert(Combat.SetChoice(b, uid, 1, enemy), "choice") end
    local events = Combat.Resolve(b)
    local order = events[1]
    eq(order.t, "order")
    for i = 2, #order.list do assert(order.list[i - 1].speed <= order.list[i].speed, "sorted") end
    eq(b.units[order.list[1].uid].id, "fast")
end)

test("cooldowns block abilities for their turns", function()
    local b = Combat.New({ Spec("a", "neutral", 10, { { id = "e_strike" }, { id = "renzik_2" } }) }, { Spec("e", "neutral", 10, nil, { hp = 900 }) }, 13)
    Combat.Deploy(b, b.bench.ally[1])
    local a = b.units[b.board.ally[1]]
    local enemy = b.board.enemy[1]
    assert(not Combat.Available(a, 2), "starts on cooldown")
    for _ = 1, 3 do
        Combat.SetChoice(b, a.uid, 1, enemy)
        Combat.Resolve(b)
    end
    assert(Combat.Available(a, 2), "ready after 3 turns")
    assert(Combat.SetChoice(b, a.uid, 2, enemy), "chosen")
    Combat.Resolve(b)
    assert(not Combat.Available(a, 2), "used")
end)

test("stuns skip the next action once", function()
    local b = Combat.New({ Spec("a", "neutral") }, { Spec("e", "neutral", 10, nil, { hp = 900 }) }, 17)
    Combat.Deploy(b, b.bench.ally[1])
    local a = b.units[b.board.ally[1]]
    a.st.stun = true
    Combat.SetChoice(b, a.uid, 1, b.board.enemy[1])
    local events = Combat.Resolve(b)
    local stunned = false
    for _, e in ipairs(events) do
        if e.t == "stunned" and e.src == a.uid then stunned = true end
        assert(not (e.t == "act" and e.src == a.uid), "acted while stunned")
    end
    assert(stunned, "stun event")
    assert(not a.st.stun, "cleared")
end)

test("fallen allies are replaced from the bench", function()
    local allies = {}
    for i = 1, 4 do allies[i] = Spec("a" .. i, "neutral", 10, nil, { hp = 20 }) end
    local b = Combat.New(allies, { Spec("e", "neutral", 10, { { id = "e_slam" } }, { hp = 900, atk = 0 }) }, 19)
    for _ = 1, 3 do Combat.Deploy(b, b.bench.ally[1]) end
    eq(#b.bench.ally, 1)
    b.units[b.board.ally[2]].hp = 1
    -- The enemy's slam kills whoever it hits; replacing may follow.
    local guard = 0
    while b.phase == "command" and #b.bench.ally == 1 and guard < 20 do
        guard = guard + 1
        Combat.AutoChoose(b)
        Combat.Resolve(b)
    end
    if b.phase == "replace" then
        assert(Combat.Deploy(b, b.bench.ally[1]), "deploy")
        eq(b.phase, "command")
        eq(#b.board.ally, 3)
    end
end)

test("a saved battle continues identically", function()
    local store = NewStore()
    local run = Bounty.NewRun(store, "elwynn", false, 99)
    local first = Bounty.Choices(run)[1]
    Bounty.Travel(store, run, first.layer, first.index)
    eq(run.phase, "battle")
    local b = run.battle
    for _ = 1, 3 do Combat.Deploy(b, b.bench.ally[1]) end
    Combat.AutoChoose(b)
    Combat.Resolve(b)
    local saved = Copy(b)
    local function Play(battle)
        local log = {}
        for _ = 1, 4 do
            if battle.phase == "replace" then Combat.Deploy(battle, battle.bench.ally[1]) end
            if battle.phase ~= "command" then break end
            Combat.AutoChoose(battle)
            for _, e in ipairs(Combat.Resolve(battle)) do log[#log + 1] = e end
        end
        return log
    end
    DeepEqual(Play(b), Play(saved))
    DeepEqual(b, saved)
end)

test("maps connect every stop and end at the boss", function()
    local store = NewStore()
    for seed = 1, 40 do
        for _, zid in ipairs(MC.ZONE_ORDER) do
            local run = Bounty.NewRun(store, zid, false, seed)
            local layers = run.map.layers
            eq(#layers[#layers], 1)
            eq(layers[#layers][1].type, "boss")
            for l = 1, #layers - 1 do
                local reached = {}
                for _, node in ipairs(layers[l]) do
                    assert(#node.links > 0, "dead end")
                    for _, j in ipairs(node.links) do
                        assert(layers[l + 1][j], "bad link")
                        reached[j] = true
                    end
                end
                for j = 1, #layers[l + 1] do assert(reached[j], zid .. " unreachable stop " .. (l + 1) .. ":" .. j) end
            end
            store.run = nil
        end
    end
end)

test("heroic needs the normal boss first", function()
    local store = NewStore()
    assert(not Bounty.NewRun(store, "elwynn", true, 1), "locked")
    Bounty.ZoneState(store, "elwynn").normal = 1
    local run = Bounty.NewRun(store, "elwynn", true, 1)
    assert(run, "unlocked")
    eq(run.map.layers[1][1].level, Bounty.HEROIC_LEVEL)
end)

test("experience levels mercenaries and unlocks abilities", function()
    local entry = Bounty.NewEntry(true)
    eq(Bounty.UnlockedAbilities(entry.level), 1)
    local gained = Bounty.AddXP(entry, 100000)
    assert(gained > 10, "levels")
    eq(Bounty.UnlockedAbilities(entry.level), entry.level >= 30 and 3 or 2)
    Bounty.AddXP(entry, 10 ^ 9)
    eq(entry.level, MC.MAX_LEVEL)
end)

test("coins recruit and rank up", function()
    local store = NewStore()
    local entry = Bounty.Entry(store, "jaina")
    assert(not Bounty.CanRecruit(store, "jaina"), "too poor")
    assert(not Bounty.CanImprove(store, "jaina"), "nothing to do while poor")
    entry.coins = Bounty.RECRUIT_COST + 30
    assert(Bounty.CanImprove(store, "jaina"), "recruiting is something to do")
    assert(Bounty.Recruit(store, "jaina"), "recruit")
    assert(entry.owned, "owned")
    assert(Bounty.CanImprove(store, "jaina"), "a rank up is something to do too")
    assert(Bounty.RankUp(store, "jaina", 1), "rank II")
    eq(entry.ranks[1], 2)
    assert(not Bounty.RankUp(store, "jaina", 2), "slot 2 locked at level 1")
    assert(not Bounty.CanImprove(store, "jaina"), "no coins left")
end)

test("every task chain ends with an item of its level for its mercenary", function()
    local Quests = MC.Quests
    for _, chain in ipairs(MC.QUEST_CHAIN_ORDER) do
        local id = Quests.RewardItem(chain)
        local item = id and MC.Items[id]
        assert(item, chain .. ": reward item")
        local level = Quests.ChainLevel(chain)
        assert(item.level >= level - 8 and item.level <= level + 4, chain .. ": item level " .. item.level .. " for " .. level)
        assert(item.kind ~= "jewelry" or level >= MC.MAX_LEVEL, chain .. ": jewellery only at the highest level")
    end
    -- A mercenary that owns the item already gets its materials instead.
    local store = NewStore()
    local chain = "cairne_mulgore"
    local id = Quests.RewardItem(chain)
    Bounty.GiveItem(store, "cairne", id)
    local st = Quests.State(store, chain)
    st.step = #MC.QUEST_CHAINS[chain].steps
    local isReady = Quests.IsReady
    Quests.IsReady = function(s, c) return c == chain or isReady(s, c) end
    local _, _, item, material, count = Quests.TurnIn(store, chain)
    Quests.IsReady = isReady
    eq(item, id)
    assert(material and count > 0 and (Bounty.Materials(store)[material] or 0) >= count, "disenchanted into materials")
end)

test("rank IV needs coins and the mercenary's dungeon cleared with it", function()
    for _, id in ipairs(MC.MERC_ORDER) do
        local dungeon = MC.Zones[MC.RANK4_DUNGEON[id]]
        assert(dungeon and dungeon.dungeon and dungeon.min >= 44, id .. ": rank IV dungeon from the mid-forties")
    end
    local store = NewStore()
    local entry = Bounty.Entry(store, "cairne")
    entry.ranks[1], entry.coins = 3, 1000
    assert(not Bounty.CanRankUp(store, "cairne", 1), "dungeon not cleared yet")
    eq(Bounty.RankDungeon(entry, "cairne", 1), MC.RANK4_DUNGEON.cairne)
    -- Clearing the dungeon with Cairne in the party (the run's end records who was there).
    local run = Bounty.NewRun(store, MC.RANK4_DUNGEON.cairne, false, 1)
    local layers = run.map.layers
    local last = layers[#layers][1]
    run.layer, run.index = #layers, 1
    run.battle = { phase = "won", units = {} }
    Bounty.AfterBattle(store, run)
    eq(run.phase, "complete")
    assert(entry.dungeons[MC.RANK4_DUNGEON.cairne], "recorded")
    assert(Bounty.RankUp(store, "cairne", 1), "rank IV")
    eq(entry.ranks[1], 4)
    -- A won fight gives a coin, the end its reward.
    eq(entry.coins, 1000 - Bounty.RANK_COST[4] + 1 + (run.rewards.coins.cairne or 0))
    eq(Bounty.RankCost(entry, 1), nil)
    assert(Combat.RANK_BONUS[4] > Combat.RANK_BONUS[3], "rank IV is stronger")
    assert(last.final, "the last stop ends the dungeon")
end)

test("a full bounty run reaches an end", function()
    local store = NewStore()
    for _, id in ipairs(store.party) do store.mercs[id].level = 12 end
    local run = Bounty.NewRun(store, "elwynn", false, 5)
    local guard = 0
    while guard < 300 do
        guard = guard + 1
        local phase = run.phase
        if phase == "map" then
            local choice = Bounty.Choices(run)[1]
            Bounty.Travel(store, run, choice.layer, choice.index)
        elseif phase == "battle" then
            AutoBattle(run.battle)
            Bounty.AfterBattle(store, run)
        elseif phase == "treasure" then
            Bounty.ChooseTreasure(store, run, 1)
        elseif phase == "healer" then
            Bounty.Revive(run, Bounty.DeadMembers(run)[1])
        elseif phase == "stranger" then
            Bounty.Stranger(run, 1)
        else
            break
        end
    end
    assert(run.phase == "complete" or run.phase == "lost", "ended in " .. run.phase)
    if run.phase == "complete" then
        eq(Bounty.ZoneState(store, "elwynn").normal, 1)
        assert(Bounty.HeroicUnlocked(store, "elwynn"), "heroic open")
        assert(store.mercs.bolvar.gears[2], "gear unlocked")
    end
end)

test("treasures only go where they help", function()
    local store = NewStore()
    -- Benedictus deals only holy damage.
    assert(not Bounty.TreasureFits(store, MC.Treasures.fire, "benedictus"), "no fire")
    assert(Bounty.TreasureFits(store, MC.Treasures.holy, "benedictus"), "holy")
    assert(not Bounty.TreasureFits(store, MC.Treasures.focus2, "benedictus"), "second ability locked")
end)

test("a guest joins once, fights at the party level and earns nothing", function()
    local store = NewStore()
    local run = Bounty.NewRun(store, "elwynn", false, 5)
    local id = Bounty.AddGuest(store, run)
    assert(id, "guest joined")
    eq(#run.party, Bounty.PARTY_SIZE + 1, "seven members")
    assert(not Bounty.AddGuest(store, run), "only one guest")
    local guest = run.party[#run.party]
    assert(not (store.mercs[id] and store.mercs[id].owned), "guest is a mercenary not yet recruited")
    eq(Bounty.MercSpec(store, id, guest, run).level, guest.guest.level, "guest level")
    local before = store.mercs[id] and store.mercs[id].xp or 0
    run.layer, run.index = 1, 1
    run.battle = { phase = "won", units = {} }
    Bounty.AfterBattle(store, run)
    eq(store.mercs[id] and store.mercs[id].xp or 0, before, "no experience for the guest")
end)

test("planner gives valid orders and leaves the battle untouched", function()
    local abilities = { { id = "jaina_1" }, { id = "jaina_2" }, { id = "jaina_3" } }
    local b = Combat.New({ Spec("a", "caster", 20, abilities), Spec("b", "fighter", 20, abilities), Spec("c", "protector", 20, abilities) },
        { Spec("e1", "fighter"), Spec("e2", "caster"), Spec("e3", "protector") }, 21)
    for _ = 1, 3 do Combat.Deploy(b, Combat.BestReplacement(b).uid) end
    eq(b.phase, "command", "party deployed")
    local before = Combat.Copy(b)
    Combat.BestChoices(b)
    assert(Combat.Ready(b), "everyone has orders")
    for _, u in ipairs(Combat.Alive(b, "ally")) do
        assert(Combat.Available(u, u.choice.slot), "chosen ability is available")
        u.choice = nil
    end
    DeepEqual(b, before)
end)

test("replacement prefers the role that beats the foes", function()
    local b = Combat.New({ Spec("p", "protector"), Spec("f", "fighter"), Spec("c", "caster") },
        { Spec("e1", "caster"), Spec("e2", "caster") }, 4)
    eq(b.units[Combat.BestReplacement(b).uid].role, "fighter", "fighter beats casters")
end)

test("the last blow is remembered", function()
    local b = Combat.New({ Spec("hero", "fighter", 60) }, { Spec("foe", "caster", 1, nil, { hp = 1 }) }, 8)
    Combat.Deploy(b, b.bench.ally[1])
    AutoBattle(b)
    eq(b.phase, "won", "the hero wins")
    local hero, foe
    for _, u in pairs(b.units) do
        if u.side == "ally" then hero = u else foe = u end
    end
    eq(foe.killedBy, hero.uid, "killer recorded")
end)

test("every treasure has a rarity, and offers follow the weights", function()
    local valid = {}
    for _, r in ipairs(MC.RARITIES) do valid[r] = true end
    for _, id in ipairs(MC.TREASURE_ORDER) do
        assert(MC.Treasures[id] and valid[MC.Treasures[id].rarity], id .. " has a rarity")
    end
    for name, weights in pairs(MC.RARITY_WEIGHTS) do
        local total = 0
        for _, r in ipairs(MC.RARITIES) do total = total + weights[r] end
        eq(total, 100, name .. " weights")
    end
    local store = NewStore()
    local run = Bounty.NewRun(store, "elwynn", false, 77)
    local seen = {}
    for _ = 1, 400 do
        for _, id in ipairs(Bounty.RollTreasures(store, run, 1, false, 3)) do
            local r = MC.Treasures[id].rarity
            seen[r] = (seen[r] or 0) + 1
        end
    end
    assert(not seen.legendary, "no legendary treasure after a regular fight")
    assert((seen.common or 0) > (seen.uncommon or 0) and (seen.uncommon or 0) > (seen.rare or 0), "rarer means less often")
    local elite = {}
    for _ = 1, 400 do
        for _, id in ipairs(Bounty.RollTreasures(store, run, 1, true, 3)) do elite[MC.Treasures[id].rarity] = true end
    end
    assert(elite.legendary, "elite fights can offer legendary treasures")
end)

test("damage preview matches the hit and shows the role advantage", function()
    for _, role in ipairs({ "caster", "protector" }) do
        local b = Combat.New({ Spec("hero", "fighter", 20) }, { Spec("foe", role, 20, nil, { hp = 500 }) }, 13)
        Combat.Deploy(b, b.bench.ally[1])
        local hero, foe
        for _, u in pairs(b.units) do
            if u.side == "ally" then hero = u else foe = u end
        end
        local info = Combat.PreviewDamage(b, hero, 1, foe)
        eq(info.adv, role == "caster", role .. " advantage")
        Combat.SetChoice(b, hero.uid, 1, foe.uid)
        -- The hero's own hit, not a retaliation when the foe struck first.
        local dealt, acting
        for _, e in ipairs(Combat.Resolve(b)) do
            if e.t == "act" then acting = e.src == hero.uid end
            if acting and e.t == "damage" and e.src == hero.uid and e.dst == foe.uid and not dealt then dealt = e.amount end
        end
        eq(dealt, info.amount, role .. " preview equals the hit")
    end
end)

-- Items ---------------------------------------------------------------------------------------------

local TEST_ITEMS = {
    test_blade = { rarity = "rare", kind = "weapon", slot = "one-hand", points = { atkPct = 4, critChance = 2 } },
    test_cloak = { rarity = "uncommon", kind = "armor", slot = "back", points = { resist_fire = 2, xpPct = 2 } },
    test_vest = { rarity = "common", kind = "armor", slot = "chest", points = { hpPct = 2 } },
    test_ring = { rarity = "rare", kind = "jewelry", slot = "finger", points = { coinPct = 6 } },
}

test("items stay within their rarity's budget", function()
    for id, item in pairs(MC.Items) do
        assert(MC.ITEM_BUDGET[item.rarity], id .. ": rarity")
        assert(MC.ItemPoints(item) <= MC.ITEM_BUDGET[item.rarity], id .. ": over budget")
        for key in pairs(item.points) do assert(MC.ITEM_POINT[key], id .. ": unknown bonus " .. key) end
    end
end)

test("items belong to one mercenary: weapon and armour slot, jewellery from the highest level", function()
    for id, item in pairs(TEST_ITEMS) do MC.Items[id] = item end
    local store = NewStore()
    local id = store.party[1]
    local entry = store.mercs[id]
    eq(Bounty.GiveItem(store, id, "test_blade"), "new")
    eq(entry.worn[1], "test_blade", "worn at once in the weapon slot")
    eq(Bounty.GiveItem(store, id, "test_blade"), "duplicate")
    eq(Bounty.GiveItem(store, id, "test_cloak"), "new")
    eq(entry.worn[2], "test_cloak", "armour slot")
    eq(Bounty.GiveItem(store, id, "test_vest"), "new")
    eq(entry.worn[2], "test_cloak", "a taken slot stays as it is")
    eq(Bounty.BagItems(entry)[1], "test_vest")
    assert(not Bounty.WearItem(store, id, 1, "test_vest"), "armour never in the weapon slot")
    assert(Bounty.WearItem(store, id, 2, "test_vest"))
    eq(Bounty.BagItems(entry)[1], "test_cloak", "the cloak back in the bag")
    eq(Bounty.GiveItem(store, id, "test_ring"), "new")
    eq(entry.worn[3], nil, "jewellery waits below the highest level")
    assert(not Bounty.WearItem(store, id, 3, "test_ring"), "no jewellery slot yet")
    entry.level = MC.MAX_LEVEL
    assert(Bounty.WearItem(store, id, 3, "test_ring"), "jewellery slot")
    assert(not Bounty.WearItem(store, store.party[2], 1, "test_blade"), "not someone else's item")
    assert(Bounty.WearItem(store, id, 2, "test_cloak"))
    -- A save from before the slots had kinds: a misplaced item goes back to the bag.
    entry.worn[1] = "test_cloak"
    assert(Bounty.OwnsItem(entry, "test_cloak"))
    eq(entry.worn[1], nil)
    entry.worn[1] = "test_blade"
    local spec = Bounty.MercSpec(store, id)
    assert(math.abs((spec.mods.critChance or 0) - 2 * MC.ITEM_POINT.critChance) < 1e-9, "item bonus in the fight")
    assert(math.abs((spec.mods.resist_fire or 0) - 2 * MC.ITEM_POINT.resist_fire) < 1e-9, "resistance")
    for id2 in pairs(TEST_ITEMS) do MC.Items[id2] = nil end
end)

test("every item can be disenchanted, every formula has known materials", function()
    for id, item in pairs(MC.Items) do
        assert(item.level and item.level > 0, id .. ": item level")
        local sum = 0
        for _, r in ipairs(MC.DisenchantResults(item)) do
            assert(MC.Materials[r[2]], id .. ": material " .. tostring(r[2]))
            assert(r[3] >= 1 and r[4] >= r[3], id .. ": counts")
            sum = sum + r[1]
        end
        assert(math.abs(sum - 1) < 1e-9, id .. ": chances add up")
    end
    for id, recipe in pairs(MC.Recipes) do
        local fits = false
        for _, item in pairs(MC.Items) do fits = fits or MC.RecipeFits(recipe, item) end
        assert(fits, id .. ": some item takes it")
        assert(#recipe.cost > 0, id .. ": materials")
        for _, cost in ipairs(recipe.cost) do assert(MC.Materials[cost[1]], id .. ": material") end
        for key in pairs(MC.RecipeMods(recipe)) do assert(MC.ITEM_POINT[key], id .. ": bonus " .. key) end
    end
    eq(#MC.RECIPE_ORDER, (function() local n = 0 for _ in pairs(MC.Recipes) do n = n + 1 end return n end)())
    -- The first dungeons' items never give more than the second tier's materials (as in Classic, their
    -- best items reach level 26-28).
    for _, dungeon in ipairs({ "deadmines", "wailing" }) do
        for _, boss in ipairs(MC.DungeonLoot[dungeon]) do
            for _, drop in ipairs(boss.drops) do
                for _, r in ipairs(MC.DisenchantResults(MC.Items[drop[1]])) do
                    assert(MC.Materials[r[2]].tier <= 2, dungeon .. " " .. drop[1])
                end
            end
        end
    end
end)

test("disenchanting fills the bag, formulas turn it into an enchant", function()
    for id, item in pairs(TEST_ITEMS) do MC.Items[id] = item end
    TEST_ITEMS.test_blade.level, TEST_ITEMS.test_cloak.level = 22, 18
    local store = NewStore()
    local id = store.party[1]
    -- A rare level-22 item always gives a Small Glimmering Shard.
    local mat, n = Bounty.Disenchant(store, "test_blade", { rng = 7 })
    eq(mat, 10978)
    eq(n, 1)
    -- Uncommon armour: mostly Strange Dust, over many rolls every result shows up.
    local seen, rng = {}, { rng = 99 }
    for _ = 1, 400 do seen[Bounty.Disenchant(NewStore(), "test_cloak", rng)] = true end
    assert(seen[10940] and seen[10939] and seen[10978], "dust, essence and shard")

    -- Only owned items that are not worn can be disenchanted.
    Bounty.GiveItem(store, id, "test_blade")
    Bounty.GiveItem(store, id, "test_cloak")
    eq(Bounty.DisenchantOwned(store, id, "test_blade"), nil, "worn")
    eq(Bounty.DisenchantOwned(store, store.party[2], "test_cloak"), nil, "someone else's")

    -- Formulas are learnt once; the enchant needs a known formula for the item's slot and the materials.
    local strike = 7788 -- Enchant Weapon - Minor Striking: Strange Dust 2, Greater Magic Essence 1, Small Glimmering Shard 1
    assert(not Bounty.CanEnchant(store, id, "test_blade", strike), "unknown formula")
    assert(Bounty.LearnRecipe(store, strike))
    assert(not Bounty.LearnRecipe(store, strike), "known already")
    assert(not Bounty.CanEnchant(store, id, "test_blade", strike), "too few materials")
    Bounty.AddMaterial(store, 10940, 2)
    Bounty.AddMaterial(store, 10939, 1)
    assert(not Bounty.CanEnchant(store, id, "test_cloak", strike), "a weapon formula on armour")
    -- A cloak formula fits a cloak only, never a chest piece; jewellery takes none.
    local cloak = 7771
    assert(MC.RecipeFits(MC.Recipes[cloak], TEST_ITEMS.test_cloak))
    assert(not MC.RecipeFits(MC.Recipes[cloak], TEST_ITEMS.test_vest))
    assert(not MC.Enchantable(TEST_ITEMS.test_ring))
    assert(MC.RecipeFits(MC.Recipes[7745], { slot = "two-hand" }), "2H formula on a two-hander")
    assert(not MC.RecipeFits(MC.Recipes[7745], TEST_ITEMS.test_blade), "but not on a one-hander")
    local before = Bounty.MercSpec(store, id).mods.atkPct or 0
    assert(Bounty.Enchant(store, id, "test_blade", strike))
    eq(store.materials[10940], nil, "used up")
    eq(store.materials[10978], nil, "the shard from the first disenchant")
    local after = Bounty.MercSpec(store, id).mods.atkPct or 0
    assert(math.abs(after - before - MC.RECIPE_POINTS[1] * MC.ITEM_POINT.atkPct) < 1e-9, "enchant in the fight")
    eq(MC.UnknownRecipes(store, 1)[1] ~= strike, true)

    -- An item kept in the bag can go; its enchant goes with it.
    store.mercs[id].worn[1] = nil
    assert(Bounty.DisenchantOwned(store, id, "test_blade"))
    assert(not Bounty.OwnsItem(store.mercs[id], "test_blade"))
    eq(Bounty.ItemEnchant(store.mercs[id], "test_blade"), nil)
    TEST_ITEMS.test_blade.level, TEST_ITEMS.test_cloak.level = nil, nil
    for id2 in pairs(TEST_ITEMS) do MC.Items[id2] = nil end
end)

test("found items wait for an owner; a duplicate or a refused one is disenchanted", function()
    local store = NewStore()
    local id = store.party[1]
    local blade = 5191
    eq(Bounty.ClaimItem(store, id), nil, "nothing waits")
    Bounty.QueueItem(store, blade)
    Bounty.QueueItem(store, blade)
    Bounty.QueueItem(store, 5443)
    eq(Bounty.ClaimItem(store, "nobody"), nil, "only a recruited mercenary")
    eq(Bounty.PendingItem(store), blade, "still waiting")
    eq(Bounty.ClaimItem(store, id), "new")
    local result, mat, n = Bounty.ClaimItem(store, id, { rng = 5 })
    eq(result, "disenchanted", "owned already")
    eq(mat, 10978)
    eq(n, 1)
    eq(Bounty.ClaimItem(store, nil, { rng = 5 }), "disenchanted", "refused")
    eq(store.pendingItems, nil)
    eq(#Bounty.BagItems(store.mercs[id]), 0, "the blade is worn")
    -- Any waiting find can go first.
    Bounty.QueueItem(store, 5444)
    Bounty.QueueItem(store, 5191)
    Bounty.QueueItem(store, 872)
    eq(Bounty.ClaimItem(store, store.party[2], nil, 3), "new", "the third one first")
    assert(Bounty.OwnsItem(store.mercs[store.party[2]], 872))
    eq(store.pendingItems[1], 5444)
    eq(store.pendingItems[2], 5191)
    eq(Bounty.ClaimItem(store, store.party[2], nil, 5), nil, "no such find")
end)

test("comfort bonuses: more experience and coins for the wearer, nothing in the fight", function()
    MC.Items.test_charm = { rarity = "rare", kind = "jewelry", level = 20, points = { xpPct = 4, coinPct = 2 } }
    local store = NewStore()
    local id = store.party[1]
    local mods = Bounty.WornMods(store.mercs[id])
    eq(mods.xpPct, nil)
    store.mercs[id].level = MC.MAX_LEVEL
    Bounty.GiveItem(store, id, "test_charm")
    mods = Bounty.WornMods(store.mercs[id])
    assert(math.abs(mods.xpPct - 0.2) < 1e-9 and math.abs(mods.coinPct - 0.1) < 1e-9, "the charm's bonuses")
    for key in pairs(MC.COMFORT) do assert(MC.ITEM_POINT[key], key) end
    MC.Items.test_charm = nil
end)

-- Tasks --------------------------------------------------------------------------------------------

test("task chains: every task is known, playable and has its texts' targets", function()
    local Quests = MC.Quests
    local count = 0
    for id, chain in pairs(MC.QUEST_CHAINS) do
        count = count + 1
        assert(MC.Mercs[chain.merc], id .. ": mercenary")
        assert(#chain.steps > 0, id .. ": tasks")
        if chain.requires and chain.requires.chain then assert(MC.QUEST_CHAINS[chain.requires.chain], id .. ": requires") end
        for i, task in ipairs(chain.steps) do
            local where = id .. " " .. i
            if task.zone then assert(MC.Zones[task.zone], where .. ": zone") end
            if task.kind == "ability" then
                assert(MC.Mercs[chain.merc].abilities[task.slot], where .. ": ability")
            elseif task.kind == "kill" then
                assert(task.what and task.count > 0, where .. ": target")
                -- Somewhere a foe of that kind turns up (in the zone, if one is named).
                local found = false
                for zid, zone in pairs(MC.Zones) do
                    if not task.zone or task.zone == zid then
                        for _, eid in ipairs(zone.pool) do
                            local prefixes = type(task.prefix) == "table" and task.prefix or { task.prefix }
                            if task.race == MC.Enemies[eid].race then found = true end
                            for _, p in ipairs(prefixes) do
                                if p and eid:sub(1, #p) == p then found = true end
                            end
                        end
                    end
                end
                assert(found, where .. ": no such foe")
            end
        end
    end
    eq(#MC.QUEST_CHAIN_ORDER, count, "every chain in the order")
end)

test("tasks: earlier progress counts, kills and abilities count in battle, handing in pays and unlocks", function()
    local Quests = MC.Quests
    local store = NewStore()
    -- Only recruited mercenaries' chains are open.
    assert(Quests.Open(store, "bolvar_defias"))
    eq(#Quests.ChainsOf(store, "bolvar"), 1)
    -- Bolvar's Defias 1: Elwynn cleared before the tasks existed.
    assert(not Quests.IsReady(store, "bolvar_defias"))
    Bounty.ZoneState(store, "elwynn").normal = 1
    assert(Quests.IsReady(store, "bolvar_defias"), "an earlier clear counts")
    eq(Quests.ReadyCount(store), 1)
    local coins = store.mercs.bolvar.coins
    eq(Quests.TurnIn(store, "bolvar_defias"), Quests.COINS[1])
    eq(store.mercs.bolvar.coins, coins + Quests.COINS[1])
    eq(Quests.TurnIn(store, "bolvar_defias"), nil, "the next one is not done yet")
    -- Defias 2: Defias fall while he is in the party, other foes do not count, guests count nothing.
    local run = { zone = "westfall", party = { { id = "bolvar" }, { id = "renzik", guest = {} } } }
    local function Battle(foes, used)
        local b = { phase = "won", units = {
            a = { side = "ally", pidx = 1, used = used },
            g = { side = "ally", pidx = 2, used = { 5 } },
        } }
        for i, id in ipairs(foes) do b.units["e" .. i] = { side = "enemy", id = id, dead = true } end
        Quests.OnBattle(store, run, b)
    end
    Battle({ "defias_pillager", "defias_trapper", "harvest_golem" })
    eq(Quests.Progress(store, "bolvar_defias"), 2)
    for _ = 1, 9 do Battle({ "defias_pillager", "defias_blackguard" }) end
    assert(Quests.IsReady(store, "bolvar_defias"), "20 Defias")
    eq(run.questsReady[1], "bolvar_defias", "the result page learns of it")
    eq(Quests.MercsOf(run.questsReady)[1], "bolvar")
    Quests.TurnIn(store, "bolvar_defias")
    -- Defias 4 (after 3): into the Deadmines with him; a bounty does not count.
    Quests.State(store, "bolvar_defias").step = 4
    Quests.OnBounty(store, { zone = "westfall", party = { { id = "bolvar" } } })
    assert(not Quests.IsReady(store, "bolvar_defias"))
    Quests.OnBounty(store, { zone = "deadmines", dungeon = "deadmines", party = { { id = "bolvar" } } })
    local _, unlock, item = Quests.TurnIn(store, "bolvar_defias")
    eq(unlock, nil, "tasks never lock a dungeon")
    -- The chain's end gives its item to Bolvar.
    eq(item, Quests.RewardItem("bolvar_defias"))
    assert(Bounty.OwnsItem(store.mercs.bolvar, item), "the chain's item is Bolvar's")
    assert(Quests.Done(store, "bolvar_defias") and not Quests.IsReady(store, "bolvar_defias"), "the chain is done")
    -- Benedictus 2: shields cast in battle.
    Bounty.ZoneState(store, "tirisfal").normal = 1
    Quests.TurnIn(store, "benedictus_light")
    run.party[1] = { id = "benedictus" }
    Battle({}, { 3, 12 })
    eq(Quests.Progress(store, "benedictus_light"), 12)
    -- Shandris 2: Darkshore with her in the party; an earlier clear does not count.
    Bounty.ZoneState(store, "teldrassil").normal = 1
    Quests.TurnIn(store, "shandris_sentinel")
    Bounty.ZoneState(store, "darkshore").normal = 3
    assert(not Quests.IsReady(store, "shandris_sentinel"))
    Quests.OnBounty(store, { zone = "darkshore", party = { { id = "shandris" } } })
    assert(Quests.IsReady(store, "shandris_sentinel"))
end)

test("tasks: a mercenary has several chains, a sequel opens after its chain, old saves move over", function()
    local Quests = MC.Quests
    MC.QUEST_CHAINS.test_sequel = { id = "test_sequel", merc = "bolvar", requires = { chain = "bolvar_defias", level = 20 },
        steps = { { kind = "dungeon", dungeon = "deadmines" } } }
    table.insert(MC.QUEST_CHAIN_ORDER, "test_sequel")
    local store = NewStore()
    assert(not Quests.Open(store, "test_sequel"), "not before the first chain is done")
    Quests.State(store, "bolvar_defias").step = 5
    assert(not Quests.Open(store, "test_sequel"), "nor below its level")
    store.mercs.bolvar.level = 20
    assert(Quests.Open(store, "test_sequel"))
    eq(#Quests.ChainsOf(store, "bolvar"), 3, "his Defias chain, its sequel for Miner Johnson and the test chain")
    -- A chain can wait for a dungeon's last boss.
    MC.QUEST_CHAINS.test_sequel.requires = { cleared = "deadmines" }
    assert(not Quests.Open(store, "test_sequel"), "only after the Deadmines")
    Bounty.ZoneState(store, "deadmines").normal = 1
    assert(Quests.Open(store, "test_sequel"))
    -- A dungeon cleared with him counts; a bounty does not.
    local run = { zone = "westfall", party = { { id = "bolvar" } } }
    Quests.OnBounty(store, run)
    assert(not Quests.IsReady(store, "test_sequel"))
    run.dungeon = "deadmines"
    Quests.OnBounty(store, run)
    assert(Quests.IsReady(store, "test_sequel"))
    MC.QUEST_CHAINS.test_sequel = nil
    table.remove(MC.QUEST_CHAIN_ORDER)

    -- A save from before chains had ids: the progress stays.
    local old = NewStore()
    old.quests = { bolvar = { step = 3, count = 4 } }
    eq(Quests.State(old, "bolvar_defias").step, 3)
    eq(old.quests.bolvar, nil)
end)

-- Dungeons -----------------------------------------------------------------------------------------

test("dungeons: wings of a group share one portal, long wings fight several trash waves", function()
    local Dungeons = MC.Dungeons
    eq(#Dungeons.Wings("sm_library"), 4)
    eq(Dungeons.Wings("sm_cathedral")[1], "sm_graveyard")
    eq(#Dungeons.Wings("deadmines"), 1)
    -- The Armory: three trash fights (the last elite), the spirit healer, Herod.
    local map = Dungeons.GenerateMap({ rng = 4242 }, NewStore(), MC.Zones.sm_armory, false)
    local kinds = {}
    for _, row in ipairs(map.layers) do kinds[#kinds + 1] = row[1].type end
    eq(table.concat(kinds, " "), "fight fight elite healer boss")
end)

test("dungeons: always open, the path is fixed, a hidden boss on a side branch, Classic loot, the last ends it", function()
    local Dungeons, Quests = MC.Dungeons, MC.Quests
    for _, id in ipairs(MC.DUNGEON_ORDER) do
        local zone = MC.Zones[id]
        assert(zone.dungeon and MC.Zones[zone.region], id .. ": entrance in a bounty zone")
        local looted = 0
        for i, enc in ipairs(zone.encounters) do
            assert(MC.Enemies[enc.boss] and MC.Enemies[enc.boss].boss, id .. " " .. i .. ": boss")
            for _, a in ipairs(enc.adds) do assert(MC.Enemies[a], id .. " " .. i .. ": add " .. a) end
            for _, t in ipairs(enc.trash or {}) do assert(MC.Enemies[t], id .. " " .. i .. ": trash " .. t) end
            -- Every boss drops something: bosses without Classic loot of their own (Bazil Thredd) share
            -- the dungeon's.
            assert(#Dungeons.LootOf(id, i) > 0, id .. " " .. i .. ": loot")
            looted = looted + #Dungeons.LootOf(id, i)
        end
        assert(looted > 0, id .. ": loot")
        for _, eid in ipairs(zone.pool) do
            for _, aid in ipairs(MC.Enemies[eid].abilities) do assert(MC.Abilities[aid], eid .. ": " .. aid) end
        end
    end
    for _, id in ipairs(MC.DUNGEON_ORDER) do for _, enc in ipairs(MC.Zones[id].encounters) do
        local def = MC.Enemies[enc.boss]
        for _, aid in ipairs(def.abilities) do assert(MC.Abilities[aid], enc.boss .. ": " .. aid) end
        assert(MC.Abilities[def.heroic], enc.boss .. ": heroic")
    end end

    local store = NewStore()
    local run = Bounty.NewRun(store, "deadmines", false, 5)
    assert(run and run.dungeon == "deadmines", "open without any task")
    -- One stop per layer but for Miner Johnson's branch: a passage beside him, he is locked; the last
    -- stop is VanCleef.
    local bosses, branch = {}, nil
    for l, row in ipairs(run.map.layers) do
        if #row == 2 then
            branch = l
            eq(row[1].type, "pass")
            eq(row[2].boss, "minerjohnson")
            assert(row[2].locked, "Johnson locked")
        else
            eq(#row, 1, "one stop per layer")
            if row[1].type == "boss" then bosses[#bosses + 1] = row[1].boss end
        end
    end
    assert(branch, "Johnson's branch")
    eq(#bosses, 7)
    eq(bosses[#bosses], "vancleef")
    eq(run.map.layers[#run.map.layers][1].final, true)
    -- Before the branch both ways are linked, but only the passage can be taken.
    run.layer, run.index = branch - 1, 1
    local choices = Bounty.Choices(run)
    eq(#choices, 1)
    eq(choices[1].index, 1, "past him")
    store.run = nil
    store.unlocks = { deadmines_johnson = true }
    run = Bounty.NewRun(store, "deadmines", false, 5)
    run.layer, run.index = branch - 1, 1
    eq(#Bounty.Choices(run), 2, "Johnson or past him once revealed")
    assert(not run.map.layers[branch][2].locked and run.map.layers[branch][2].final == false)
    -- The passage just walks on.
    assert(Bounty.Travel(store, run, branch, 1))
    eq(run.phase, "map")

    -- Loot after a boss: Classic's chances; over many kills of Rhahk'Zor both his items drop, the
    -- common hammer far more often.
    local counts = {}
    local node = { type = "boss", boss = "rhahkzor", encounter = 1, final = false }
    for _ = 1, 300 do Dungeons.Loot(store, run, node) end
    for _, item in ipairs(run.itemsFound) do counts[item] = (counts[item] or 0) + 1 end
    assert((counts[5187] or 0) > 150 and (counts[872] or 0) > 2 and (counts[872] or 0) < 40, "Classic's odds")
    eq(#store.pendingItems, #run.itemsFound, "every find waits for an owner")
    assert(#run.recipesFound > 0, "formulas now and then")
    for _, rid in ipairs(run.recipesFound) do eq(MC.Recipes[rid].tier, 1, "tier 1 in normal") end
end)

test("Wailing Caverns: Verdan ends it until Hamuul's dream wakes Mutanus; the faerie dragon is rare", function()
    local Quests = MC.Quests
    local store = NewStore()
    store.unlocks = { wailing = true }
    local function Bosses(seed)
        store.run = nil
        local run = Bounty.NewRun(store, "wailing", false, seed)
        local out = {}
        for _, row in ipairs(run.map.layers) do
            for _, node in ipairs(row) do
                if node.type == "boss" and not node.locked then out[#out + 1] = node.boss end
            end
        end
        return out, run
    end
    local dragons, runs = 0, 40
    for seed = 1, runs do
        local bosses = Bosses(seed * 48271 + 1700000000)
        eq(bosses[#bosses], "verdan", "Verdan last")
        for _, b in ipairs(bosses) do
            assert(b ~= "mutanus", "Mutanus asleep")
            if b == "faeriedragon" then dragons = dragons + 1 end
        end
    end
    assert(dragons > 3 and dragons < runs - 5, "the faerie dragon now and then: " .. dragons)
    -- Hamuul's second chain: 30 deviate creatures in the caverns.
    Quests.State(store, "hamuul_naralex").step = 5
    assert(Quests.Open(store, "hamuul_dream"))
    local run = { zone = "wailing", party = { { id = "hamuul" } } }
    for _ = 1, 10 do
        Quests.OnBattle(store, run, { phase = "won", units = {
            a = { side = "ally", pidx = 1 },
            e1 = { side = "enemy", id = "deviate_ravager", dead = true },
            e2 = { side = "enemy", id = "deviate_adder", dead = true },
            e3 = { side = "enemy", id = "druid_of_the_fang", dead = true },
        } })
    end
    eq(Quests.Progress(store, "hamuul_dream"), 20, "deviate creatures only")
    for _ = 1, 5 do
        Quests.OnBattle(store, run, { phase = "won", units = {
            a = { side = "ally", pidx = 1 },
            e1 = { side = "enemy", id = "deviate_lasher", dead = true },
            e2 = { side = "enemy", id = "deviate_guardian", dead = true },
        } })
    end
    local _, unlock = Quests.TurnIn(store, "hamuul_dream")
    eq(unlock, "wailing_mutanus")
    local bosses = Bosses(3)
    eq(bosses[#bosses], "verdan", "Verdan still ends it")
    local awake = false
    for _, b in ipairs(bosses) do awake = awake or b == "mutanus" end
    assert(awake, "Mutanus on his branch once awake")
end)

test("dungeons: a boss in the middle offers a treasure, the last completes the run and counts for tasks", function()
    local store = NewStore()
    store.unlocks = { deadmines = true }
    local run = Bounty.NewRun(store, "deadmines", false, 9)
    -- Stand at the first boss and win.
    for l, row in ipairs(run.map.layers) do
        if row[1].type == "boss" and not row[1].locked then
            run.layer, run.index = l, 1
            break
        end
    end
    run.battle = { phase = "won", units = {} }
    Bounty.AfterBattle(store, run)
    eq(run.phase, "treasure", "a treasure after a boss in the middle")
    -- The last boss.
    run.offer, run.phase = nil, "map"
    run.layer, run.index = #run.map.layers, 1
    run.battle = { phase = "won", units = {} }
    Bounty.AfterBattle(store, run)
    eq(run.phase, "complete")
    eq(Bounty.ZoneState(store, "deadmines").normal, 1, "heroic opens after a clear")
    -- A dungeon task counts the clear.
    MC.Quests.State(store, "bolvar_defias").step = 4
    run.party = { { id = "bolvar", treasures = {} } }
    MC.Quests.OnBounty(store, run)
    assert(MC.Quests.IsReady(store, "bolvar_defias"), "Beneath Moonbrook")
end)

test("resistances and spell damage change hits of their school", function()
    local function Hit(attackerMods, targetMods, school)
        local b = Combat.New({ Spec("a", "neutral", 20, nil, { mods = attackerMods }) },
            { Spec("t", "neutral", 20, nil, { mods = targetMods, hp = 1000 }) }, 3)
        local a, t = b.units[b.bench.ally[1]], b.units[b.board.enemy[1]]
        return Combat.Damage({ b = b }, a, t, 100, school)
    end
    eq(Hit({}, {}, "fire"), 100, "plain")
    eq(Hit({}, { resist_fire = 0.25 }, "fire"), 75, "fire resistance")
    eq(Hit({}, { resist_fire = 0.25 }, "frost"), 100, "only its school")
    eq(Hit({}, { resist_fire = 2 }, "fire"), 25, "at most 75 %")
    eq(Hit({ spellPct = 0.2 }, {}, "fire"), 120, "spell damage")
    eq(Hit({ spellPct = 0.2 }, {}, "physical"), 100, "not for physical hits")
end)

return passed, failed
