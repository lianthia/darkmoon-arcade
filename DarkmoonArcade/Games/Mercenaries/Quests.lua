-- Tasks and stories: a chain of four tasks for each starting mercenary, close to its lore. A task is
-- done by playing as usual; it is then handed in at the task board by the fire (as in WoW), which pays
-- its coins and opens the next one. The last task of some chains opens a dungeon.
--
-- What a task asks (kind):
--   clear    the bounty of `zone` (with = the mercenary in the party; without, an earlier clear counts)
--   kill     `count` foes of a `race` or an id `prefix` (optionally in `zone`), the mercenary in the party
--   ability  the mercenary's ability `slot`, `count` times
--   boss     the boss of `zone` falls while the mercenary stands
--   level    the mercenary reaches `level` (counts from before, too)
-- Texts: MC_Q_<merc>_<step>_TITLE / _TEXT; kill targets MC_QK_<what>.
-- Saved per mercenary in store.quests[merc] = { step, count }; step 5 = chain done.

local _, ns = ...
local MC = ns.Mercenaries
local Bounty = MC.Bounty

local Quests = {}
MC.Quests = Quests

Quests.COINS = { 10, 15, 15, 20 }
Quests.STEPS = 4

MC.QUESTS = {
    cairne = {
        { kind = "clear", zone = "mulgore" },
        { kind = "kill", race = "centaur", count = 15, what = "CENTAUR" },
        { kind = "ability", slot = 2, count = 25 },
        { kind = "boss", zone = "barrens" },
    },
    bolvar = {
        { kind = "clear", zone = "elwynn" },
        { kind = "kill", prefix = "defias_", count = 20, what = "DEFIAS" },
        { kind = "boss", zone = "westfall" },
        { kind = "level", level = 17, unlock = "deadmines" },
    },
    mankrik = {
        { kind = "clear", zone = "durotar" },
        { kind = "kill", prefix = { "razormane_", "bristleback_" }, count = 10, what = "QUILBOAR" },
        { kind = "ability", slot = 1, count = 40 },
        { kind = "boss", zone = "barrens" },
    },
    shandris = {
        { kind = "clear", zone = "teldrassil" },
        { kind = "clear", zone = "darkshore", with = true },
        { kind = "ability", slot = 1, count = 40 },
        { kind = "boss", zone = "ashenvale" },
    },
    benedictus = {
        { kind = "clear", zone = "tirisfal" },
        { kind = "ability", slot = 2, count = 30 },
        { kind = "kill", race = "undead", count = 20, what = "UNDEAD" },
        { kind = "boss", zone = "duskwood" },
    },
    hamuul = {
        { kind = "clear", zone = "mulgore" },
        { kind = "ability", slot = 2, count = 30 },
        { kind = "kill", race = "beast", zone = "barrens", count = 15, what = "BEAST" },
        { kind = "level", level = 17, unlock = "wailing" },
    },
}
-- The chains in the order of the collection.
MC.QUEST_ORDER = {}
for _, id in ipairs(MC.MERC_ORDER) do
    if MC.QUESTS[id] then MC.QUEST_ORDER[#MC.QUEST_ORDER + 1] = id end
end

function Quests.State(store, merc)
    store.quests = store.quests or {}
    local st = store.quests[merc]
    if not st then
        st = { step = 1, count = 0 }
        store.quests[merc] = st
    end
    return st
end

-- Whether a chain can be followed: its mercenary is recruited.
function Quests.Open(store, merc)
    return MC.QUESTS[merc] ~= nil and store.mercs[merc] ~= nil and store.mercs[merc].owned == true
end

-- The current task (nil once the chain is done) and its index.
function Quests.Current(store, merc)
    local st = Quests.State(store, merc)
    return MC.QUESTS[merc][st.step], st.step
end

-- How far the current task is: done so far and needed.
function Quests.Progress(store, merc)
    local task = Quests.Current(store, merc)
    if not task then return 0, 0 end
    local st = Quests.State(store, merc)
    if task.kind == "level" then
        local level = store.mercs[merc] and store.mercs[merc].level or 1
        return math.min(level, task.level), task.level
    elseif task.kind == "clear" and not task.with then
        return (Bounty.ZoneState(store, task.zone).normal or 0) > 0 and 1 or 0, 1
    end
    return math.min(st.count, task.count or 1), task.count or 1
end

function Quests.IsReady(store, merc)
    if not Quests.Open(store, merc) or not Quests.Current(store, merc) then return false end
    local done, need = Quests.Progress(store, merc)
    return done >= need
end

-- Whether any task waits to be handed in (the board's "?").
function Quests.AnyReady(store)
    for _, merc in ipairs(MC.QUEST_ORDER) do
        if Quests.IsReady(store, merc) then return true end
    end
    return false
end

-- Hands in the current task: its coins to the mercenary, its unlock, and the next task.
-- Returns the coins and the unlock, or nil.
function Quests.TurnIn(store, merc)
    if not Quests.IsReady(store, merc) then return nil end
    local task, step = Quests.Current(store, merc)
    local st = Quests.State(store, merc)
    local coins = Quests.COINS[step] or 0
    local entry = store.mercs[merc]
    entry.coins = entry.coins + coins
    if task.unlock then
        store.unlocks = store.unlocks or {}
        store.unlocks[task.unlock] = true
    end
    st.step, st.count = step + 1, 0
    return coins, task.unlock
end

function Quests.Unlocked(store, key)
    return store.unlocks ~= nil and store.unlocks[key] == true
end

-- Progress from play ------------------------------------------------------------------------------

local function Matches(task, unit)
    if task.race then return unit.race == task.race end
    local prefixes = type(task.prefix) == "table" and task.prefix or { task.prefix }
    for _, prefix in ipairs(prefixes) do
        if type(unit.id) == "string" and unit.id:sub(1, #prefix) == prefix then return true end
    end
    return false
end

-- Adds to a counting task; returns true when that made it ready.
local function Count(store, merc, amount)
    if amount <= 0 or not Quests.Open(store, merc) then return false end
    local was = Quests.IsReady(store, merc)
    local st = Quests.State(store, merc)
    st.count = st.count + amount
    return not was and Quests.IsReady(store, merc)
end

-- After a won or lost battle (before the run moves on): kills, abilities used and bosses. Mercenaries
-- whose task became ready are listed in run.questsReady.
function Quests.OnBattle(store, run, b)
    local won = b.phase == "won"
    run.questsReady = run.questsReady or {}
    for _, u in pairs(b.units) do
        local member = u.side == "ally" and u.pidx and run.party[u.pidx]
        if member and not member.guest and Quests.Open(store, member.id) then
            local merc = member.id
            local task = Quests.Current(store, merc)
            local amount = 0
            if task and task.kind == "kill" and (not task.zone or task.zone == run.zone) then
                for _, foe in pairs(b.units) do
                    if foe.side == "enemy" and foe.dead and Matches(task, MC.Enemies[foe.id] and
                        { id = foe.id, race = MC.Enemies[foe.id].race } or foe) then
                        amount = amount + 1
                    end
                end
            elseif task and task.kind == "ability" then
                amount = u.used and u.used[task.slot] or 0
            elseif task and task.kind == "boss" and won and task.zone == run.zone and not u.dead then
                local node = Bounty.Node(run)
                if node and node.type == "boss" then amount = 1 end
            end
            if Count(store, merc, amount) then run.questsReady[#run.questsReady + 1] = merc end
        end
    end
end

-- After a bounty is complete: "clear" tasks that need the mercenary in the party.
function Quests.OnBounty(store, run)
    run.questsReady = run.questsReady or {}
    for _, member in ipairs(run.party) do
        if not member.guest and Quests.Open(store, member.id) then
            local task = Quests.Current(store, member.id)
            if task and task.kind == "clear" and task.with and task.zone == run.zone then
                if Count(store, member.id, 1) then run.questsReady[#run.questsReady + 1] = member.id end
            end
        end
    end
end
