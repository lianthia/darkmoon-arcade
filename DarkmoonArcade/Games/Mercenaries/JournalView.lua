-- The adventure guide of a dungeon, as in WoW: its bosses in order on the left (a hidden one as "???"
-- with the task that reveals it), the chosen boss's loot on the right - every item with Classic's
-- drop chance and who owns it already - and what formulas the bosses may teach.

local _, ns = ...
local MC = ns.Mercenaries
local Kit, Describe, Bounty = MC.Kit, MC.Describe, MC.Bounty
local Quests, Dungeons = MC.Quests, MC.Dungeons
local Widgets, L = ns.Widgets, ns.L
local Module = MC.Module
local W, H = MC.W, MC.H

local INK = { 0.2, 0.12, 0.05 }
local LIST_X, LIST_W = 14, 250
local PAGE_X = LIST_X + LIST_W + 12
local PAGE_W = W - PAGE_X - 14
local TOP, ROW_H, ROWS = 58, 52, 9
local LOOT_ROWS = 6

-- The mercenary whose task opens `unlock`.
function Dungeons.UnlockedBy(unlock)
    for _, id in ipairs(MC.QUEST_CHAIN_ORDER) do
        for _, task in ipairs(MC.QUEST_CHAINS[id].steps) do
            if task.unlock == unlock then return MC.QUEST_CHAINS[id].merc end
        end
    end
end

function Module:BuildJournal()
    local view = self:AddView("journal", CreateFrame("Frame", nil, self.container))
    local wood = Kit.Wood(view, W, H, true)
    wood:SetPoint("TOPLEFT")
    view.title = Kit.Plaque(view, 380, nil, 16)
    view.title:SetPoint("TOP", view, "TOP", 0, -4)

    local list = CreateFrame("Frame", nil, view)
    list:SetSize(LIST_W, H - TOP - 60)
    list:SetPoint("TOPLEFT", LIST_X, -TOP)
    local fill = list:CreateTexture(nil, "BACKGROUND", nil, 2)
    fill:SetAllPoints()
    fill:SetColorTexture(0.08, 0.05, 0.03, 0.78)
    Widgets.Rim(list, list)
    view.rows = {}
    for i = 1, ROWS do
        local b = CreateFrame("Button", nil, list)
        b:SetSize(LIST_W - 16, ROW_H - 4)
        b:SetPoint("TOP", 0, -8 - (i - 1) * ROW_H)
        b.shade = b:CreateTexture(nil, "BACKGROUND")
        b.shade:SetAllPoints()
        b.shade:SetColorTexture(1, 0.85, 0.5, 0.06)
        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 0.85, 0.4, 0.12)
        b.coin = Kit.Coin(b, 40)
        b.coin:SetPoint("LEFT", 4, 0)
        b.coin:EnableMouse(false)
        b.name = Kit.Ink(b, 13, { 1, 0.82, 0 })
        b.name:SetPoint("LEFT", b.coin, "RIGHT", 8, 6)
        b.name:SetWidth(LIST_W - 80)
        b.name:SetJustifyH("LEFT")
        b.name:SetWordWrap(false)
        b.sub = Widgets.Text(b, 10, "gray")
        b.sub:SetPoint("TOPLEFT", b.name, "BOTTOMLEFT", 0, -3)
        b.sub:SetWidth(LIST_W - 80)
        b.sub:SetJustifyH("LEFT")
        b:SetScript("OnClick", function()
            MC.Sound("select")
            self.journalEncounter = b.encounter
            self:RefreshJournal()
        end)
        view.rows[i] = b
    end

    local page = CreateFrame("Frame", nil, view)
    page:SetSize(PAGE_W, H - TOP - 60)
    page:SetPoint("TOPLEFT", PAGE_X, -TOP)
    Kit.Parchment(page)
    Widgets.Rim(page, page)
    local tw = PAGE_W - 48
    view.bossName = Kit.Ink(page, 20, { 0.45, 0.12, 0.04 })
    view.bossName:SetPoint("TOPLEFT", 24, -48)
    view.bossName:SetWidth(tw)
    view.bossName:SetJustifyH("LEFT")
    view.bossText = Kit.Ink(page, 12, INK)
    view.bossText:SetPoint("TOPLEFT", view.bossName, "BOTTOMLEFT", 0, -8)
    view.bossText:SetWidth(tw)
    view.bossText:SetJustifyH("LEFT")
    view.loot = {}
    for i = 1, LOOT_ROWS do
        local row = CreateFrame("Frame", nil, page)
        row:SetSize(tw, 46)
        row:SetPoint("TOPLEFT", 24, -116 - (i - 1) * 50)
        local shade = row:CreateTexture(nil, "BACKGROUND")
        shade:SetAllPoints()
        shade:SetColorTexture(INK[1], INK[2], INK[3], 0.07)
        row.icon = Kit.Medallion(row, 42, true)
        row.icon:SetPoint("LEFT", 2, 0)
        row.icon:HookScript("OnEnter", function()
            if row.item then self:ItemTooltip(row.icon, row.item) end
        end)
        row.icon:HookScript("OnLeave", GameTooltip_Hide)
        row.name = Kit.Ink(row, 13, INK)
        row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, -4)
        row.name:SetWidth(tw - 150)
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(false)
        row.info = Kit.Ink(row, 10, { 0.35, 0.28, 0.2 })
        row.info:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -3)
        row.info:SetWidth(tw - 150)
        row.info:SetJustifyH("LEFT")
        row.info:SetWordWrap(false)
        row.chance = Kit.Ink(row, 16, { 0.45, 0.12, 0.04 })
        row.chance:SetPoint("RIGHT", -10, 0)
        row.chance:SetJustifyH("RIGHT")
        view.loot[i] = row
    end
    view.formulas = Kit.Ink(page, 11, { 0.05, 0.28, 0.62 })
    view.formulas:SetPoint("BOTTOMLEFT", 24, 20)
    view.formulas:SetWidth(tw)
    view.formulas:SetJustifyH("LEFT")

    local back = Kit.Button(view, 140, 30, "BACK", function() self:ShowView("travel") end, "red")
    Kit.Place(back, W / 2, H - 30, view)
    -- The title over the panels.
    view.title:SetFrameLevel(page:GetFrameLevel() + 10)
    view.refresh = function() self:RefreshJournal() end
end

-- Who owns an item already, by name.
local function Owners(store, item)
    local names = {}
    for _, merc in ipairs(MC.MERC_ORDER) do
        local entry = store.mercs[merc]
        if entry and entry.items and Bounty.OwnsItem(entry, item) then names[#names + 1] = Describe.MercName(merc) end
    end
    return names
end

function Module:OpenJournal(id)
    self.journalDungeon, self.journalEncounter = id, nil
    self:ShowView("journal")
end

function Module:RefreshJournal()
    local view, store = self.views.journal, self:Store()
    self:SetScene(nil)
    local id = self.journalDungeon
    local zone = id and MC.Zones[id]
    if not zone then return end
    view.title.text:SetText(L.MC_JOURNAL .. ": " .. Describe.ZoneName(id))
    local shown = {}
    for _, i in ipairs(Dungeons.Encounters(store, id)) do shown[i] = true end
    self.journalEncounter = self.journalEncounter or 1
    for i, b in ipairs(view.rows) do
        local enc = zone.encounters[i]
        b:SetShown(enc ~= nil)
        if enc then
            b.encounter = i
            local known = shown[i]
            local def = MC.Enemies[enc.boss]
            if not (known and b.coin:SetCreature(def.display)) then
                b.coin:SetIcon(known and ("Interface\\Icons\\" .. (MC.BOSS_ICON[enc.boss] or "INV_Misc_Bone_HumanSkull_01"))
                    or "Interface\\Icons\\INV_Misc_QuestionMark")
            end
            b.coin:SetMetal(enc.hidden and "gold" or "silver")
            b.name:SetText(known and L["MC_E_" .. enc.boss] or "???")
            b.sub:SetText(enc.hidden and L.MC_JOURNAL_HIDDEN or "")
            b.shade:SetColorTexture(1, 0.85, 0.5, i == self.journalEncounter and 0.2 or 0.06)
        end
    end

    local i = self.journalEncounter
    local enc = zone.encounters[i]
    local known = shown[i]
    view.bossName:SetText(known and L["MC_E_" .. enc.boss] or "???")
    if not known then
        local merc = Dungeons.UnlockedBy(enc.hidden)
        view.bossText:SetText(L.MC_JOURNAL_HIDDEN_HINT:format(merc and Describe.MercName(merc) or "?"))
    else
        view.bossText:SetText(enc.hidden and L.MC_JOURNAL_HIDDEN or "")
    end
    local loot = known and Dungeons.LootOf(id, i) or {}
    table.sort(loot, function(a, b) return a[2] > b[2] end)
    for r, row in ipairs(view.loot) do
        local drop = loot[r]
        row:SetShown(drop ~= nil)
        row.item = drop and drop[1]
        if drop then
            local item = MC.Items[drop[1]]
            local ink = MC.RARITY_INKS[item.rarity]
            row.icon.icon:SetTexture(item.icon)
            local color = MC.RARITY_COLORS[item.rarity]
            row.icon.ring:SetDesaturated(true)
            row.icon.ring:SetVertexColor(color[1], color[2], color[3])
            row.name:SetText(MC.ItemName(drop[1]))
            row.name:SetTextColor(ink[1], ink[2], ink[3])
            local owners = Owners(store, drop[1])
            row.info:SetText(MC.SlotName(item.slot) .. "  ·  " .. Describe.Mods(MC.ItemMods(item))
                .. (#owners > 0 and ("  ·  " .. L.MC_JOURNAL_OWNED:format(table.concat(owners, ", "))) or ""))
            row.chance:SetText(("%g%%"):format(math.floor(drop[2] * 10 + 0.5) / 10))
        end
    end
    view.formulas:SetText(L.MC_JOURNAL_FORMULAS:format(zone.tier or 1, (zone.tier or 1) + 1))
end
