-- Mercenaries combat: two parties of three on the board, everyone picks an ability each turn and
-- all of them resolve by speed, lowest first. Pure logic on plain tables, so a battle can sit in the
-- saved variables between flights and continue exactly where it stopped.

local _, ns = ...
ns.Mercenaries = ns.Mercenaries or {}
local MC = ns.Mercenaries

local Combat = {}
MC.Combat = Combat

-- Each role deals double damage to the role it beats.
Combat.BEATS = { protector = "fighter", fighter = "caster", caster = "protector" }
Combat.BOARD = 3
-- From this turn on everyone takes growing damage, so no battle can stall forever.
Combat.FATIGUE_TURN = 30

-- A target above the attacker's level makes hits miss more often and land softer, like in WoW.
Combat.GAP = { miss = 0.03, missSq = 0.008, missCap = 0.85, dmg = 0.06, dmgFloor = 0.15, bonus = 0.025, bonusCap = 1.25 }
Combat.RANK_BONUS = { 1, 1.12, 1.25 }

local GAP, BEATS = Combat.GAP, Combat.BEATS
local MOD = 2147483647

-- Random numbers ----------------------------------------------------------------------

function Combat.Seed(seed)
    local s = math.floor(math.abs(seed or 1)) % MOD
    if s == 0 then s = 1 end
    return s
end

-- Park-Miller generator: the state is one number in the saved battle, so a reload continues the
-- same sequence. With `n` it returns 1..n, otherwise a number in [0, 1).
function Combat.Random(b, n)
    b.rng = (b.rng * 16807) % MOD
    local r = (b.rng - 1) / (MOD - 1)
    if n then return math.min(n, math.floor(r * n) + 1) end
    return r
end
local Random = Combat.Random

-- Scaling -------------------------------------------------------------------------------

-- Base values describe a level 60 unit; a level 1 unit has half of them.
function Combat.LevelFactor(level)
    level = math.max(1, math.min(63, level or 1))
    return 0.5 + 0.5 * (level - 1) / 59
end

local function Mod(u, key)
    return u.mods[key] or 0
end

local function Buff(u, key)
    local sum = 0
    for _, buff in ipairs(u.buffs) do
        if buff.k == key then sum = sum + buff.v end
    end
    return sum
end
Combat.Mod, Combat.Buff = Mod, Buff

function Combat.Attack(u)
    return math.max(0, math.floor(u.atk * (1 + Buff(u, "atkPct")) + Buff(u, "atk") + 0.5))
end

local function Def(slot)
    return MC.Abilities[slot.id]
end

-- The value of an ability effect for this unit: level, rank and per-slot bonuses applied.
function Combat.Value(u, slotIndex, base)
    local slot = u.abilities[slotIndex]
    local rank = Combat.RANK_BONUS[slot and slot.rank or 1] or 1
    return base * Combat.LevelFactor(u.level) * rank * (1 + Mod(u, "abil" .. slotIndex .. "_value"))
end

function Combat.Speed(b, u, slotIndex)
    local def = Def(u.abilities[slotIndex])
    local speed = def.speed + Mod(u, "speed") + Mod(u, "abil" .. slotIndex .. "_speed") + Buff(u, "speed")
    return math.max(0, speed)
end

function Combat.Cooldown(u, slotIndex)
    local def = Def(u.abilities[slotIndex])
    return math.max(0, (def.cd or 0) + Mod(u, "abil" .. slotIndex .. "_cd"))
end

-- Units ---------------------------------------------------------------------------------

local function Opponent(side)
    return side == "ally" and "enemy" or "ally"
end
Combat.Opponent = Opponent

-- spec: { id, kind, role, race, level, atk, hp (both at level 60), abilities = { {id, rank} },
--         mods = { ... }, display, npc }
local function NewUnit(b, side, spec)
    b.nextUid = b.nextUid + 1
    local factor = Combat.LevelFactor(spec.level)
    local mods = spec.mods or {}
    local maxHp = math.max(1, math.floor(spec.hp * factor * (1 + (mods.hpPct or 0)) + 0.5))
    local u = {
        uid = b.nextUid,
        side = side,
        id = spec.id,
        kind = spec.kind or "merc",
        -- Party slot of a mercenary, so the run knows who fell.
        pidx = spec.pidx,
        role = spec.role or "neutral",
        race = spec.race,
        level = spec.level,
        atk = math.max(0, spec.atk * factor * (1 + (mods.atkPct or 0))),
        maxHp = maxHp,
        hp = maxHp,
        abilities = {},
        mods = mods,
        st = {},
        buffs = {},
        dots = {},
    }
    for i, entry in ipairs(spec.abilities) do
        u.abilities[i] = { id = entry.id or entry[1], rank = entry.rank or entry[2] or 1, cd = 0 }
    end
    for i, slot in ipairs(u.abilities) do
        if not Def(slot).passive and not mods.readyStart then slot.cd = Combat.Cooldown(u, i) end
    end
    b.units[u.uid] = u
    return u
end

function Combat.Unit(b, uid)
    return b.units[uid]
end

-- A new battle: the allies wait on the bench until they are deployed, the enemies start on the
-- board with any extras waiting in reserve.
function Combat.New(allySpecs, enemySpecs, seed)
    local b = {
        rng = Combat.Seed(seed),
        turn = 1,
        phase = "deploy",
        nextUid = 0,
        units = {},
        board = { ally = {}, enemy = {} },
        bench = { ally = {}, enemy = {} },
        events = {},
        log = { deaths = { ally = 0, enemy = 0 } },
    }
    for _, spec in ipairs(allySpecs) do
        local u = NewUnit(b, "ally", spec)
        b.bench.ally[#b.bench.ally + 1] = u.uid
    end
    for i, spec in ipairs(enemySpecs) do
        local u = NewUnit(b, "enemy", spec)
        local list = i <= Combat.BOARD and b.board.enemy or b.bench.enemy
        list[#list + 1] = u.uid
        if i <= Combat.BOARD then Combat.OnEnter(b, u) end
    end
    return b
end

local function Event(b, e)
    b.events[#b.events + 1] = e
end
Combat.Event = Event

function Combat.OnEnter(b, u)
    if u.mods.startShield then
        u.st.shield = true
        Event(b, { t = "shield", dst = u.uid })
    end
end

-- How many allies the player still has to put on the board.
function Combat.DeploySlots(b)
    return math.min(Combat.BOARD - #b.board.ally, #b.bench.ally)
end

function Combat.Deploy(b, uid)
    if b.phase ~= "deploy" and b.phase ~= "replace" then return false end
    for i, id in ipairs(b.bench.ally) do
        if id == uid and #b.board.ally < Combat.BOARD then
            table.remove(b.bench.ally, i)
            b.board.ally[#b.board.ally + 1] = uid
            Combat.OnEnter(b, b.units[uid])
            if Combat.DeploySlots(b) == 0 then b.phase = "command" end
            return true
        end
    end
    return false
end

-- Targets -------------------------------------------------------------------------------

local function Alive(b, side)
    local list = {}
    for _, uid in ipairs(b.board[side]) do
        local u = b.units[uid]
        if not u.dead then list[#list + 1] = u end
    end
    return list
end
Combat.Alive = Alive

-- Single-target choices against `side`: stealthed units can't be picked, taunting units must be.
function Combat.Targetable(b, side)
    local visible, taunting = {}, {}
    for _, u in ipairs(Alive(b, side)) do
        if not u.st.stealth then
            visible[#visible + 1] = u
            if u.st.taunt then taunting[#taunting + 1] = u end
        end
    end
    return #taunting > 0 and taunting or visible
end

function Combat.ValidTargets(b, u, slotIndex)
    local def = Def(u.abilities[slotIndex])
    if def.target == "enemy" then return Combat.Targetable(b, Opponent(u.side)) end
    if def.target == "ally" then return Alive(b, u.side) end
    return {}
end

function Combat.Available(u, slotIndex)
    local slot = u.abilities[slotIndex]
    return slot ~= nil and slot.cd <= 0 and not Def(slot).passive
end

function Combat.SetChoice(b, uid, slotIndex, targetUid)
    local u = b.units[uid]
    if b.phase ~= "command" or not u or u.side ~= "ally" or u.dead or not Combat.Available(u, slotIndex) then
        return false
    end
    local def = Def(u.abilities[slotIndex])
    if def.target == "enemy" or def.target == "ally" then
        local ok = false
        for _, t in ipairs(Combat.ValidTargets(b, u, slotIndex)) do
            if t.uid == targetUid then ok = true end
        end
        if not ok then return false end
    else
        targetUid = nil
    end
    u.choice = { slot = slotIndex, target = targetUid }
    return true
end

function Combat.ClearChoice(b, uid)
    local u = b.units[uid]
    if u then u.choice = nil end
end

function Combat.Ready(b)
    if b.phase ~= "command" then return false end
    for _, u in ipairs(Alive(b, "ally")) do
        if not u.choice then return false end
    end
    return true
end

-- Damage and healing ----------------------------------------------------------------------

local Kill

local function Heal(b, src, tgt, amount)
    if tgt.dead or amount <= 0 then return 0 end
    amount = math.floor(amount * (1 + Mod(src, "healPct")) + 0.5)
    local healed = math.min(amount, tgt.maxHp - tgt.hp)
    tgt.hp = tgt.hp + healed
    Event(b, { t = "heal", src = src.uid, dst = tgt.uid, amount = healed })
    return healed
end
Combat.Heal = Heal

local function GapMultiplier(src, tgt)
    local gap = tgt.level - src.level
    if gap > 0 then return math.max(GAP.dmgFloor, 1 - GAP.dmg * gap) end
    return math.min(GAP.bonusCap, 1 - GAP.bonus * gap)
end

local function MissChance(src, tgt)
    local gap = tgt.level - src.level
    if gap <= 0 then return 0 end
    return math.min(GAP.missCap, GAP.miss * gap + GAP.missSq * gap * gap)
end
Combat.MissChance = MissChance

-- Applies damage after shields; used directly by damage over time and fatigue.
local function Hurt(b, src, tgt, dmg, school, info)
    if tgt.st.shield then
        tgt.st.shield = nil
        Event(b, { t = "shieldBreak", src = src and src.uid, dst = tgt.uid })
        return 0
    end
    if tgt.st.absorb then
        local absorbed = math.min(tgt.st.absorb, dmg)
        tgt.st.absorb = tgt.st.absorb - absorbed
        if tgt.st.absorb <= 0 then tgt.st.absorb = nil end
        dmg = dmg - absorbed
        if absorbed > 0 then Event(b, { t = "absorb", dst = tgt.uid, amount = absorbed }) end
    end
    if dmg <= 0 then return 0 end
    tgt.hp = tgt.hp - dmg
    local e = { t = "damage", src = src and src.uid, dst = tgt.uid, amount = dmg, school = school }
    if info then
        for k, v in pairs(info) do e[k] = v end
    end
    Event(b, e)
    if tgt.hp <= 0 then Kill(b, tgt) end
    return dmg
end

-- The full damage pipeline for a hit from `src`: level gap, bonuses, role advantage, criticals.
local function Damage(ctx, src, tgt, amount, school, opts)
    local b = ctx.b
    if tgt.dead or amount <= 0 then return 0 end
    opts = opts or {}
    if Random(b) < MissChance(src, tgt) then
        Event(b, { t = "miss", src = src.uid, dst = tgt.uid })
        return 0
    end
    local mult = 1 + Mod(src, "dmgPct") + Buff(src, "dmg") + Mod(src, "school_" .. school)
    local adv = BEATS[src.role] == tgt.role
    if adv then mult = mult * 2 end
    mult = mult * GapMultiplier(src, tgt)
    mult = mult * math.max(0.1, 1 + Mod(tgt, "takenPct") + Buff(tgt, "taken"))
    if tgt.hp < tgt.maxHp * 0.3 then mult = mult * (1 + Mod(src, "executePct")) end
    if ctx.ambush then mult = mult * (1 + ctx.ambush) end
    local crit = Random(b) < Mod(src, "critChance")
    if crit then mult = mult * 2 end
    local dmg = math.max(1, math.floor(amount * mult + 0.5))
    local dealt = Hurt(b, src, tgt, dmg, school, { adv = adv or nil, crit = crit or nil })
    local steal = Mod(src, "lifesteal")
    if dealt > 0 and steal > 0 and not src.dead then Heal(b, src, src, dealt * steal) end
    if opts.attack and not src.dead then
        local thorns = Mod(tgt, "thorns") + Buff(tgt, "thorns")
        if thorns > 0 then
            Hurt(b, tgt, src, math.max(1, math.floor(thorns * Combat.LevelFactor(tgt.level) + 0.5)), "nature", { thorns = true })
        end
    end
    return dealt
end
Combat.Damage = Damage

Kill = function(b, u)
    if u.dead then return end
    u.dead = true
    u.hp = 0
    u.choice = nil
    b.log.deaths[u.side] = b.log.deaths[u.side] + 1
    Event(b, { t = "death", dst = u.uid })
    for _, ally in ipairs(Alive(b, u.side)) do
        local gain = Mod(ally, "vengeance")
        if gain > 0 then
            ally.buffs[#ally.buffs + 1] = { k = "atkPct", v = gain }
            Event(b, { t = "buff", dst = ally.uid, k = "atkPct", v = gain })
        end
    end
end

-- Effects -------------------------------------------------------------------------------------

local function Pick(b, list)
    if #list == 0 then return nil end
    return list[Random(b, #list)]
end

local function Neighbors(b, tgt)
    local list, row = {}, b.board[tgt.side]
    for i, uid in ipairs(row) do
        if uid == tgt.uid then
            for _, j in ipairs({ i - 1, i + 1 }) do
                local n = row[j] and b.units[row[j]]
                if n and not n.dead then list[#list + 1] = n end
            end
        end
    end
    return list
end

local function Targets(ctx, to)
    local b, u = ctx.b, ctx.unit
    to = to or "target"
    if to == "target" then return ctx.target and { ctx.target } or {} end
    if to == "self" then return { u } end
    if to == "all" then return Alive(b, Opponent(u.side)) end
    if to == "allies" then return Alive(b, u.side) end
    if to == "others" then
        local list = {}
        for _, a in ipairs(Alive(b, u.side)) do
            if a ~= u then list[#list + 1] = a end
        end
        return list
    end
    if to == "adjacent" then return ctx.target and Neighbors(b, ctx.target) or {} end
    if to == "random" then
        local t = Pick(b, Combat.Targetable(b, Opponent(u.side)))
        return t and { t } or {}
    end
    if to == "lowest" then
        local best
        for _, a in ipairs(Alive(b, u.side)) do
            if not best or a.hp / a.maxHp < best.hp / best.maxHp then best = a end
        end
        return best and { best } or {}
    end
    return {}
end

-- More damage taken and slower abilities are bad; for every other kind a negative value is.
function Combat.IsDebuff(buff)
    if buff.k == "taken" or buff.k == "speed" then return buff.v > 0 end
    return buff.v < 0
end

local function AddBuff(b, tgt, k, v, turns)
    tgt.buffs[#tgt.buffs + 1] = { k = k, v = v, t = turns }
    Event(b, { t = "buff", dst = tgt.uid, k = k, v = v })
end

local EFFECTS = {}

EFFECTS.damage = function(ctx, e)
    local value = ctx.value(e.v)
    for _ = 1, e.hits or 1 do
        for _, t in ipairs(Targets(ctx, e.to)) do
            Damage(ctx, ctx.unit, t, value, e.school or ctx.school)
        end
    end
end

-- A melee attack: the attacker's Attack plus a bonus, and the defender strikes back.
EFFECTS.attack = function(ctx, e)
    local u = ctx.unit
    local bonus = e.v and ctx.value(e.v) or 0
    for _, t in ipairs(Targets(ctx, e.to)) do
        Damage(ctx, u, t, Combat.Attack(u) + bonus, "physical", { attack = true })
        if not e.noRetaliate and not u.dead and Combat.Attack(t) > 0 then
            Damage({ b = ctx.b }, t, u, Combat.Attack(t), "physical", { retaliate = true })
        end
    end
end

EFFECTS.heal = function(ctx, e)
    for _, t in ipairs(Targets(ctx, e.to)) do Heal(ctx.b, ctx.unit, t, ctx.value(e.v)) end
end

EFFECTS.shield = function(ctx, e)
    for _, t in ipairs(Targets(ctx, e.to)) do
        t.st.shield = true
        Event(ctx.b, { t = "shield", dst = t.uid })
    end
end

EFFECTS.absorb = function(ctx, e)
    for _, t in ipairs(Targets(ctx, e.to)) do
        t.st.absorb = (t.st.absorb or 0) + math.floor(ctx.value(e.v) + 0.5)
        Event(ctx.b, { t = "absorbUp", dst = t.uid, amount = t.st.absorb })
    end
end

EFFECTS.taunt = function(ctx, e)
    for _, t in ipairs(Targets(ctx, e.to or "self")) do
        t.st.taunt = math.max(t.st.taunt or 0, e.turns or 1)
        Event(ctx.b, { t = "taunt", dst = t.uid })
    end
end

EFFECTS.stealth = function(ctx, e)
    for _, t in ipairs(Targets(ctx, e.to or "self")) do
        t.st.stealth = true
        Event(ctx.b, { t = "stealth", dst = t.uid })
    end
    ctx.keepStealth = true
end

EFFECTS.stun = function(ctx, e)
    for _, t in ipairs(Targets(ctx, e.to)) do
        if not t.dead and not t.st.stunImmune then
            t.st.stun = true
            Event(ctx.b, { t = "stun", dst = t.uid })
        end
    end
end

EFFECTS.dot = function(ctx, e)
    local u = ctx.unit
    local school = e.school or ctx.school
    local tick = ctx.value(e.v) * (1 + Mod(u, "dmgPct") + Mod(u, "school_" .. school))
    for _, t in ipairs(Targets(ctx, e.to)) do
        if not t.dead then
            t.dots[#t.dots + 1] = { v = tick, t = e.turns or 2, school = school, src = u.uid }
            Event(ctx.b, { t = "dot", dst = t.uid, school = school })
        end
    end
end

EFFECTS.hot = function(ctx, e)
    local tick = ctx.value(e.v)
    for _, t in ipairs(Targets(ctx, e.to)) do
        t.dots[#t.dots + 1] = { v = tick, t = e.turns or 2, heal = true, src = ctx.unit.uid }
        Event(ctx.b, { t = "hot", dst = t.uid })
    end
end

-- Buff kinds: atk (flat, scaled), atkPct, dmg, taken, speed, thorns (scaled), ambush.
EFFECTS.buff = function(ctx, e)
    local v = e.v
    if e.k == "atk" or e.k == "thorns" then v = ctx.value(v) end
    for _, t in ipairs(Targets(ctx, e.to)) do
        if not t.dead then AddBuff(ctx.b, t, e.k, v, e.turns) end
    end
end

EFFECTS.maxhp = function(ctx, e)
    local v = math.floor(ctx.value(e.v) + 0.5)
    for _, t in ipairs(Targets(ctx, e.to)) do
        if not t.dead then
            t.maxHp = t.maxHp + v
            t.hp = t.hp + v
            Event(ctx.b, { t = "maxhp", dst = t.uid, amount = v })
        end
    end
end

EFFECTS.cleanse = function(ctx, e)
    for _, t in ipairs(Targets(ctx, e.to)) do
        for i = #t.dots, 1, -1 do
            if not t.dots[i].heal then table.remove(t.dots, i) end
        end
        for i = #t.buffs, 1, -1 do
            if Combat.IsDebuff(t.buffs[i]) then table.remove(t.buffs, i) end
        end
        t.st.stun = nil
        Event(ctx.b, { t = "cleanse", dst = t.uid })
    end
end
Combat.EFFECTS = EFFECTS

-- Turn resolution ------------------------------------------------------------------------------

local function IsHarmful(def)
    return def.target == "enemy" or def.harmful
end

local function Retarget(b, u, def, targetUid)
    local t = targetUid and b.units[targetUid]
    if def.target == "enemy" then
        local valid = Combat.Targetable(b, Opponent(u.side))
        for _, v in ipairs(valid) do
            if v == t then return t end
        end
        return Pick(b, valid)
    elseif def.target == "ally" then
        if t and not t.dead then return t end
        return u
    end
    return nil
end

local function Perform(b, u, choice)
    local slot = u.abilities[choice.slot]
    local def = Def(slot)
    local target = Retarget(b, u, def, choice.target)
    if def.target == "enemy" and not target then
        Event(b, { t = "fizzle", src = u.uid, ability = slot.id })
        return
    end
    Event(b, { t = "act", src = u.uid, ability = slot.id, dst = target and target.uid, slot = choice.slot })
    slot.cd = Combat.Cooldown(u, choice.slot) + 1
    local ctx = {
        b = b, unit = u, target = target, school = def.school or "physical",
        value = function(base) return Combat.Value(u, choice.slot, base) end,
    }
    if IsHarmful(def) then
        for i = #u.buffs, 1, -1 do
            if u.buffs[i].k == "ambush" then
                ctx.ambush = (ctx.ambush or 0) + u.buffs[i].v
                table.remove(u.buffs, i)
            end
        end
    end
    for _, e in ipairs(def.effects) do
        if u.dead and not e.afterDeath then break end
        EFFECTS[e[1]](ctx, e)
    end
    if u.st.stealth and not ctx.keepStealth and IsHarmful(def) then
        u.st.stealth = nil
        Event(b, { t = "unstealth", dst = u.uid })
    end
end

-- Enemy choices: abilities by weight, targets with a taste for role advantage and wounded foes.
function Combat.Choose(b, u)
    local options, total = {}, 0
    for i, slot in ipairs(u.abilities) do
        if Combat.Available(u, i) then
            local def = Def(slot)
            local w = def.ai or 1
            if def.target == "ally" and def.effects[1][1] == "heal" then
                local hurt = false
                for _, a in ipairs(Alive(b, u.side)) do
                    if a.hp < a.maxHp * 0.7 then hurt = true end
                end
                if not hurt then w = 0.1 end
            end
            options[#options + 1] = { i = i, w = w }
            total = total + w
        end
    end
    if total <= 0 then return nil end
    local roll, pick = Random(b) * total, options[#options]
    for _, o in ipairs(options) do
        roll = roll - o.w
        if roll <= 0 then
            pick = o
            break
        end
    end
    local def = Def(u.abilities[pick.i])
    local target
    if def.target == "enemy" then
        local valid = Combat.Targetable(b, Opponent(u.side))
        local r = Random(b)
        if r < 0.45 then
            local favored = {}
            for _, t in ipairs(valid) do
                if BEATS[u.role] == t.role then favored[#favored + 1] = t end
            end
            target = Pick(b, favored)
        elseif r < 0.7 then
            for _, t in ipairs(valid) do
                if not target or t.hp < target.hp then target = t end
            end
        end
        target = target or Pick(b, valid)
    elseif def.target == "ally" then
        for _, a in ipairs(Alive(b, u.side)) do
            if not target or a.hp / a.maxHp < target.hp / target.maxHp then target = a end
        end
    end
    return { slot = pick.i, target = target and target.uid }
end

local function TickDots(b, u)
    for i = #u.dots, 1, -1 do
        local dot = u.dots[i]
        if not u.dead then
            local src = b.units[dot.src]
            if dot.heal then
                Heal(b, src or u, u, dot.v)
            else
                local dmg = math.max(1, math.floor(dot.v * math.max(0.1, 1 + Mod(u, "takenPct") + Buff(u, "taken")) + 0.5))
                Hurt(b, src, u, dmg, dot.school, { dot = true })
            end
        end
        dot.t = dot.t - 1
        if dot.t <= 0 then table.remove(u.dots, i) end
    end
end

local function Compact(b, side)
    local row = {}
    for _, uid in ipairs(b.board[side]) do
        if not b.units[uid].dead then row[#row + 1] = uid end
    end
    b.board[side] = row
end

local function EndOfTurn(b)
    for _, side in ipairs({ "ally", "enemy" }) do
        for _, u in ipairs(Alive(b, side)) do
            TickDots(b, u)
            local regen = Mod(u, "regenPct")
            if regen > 0 and not u.dead then Heal(b, u, u, u.maxHp * regen) end
        end
    end
    if b.turn >= Combat.FATIGUE_TURN then
        local share = 0.1 * (b.turn - Combat.FATIGUE_TURN + 1)
        for _, side in ipairs({ "ally", "enemy" }) do
            for _, u in ipairs(Alive(b, side)) do
                Hurt(b, nil, u, math.max(1, math.floor(u.maxHp * share)), "physical", { fatigue = true })
            end
        end
    end
    for _, u in pairs(b.units) do
        u.choice = nil
        for i = #u.buffs, 1, -1 do
            local buff = u.buffs[i]
            if buff.t then
                buff.t = buff.t - 1
                if buff.t <= 0 then table.remove(u.buffs, i) end
            end
        end
        if u.st.taunt then
            u.st.taunt = u.st.taunt - 1
            if u.st.taunt <= 0 then u.st.taunt = nil end
        end
        u.st.stunImmune = nil
        for _, slot in ipairs(u.abilities) do
            if slot.cd > 0 then slot.cd = slot.cd - 1 end
        end
    end
    Compact(b, "ally")
    Compact(b, "enemy")
    while #b.board.enemy < Combat.BOARD and #b.bench.enemy > 0 do
        local uid = table.remove(b.bench.enemy, 1)
        b.board.enemy[#b.board.enemy + 1] = uid
        Combat.OnEnter(b, b.units[uid])
        Event(b, { t = "enter", dst = uid })
    end
    b.turn = b.turn + 1
    local allyLeft = #b.board.ally + #b.bench.ally
    local enemyLeft = #b.board.enemy + #b.bench.enemy
    if allyLeft == 0 then
        b.phase = "lost"
    elseif enemyLeft == 0 then
        b.phase = "won"
    elseif Combat.DeploySlots(b) > 0 then
        b.phase = "replace"
    else
        b.phase = "command"
    end
    Event(b, { t = "turnEnd", phase = b.phase })
end

-- Runs one full turn. Returns the list of events for the board to play back.
function Combat.Resolve(b)
    if not Combat.Ready(b) then return nil end
    b.events = {}
    for _, u in ipairs(Alive(b, "enemy")) do u.choice = Combat.Choose(b, u) end
    local acts = {}
    for _, side in ipairs({ "ally", "enemy" }) do
        for _, u in ipairs(Alive(b, side)) do
            if u.choice then
                acts[#acts + 1] = { u = u, speed = Combat.Speed(b, u, u.choice.slot), tie = Random(b), choice = u.choice }
            end
        end
    end
    table.sort(acts, function(x, y)
        if x.speed ~= y.speed then return x.speed < y.speed end
        return x.tie < y.tie
    end)
    local order = {}
    for i, act in ipairs(acts) do order[i] = { uid = act.u.uid, speed = act.speed, ability = act.u.abilities[act.choice.slot].id } end
    Event(b, { t = "order", list = order })
    for _, act in ipairs(acts) do
        local u = act.u
        if not u.dead then
            if u.st.stun then
                u.st.stun = nil
                -- Nobody stays stunned two turns in a row.
                u.st.stunImmune = true
                Event(b, { t = "stunned", src = u.uid })
            else
                Perform(b, u, act.choice)
            end
        end
    end
    EndOfTurn(b)
    return b.events
end

-- The same choices the enemy makes, for the balance bot and an "auto" helper.
function Combat.AutoChoose(b)
    for _, u in ipairs(Alive(b, "ally")) do
        if not u.choice then
            local choice = Combat.Choose(b, u)
            if choice then
                u.choice = choice
            else
                u.choice = { slot = 1 }
            end
        end
    end
end
