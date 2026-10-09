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
        assert(not normalGear[zone.gear.normal], "normal gear twice: " .. zone.gear.normal)
        assert(not heroicGear[zone.gear.heroic], "heroic gear twice: " .. zone.gear.heroic)
        normalGear[zone.gear.normal], heroicGear[zone.gear.heroic] = true, true
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
    entry.coins = Bounty.RECRUIT_COST + 30
    assert(Bounty.Recruit(store, "jaina"), "recruit")
    assert(entry.owned, "owned")
    assert(Bounty.RankUp(store, "jaina", 1), "rank II")
    eq(entry.ranks[1], 2)
    assert(not Bounty.RankUp(store, "jaina", 2), "slot 2 locked at level 1")
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

return passed, failed
