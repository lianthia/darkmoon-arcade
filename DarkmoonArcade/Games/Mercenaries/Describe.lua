-- Builds the texts for abilities, equipment and treasures from their data, so descriptions
-- always show the values the combat really uses (level, rank and bonuses included).

local _, ns = ...
local MC = ns.Mercenaries
local Combat = MC.Combat
local L = ns.L

local Describe = {}
MC.Describe = Describe

local function Round(v)
    return math.floor(v + 0.5)
end

local function Percent(v)
    return Round(v * 100)
end

local function Turns(n)
    return n == 1 and L.MC_ONE_TURN or L.MC_TURNS:format(n)
end

local function Suffix(to)
    local key = to and L["MC_TO_" .. to:upper()]
    return key or ""
end

local function DamageName(school)
    return L["MC_DMG_" .. (school or "physical")]
end

-- `unit` needs level, mods and abilities (with ranks); `slot` is the ability's slot or nil.
local function Valuer(unit, slot)
    return function(base)
        if not unit then return Round(base) end
        local rank = slot and unit.abilities and unit.abilities[slot] and unit.abilities[slot].rank or 1
        local bonus = slot and (unit.mods and unit.mods["abil" .. slot .. "_value"] or 0) or 0
        return Round(base * Combat.LevelFactor(unit.level) * (Combat.RANK_BONUS[rank] or 1) * (1 + bonus))
    end
end

local EFFECT_TEXT = {
    damage = function(e, value, def)
        local text = L.MC_FX_DAMAGE:format(value(e.v), DamageName(e.school or def.school))
        if e.hits and e.hits > 1 then text = text .. L.MC_TIMES:format(e.hits) end
        return text .. Suffix(e.to)
    end,
    attack = function(e, value, _, unit)
        local bonus = e.v and e.v > 0 and value(e.v) or 0
        local atk = unit and Combat.Attack and unit.atk and Round(unit.atk) or nil
        if e.to == "all" then
            return atk and L.MC_FX_ATTACK_ALL:format(atk + bonus) or L.MC_FX_ATTACK_ALL_PLAIN
        end
        if atk then return L.MC_FX_ATTACK:format(atk + bonus) end
        return bonus > 0 and L.MC_FX_ATTACK_BONUS:format(bonus) or L.MC_FX_ATTACK_PLAIN
    end,
    heal = function(e, value) return L.MC_FX_HEAL:format(value(e.v)) .. Suffix(e.to and ("heal_" .. e.to)) end,
    shield = function(e) return L.MC_FX_SHIELD .. Suffix(e.to and ("buff_" .. e.to)) end,
    absorb = function(e, value) return L.MC_FX_ABSORB:format(value(e.v)) .. Suffix(e.to and ("buff_" .. e.to)) end,
    taunt = function(e) return L.MC_FX_TAUNT:format(Turns(e.turns or 1)) end,
    stealth = function() return L.MC_FX_STEALTH end,
    stun = function() return L.MC_FX_STUN end,
    dot = function(e, value, def)
        return L.MC_FX_DOT:format(value(e.v), DamageName(e.school or def.school), Turns(e.turns or 2)) .. Suffix(e.to)
    end,
    hot = function(e, value) return L.MC_FX_HOT:format(value(e.v), Turns(e.turns or 2)) .. Suffix(e.to and ("heal_" .. e.to)) end,
    buff = function(e, value)
        local v = e.v
        local text
        if e.k == "atk" then
            text = L.MC_BUFF_ATK:format(value(v))
        elseif e.k == "thorns" then
            text = L.MC_BUFF_THORNS:format(value(v))
        elseif e.k == "speed" then
            text = L.MC_BUFF_SPEED:format(v)
        else
            text = L["MC_BUFF_" .. e.k:upper()]:format(Percent(v))
        end
        if e.turns then text = text .. L.MC_FOR:format(Turns(e.turns)) end
        return text .. Suffix(e.to and ("buff_" .. e.to))
    end,
    maxhp = function(e, value) return L.MC_FX_MAXHP:format(value(e.v)) .. Suffix(e.to and ("buff_" .. e.to)) end,
    cleanse = function() return L.MC_FX_CLEANSE end,
}

function Describe.AbilityName(id)
    return L["MC_A_" .. id]
end

function Describe.Ability(id, unit, slot)
    local def = MC.Abilities[id]
    local value = Valuer(unit, slot)
    local parts = {}
    for _, e in ipairs(def.effects) do
        parts[#parts + 1] = EFFECT_TEXT[e[1]](e, value, def, unit)
    end
    return table.concat(parts, ". ") .. "."
end

-- Speed and cooldown line for tooltips and cards.
function Describe.AbilityStats(id, unit, slot)
    local def = MC.Abilities[id]
    local speed = def.speed
    local cd = def.cd or 0
    if unit and slot and unit.mods then
        speed = math.max(0, speed + (unit.mods.speed or 0) + (unit.mods["abil" .. slot .. "_speed"] or 0))
        cd = math.max(0, cd + (unit.mods["abil" .. slot .. "_cd"] or 0))
    end
    local text = L.MC_SPEED:format(speed)
    if cd > 0 then text = text .. "  ·  " .. L.MC_COOLDOWN:format(cd) end
    return text, speed, cd
end

-- Equipment and treasure effects; `abilities` names the owner's ability ids for slot mods.
function Describe.Mods(mods, abilities)
    local parts = {}
    local keys = {}
    for k in pairs(mods) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do
        local v = mods[k]
        local slot, what = k:match("^abil(%d)_(%a+)$")
        local school = k:match("^school_(%a+)$")
        local text
        if slot then
            local name = abilities and abilities[tonumber(slot)] and Describe.AbilityName(abilities[tonumber(slot)])
                or L.MC_ABILITY_N:format(tonumber(slot))
            if what == "value" then
                text = L.MC_MOD_ABIL_VALUE:format(name, Percent(v))
            elseif what == "speed" then
                text = L.MC_MOD_ABIL_SPEED:format(name, v)
            else
                text = L.MC_MOD_ABIL_CD:format(name, v)
            end
        elseif school then
            text = L.MC_MOD_SCHOOL:format(Percent(v), DamageName(school))
        elseif type(v) == "boolean" then
            text = L["MC_MOD_" .. k:upper()]
        elseif k == "thorns" or k == "speed" then
            text = L["MC_MOD_" .. k:upper()]:format(v)
        else
            text = L["MC_MOD_" .. k:upper()]:format(Percent(math.abs(v)))
        end
        parts[#parts + 1] = text
    end
    return table.concat(parts, ". ") .. "."
end

function Describe.MercName(id)
    return L["MC_M_" .. id]
end

-- Enemy names come from the generated name list; mercenaries have their own.
function Describe.UnitName(kind, id)
    if kind == "merc" then return Describe.MercName(id) end
    return L["MC_E_" .. id]
end

function Describe.ZoneName(id)
    return L["MC_Z_" .. id]
end

function Describe.RoleName(role)
    return L["MC_ROLE_" .. role]
end
