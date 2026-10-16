-- Enchanting: an item found twice, or one a mercenary no longer wants, is disenchanted into Classic's
-- enchanting materials, by the item's level and rarity with Classic's odds. Formulas, found only as
-- loot, turn materials into an enchant; an item holds one enchant, a new one replaces it. Materials and
-- known formulas belong to the whole collection (store.materials, store.recipes); an item's enchant to
-- the mercenary that owns the item (entry.enchants).
--
-- A formula's tier is that of its strongest material (ItemData.lua), so the best enchants need the
-- materials of the hardest content: farming the first dungeons never leads to them.

local _, ns = ...
local MC = ns.Mercenaries
local Bounty = MC.Bounty
local Random = MC.Combat.Random

-- Classic's disenchanting by item level: dust and essence (id, least, most) and the shard of rare items.
MC.DISENCHANT = {
    { level = 15, dust = { 10940, 1, 2 }, essence = { 10938, 1, 2 }, shard = 10978 },
    { level = 20, dust = { 10940, 2, 3 }, essence = { 10939, 1, 2 }, shard = 10978 },
    { level = 25, dust = { 10940, 4, 6 }, essence = { 10998, 1, 2 }, shard = 10978 },
    { level = 30, dust = { 11083, 1, 2 }, essence = { 11082, 1, 2 }, shard = 11084 },
    { level = 35, dust = { 11083, 2, 5 }, essence = { 11134, 1, 2 }, shard = 11138 },
    { level = 40, dust = { 11137, 1, 2 }, essence = { 11135, 1, 2 }, shard = 11139 },
    { level = 45, dust = { 11137, 2, 5 }, essence = { 11174, 1, 2 }, shard = 11177 },
    { level = 50, dust = { 11176, 1, 2 }, essence = { 11175, 1, 2 }, shard = 11178 },
    { level = 55, dust = { 11176, 2, 5 }, essence = { 16202, 1, 2 }, shard = 14343 },
    { level = 60, dust = { 16204, 1, 2 }, essence = { 16203, 1, 2 }, shard = 14344 },
    { level = math.huge, dust = { 16204, 2, 5 }, essence = { 16203, 2, 3 }, shard = 14344 },
}
MC.NEXUS_CRYSTAL = 20725
-- What a formula's bonus is worth by its tier, in budget points (MC.ITEM_POINT).
MC.RECIPE_POINTS = { 1, 2, 3, 4 }
-- "All resistances" spreads its points over the magic schools at half the worth each.
local MAGIC = { "fire", "frost", "nature", "shadow", "holy", "arcane" }

local function Bracket(level)
    for _, b in ipairs(MC.DISENCHANT) do
        if (level or 0) <= b.level then return b end
    end
end

-- The possible results of disenchanting an item: { chance (0..1), material, least, most }.
-- Uncommon armour mostly gives dust, uncommon weapons mostly essence, rare items a shard, epic items
-- shards or (from level 56) a Nexus Crystal. A common item only gives a pinch of dust.
function MC.DisenchantResults(item)
    local b = Bracket(item.level)
    local dust, essence = b.dust, b.essence
    if item.rarity == "common" then
        return { { 1, dust[1], 1, 1 } }
    elseif item.rarity == "uncommon" then
        local dustChance = item.kind == "weapon" and 0.2 or 0.75
        return {
            { dustChance, dust[1], dust[2], dust[3] },
            { 0.95 - dustChance, essence[1], essence[2], essence[3] },
            { 0.05, b.shard, 1, 1 },
        }
    elseif item.rarity == "rare" then
        if item.level >= 56 then return { { 0.995, b.shard, 1, 1 }, { 0.005, MC.NEXUS_CRYSTAL, 1, 1 } } end
        return { { 1, b.shard, 1, 1 } }
    elseif item.rarity == "epic" then
        if item.level >= 61 then return { { 1, MC.NEXUS_CRYSTAL, 1, 2 } } end
        if item.level >= 56 then return { { 1, MC.NEXUS_CRYSTAL, 1, 1 } } end
        return { { 1, b.shard, 2, 4 } }
    end
    return { { 1, MC.NEXUS_CRYSTAL, 2, 3 } }
end

local function Rng(rng)
    return rng or { rng = math.random(1, 2147483646) }
end

function Bounty.Materials(store)
    store.materials = store.materials or {}
    return store.materials
end

function Bounty.AddMaterial(store, id, count)
    local bag = Bounty.Materials(store)
    bag[id] = math.max(0, (bag[id] or 0) + count)
    if bag[id] == 0 then bag[id] = nil end
end

-- Disenchants one item (a duplicate find, say) into the bag; returns the material and how many.
function Bounty.Disenchant(store, itemId, rng)
    local item = MC.Items[itemId]
    if not item then return nil end
    rng = Rng(rng)
    local results = MC.DisenchantResults(item)
    local roll, pick = Random(rng), results[#results]
    for _, r in ipairs(results) do
        if roll < r[1] then
            pick = r
            break
        end
        roll = roll - r[1]
    end
    local count = pick[3] + Random(rng, pick[4] - pick[3] + 1) - 1
    Bounty.AddMaterial(store, pick[2], count)
    return pick[2], count
end

-- Disenchants an item a mercenary owns but does not wear; it and its enchant are gone for good.
function Bounty.DisenchantOwned(store, mercId, itemId, rng)
    local entry = store.mercs[mercId]
    if not entry or not Bounty.OwnsItem(entry, itemId) then return nil end
    if Bounty.IsWorn(entry, itemId) then return nil end
    for i, owned in ipairs(entry.items) do
        if owned == itemId then
            table.remove(entry.items, i)
            break
        end
    end
    if entry.enchants then entry.enchants[itemId] = nil end
    return Bounty.Disenchant(store, itemId, rng)
end

-- Formulas ---------------------------------------------------------------------------------------

-- All formulas, weakest first (by tier, then id).
MC.RECIPE_ORDER = {}
for id in pairs(MC.Recipes or {}) do MC.RECIPE_ORDER[#MC.RECIPE_ORDER + 1] = id end
table.sort(MC.RECIPE_ORDER, function(a, b)
    local ra, rb = MC.Recipes[a], MC.Recipes[b]
    if ra.tier ~= rb.tier then return ra.tier < rb.tier end
    return a < b
end)

-- A formula's bonus.
function MC.RecipeMods(recipe)
    local points = MC.RECIPE_POINTS[recipe.tier] or 1
    if recipe.bonus == "resist_all" then
        local mods = {}
        for _, school in ipairs(MAGIC) do mods["resist_" .. school] = points * MC.ITEM_POINT["resist_" .. school] / 2 end
        return mods
    end
    return { [recipe.bonus] = points * MC.ITEM_POINT[recipe.bonus] }
end

-- Formulas of a tier and below that the collection does not know yet: what loot can still teach.
function MC.UnknownRecipes(store, tier)
    local out = {}
    for _, id in ipairs(MC.RECIPE_ORDER) do
        if MC.Recipes[id].tier <= tier and not Bounty.KnowsRecipe(store, id) then out[#out + 1] = id end
    end
    return out
end

function Bounty.KnowsRecipe(store, id)
    return store.recipes ~= nil and store.recipes[id] == true
end

-- Learns a formula found as loot; false when it was known already.
function Bounty.LearnRecipe(store, id)
    if not MC.Recipes[id] or Bounty.KnowsRecipe(store, id) then return false end
    store.recipes = store.recipes or {}
    store.recipes[id] = true
    return true
end

function Bounty.HasMaterials(store, recipe)
    local bag = Bounty.Materials(store)
    for _, cost in ipairs(recipe.cost) do
        if (bag[cost[1]] or 0) < cost[2] then return false end
    end
    return true
end

-- Whether a formula fits an item, as in Classic: "weapon" formulas any melee weapon, the others their
-- one slot (a cloak formula only a cloak). Ranged weapons and jewellery take none.
local MELEE = { ["one-hand"] = true, ["two-hand"] = true, ["main-hand"] = true, ["off-hand"] = true }
function MC.RecipeFits(recipe, item)
    if recipe.target == "weapon" then return MELEE[item.slot] == true end
    return recipe.target == item.slot
end

-- A Classic slot's name in the player's language (the client's INVTYPE_* strings); "weapon" (any
-- melee weapon) and a missing string fall back to our kind names.
local INVTYPE = {
    ["one-hand"] = "INVTYPE_WEAPON", ["two-hand"] = "INVTYPE_2HWEAPON", ["main-hand"] = "INVTYPE_WEAPONMAINHAND",
    ["off-hand"] = "INVTYPE_WEAPONOFFHAND", ranged = "INVTYPE_RANGED", held = "INVTYPE_HOLDABLE",
    shield = "INVTYPE_SHIELD", head = "INVTYPE_HEAD", shoulder = "INVTYPE_SHOULDER", chest = "INVTYPE_CHEST",
    back = "INVTYPE_CLOAK", wrist = "INVTYPE_WRIST", hands = "INVTYPE_HAND", waist = "INVTYPE_WAIST",
    legs = "INVTYPE_LEGS", feet = "INVTYPE_FEET", finger = "INVTYPE_FINGER", neck = "INVTYPE_NECK",
    trinket = "INVTYPE_TRINKET",
}
local JEWELRY = { finger = true, neck = true, trinket = true }
local WEAPONS = { ["one-hand"] = true, ["two-hand"] = true, ["main-hand"] = true, ["off-hand"] = true,
    ranged = true, held = true, weapon = true }
function MC.SlotName(slot)
    local name = INVTYPE[slot] and _G[INVTYPE[slot]]
    if type(name) == "string" and name ~= "" then return name end
    local L = ns.L
    return WEAPONS[slot] and L.MC_RECIPE_WEAPON or JEWELRY[slot] and L.MC_ITEM_JEWELRY or L.MC_RECIPE_ARMOR
end

-- Whether any formula could ever fit the item.
function MC.Enchantable(item)
    for _, recipe in pairs(MC.Recipes) do
        if MC.RecipeFits(recipe, item) then return true end
    end
    return false
end

-- Whether a mercenary's item can take a formula: a known formula that fits it and the materials in the bag.
function Bounty.CanEnchant(store, mercId, itemId, recipeId)
    local entry, item, recipe = store.mercs[mercId], MC.Items[itemId], MC.Recipes[recipeId]
    if not entry or not item or not recipe then return false end
    return Bounty.OwnsItem(entry, itemId) and Bounty.KnowsRecipe(store, recipeId) and MC.RecipeFits(recipe, item)
        and Bounty.HasMaterials(store, recipe)
end

-- Enchants a mercenary's item, using up the materials; an older enchant is replaced.
function Bounty.Enchant(store, mercId, itemId, recipeId)
    if not Bounty.CanEnchant(store, mercId, itemId, recipeId) then return false end
    for _, cost in ipairs(MC.Recipes[recipeId].cost) do Bounty.AddMaterial(store, cost[1], -cost[2]) end
    local entry = store.mercs[mercId]
    entry.enchants = entry.enchants or {}
    entry.enchants[itemId] = recipeId
    return true
end

function Bounty.ItemEnchant(entry, itemId)
    return entry.enchants and entry.enchants[itemId]
end
