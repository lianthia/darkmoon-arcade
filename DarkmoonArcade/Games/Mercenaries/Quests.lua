-- Tasks and stories: chains of tasks close to the mercenaries' lore. A mercenary can have several
-- chains; a chain opens once its mercenary is recruited and its `requires` are met (another chain done,
-- a level, an unlock, a dungeon cleared - `cleared`), so stories can continue and some appear only
-- after a dungeon's last boss fell. Tasks never lock a dungeon; they may reveal a hidden boss in one. A task is done by playing as
-- usual; it is then handed in at the task board by the fire (as in WoW), which pays its coins and opens
-- the next one. The last task of some chains opens a dungeon.
--
-- What a task asks (kind):
--   clear    the bounty of `zone` (with = the mercenary in the party; without, an earlier clear counts)
--   kill     `count` foes of a `race` or an id `prefix` (optionally in `zone`), the mercenary in the party
--   ability  the mercenary's ability `slot`, `count` times
--   boss     the boss of `zone` falls while the mercenary stands
--   level    the mercenary reaches `level` (counts from before, too)
--   dungeon  `dungeon` cleared with the mercenary in the party
-- Texts: MC_Q_<chain>_<step>_TITLE / _TEXT; kill targets MC_QK_<what>.
-- Saved per chain in store.quests[chain] = { step, count }; a step past the last = chain done.

local _, ns = ...
local MC = ns.Mercenaries
local Bounty = MC.Bounty

local Quests = {}
MC.Quests = Quests

Quests.COINS = { 10, 15, 15, 20 }

MC.QUEST_CHAINS = {
    cairne_mulgore = { merc = "cairne", steps = {
        { kind = "clear", zone = "mulgore" },
        { kind = "kill", race = "centaur", count = 15, what = "CENTAUR" },
        { kind = "ability", slot = 2, count = 25 },
        { kind = "boss", zone = "barrens" },
    } },
    bolvar_defias = { merc = "bolvar", steps = {
        { kind = "clear", zone = "elwynn" },
        { kind = "kill", prefix = "defias_", count = 20, what = "DEFIAS" },
        { kind = "boss", zone = "westfall" },
        { kind = "dungeon", dungeon = "deadmines" },
    } },
    -- After the brotherhood's fall: reveals Miner Johnson in the Deadmines.
    bolvar_deadmines = { merc = "bolvar", requires = { chain = "bolvar_defias" }, steps = {
        { kind = "kill", prefix = "defias_", zone = "deadmines", count = 30, what = "DEFIAS", unlock = "deadmines_johnson" },
    } },
    mankrik_olgra = { merc = "mankrik", steps = {
        { kind = "clear", zone = "durotar" },
        { kind = "kill", prefix = { "razormane_", "bristleback_" }, count = 10, what = "QUILBOAR" },
        { kind = "ability", slot = 1, count = 40 },
        { kind = "boss", zone = "barrens" },
    } },
    shandris_sentinel = { merc = "shandris", steps = {
        { kind = "clear", zone = "teldrassil" },
        { kind = "clear", zone = "darkshore", with = true },
        { kind = "ability", slot = 1, count = 40 },
        { kind = "boss", zone = "ashenvale" },
    } },
    benedictus_light = { merc = "benedictus", steps = {
        { kind = "clear", zone = "tirisfal" },
        { kind = "ability", slot = 2, count = 30 },
        { kind = "kill", race = "undead", count = 20, what = "UNDEAD" },
        { kind = "boss", zone = "duskwood" },
    } },
    -- After Naralex's dream: wakes Mutanus in the Wailing Caverns.
    hamuul_dream = { merc = "hamuul", requires = { chain = "hamuul_naralex" }, steps = {
        { kind = "kill", prefix = "deviate_", zone = "wailing", count = 30, what = "DEVIATE", unlock = "wailing_mutanus" },
    } },
    hamuul_naralex = { merc = "hamuul", steps = {
        { kind = "clear", zone = "mulgore" },
        { kind = "ability", slot = 2, count = 30 },
        { kind = "kill", race = "beast", zone = "barrens", count = 15, what = "BEAST" },
        { kind = "dungeon", dungeon = "wailing" },
    } },
    magni_ironforge = { merc = "magni", steps = {
        { kind = "clear", zone = "dunmorogh" },
        { kind = "kill", race = "trogg", count = 15, what = "TROGG" },
        { kind = "kill", prefix = "dark_iron_", count = 10, what = "DARKIRON" },
        { kind = "boss", zone = "wetlands" },
    } },
    tirion_exile = { merc = "tirion", steps = {
        { kind = "ability", slot = 1, count = 40 },
        { kind = "kill", race = "undead", count = 20, what = "UNDEAD" },
        { kind = "clear", zone = "hillsbrad", with = true },
        { kind = "level", level = 30 },
    } },
    eitrigg_oldclan = { merc = "eitrigg", steps = {
        { kind = "kill", prefix = "blackrock_", count = 15, what = "BLACKROCK" },
        { kind = "ability", slot = 2, count = 20 },
        { kind = "boss", zone = "redridge" },
        { kind = "clear", zone = "wetlands", with = true },
    } },
    taelan_crusade = { merc = "taelan", steps = {
        { kind = "clear", zone = "tirisfal" },
        { kind = "kill", prefix = "scarlet_", count = 20, what = "SCARLET" },
        { kind = "ability", slot = 2, count = 25 },
        { kind = "clear", zone = "hillsbrad", with = true },
    } },
    saurfang_warrior = { merc = "saurfang", steps = {
        { kind = "clear", zone = "thousandneedles" },
        { kind = "kill", prefix = "galak_", count = 20, what = "CENTAUR" },
        { kind = "ability", slot = 1, count = 40 },
        { kind = "boss", zone = "arathi" },
    } },
    windsor_marshal = { merc = "windsor", steps = {
        { kind = "clear", zone = "alterac" },
        { kind = "kill", prefix = "syndicate_", count = 20, what = "SYNDICATE" },
        { kind = "kill", race = "ogre", count = 20, what = "OGRE" },
        { kind = "boss", zone = "badlands" },
    } },
    rexxar_wild = { merc = "rexxar", steps = {
        { kind = "kill", race = "beast", count = 25, what = "BEAST" },
        { kind = "clear", zone = "stonetalon", with = true },
        { kind = "ability", slot = 1, count = 40 },
        { kind = "boss", zone = "stranglethorn" },
    } },
    sylvanas_forsaken = { merc = "sylvanas", steps = {
        { kind = "clear", zone = "tirisfal" },
        { kind = "kill", race = "worgen", count = 15, what = "WORGEN" },
        { kind = "boss", zone = "silverpine" },
        { kind = "ability", slot = 2, count = 30 },
    } },
    voljin_darkspear = { merc = "voljin", steps = {
        { kind = "clear", zone = "durotar" },
        { kind = "kill", race = "troll", count = 20, what = "TROLL" },
        { kind = "ability", slot = 2, count = 25 },
        { kind = "boss", zone = "stranglethorn" },
    } },
    renzik_shiv = { merc = "renzik", steps = {
        { kind = "clear", zone = "elwynn" },
        { kind = "kill", prefix = "defias_", count = 15, what = "DEFIAS" },
        { kind = "ability", slot = 2, count = 25 },
        { kind = "boss", zone = "duskwood" },
    } },
    renzik_loose_ends = { merc = "renzik", requires = { chain = "renzik_shiv", cleared = "deadmines" }, steps = {
        { kind = "dungeon", dungeon = "deadmines" },
        { kind = "ability", slot = 1, count = 60 },
    } },
    jorach_ravenholdt = { merc = "jorach", steps = {
        { kind = "clear", zone = "alterac" },
        { kind = "kill", prefix = "syndicate_", count = 25, what = "SYNDICATE" },
        { kind = "ability", slot = 2, count = 30 },
        { kind = "boss", zone = "alterac" },
    } },
    natpagle_fishing = { merc = "natpagle", steps = {
        { kind = "clear", zone = "dustwallow" },
        { kind = "kill", prefix = { "sawtooth_", "drywallow_" }, count = 15, what = "CROCOLISK" },
        { kind = "ability", slot = 2, count = 30 },
        { kind = "kill", race = "murloc", count = 25, what = "MURLOC" },
    } },
    jaina_theramore = { merc = "jaina", steps = {
        { kind = "clear", zone = "zephras" },
        { kind = "ability", slot = 2, count = 40 },
        { kind = "clear", zone = "silverpine", with = true },
        { kind = "boss", zone = "dustwallow" },
    } },
    thrall_warchief = { merc = "thrall", steps = {
        { kind = "clear", zone = "durotar" },
        { kind = "ability", slot = 1, count = 40 },
        { kind = "kill", prefix = "dragonmaw_", count = 15, what = "DRAGONMAW" },
        { kind = "boss", zone = "wetlands" },
    } },
    tyrande_elune = { merc = "tyrande", steps = {
        { kind = "clear", zone = "teldrassil" },
        { kind = "ability", slot = 2, count = 30 },
        { kind = "clear", zone = "darkshore", with = true },
        { kind = "kill", race = "satyr", count = 15, what = "SATYR" },
    } },
    magatha_grimtotem = { merc = "magatha", steps = {
        { kind = "clear", zone = "mulgore" },
        { kind = "kill", prefix = "grimtotem_", count = 15, what = "GRIMTOTEM" },
        { kind = "ability", slot = 2, count = 25 },
        { kind = "boss", zone = "thousandneedles" },
    } },
    magatha_whispers = { merc = "magatha", requires = { chain = "magatha_grimtotem", cleared = "wailing" }, steps = {
        { kind = "dungeon", dungeon = "wailing" },
        { kind = "kill", prefix = "druid_of_the_fang", zone = "wailing", count = 15, what = "FANG" },
    } },
    fandral_staghelm = { merc = "fandral", steps = {
        { kind = "clear", zone = "desolace" },
        { kind = "ability", slot = 1, count = 40 },
        { kind = "kill", race = "satyr", count = 20, what = "SATYR" },
        { kind = "boss", zone = "feralas" },
    } },
    drekthar_frostwolf = { merc = "drekthar", steps = {
        { kind = "clear", zone = "alterac" },
        { kind = "ability", slot = 1, count = 40 },
        { kind = "kill", race = "ogre", count = 20, what = "OGRE" },
        { kind = "boss", zone = "hinterlands" },
    } },
    thrall_ragefire = { merc = "thrall", requires = { chain = "thrall_warchief", cleared = "ragefire" }, steps = {
        { kind = "dungeon", dungeon = "ragefire" },
        { kind = "kill", prefix = "searing_blade_", zone = "ragefire", count = 20, what = "SEARINGBLADE" },
    } },
    sylvanas_arugal = { merc = "sylvanas", requires = { chain = "sylvanas_forsaken", cleared = "shadowfang" }, steps = {
        { kind = "dungeon", dungeon = "shadowfang" },
        { kind = "kill", race = "worgen", zone = "shadowfang", count = 25, what = "WORGEN" },
    } },
    shandris_blackfathom = { merc = "shandris", requires = { chain = "shandris_sentinel" }, steps = {
        { kind = "kill", prefix = "twilight_", zone = "blackfathom", count = 20, what = "TWILIGHT", unlock = "blackfathom_aquanis" },
    } },
    windsor_stockade = { merc = "windsor", requires = { chain = "windsor_marshal", cleared = "stockade" }, steps = {
        { kind = "dungeon", dungeon = "stockade" },
        { kind = "kill", prefix = "defias_", zone = "stockade", count = 30, what = "DEFIAS" },
    } },
    magni_gnomeregan = { merc = "magni", requires = { chain = "magni_ironforge", cleared = "gnomeregan" }, steps = {
        { kind = "dungeon", dungeon = "gnomeregan" },
        { kind = "kill", prefix = "irradiated_", zone = "gnomeregan", count = 20, what = "IRRADIATED" },
    } },
    cairne_kraul = { merc = "cairne", requires = { chain = "cairne_mulgore", cleared = "kraul" }, steps = {
        { kind = "dungeon", dungeon = "kraul" },
        { kind = "kill", prefix = { "razorfen_", "deaths_head_" }, zone = "kraul", count = 25, what = "RAZORFEN" },
    } },
}
-- The chains in the order of the collection, a mercenary's chains in the order they follow.
MC.QUEST_CHAIN_ORDER = {}
do
    local byMerc = {}
    for id, chain in pairs(MC.QUEST_CHAINS) do
        chain.id = id
        byMerc[chain.merc] = byMerc[chain.merc] or {}
        table.insert(byMerc[chain.merc], chain)
    end
    for _, merc in ipairs(MC.MERC_ORDER) do
        local list = byMerc[merc] or {}
        -- A chain that requires another comes after it.
        table.sort(list, function(a, b)
            if a.requires and a.requires.chain == b.id then return false end
            if b.requires and b.requires.chain == a.id then return true end
            return a.id < b.id
        end)
        for _, chain in ipairs(list) do MC.QUEST_CHAIN_ORDER[#MC.QUEST_CHAIN_ORDER + 1] = chain.id end
    end
end

-- Saves from before chains had ids kept their progress under the mercenary's id.
local function Migrate(store)
    if not store.quests or store.quests.v == 2 then return end
    for _, id in ipairs(MC.QUEST_CHAIN_ORDER) do
        local merc = MC.QUEST_CHAINS[id].merc
        local old = store.quests[merc]
        if type(old) == "table" and old.step then
            store.quests[id] = store.quests[id] or old
            store.quests[merc] = nil
        end
    end
    store.quests.v = 2
end

function Quests.State(store, chain)
    store.quests = store.quests or { v = 2 }
    Migrate(store)
    local st = store.quests[chain]
    if not st then
        st = { step = 1, count = 0 }
        store.quests[chain] = st
    end
    return st
end

function Quests.Unlocked(store, key)
    return store.unlocks ~= nil and store.unlocks[key] == true
end

function Quests.Done(store, chain)
    return Quests.State(store, chain).step > #MC.QUEST_CHAINS[chain].steps
end

-- Whether a chain can be followed: its mercenary is recruited and what it requires is met.
function Quests.Open(store, chain)
    local def = MC.QUEST_CHAINS[chain]
    if not def then return false end
    local entry = store.mercs[def.merc]
    if not (entry and entry.owned) then return false end
    local req = def.requires
    if req then
        if req.chain and not Quests.Done(store, req.chain) then return false end
        if req.level and entry.level < req.level then return false end
        if req.unlock and not Quests.Unlocked(store, req.unlock) then return false end
        if req.cleared and (Bounty.ZoneState(store, req.cleared).normal or 0) == 0 then return false end
    end
    return true
end

-- The open chains of a mercenary.
function Quests.ChainsOf(store, merc)
    local out = {}
    for _, id in ipairs(MC.QUEST_CHAIN_ORDER) do
        if MC.QUEST_CHAINS[id].merc == merc and Quests.Open(store, id) then out[#out + 1] = id end
    end
    return out
end

-- The current task of a chain (nil once it is done) and its index.
function Quests.Current(store, chain)
    local st = Quests.State(store, chain)
    return MC.QUEST_CHAINS[chain].steps[st.step], st.step
end

-- How far the current task is: done so far and needed.
function Quests.Progress(store, chain)
    local task = Quests.Current(store, chain)
    if not task then return 0, 0 end
    local st = Quests.State(store, chain)
    local merc = MC.QUEST_CHAINS[chain].merc
    if task.kind == "level" then
        local level = store.mercs[merc] and store.mercs[merc].level or 1
        return math.min(level, task.level), task.level
    elseif task.kind == "clear" and not task.with then
        return (Bounty.ZoneState(store, task.zone).normal or 0) > 0 and 1 or 0, 1
    end
    return math.min(st.count, task.count or 1), task.count or 1
end

function Quests.IsReady(store, chain)
    if not Quests.Open(store, chain) or not Quests.Current(store, chain) then return false end
    local done, need = Quests.Progress(store, chain)
    return done >= need
end

-- How many tasks wait to be handed in (the board's "?").
function Quests.ReadyCount(store)
    local n = 0
    for _, id in ipairs(MC.QUEST_CHAIN_ORDER) do
        if Quests.IsReady(store, id) then n = n + 1 end
    end
    return n
end

-- Hands in the current task: its coins to the mercenary, its unlock, and the next task.
-- Returns the coins and the unlock, or nil.
function Quests.TurnIn(store, chain)
    if not Quests.IsReady(store, chain) then return nil end
    local task, step = Quests.Current(store, chain)
    local st = Quests.State(store, chain)
    local coins = Quests.COINS[step] or 0
    local entry = store.mercs[MC.QUEST_CHAINS[chain].merc]
    entry.coins = entry.coins + coins
    if task.unlock then
        store.unlocks = store.unlocks or {}
        store.unlocks[task.unlock] = true
    end
    st.step, st.count = step + 1, 0
    return coins, task.unlock
end

-- Progress from play ------------------------------------------------------------------------------

local function Matches(task, id)
    local def = MC.Enemies[id]
    if task.race then return def ~= nil and def.race == task.race end
    local prefixes = type(task.prefix) == "table" and task.prefix or { task.prefix }
    for _, prefix in ipairs(prefixes) do
        if type(id) == "string" and id:sub(1, #prefix) == prefix then return true end
    end
    return false
end

-- Adds to the counting task of every open chain of `merc` that `test` accepts; chains whose task
-- became ready go into `ready`.
local function Count(store, merc, ready, amountOf)
    for _, chain in ipairs(Quests.ChainsOf(store, merc)) do
        local task = Quests.Current(store, chain)
        local amount = task and amountOf(task) or 0
        if amount > 0 then
            local was = Quests.IsReady(store, chain)
            local st = Quests.State(store, chain)
            st.count = st.count + amount
            if not was and Quests.IsReady(store, chain) then ready[#ready + 1] = chain end
        end
    end
end

-- After a won or lost battle (before the run moves on): kills, abilities used and bosses. Chains whose
-- task became ready are listed in run.questsReady.
function Quests.OnBattle(store, run, b)
    local won = b.phase == "won"
    run.questsReady = run.questsReady or {}
    for _, u in pairs(b.units) do
        local member = u.side == "ally" and u.pidx and run.party[u.pidx]
        if member and not member.guest then
            Count(store, member.id, run.questsReady, function(task)
                if task.kind == "kill" and (not task.zone or task.zone == run.zone) then
                    local n = 0
                    for _, foe in pairs(b.units) do
                        if foe.side == "enemy" and foe.dead and Matches(task, foe.id) then n = n + 1 end
                    end
                    return n
                elseif task.kind == "ability" then
                    return u.used and u.used[task.slot] or 0
                elseif task.kind == "boss" and won and task.zone == run.zone and not u.dead then
                    local node = Bounty.Node(run)
                    return (node and node.type == "boss") and 1 or 0
                end
                return 0
            end)
        end
    end
end

-- After a bounty or a dungeon is complete: "clear" and "dungeon" tasks that need the mercenary in the party.
function Quests.OnBounty(store, run)
    run.questsReady = run.questsReady or {}
    for _, member in ipairs(run.party) do
        if not member.guest then
            Count(store, member.id, run.questsReady, function(task)
                if task.kind == "clear" and task.with and task.zone == run.zone and not run.dungeon then return 1 end
                if task.kind == "dungeon" and run.dungeon and task.dungeon == run.dungeon then return 1 end
                return 0
            end)
        end
    end
end

-- The mercenaries of the chains in a list (the result page names them once each).
function Quests.MercsOf(chains)
    local out, seen = {}, {}
    for _, chain in ipairs(chains or {}) do
        local merc = MC.QUEST_CHAINS[chain] and MC.QUEST_CHAINS[chain].merc
        if merc and not seen[merc] then
            seen[merc] = true
            out[#out + 1] = merc
        end
    end
    return out
end
