-- Items on screen: the mercenary page's second sheet (the two slots, the bag and the chosen item with
-- wear, take off, enchant and disenchant), the item tooltip, and the find page that asks who gets a
-- found item (it stays with that mercenary for good).
-- Until the dungeons bring items, the sheet's tabs only show in the dev copy.

local _, ns = ...
local MC = ns.Mercenaries
local Kit, Describe, Bounty = MC.Kit, MC.Describe, MC.Bounty
local Widgets, L = ns.Widgets, ns.L
local Module = MC.Module
local W = MC.W

local INK = { 0.2, 0.12, 0.05 }
local SHEET_W, SHEET_H = W - 264, MC.H - 60
local SPLIT = 330
local BAG_COLS, BAG_ROWS = 5, 2
local PICK_ROWS = 6

local function KindName(item)
    return item.kind == "weapon" and L.MC_RECIPE_WEAPON or item.kind == "armor" and L.MC_RECIPE_ARMOR
        or L.MC_ITEM_JEWELRY
end

-- "75% Strange Dust x1-2, 20% ..." from Classic's odds.
function MC.DisenchantText(item)
    local parts = {}
    for _, r in ipairs(MC.DisenchantResults(item)) do
        local count = r[3] == r[4] and ("x" .. r[3]) or ("x" .. r[3] .. "-" .. r[4])
        local chance = r[1] < 1 and (("%g%% "):format(math.floor(r[1] * 1000 + 0.5) / 10)) or ""
        parts[#parts + 1] = chance .. L["MC_M_" .. r[2]] .. " " .. count
    end
    return table.concat(parts, ", ")
end

function MC.ItemName(id)
    return L["MC_I_" .. id] or tostring(id)
end

-- The item tooltip: name in its rarity's colour, kind and level, bonus, enchant (of `entry`'s copy)
-- and what disenchanting gives.
function Module:ItemTooltip(owner, id, entry)
    local item = MC.Items[id]
    if not item then return end
    local color = MC.RARITY_COLORS[item.rarity]
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(MC.ItemName(id), color[1], color[2], color[3])
    GameTooltip:AddLine(KindName(item) .. "  ·  " .. L.MC_ITEM_LEVEL:format(item.level or 0), 0.7, 0.7, 0.7)
    GameTooltip:AddLine(Describe.Mods(MC.ItemMods(item)), 1, 1, 1, true)
    local recipe = entry and Bounty.ItemEnchant(entry, id)
    if recipe then GameTooltip:AddLine(L.MC_ITEM_ENCHANT:format(L["MC_F_" .. recipe]), 0.3, 1, 0.3, true) end
    GameTooltip:AddLine(L.MC_ITEM_DISENCHANT_INTO:format(MC.DisenchantText(item)), 0.6, 0.8, 1, true)
    GameTooltip:Show()
end

-- Paints a medallion with an item (or empty, with `empty` as its picture): icon and a ring in the
-- rarity's colour.
local function SetItemMedallion(m, id, empty)
    local item = id and MC.Items[id]
    m.itemId = id
    m.icon:SetTexture(item and item.icon or empty)
    local color = item and MC.RARITY_COLORS[item.rarity]
    m.ring:SetDesaturated(color ~= nil)
    if color and item.rarity ~= "common" then
        m.ring:SetVertexColor(color[1], color[2], color[3])
    else
        m.ring:SetVertexColor(1, 1, 1)
    end
end

-- Mercenary page ------------------------------------------------------------------------------------

function Module:BuildMercItems(view)
    local sheet = CreateFrame("Frame", nil, view)
    sheet:SetPoint("TOPLEFT", 252, -14)
    sheet:SetPoint("BOTTOMRIGHT", -12, 46)
    sheet:SetFrameLevel(view.sheet:GetFrameLevel() + 5)
    Kit.Parchment(sheet)
    sheet:Hide()
    view.itemSheet = sheet
    local title = Kit.Plaque(sheet, 220, "MC_ITEMS", 16)
    title:SetPoint("TOP", 0, 4)
    local function Select(sel)
        self.itemSel = sel
        self.itemPicking = false
        self.itemSure = false
        self:RefreshMercItems()
    end

    -- Left: the worn items, then the bag.
    local worn = Widgets.LocalizedText(sheet, 12, "white", "MC_ITEMS_WORN")
    worn:SetTextColor(unpack(INK))
    worn:SetPoint("TOPLEFT", 24, -48)
    view.slots = {}
    for i = 1, 2 do
        local m = Kit.Medallion(sheet, 64, true)
        Kit.Place(m, 60, 104 + (i - 1) * 92, sheet)
        Kit.Hover(m, { grow = 1.08 })
        m:SetScript("OnClick", function() Select({ slot = i }) end)
        m:HookScript("OnEnter", function()
            if m.itemId then self:ItemTooltip(m, m.itemId, self:Store().mercs[self.mercShown]) end
        end)
        m:HookScript("OnLeave", GameTooltip_Hide)
        m.name = Kit.Ink(sheet, 12, INK)
        m.name:SetPoint("TOPLEFT", m, "TOPRIGHT", 10, -6)
        m.name:SetWidth(SPLIT - 120)
        m.name:SetJustifyH("LEFT")
        m.name:SetWordWrap(false)
        m.desc = Kit.Ink(sheet, 10, INK)
        m.desc:SetPoint("TOPLEFT", m.name, "BOTTOMLEFT", 0, -4)
        m.desc:SetWidth(SPLIT - 120)
        m.desc:SetJustifyH("LEFT")
        m.desc:SetJustifyV("TOP")
        m.desc:SetHeight(64)
        m.desc:SetSpacing(2)
        view.slots[i] = m
    end
    local bagTitle = Widgets.LocalizedText(sheet, 12, "white", "MC_ITEMS_BAG")
    bagTitle:SetTextColor(unpack(INK))
    bagTitle:SetPoint("TOPLEFT", 24, -292)
    view.bag = {}
    for i = 1, BAG_COLS * BAG_ROWS do
        local m = Kit.Medallion(sheet, 50, true)
        local col, row = (i - 1) % BAG_COLS, math.floor((i - 1) / BAG_COLS)
        Kit.Place(m, 50 + col * 58, 342 + row * 60, sheet)
        Kit.Hover(m, { grow = 1.1 })
        m:SetScript("OnClick", function() if m.itemId then Select({ id = m.itemId }) end end)
        m:HookScript("OnEnter", function()
            if m.itemId then self:ItemTooltip(m, m.itemId, self:Store().mercs[self.mercShown]) end
        end)
        m:HookScript("OnLeave", GameTooltip_Hide)
        view.bag[i] = m
    end
    view.itemsNone = Kit.Ink(sheet, 13, INK)
    view.itemsNone:SetPoint("CENTER", 0, 0)
    view.itemsNone:SetWidth(SHEET_W - 120)

    local line = sheet:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(INK[1], INK[2], INK[3], 0.25)
    line:SetSize(1, SHEET_H - 90)
    line:SetPoint("TOPLEFT", SPLIT, -50)
    view.itemLine = line

    -- Right: the chosen item.
    local detail = CreateFrame("Frame", nil, sheet)
    detail:SetPoint("TOPLEFT", SPLIT + 10, -40)
    detail:SetPoint("BOTTOMRIGHT", -14, 14)
    view.detail = detail
    local dw = SHEET_W - SPLIT - 24
    view.dIcon = Kit.Medallion(detail, 76, true)
    view.dIcon:SetPoint("TOP", 0, -6)
    view.dIcon:EnableMouse(false)
    view.dName = Kit.Ink(detail, 15, INK)
    view.dName:SetPoint("TOP", view.dIcon, "BOTTOM", 0, -6)
    view.dName:SetWidth(dw)
    view.dKind = Kit.Ink(detail, 11, { 0.35, 0.28, 0.2 })
    view.dKind:SetPoint("TOP", view.dName, "BOTTOM", 0, -4)
    view.dText = Kit.Ink(detail, 12, INK)
    view.dText:SetPoint("TOP", view.dKind, "BOTTOM", 0, -12)
    view.dText:SetWidth(dw - 10)
    view.dText:SetSpacing(3)
    view.dEnchant = Kit.Ink(detail, 11, { 0.05, 0.42, 0 })
    view.dEnchant:SetPoint("TOP", view.dText, "BOTTOM", 0, -10)
    view.dEnchant:SetWidth(dw - 10)
    view.dDisenchant = Kit.Ink(detail, 10, { 0.35, 0.28, 0.2 })
    view.dDisenchant:SetPoint("TOP", view.dEnchant, "BOTTOM", 0, -10)
    view.dDisenchant:SetWidth(dw - 10)

    local function Act(fn)
        return function()
            if fn(self:Store(), self.mercShown) then
                MC.Sound("select")
                self:RefreshMercView()
            end
        end
    end
    -- Into a slot: the item worn there before goes back to the bag.
    view.wear = {}
    for slot = 1, 2 do
        view.wear[slot] = Kit.Button(detail, 130, 28, nil, Act(function(store, merc)
            local ok = Bounty.WearItem(store, merc, slot, self.itemSel and self.itemSel.id)
            if ok then self.itemSel = { slot = slot } end
            return ok
        end), "green")
    end
    view.takeOff = Kit.Button(detail, 130, 28, "MC_ITEM_REMOVE", Act(function(store, merc)
        local slot = self.itemSel and self.itemSel.slot
        local id = slot and store.mercs[merc].worn[slot]
        local ok = slot and Bounty.WearItem(store, merc, slot, nil)
        if ok then self.itemSel = { id = id } end
        return ok
    end))
    view.enchant = Kit.Button(detail, 130, 28, "MC_ITEM_ENCHANT_BTN", function()
        self.itemPicking = true
        self:RefreshMercItems()
    end, "blue")
    view.disenchant = Kit.Button(detail, 130, 28, nil, function()
        if not self.itemSure then
            self.itemSure = true
            self:RefreshMercItems()
            return
        end
        local id = self.itemSel and self.itemSel.id
        local mat, n = Bounty.DisenchantOwned(self:Store(), self.mercShown, id)
        if mat then
            PlaySound(SOUNDKIT.IG_QUEST_LIST_COMPLETE)
            self.itemSel = nil
            self.itemSure = false
            self:RefreshMercView()
            self.overlay:Show("event", {
                icon = MC.Materials[mat].icon, title = L.MC_ITEM_DISENCHANTED,
                text = L.MC_ITEM_GOT_MATERIAL:format(n, L["MC_M_" .. mat]),
            })
        end
    end, "red")

    -- The formula picker in place of the detail.
    local pick = CreateFrame("Frame", nil, sheet)
    pick:SetPoint("TOPLEFT", SPLIT + 10, -40)
    pick:SetPoint("BOTTOMRIGHT", -14, 14)
    view.pick = pick
    local pickTitle = Kit.Ink(pick, 14, INK)
    pickTitle:SetPoint("TOP", 0, -4)
    Widgets.OnRefresh(function() pickTitle:SetText(L.MC_ITEM_PICK_RECIPE) end)
    view.pickNone = Kit.Ink(pick, 12, INK)
    view.pickNone:SetPoint("TOP", 0, -60)
    view.pickNone:SetWidth(dw - 20)
    view.pickRows = {}
    for i = 1, PICK_ROWS do
        local b = CreateFrame("Button", nil, pick)
        b:SetSize(dw, 52)
        b:SetPoint("TOP", 0, -30 - (i - 1) * 56)
        local fill = b:CreateTexture(nil, "BACKGROUND")
        fill:SetAllPoints()
        fill:SetColorTexture(INK[1], INK[2], INK[3], 0.08)
        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 0.85, 0.4, 0.18)
        b.name = Kit.Ink(b, 11, INK)
        b.name:SetPoint("TOPLEFT", 6, -6)
        b.name:SetWidth(dw - 120)
        b.name:SetJustifyH("LEFT")
        b.name:SetWordWrap(false)
        b.desc = Kit.Ink(b, 10, { 0.05, 0.42, 0 })
        b.desc:SetPoint("TOPLEFT", b.name, "BOTTOMLEFT", 0, -4)
        b.desc:SetWidth(dw - 120)
        b.desc:SetJustifyH("LEFT")
        b.costs = {}
        for c = 1, 3 do
            local icon = b:CreateTexture(nil, "ARTWORK")
            icon:SetSize(26, 26)
            icon:SetPoint("RIGHT", -6 - (3 - c) * 34, 2)
            icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            local count = Kit.Ink(b, 10, { 1, 1, 1 }, "OUTLINE")
            count:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -2)
            b.costs[c] = { icon = icon, count = count }
        end
        b:SetScript("OnClick", function()
            local sel = self.itemSel
            local id = sel and (sel.id or self:Store().mercs[self.mercShown].worn[sel.slot])
            if b.recipe and Bounty.Enchant(self:Store(), self.mercShown, id, b.recipe) then
                PlaySound(SOUNDKIT.IG_QUEST_LIST_COMPLETE)
                self.itemPicking = false
                self:RefreshMercView()
            end
        end)
        b:SetMotionScriptsWhileDisabled(true)
        view.pickRows[i] = b
    end
    local pickBack = Kit.Button(pick, 130, 28, "BACK", function()
        self.itemPicking = false
        self:RefreshMercItems()
    end, "red")
    pickBack:SetPoint("BOTTOM", 0, 4)

    -- The two sheets' tabs below them.
    local function Tab(key, items)
        local b = Kit.Button(view, 150, 30, key, function()
            self.mercItemsTab = items
            self:RefreshMercView()
        end)
        return b
    end
    view.tabAbilities = Tab("MC_ABILITIES", false)
    Kit.Place(view.tabAbilities, 340, MC.H - 20)
    view.tabItems = Tab("MC_ITEMS", true)
    Kit.Place(view.tabItems, 500, MC.H - 20)
end

-- What the chosen item is: { id, slot (when worn) } or nil.
local function Chosen(self, entry)
    local sel = self.itemSel
    if not sel then return nil end
    if sel.slot then
        local id = entry.worn and entry.worn[sel.slot]
        return id and { id = id, slot = sel.slot }
    end
    return Bounty.OwnsItem(entry, sel.id) and { id = sel.id } or nil
end

function Module:RefreshMercItems()
    local view, store = self.views.merc, self:Store()
    local id = self.mercShown
    local entry = store.mercs[id] or Bounty.NewEntry(false)
    local tabs = MC.DEV and entry.owned
    view.tabAbilities:SetShown(tabs)
    view.tabItems:SetShown(tabs)
    local showItems = tabs and self.mercItemsTab == true
    Kit.SetSelected(view.tabAbilities, not showItems)
    Kit.SetSelected(view.tabItems, showItems)
    view.itemSheet:SetShown(showItems)
    if not showItems then return end

    entry.items, entry.worn = entry.items or {}, entry.worn or {}
    local slots = MC.ItemSlots(entry)
    local any = #entry.items > 0
    view.itemsNone:SetShown(not any)
    view.itemsNone:SetText(L.MC_ITEMS_NONE)
    for i, m in ipairs(view.slots) do
        local wornId = entry.worn[i]
        local open = i <= slots
        m:SetShown(any)
        m.name:SetShown(any)
        m.desc:SetShown(any)
        SetItemMedallion(m, open and wornId or nil, "Interface\\PaperDoll\\UI-Backpack-EmptySlot")
        m.icon:SetDesaturated(not open)
        m:SetEnabled(open and wornId ~= nil)
        Kit.SetSelected(m, self.itemSel ~= nil and self.itemSel.slot == i and wornId ~= nil)
        local item = open and MC.Items[wornId]
        if item then
            local ink = MC.RARITY_INKS[item.rarity]
            m.name:SetText(MC.ItemName(wornId))
            m.name:SetTextColor(ink[1], ink[2], ink[3])
            local recipe = Bounty.ItemEnchant(entry, wornId)
            m.desc:SetText(Describe.Mods(MC.ItemMods(item))
                .. (recipe and ("\n" .. L.MC_ITEM_ENCHANT:format(L["MC_F_" .. recipe])) or ""))
        else
            m.name:SetText(open and L.MC_ITEM_EMPTY or L.MC_ITEM_SLOT_LOCKED:format(MC.MAX_LEVEL))
            m.name:SetTextColor(0.35, 0.28, 0.2)
            m.desc:SetText("")
        end
    end
    local bag = Bounty.BagItems(entry)
    for i, m in ipairs(view.bag) do
        local bagId = bag[i]
        m:SetShown(any)
        SetItemMedallion(m, bagId)
        m:SetEnabled(bagId ~= nil)
        Kit.SetSelected(m, bagId ~= nil and self.itemSel ~= nil and self.itemSel.id == bagId)
    end

    local chosen = Chosen(self, entry)
    view.itemLine:SetShown(any)
    view.detail:SetShown(chosen ~= nil and not self.itemPicking)
    view.pick:SetShown(chosen ~= nil and self.itemPicking == true)
    if not chosen then return end
    local item = MC.Items[chosen.id]
    if self.itemPicking then
        self:RefreshItemPicker(entry, chosen.id, item)
        return
    end
    SetItemMedallion(view.dIcon, chosen.id)
    local ink = MC.RARITY_INKS[item.rarity]
    view.dName:SetText(MC.ItemName(chosen.id))
    view.dName:SetTextColor(ink[1], ink[2], ink[3])
    view.dKind:SetText(L["MC_RARITY_" .. item.rarity:upper()] .. "  ·  " .. KindName(item) .. "  ·  "
        .. L.MC_ITEM_LEVEL:format(item.level or 0))
    view.dText:SetText(Describe.Mods(MC.ItemMods(item)))
    local recipe = Bounty.ItemEnchant(entry, chosen.id)
    view.dEnchant:SetText(recipe and L.MC_ITEM_ENCHANT:format(L["MC_F_" .. recipe])
        or (item.kind == "jewelry" and L.MC_ITEM_NO_JEWELRY_ENCHANT or L.MC_ITEM_NO_ENCHANT))
    view.dDisenchant:SetText(L.MC_ITEM_DISENCHANT_INTO:format(MC.DisenchantText(item)))

    -- The buttons for what can be done with it, stacked from the bottom.
    local shown = {}
    local inBag = chosen.slot == nil
    for slot, b in ipairs(view.wear) do
        local can = inBag and slot <= slots
        b:SetShown(can)
        if can then
            b:SetText(slots > 1 and L.MC_ITEM_WEAR_SLOT:format(slot) or L.MC_ITEM_WEAR)
            shown[#shown + 1] = b
        end
    end
    view.takeOff:SetShown(not inBag)
    if not inBag then shown[#shown + 1] = view.takeOff end
    view.enchant:SetShown(item.kind ~= "jewelry")
    if item.kind ~= "jewelry" then shown[#shown + 1] = view.enchant end
    view.disenchant:SetShown(inBag)
    if inBag then
        view.disenchant:SetText(self.itemSure and L.MC_ITEM_DISENCHANT_SURE or L.MC_ITEM_DISENCHANT_BTN)
        shown[#shown + 1] = view.disenchant
    end
    for i, b in ipairs(shown) do
        b:ClearAllPoints()
        local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
        b:SetPoint("BOTTOM", view.detail, "BOTTOM", (col == 0 and -70 or 70), 4 + row * 34)
    end
end

-- Known formulas for the item's kind, the affordable ones first.
function Module:RefreshItemPicker(entry, itemId, item)
    local view, store = self.views.merc, self:Store()
    local list = {}
    for _, rid in ipairs(MC.RECIPE_ORDER) do
        if Bounty.KnowsRecipe(store, rid) and MC.Recipes[rid].kind == item.kind then list[#list + 1] = rid end
    end
    table.sort(list, function(a, b)
        local ca, cb = Bounty.HasMaterials(store, MC.Recipes[a]), Bounty.HasMaterials(store, MC.Recipes[b])
        if ca ~= cb then return ca end
        return MC.Recipes[a].tier > MC.Recipes[b].tier or (MC.Recipes[a].tier == MC.Recipes[b].tier and a < b)
    end)
    view.pickNone:SetShown(#list == 0)
    view.pickNone:SetText(item.kind == "jewelry" and L.MC_ITEM_NO_JEWELRY_ENCHANT or L.MC_ITEM_NO_RECIPES)
    local current = Bounty.ItemEnchant(entry, itemId)
    local bag = Bounty.Materials(store)
    for i, b in ipairs(view.pickRows) do
        local rid = list[i]
        b:SetShown(rid ~= nil)
        b.recipe = rid
        if rid then
            local recipe = MC.Recipes[rid]
            local can = Bounty.HasMaterials(store, recipe)
            b:SetEnabled(can and rid ~= current)
            b:SetAlpha((can and rid ~= current) and 1 or 0.55)
            b.name:SetText(L["MC_F_" .. rid])
            b.desc:SetText(Describe.Mods(MC.RecipeMods(recipe)))
            for c, cost in ipairs(b.costs) do
                local need = recipe.cost[c]
                cost.icon:SetShown(need ~= nil)
                cost.count:SetShown(need ~= nil)
                if need then
                    local short = (bag[need[1]] or 0) < need[2]
                    cost.icon:SetTexture(MC.Materials[need[1]].icon)
                    cost.count:SetText(need[2])
                    cost.count:SetTextColor(1, short and 0.3 or 1, short and 0.3 or 1)
                end
            end
        end
    end
end

-- Find page ----------------------------------------------------------------------------------------

function Module:CreateItemFoundPage()
    local page = self.overlay:AddPage("itemfound")
    Widgets.PageTitle(page, "MC_ITEM_FOUND_TITLE", -26)
    local card = MC.OptionButton(page, 260, 170)
    card:SetPoint("TOP", 0, -70)
    card:EnableMouse(false)
    Kit.NoHover(card)
    local sub = Widgets.LocalizedText(page, 13, "blue", "MC_ITEM_FOUND_SUB")
    sub:SetPoint("TOP", 0, -258)
    local buttons = {}
    for i = 1, 6 do
        local b = MC.OptionButton(page, 120, 124)
        b:SetScript("OnClick", function() self:ClaimFoundItem(b.merc) end)
        buttons[i] = b
    end
    local away = Kit.Button(page, 180, 30, "MC_ITEM_DISENCHANT_BTN", function() self:ClaimFoundItem(nil) end, "red")
    away:SetPoint("TOP", 0, -440)
    self.itemFoundButtons = buttons
    page.refresh = function()
        local store = self:Store()
        local id = Bounty.PendingItem(store)
        local item = id and MC.Items[id]
        if not item then return end
        card.icon:SetTexture(item.icon)
        card.name:SetText(MC.ItemName(id))
        card.desc:SetText(Describe.Mods(MC.ItemMods(item)))
        card:SetRarity(item.rarity)
        local mercs = {}
        for _, member in ipairs(store.run and store.run.party or {}) do
            if store.mercs[member.id] and store.mercs[member.id].owned then mercs[#mercs + 1] = member.id end
        end
        if #mercs == 0 then mercs = store.party end
        for i, b in ipairs(buttons) do
            local merc = mercs[i]
            b:SetShown(merc ~= nil)
            b.merc = merc
            if merc then
                if Kit.HAS_PORTRAITS then
                    SetPortraitTextureFromCreatureDisplayID(b.icon, MC.Mercs[merc].display)
                else
                    b.icon:SetTexture(MC.RoleTex("role_", MC.Mercs[merc].role))
                end
                b.name:SetText(Describe.MercName(merc))
                b.desc:SetText(Bounty.OwnsItem(store.mercs[merc], id) and L.MC_ITEM_FOUND_OWNED or "")
                b:ClearAllPoints()
                b:SetPoint("TOP", page, "TOP", (i - (#mercs + 1) / 2) * 130, -290)
            end
        end
    end
end

function Module:ClaimFoundItem(mercId)
    local store = self:Store()
    local result, mat, n = Bounty.ClaimItem(store, mercId)
    if not result then return end
    PlaySound(SOUNDKIT.IG_QUEST_LIST_COMPLETE)
    if result == "disenchanted" and mat then
        self.overlay:Show("event", {
            icon = MC.Materials[mat].icon, title = L.MC_ITEM_DISENCHANTED,
            text = L.MC_ITEM_GOT_MATERIAL:format(n, L["MC_M_" .. mat]),
        })
    elseif Bounty.PendingItem(store) then
        self.overlay:Show("itemfound")
    else
        self:Route()
    end
end

-- Shows the find page while items wait for an owner (outside a bounty).
function Module:CheckPendingItems()
    local store = self:Store()
    if Bounty.PendingItem(store) and not store.run then self.overlay:Show("itemfound") end
end
