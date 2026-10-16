-- The workshop (the map table in the camp): the material bag and the known enchanting formulas.
-- Every material shows, also those not found yet, with where it comes from, so the way to the best
-- enchants is plain to see. Enchanting an item itself happens on the mercenary's page.

local _, ns = ...
local MC = ns.Mercenaries
local Kit, Describe, Bounty = MC.Kit, MC.Describe, MC.Bounty
local Widgets, L = ns.Widgets, ns.L
local Module = MC.Module
local W, H = MC.W, MC.H

local SLOT, SLOT_GAP = 42, 48
local BAG_X, BAG_W = 14, 418
local LIST_X = BAG_X + BAG_W + 12
local LIST_W = W - LIST_X - 14
local PANEL_Y, PANEL_H = 76, H - 136
local ROWS, ROW_H = 7, 50

-- The materials by tier, in the order of MC.DISENCHANT (dust, essence, shard), the Nexus Crystal last.
local TIERS = {}
do
    local seen = {}
    local function Add(id)
        if not id or seen[id] then return end
        seen[id] = true
        local tier = MC.Materials[id].tier
        TIERS[tier] = TIERS[tier] or {}
        table.insert(TIERS[tier], id)
    end
    for _, b in ipairs(MC.DISENCHANT) do
        Add(b.dust[1])
        Add(b.essence[1])
        Add(b.shard)
    end
    Add(MC.NEXUS_CRYSTAL)
end

-- Where a material comes from: the item levels whose disenchanting gives it.
local function Source(id)
    if id == MC.NEXUS_CRYSTAL then return L.MC_MAT_SOURCE_EPIC end
    local low, high, shard, from = nil, nil, false, 0
    for _, b in ipairs(MC.DISENCHANT) do
        if b.dust[1] == id or b.essence[1] == id or b.shard == id then
            low = low or from + 1
            high = b.level
            shard = shard or b.shard == id
        end
        from = b.level
    end
    if not low then return "" end
    local text = high == math.huge and L.MC_MAT_SOURCE_UP:format(low) or L.MC_MAT_SOURCE:format(low, high)
    return shard and (text .. " " .. L.MC_MAT_SOURCE_RARE) or text
end

-- What a formula does: "all resistances" in a word instead of six schools.
local function RecipeBonus(recipe)
    if recipe.bonus == "resist_all" then
        local mods = MC.RecipeMods(recipe)
        return L.MC_MOD_RESIST_ALL:format(math.floor(mods.resist_fire * 100 + 0.5))
    end
    return Describe.Mods(MC.RecipeMods(recipe))
end

local function Panel(parent, x, y, w, h)
    local p = CreateFrame("Frame", nil, parent)
    p:SetSize(w, h)
    p:SetPoint("TOPLEFT", x, -y)
    local fill = p:CreateTexture(nil, "BACKGROUND", nil, 2)
    fill:SetAllPoints()
    fill:SetColorTexture(0.08, 0.05, 0.03, 0.78)
    Widgets.Rim(p, p)
    return p
end

local function MaterialSlot(parent, size)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size, size)
    local back = b:CreateTexture(nil, "BACKGROUND")
    back:SetPoint("TOPLEFT", -2, 2)
    back:SetPoint("BOTTOMRIGHT", 2, -2)
    back:SetColorTexture(0, 0, 0, 0.7)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b.count = Kit.Ink(b, math.max(10, math.floor(size * 0.3)), { 1, 1, 1 }, "OUTLINE")
    b.count:SetPoint("BOTTOMRIGHT", -1, 2)
    b:SetScript("OnLeave", GameTooltip_Hide)
    return b
end

-- Shows a material in a slot: dimmed while the bag holds none.
local function SetMaterial(b, id, count, need)
    b.material = id
    b.icon:SetTexture(MC.Materials[id].icon)
    local short = need and count < need
    b.icon:SetDesaturated(count == 0)
    b.icon:SetAlpha(count == 0 and 0.45 or 1)
    if need then
        b.count:SetText(need)
        b.count:SetTextColor(1, short and 0.3 or 1, short and 0.3 or 1)
    else
        b.count:SetText(count > 0 and count or "")
        b.count:SetTextColor(1, 1, 1)
    end
end

local function MaterialTooltip(b)
    local id = b.material
    if not id then return end
    local store = b.store()
    GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
    GameTooltip:SetText(L["MC_M_" .. id], 1, 0.82, 0)
    GameTooltip:AddLine(L.MC_MAT_TIER:format(MC.Materials[id].tier), 0.7, 0.7, 0.7)
    GameTooltip:AddLine(L.MC_MAT_OWNED:format(Bounty.Materials(store)[id] or 0), 1, 1, 1)
    GameTooltip:AddLine(Source(id), 0.6, 0.8, 1, true)
    GameTooltip:Show()
end

function Module:BuildWorkshop()
    local view = self:AddView("workshop", CreateFrame("Frame", nil, self.container))
    local wood = Kit.Wood(view, W, H, true)
    wood:SetPoint("TOPLEFT")
    local store = function() return self:Store() end

    local title = Kit.Plaque(view, 300, "MC_WORKSHOP", 16)
    title:SetPoint("TOP", view, "TOP", 0, -4)

    -- The bag: one row per tier.
    local bag = Panel(view, BAG_X, PANEL_Y, BAG_W, PANEL_H)
    local bagTitle = Kit.Plaque(bag, 200, "MC_MATERIALS", 14)
    bagTitle:SetPoint("TOP", 0, 22)
    view.slots = {}
    local rowH = (PANEL_H - 40) / #TIERS
    for tier, ids in ipairs(TIERS) do
        local y = 36 + (tier - 1) * rowH
        local label = Kit.Ink(bag, 11, { 0.85, 0.75, 0.55 })
        label:SetPoint("TOPLEFT", 14, -y)
        Widgets.OnRefresh(function() label:SetText(L.MC_MAT_TIER:format(tier)) end)
        for i, id in ipairs(ids) do
            local b = MaterialSlot(bag, SLOT)
            b:SetPoint("TOPLEFT", 14 + (i - 1) * SLOT_GAP, -(y + 16))
            b.store = store
            b:SetScript("OnEnter", MaterialTooltip)
            b.material = id
            view.slots[#view.slots + 1] = b
        end
    end

    -- The formulas: known ones with what they cost, a page at a time.
    local list = Panel(view, LIST_X, PANEL_Y, LIST_W, PANEL_H)
    local listTitle = Kit.Plaque(list, 200, "MC_RECIPES", 14)
    listTitle:SetPoint("TOP", 0, 22)
    view.known = Widgets.Text(list, 11, "gray")
    view.known:SetPoint("TOP", 0, -30)
    view.empty = Widgets.Text(list, 12, "white")
    view.empty:SetPoint("TOP", 0, -80)
    view.empty:SetWidth(LIST_W - 40)
    view.empty:SetSpacing(4)
    view.rows = {}
    for i = 1, ROWS do
        local row = CreateFrame("Frame", nil, list)
        row:SetSize(LIST_W - 24, ROW_H - 4)
        row:SetPoint("TOPLEFT", 12, -(50 + (i - 1) * ROW_H))
        local shade = row:CreateTexture(nil, "BACKGROUND")
        shade:SetAllPoints()
        shade:SetColorTexture(1, 0.9, 0.7, i % 2 == 0 and 0.04 or 0.08)
        row.name = Kit.Ink(row, 12, { 1, 0.82, 0 })
        row.name:SetPoint("TOPLEFT", 8, -6)
        row.name:SetWidth(LIST_W - 200)
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(false)
        row.info = Widgets.Text(row, 10, "gray")
        row.info:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -4)
        row.info:SetWidth(LIST_W - 200)
        row.info:SetJustifyH("LEFT")
        row.info:SetWordWrap(false)
        row.costs = {}
        for c = 1, 3 do
            local b = MaterialSlot(row, 30)
            b:SetPoint("RIGHT", row, "RIGHT", -6 - (3 - c) * 36, 0)
            b.store = store
            b:SetScript("OnEnter", MaterialTooltip)
            row.costs[c] = b
        end
        view.rows[i] = row
    end
    view.prev = Kit.Arrow(list, -1, function()
        self.workshopPage = math.max(1, (self.workshopPage or 1) - 1)
        self:RefreshWorkshop()
    end)
    view.prev:SetPoint("BOTTOMLEFT", 10, 8)
    view.next = Kit.Arrow(list, 1, function()
        self.workshopPage = (self.workshopPage or 1) + 1
        self:RefreshWorkshop()
    end)
    view.next:SetPoint("BOTTOMRIGHT", -10, 8)
    view.page = Widgets.Text(list, 11, "gray")
    view.page:SetPoint("BOTTOM", 0, 16)

    local back = Kit.Button(view, 140, 30, "BACK", function() self:ShowView("camp") end, "red")
    Kit.Place(back, W / 2, H - 30, view)

    -- Dev copy in debug mode: a handful of loot to try the workshop with.
    view.devLoot, view.devItem = false, false
    if MC.DEV then
        view.devLoot = Kit.Button(view, 140, 30, "MC_DEV_LOOT", function()
            local ids = {}
            for id in pairs(MC.Items) do ids[#ids + 1] = id end
            for _ = 1, 5 do Bounty.Disenchant(self:Store(), ids[math.random(#ids)]) end
            local unknown = MC.UnknownRecipes(self:Store(), 4)
            if #unknown > 0 then Bounty.LearnRecipe(self:Store(), unknown[math.random(#unknown)]) end
            self:RefreshWorkshop()
        end)
        Kit.Place(view.devLoot, W - 90, H - 30, view)
        -- ... and a found item, to try who gets it.
        view.devItem = Kit.Button(view, 140, 30, "MC_DEV_ITEM", function()
            local ids = {}
            for id in pairs(MC.Items) do ids[#ids + 1] = id end
            Bounty.QueueItem(self:Store(), ids[math.random(#ids)])
            self:ShowView("camp")
        end)
        Kit.Place(view.devItem, 90, H - 30, view)
    end

    view.refresh = function() self:RefreshWorkshop() end
end

function Module:RefreshWorkshop()
    local view, store = self.views.workshop, self:Store()
    self:SetScene(nil)
    if view.devLoot then view.devLoot:SetShown(MC.AutoBattleAllowed()) end
    if view.devItem then view.devItem:SetShown(MC.AutoBattleAllowed()) end
    local bag = Bounty.Materials(store)
    for _, b in ipairs(view.slots) do SetMaterial(b, b.material, bag[b.material] or 0) end

    local known = {}
    for _, id in ipairs(MC.RECIPE_ORDER) do
        if Bounty.KnowsRecipe(store, id) then known[#known + 1] = id end
    end
    view.known:SetText(L.MC_RECIPES_KNOWN:format(#known, #MC.RECIPE_ORDER))
    view.empty:SetShown(#known == 0)
    view.empty:SetText(L.MC_RECIPES_NONE)
    local pages = math.max(1, math.ceil(#known / ROWS))
    local page = math.min(self.workshopPage or 1, pages)
    self.workshopPage = page
    for i, row in ipairs(view.rows) do
        local id = known[(page - 1) * ROWS + i]
        row:SetShown(id ~= nil)
        if id then
            local recipe = MC.Recipes[id]
            row.name:SetText(L["MC_F_" .. id])
            row.info:SetText(MC.SlotName(recipe.target) .. "  ·  "
                .. RecipeBonus(recipe))
            for c, b in ipairs(row.costs) do
                local cost = recipe.cost[c]
                b:SetShown(cost ~= nil)
                if cost then SetMaterial(b, cost[1], bag[cost[1]] or 0, cost[2]) end
            end
        end
    end
    view.prev:SetShown(pages > 1)
    view.next:SetShown(pages > 1)
    view.prev:SetEnabled(page > 1)
    view.next:SetEnabled(page < pages)
    view.page:SetShown(pages > 1)
    view.page:SetText(("%d / %d"):format(page, pages))
end
