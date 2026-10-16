-- Items: loot from dungeons (later raids) and rewards of tasks. An item belongs to the mercenary who
-- received it (chosen when it drops) and never moves. A mercenary has a weapon slot and an armour slot,
-- and from the highest level a jewellery slot; an item fits the slot of its kind. The items it owns but
-- does not wear wait in its bag (jewellery found earlier waits there for the jewellery slot).
--
-- Every item has a small base value (weapons attack, armour health) and bonuses bought from a point
-- budget per rarity: what one point buys is MC.ITEM_POINT. Items are named and pictured after real
-- Classic loot; their points follow that item's stats (ItemData.lua, tools/gen_mercenaries_items.py).
-- Comfort bonuses (experience, coins) count outside fights.

local _, ns = ...
local MC = ns.Mercenaries
local Bounty = MC.Bounty

MC.ITEM_BUDGET = { common = 2, uncommon = 4, rare = 6, epic = 8, legendary = 10 }
-- The base value by rarity: weapons attack, armour health (in share of the mercenary's own).
local BASE_TIER = { common = 0, uncommon = 1, rare = 2, epic = 3, legendary = 4 }
local BASE = { weapon = { atkPct = 0.01 }, armor = { hpPct = 0.015 } }

MC.SCHOOLS = { "physical", "fire", "frost", "nature", "shadow", "holy", "arcane" }
-- What one budget point buys of each bonus.
MC.ITEM_POINT = {
    atkPct = 0.01, critChance = 0.01, hpPct = 0.015, spellPct = 0.015, takenPct = -0.01, regenPct = 0.005,
    xpPct = 0.05, coinPct = 0.05,
}
for _, school in ipairs(MC.SCHOOLS) do
    MC.ITEM_POINT["resist_" .. school] = 0.04
    if school ~= "physical" then MC.ITEM_POINT["school_" .. school] = 0.03 end
end
-- Bonuses that never change a fight.
MC.COMFORT = { xpPct = true, coinPct = true }

MC.Items = MC.Items or {}

-- The slots in order; the last one opens at the highest level.
MC.ITEM_SLOT_KINDS = { "weapon", "armor", "jewelry" }
local SLOT_OF = { weapon = 1, armor = 2, jewelry = 3 }

-- How many slots a mercenary has open.
function MC.ItemSlots(entry)
    return (entry.level or 1) >= MC.MAX_LEVEL and 3 or 2
end

-- The slot an item fits.
function MC.ItemSlot(item)
    return SLOT_OF[item.kind]
end

-- An item's bonuses: its base value plus what its points buy.
function MC.ItemMods(item)
    local mods = {}
    for k, v in pairs(BASE[item.kind] or {}) do mods[k] = (mods[k] or 0) + v * BASE_TIER[item.rarity] end
    for k, points in pairs(item.points) do mods[k] = (mods[k] or 0) + points * MC.ITEM_POINT[k] end
    return mods
end

-- Points spent; never more than its rarity's budget.
function MC.ItemPoints(item)
    local sum = 0
    for _, points in pairs(item.points) do sum = sum + points end
    return sum
end

local function Holdings(entry)
    entry.items = entry.items or {}
    entry.worn = entry.worn or {}
    -- An item in a slot it does not fit (saved before the slots had kinds) goes back to the bag.
    for slot, id in pairs(entry.worn) do
        local item = MC.Items[id]
        if not item or MC.ItemSlot(item) ~= slot then entry.worn[slot] = nil end
    end
    return entry
end

function Bounty.OwnsItem(entry, id)
    for _, owned in ipairs(Holdings(entry).items) do
        if owned == id then return true end
    end
    return false
end

-- Gives a mercenary an item: worn at once when its slot is open and free. An item it already owns
-- comes back as "duplicate" (to be disenchanted); otherwise "new".
function Bounty.GiveItem(store, mercId, id)
    local entry = Holdings(Bounty.Entry(store, mercId))
    if Bounty.OwnsItem(entry, id) then return "duplicate" end
    entry.items[#entry.items + 1] = id
    local slot = MC.ItemSlot(MC.Items[id])
    if slot <= MC.ItemSlots(entry) and not entry.worn[slot] then entry.worn[slot] = id end
    return "new"
end

-- Wears an owned item in its slot (the one worn there goes back to the bag); `id` nil empties `slot`.
function Bounty.WearItem(store, mercId, slot, id)
    local entry = Holdings(Bounty.Entry(store, mercId))
    if slot < 1 or slot > MC.ItemSlots(entry) then return false end
    if id and not (Bounty.OwnsItem(entry, id) and MC.ItemSlot(MC.Items[id]) == slot) then return false end
    entry.worn[slot] = id
    return true
end

function Bounty.IsWorn(entry, id)
    for slot = 1, #MC.ITEM_SLOT_KINDS do
        if entry.worn and entry.worn[slot] == id then return true end
    end
    return false
end

-- The bonuses of the items a mercenary wears and their enchants (the jewellery slot counts from the
-- highest level on).
function Bounty.WornMods(entry)
    local mods = {}
    for slot = 1, MC.ItemSlots(entry) do
        local id = entry.worn and entry.worn[slot]
        local item = MC.Items[id]
        if item then
            Bounty.AddMods(mods, MC.ItemMods(item))
            local recipe = MC.Recipes[entry.enchants and entry.enchants[id]]
            if recipe then Bounty.AddMods(mods, MC.RecipeMods(recipe)) end
        end
    end
    return mods
end

-- Finds -------------------------------------------------------------------------------------------

-- A found item waits in store.pendingItems until the player chose who gets it (it survives a reload).
function Bounty.QueueItem(store, id)
    store.pendingItems = store.pendingItems or {}
    store.pendingItems[#store.pendingItems + 1] = id
end

function Bounty.PendingItem(store)
    return store.pendingItems and store.pendingItems[1]
end

-- Hands the first waiting item to a recruited mercenary, or disenchants it (mercId nil). A mercenary
-- that owns it already gets its materials instead. Returns "new" or "disenchanted", and for the latter
-- the material and how many.
function Bounty.ClaimItem(store, mercId, rng)
    local id = Bounty.PendingItem(store)
    if not id then return nil end
    if mercId and not (store.mercs[mercId] and store.mercs[mercId].owned) then return nil end
    table.remove(store.pendingItems, 1)
    if #store.pendingItems == 0 then store.pendingItems = nil end
    if mercId and Bounty.GiveItem(store, mercId, id) == "new" then return "new" end
    return "disenchanted", Bounty.Disenchant(store, id, rng)
end

-- The items a mercenary owns but does not wear.
function Bounty.BagItems(entry)
    local out = {}
    for _, id in ipairs(entry.items or {}) do
        if not Bounty.IsWorn(entry, id) then out[#out + 1] = id end
    end
    return out
end
