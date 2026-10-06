-- Spellbounce: talent trees (pure logic, no WoW API).
-- Every class has a tree laid out like the classic talent frame: four columns, tiers that need
-- five points spent per tier above them, and talents that require another one first.

local _, ns = ...

local SB = ns.Spellbounce or {}
ns.Spellbounce = SB

local Talents = {}
SB.Talents = Talents

Talents.MAX_POINTS = 21
Talents.POINTS_PER_TIER = 5

-- The same skeleton for every class; `power` talents strengthen the class's own power.
Talents.TREE = {
    { id = "focus", tier = 1, col = 2, max = 5 },
    { id = "well", tier = 1, col = 3, max = 5 },
    { id = "power1", tier = 2, col = 1, max = 3 },
    { id = "secondwind", tier = 2, col = 3, max = 5 },
    { id = "runes", tier = 3, col = 1, max = 1, req = "power1" },
    { id = "ricochet", tier = 3, col = 4, max = 2 },
    { id = "power2", tier = 4, col = 1, max = 2, req = "runes" },
    { id = "pockets", tier = 4, col = 3, max = 2 },
    { id = "gilded", tier = 5, col = 2, max = 1, req = "power2" },
}
local BY_ID = {}
for _, t in ipairs(Talents.TREE) do BY_ID[t.id] = t end
Talents.BY_ID = BY_ID

-- Per rank: +6% red rune points, +8% moonwell width, +5% chance to keep a lost orb.
Talents.FOCUS, Talents.WELL, Talents.SECOND_WIND = 0.06, 0.08, 5

function Talents.Points(alloc)
    local n = 0
    for _, rank in pairs(alloc or {}) do n = n + rank end
    return n
end

local function SpentBelow(alloc, tier)
    local n = 0
    for _, t in ipairs(Talents.TREE) do
        if t.tier < tier then n = n + (alloc[t.id] or 0) end
    end
    return n
end

-- Whether one more point may go into talent `id`.
function Talents.CanAdd(alloc, id, available)
    local t = BY_ID[id]
    if not t then return false end
    if Talents.Points(alloc) >= available then return false end
    if (alloc[id] or 0) >= t.max then return false end
    if SpentBelow(alloc, t.tier) < (t.tier - 1) * Talents.POINTS_PER_TIER then return false end
    if t.req and (alloc[t.req] or 0) < BY_ID[t.req].max then return false end
    return true
end

-- An allocation is valid when every talent still meets its tier and requirement.
function Talents.Valid(alloc)
    for _, t in ipairs(Talents.TREE) do
        local rank = alloc[t.id] or 0
        if rank > 0 then
            if rank > t.max then return false end
            if SpentBelow(alloc, t.tier) < (t.tier - 1) * Talents.POINTS_PER_TIER then return false end
            if t.req and (alloc[t.req] or 0) < BY_ID[t.req].max then return false end
        end
    end
    return true
end

function Talents.CanRemove(alloc, id)
    if (alloc[id] or 0) <= 0 then return false end
    alloc[id] = alloc[id] - 1
    local ok = Talents.Valid(alloc)
    alloc[id] = alloc[id] + 1
    return ok
end

-- The game-facing modifiers of an allocation.
function Talents.Modifiers(alloc)
    alloc = alloc or {}
    return {
        focus = (alloc.focus or 0) * Talents.FOCUS,
        well = (alloc.well or 0) * Talents.WELL,
        power = (alloc.power1 or 0) + (alloc.power2 or 0),
        refund = (alloc.secondwind or 0) * Talents.SECOND_WIND,
        powerRunes = alloc.runes or 0,
        bonusHits = (alloc.ricochet or 0) * 2,
        orbs = alloc.pockets or 0,
        gilded = (alloc.gilded or 0) > 0,
    }
end
