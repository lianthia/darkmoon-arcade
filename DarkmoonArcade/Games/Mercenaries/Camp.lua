-- The camp between bounties: the party on display, the travel board with every zone and the
-- collection where mercenaries are recruited, upgraded and put into the party.

local _, ns = ...
local MC = ns.Mercenaries
local Combat, Bounty, Describe = MC.Combat, MC.Bounty, MC.Describe
local Widgets, L = ns.Widgets, ns.L
local Module = MC.Module
local W, H = MC.W, MC.H

local CONTINENTS = { "ek", "kal", "zephras" }
local ZONE_CARD_W, ZONE_CARD_H, ZONE_COLUMNS, ZONE_ROWS = 192, 128, 4, 3

local function Fill(frame, r, g, b, a)
    local t = frame:CreateTexture(nil, "BACKGROUND")
    t:SetAllPoints()
    t:SetColorTexture(r, g, b, a)
    return t
end

-- What the collection shows of a mercenary: its level, equipment and ranks applied.
function MC.PreviewUnit(store, id)
    local def, entry = MC.Mercs[id], store.mercs[id] or Bounty.NewEntry(false)
    local mods = {}
    local gear = def.gear[entry.gear or 1]
    if gear then Bounty.AddMods(mods, gear.mods) end
    local abilities = {}
    for i = 1, 3 do abilities[i] = { id = def.abilities[i], rank = entry.ranks[i] or 1, cd = 0 } end
    return {
        kind = "merc", id = id, role = def.role, level = entry.level, mods = mods, abilities = abilities,
        atk = def.atk * Combat.LevelFactor(entry.level) * (1 + (mods.atkPct or 0)),
    }
end

-- Camp ----------------------------------------------------------------------------------------------

function Module:BuildCamp()
    local view = self:AddView("camp", CreateFrame("Frame", nil, self.container))
    local title = Widgets.LocalizedText(view, 30, "gold", "MC_NAME")
    title:SetPoint("TOP", 0, -26)
    local tagline = Widgets.LocalizedText(view, 14, "blue", "MC_TAGLINE")
    tagline:SetPoint("TOP", title, "BOTTOM", 0, -6)

    self.campModels = {}
    for i = 1, Bounty.PARTY_SIZE do
        local x = W / 2 + (i - 3.5) * 120
        local m = MC.Model(view, nil)
        m:SetSize(120, 190)
        m:SetPoint("CENTER", view, "TOPLEFT", x, -230)
        m.name = Widgets.Text(view, 12, "white")
        m.name:SetPoint("TOP", view, "TOPLEFT", x, -330)
        m.level = Widgets.Text(view, 10, "gray")
        m.level:SetPoint("TOP", m.name, "BOTTOM", 0, -2)
        self.campModels[i] = m
    end

    view.runInfo = Widgets.Text(view, 13, "white")
    view.runInfo:SetPoint("TOP", 0, -372)
    local continue = Widgets.Button(view, 240, 30, "MC_CONTINUE_RUN", function() self:Route() end)
    local travel = Widgets.Button(view, 240, 30, "MC_BOUNTIES", function() self:ShowView("travel") end)
    local collection = Widgets.Button(view, 240, 30, "MC_COLLECTION", function() self:ShowView("collection") end)
    local scores = Widgets.Button(view, 240, 26, "HIGHSCORES", function() self.overlay:Show("scores") end)
    view.refresh = function()
        local store = self:Store()
        self:TintBoard(nil)
        for i, m in ipairs(self.campModels) do
            local id = store.party[i]
            m:SetShown(id ~= nil)
            m.name:SetShown(id ~= nil)
            m.level:SetShown(id ~= nil)
            if id then
                m:SetDisplay(MC.Mercs[id].display, (i - 3.5) * -0.12)
                m.name:SetText(Describe.MercName(id))
                m.level:SetText(L.LEVEL:format(store.mercs[id].level))
            end
        end
        local run = store.run
        continue:SetShown(run ~= nil)
        travel:SetShown(run == nil)
        if run then
            view.runInfo:SetText(L.MC_RUN_ACTIVE:format(Describe.ZoneName(run.zone)))
            Widgets.Stack(view, { continue, collection, scores }, -400)
        else
            view.runInfo:SetText("")
            Widgets.Stack(view, { travel, collection, scores }, -400)
        end
    end
end

-- Travel -------------------------------------------------------------------------------------------

function Module:BuildTravel()
    local view = self:AddView("travel", CreateFrame("Frame", nil, self.container))
    local title = Widgets.LocalizedText(view, 22, "gold", "MC_BOUNTIES")
    title:SetPoint("TOPLEFT", 20, -14)
    view.party = Widgets.Text(view, 12, "white")
    view.party:SetPoint("TOPRIGHT", -20, -20)
    self.travelContinent, self.travelPage = "ek", 1

    view.tabs = {}
    for i, c in ipairs(CONTINENTS) do
        local tab = Widgets.Button(view, 170, 24, "MC_CONTINENT_" .. c:upper(), function()
            self.travelContinent, self.travelPage = c, 1
            view.refresh()
        end)
        tab:SetPoint("TOP", view, "TOP", (i - 2) * 180, -48)
        view.tabs[c] = tab
    end

    view.cards = {}
    local left = (W - (ZONE_COLUMNS * ZONE_CARD_W + (ZONE_COLUMNS - 1) * 12)) / 2
    for i = 1, ZONE_COLUMNS * ZONE_ROWS do
        local col, row = (i - 1) % ZONE_COLUMNS, math.floor((i - 1) / ZONE_COLUMNS)
        local card = CreateFrame("Frame", nil, view)
        card:SetSize(ZONE_CARD_W, ZONE_CARD_H)
        card:SetPoint("TOPLEFT", left + col * (ZONE_CARD_W + 12), -84 - row * (ZONE_CARD_H + 10))
        Fill(card, 0.06, 0.04, 0.03, 0.85)
        Widgets.Rim(card, card)
        card.back = card:CreateTexture(nil, "BACKGROUND", nil, 1)
        card.back:SetTexture(MC.Tex("token_back"))
        card.back:SetPoint("TOPLEFT", 6, -6)
        card.back:SetSize(64, 80)
        card.model = MC.Model(card, 0.7)
        card.model:SetPoint("TOPLEFT", 6, -6)
        card.model:SetSize(64, 80)
        card.name = Widgets.Text(card, 13, "gold")
        card.name:SetPoint("TOPLEFT", 76, -8)
        card.name:SetWidth(ZONE_CARD_W - 82)
        card.name:SetJustifyH("LEFT")
        card.levels = Widgets.Text(card, 11, "white")
        card.levels:SetPoint("TOPLEFT", card.name, "BOTTOMLEFT", 0, -4)
        card.boss = Widgets.Text(card, 10, "gray")
        card.boss:SetPoint("TOPLEFT", card.levels, "BOTTOMLEFT", 0, -3)
        card.boss:SetWidth(ZONE_CARD_W - 82)
        card.boss:SetJustifyH("LEFT")
        card.status = Widgets.Text(card, 10, "white")
        card.status:SetPoint("TOPLEFT", card.boss, "BOTTOMLEFT", 0, -3)
        card.normal = Widgets.Button(card, 88, 22, "MC_NORMAL", function() self:StartBounty(card.zone, false) end)
        card.normal:SetPoint("BOTTOMLEFT", 6, 6)
        card.heroic = Widgets.Button(card, 88, 22, "MC_HEROIC", function() self:StartBounty(card.zone, true) end)
        card.heroic:SetPoint("BOTTOMRIGHT", -6, 6)
        card.heroic:SetScript("OnEnter", function(b)
            if not b:IsEnabled() then
                GameTooltip:SetOwner(b, "ANCHOR_TOP")
                GameTooltip:SetText(L.MC_HEROIC_LOCKED, 1, 1, 1, 1, true)
                GameTooltip:Show()
            end
        end)
        card.heroic:SetScript("OnLeave", GameTooltip_Hide)
        view.cards[i] = card
    end

    local back = Widgets.Button(view, 140, 24, "BACK", function() self:ShowView("camp") end)
    back:SetPoint("BOTTOMLEFT", 20, 16)
    view.pager = Widgets.Cycler(view, 140, function(dir)
        self.travelPage = self.travelPage + dir
        view.refresh()
    end)
    view.pager:SetPoint("BOTTOM", 0, 16)

    view.refresh = function()
        local store = self:Store()
        self:TintBoard(nil)
        local reference = math.floor(Bounty.PartyLevel(store) + 0.5)
        view.party:SetText(L.MC_PARTY_LEVEL:format(reference))
        for c, tab in pairs(view.tabs) do tab:SetEnabled(c ~= self.travelContinent) end
        local zones = {}
        for _, zid in ipairs(MC.ZONE_ORDER) do
            if MC.Zones[zid].continent == self.travelContinent then zones[#zones + 1] = zid end
        end
        local perPage = #view.cards
        local pages = math.max(1, math.ceil(#zones / perPage))
        self.travelPage = (self.travelPage - 1) % pages + 1
        view.pager:SetShown(pages > 1)
        view.pager.label:SetText(("%d / %d"):format(self.travelPage, pages))
        local running = store.run ~= nil
        for i, card in ipairs(view.cards) do
            local zid = zones[(self.travelPage - 1) * perPage + i]
            card:SetShown(zid ~= nil)
            if zid then
                local zone = MC.Zones[zid]
                local state = Bounty.ZoneState(store, zid)
                card.zone = zid
                card.name:SetText(Describe.ZoneName(zid))
                local bossLevel = Bounty.BossLevel(zone, false)
                local r, g, b = MC.ConColor(bossLevel, reference)
                card.levels:SetText(L.MC_LEVEL_RANGE:format(zone.min, zone.max)
                    .. ("  |cff%02x%02x%02x(%d)|r"):format(r * 255, g * 255, b * 255, bossLevel))
                card.boss:SetText(L["MC_E_" .. zone.boss])
                local status = {}
                if state.normal > 0 then status[#status + 1] = "|cff40ff40" .. L.MC_DONE_NORMAL .. "|r" end
                if state.heroic > 0 then status[#status + 1] = "|cffa335ee" .. L.MC_DONE_HEROIC .. "|r" end
                card.status:SetText(table.concat(status, "  "))
                card.model:SetDisplay(MC.Enemies[zone.boss].display, 0.35)
                card.normal:SetEnabled(not running)
                card.heroic:SetEnabled(not running and Bounty.HeroicUnlocked(store, zid))
            end
        end
    end
end

-- Collection ---------------------------------------------------------------------------------------

local function ListButton(parent, w, h)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w, h)
    b.fill = Fill(b, 0.06, 0.04, 0.03, 0.85)
    b.rim = Widgets.Rim(b, b)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 0.82, 0.4, 0.12)
    b.mark = b:CreateTexture(nil, "BORDER")
    b.mark:SetAllPoints()
    b.mark:SetColorTexture(1, 0.82, 0.3, 0.22)
    b.mark:Hide()
    b.role = b:CreateTexture(nil, "ARTWORK")
    b.role:SetSize(20, 20)
    b.role:SetPoint("LEFT", 5, 0)
    b.name = Widgets.Text(b, 11, "white")
    b.name:SetPoint("TOPLEFT", b.role, "TOPRIGHT", 5, 2)
    b.name:SetWidth(w - 34)
    b.name:SetJustifyH("LEFT")
    b.name:SetWordWrap(false)
    b.sub = Widgets.Text(b, 10, "gray")
    b.sub:SetPoint("TOPLEFT", b.name, "BOTTOMLEFT", 0, -2)
    return b
end

function Module:BuildCollection()
    local view = self:AddView("collection", CreateFrame("Frame", nil, self.container))
    local title = Widgets.LocalizedText(view, 22, "gold", "MC_COLLECTION")
    title:SetPoint("TOPLEFT", 20, -14)

    -- Party slots on the left.
    local partyTitle = Widgets.LocalizedText(view, 13, "gold", "MC_PARTY")
    partyTitle:SetPoint("TOPLEFT", 20, -56)
    view.slots = {}
    for i = 1, Bounty.PARTY_SIZE do
        local b = ListButton(view, 180, 44)
        b:SetPoint("TOPLEFT", 16, -78 - (i - 1) * 50)
        b:SetScript("OnClick", function()
            self.partySlot = self.partySlot ~= i and i or nil
            self.collectionSelected = self:Store().party[i]
            view.refresh()
        end)
        view.slots[i] = b
    end
    view.slotHint = Widgets.Text(view, 10, "gray")
    view.slotHint:SetPoint("TOPLEFT", 18, -386)
    view.slotHint:SetWidth(180)
    view.slotHint:SetJustifyH("LEFT")

    -- Every mercenary in the middle.
    view.grid = {}
    for i, id in ipairs(MC.MERC_ORDER) do
        local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
        local b = ListButton(view, 104, 44)
        b:SetPoint("TOPLEFT", 210 + col * 108, -56 - row * 50)
        b.id = id
        b:SetScript("OnClick", function()
            local store = self:Store()
            if self.partySlot and store.mercs[id] and store.mercs[id].owned then
                if Bounty.SetPartySlot(store, self.partySlot, id) then MC.Sound("select") end
                self.partySlot = nil
            end
            self.collectionSelected = id
            view.refresh()
        end)
        view.grid[i] = b
    end

    -- The chosen mercenary on the right.
    local detail = CreateFrame("Frame", nil, view)
    detail:SetPoint("TOPLEFT", 540, -14)
    detail:SetPoint("BOTTOMRIGHT", -10, 10)
    Fill(detail, 0.05, 0.03, 0.02, 0.8)
    Widgets.Rim(detail, detail)
    view.detail = detail
    detail.model = MC.Model(detail, nil)
    detail.model:SetSize(160, 170)
    detail.model:SetPoint("TOPLEFT", 6, -6)
    detail.name = Widgets.Text(detail, 16, "gold")
    detail.name:SetPoint("TOPLEFT", 170, -14)
    detail.name:SetWidth(110)
    detail.name:SetJustifyH("LEFT")
    detail.role = Widgets.Text(detail, 11, "white")
    detail.role:SetPoint("TOPLEFT", detail.name, "BOTTOMLEFT", 0, -4)
    detail.level = Widgets.Text(detail, 11, "white")
    detail.level:SetPoint("TOPLEFT", detail.role, "BOTTOMLEFT", 0, -6)
    detail.xp = Widgets.Text(detail, 10, "gray")
    detail.xp:SetPoint("TOPLEFT", detail.level, "BOTTOMLEFT", 0, -2)
    detail.coins = Widgets.Text(detail, 11, "gold")
    detail.coins:SetPoint("TOPLEFT", detail.xp, "BOTTOMLEFT", 0, -8)
    detail.recruit = Widgets.Button(detail, 112, 24, "MC_RECRUIT", function()
        local store = self:Store()
        if Bounty.Recruit(store, self.collectionSelected) then
            PlaySound(SOUNDKIT.IG_QUEST_LIST_COMPLETE)
            self:CheckLevels()
            view.refresh()
        end
    end)
    detail.recruit:SetPoint("TOPLEFT", detail.coins, "BOTTOMLEFT", 0, -8)

    detail.abilities = {}
    for i = 1, 3 do
        local row = CreateFrame("Frame", nil, detail)
        row:SetSize(270, 44)
        row:SetPoint("TOPLEFT", 10, -186 - (i - 1) * 50)
        row:EnableMouse(true)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(36, 36)
        row.icon:SetPoint("LEFT")
        row.name = Widgets.Text(row, 12, "gold")
        row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, -1)
        row.name:SetWidth(140)
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(false)
        row.sub = Widgets.Text(row, 10, "gray")
        row.sub:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -2)
        row.up = Widgets.Button(row, 74, 22, nil, function()
            if Bounty.RankUp(self:Store(), self.collectionSelected, i) then
                PlaySound(SOUNDKIT.IG_QUEST_LIST_COMPLETE)
                self:CheckLevels()
                view.refresh()
            end
        end)
        row.up:SetPoint("RIGHT")
        row:SetScript("OnEnter", function()
            local store = self:Store()
            local unit = MC.PreviewUnit(store, self.collectionSelected)
            local aid = unit.abilities[i].id
            GameTooltip:SetOwner(row, "ANCHOR_LEFT")
            GameTooltip:SetText(Describe.AbilityName(aid), 1, 0.82, 0)
            GameTooltip:AddLine(Describe.AbilityStats(aid, unit, i), 0.7, 0.7, 0.7)
            GameTooltip:AddLine(Describe.Ability(aid, unit, i), 1, 1, 1, true)
            if unit.level < MC.ABILITY_LEVELS[i] then
                GameTooltip:AddLine(L.MC_UNLOCKS_AT:format(MC.ABILITY_LEVELS[i]), 1, 0.4, 0.3)
            end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", GameTooltip_Hide)
        detail.abilities[i] = row
    end

    local gearTitle = Widgets.LocalizedText(detail, 12, "gold", "MC_EQUIPMENT")
    gearTitle:SetPoint("TOPLEFT", 10, -340)
    detail.gear = {}
    for i = 1, 3 do
        local b = CreateFrame("Button", nil, detail)
        b:SetSize(40, 40)
        b:SetPoint("TOPLEFT", 10 + (i - 1) * 48, -360)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetAllPoints()
        b.mark = b:CreateTexture(nil, "OVERLAY")
        b.mark:SetTexture("Interface\\Buttons\\CheckButtonHilight")
        b.mark:SetBlendMode("ADD")
        b.mark:SetAllPoints()
        b:SetScript("OnClick", function()
            if Bounty.SetGear(self:Store(), self.collectionSelected, i) then
                MC.Sound("select")
                view.refresh()
            end
        end)
        b:SetScript("OnEnter", function() self:GearTooltip(b, self.collectionSelected, i) end)
        b:SetScript("OnLeave", GameTooltip_Hide)
        detail.gear[i] = b
    end
    detail.gearText = Widgets.Text(detail, 10, "white")
    detail.gearText:SetPoint("TOPLEFT", 10, -408)
    detail.gearText:SetWidth(270)
    detail.gearText:SetJustifyH("LEFT")

    local back = Widgets.Button(view, 140, 24, "BACK", function()
        self.partySlot = nil
        self:ShowView("camp")
    end)
    back:SetPoint("BOTTOMLEFT", 20, 16)

    view.refresh = function() self:RefreshCollection() end
end

-- Where a piece of equipment drops, for the tooltip of a locked one.
function Module:GearSource(mercId, slot)
    local key = slot == 2 and "normal" or "heroic"
    for _, zid in ipairs(MC.ZONE_ORDER) do
        if MC.Zones[zid].gear[key] == mercId then return zid, key end
    end
end

function Module:GearTooltip(owner, mercId, slot)
    local store = self:Store()
    local def, entry = MC.Mercs[mercId], store.mercs[mercId] or Bounty.NewEntry(false)
    GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
    GameTooltip:SetText(L["MC_G_" .. mercId .. "_" .. slot], 1, 0.82, 0)
    GameTooltip:AddLine(Describe.Mods(def.gear[slot].mods, def.abilities), 1, 1, 1, true)
    if not entry.gears[slot] then
        local zid, key = self:GearSource(mercId, slot)
        if zid then
            GameTooltip:AddLine(L.MC_GEAR_FROM:format(L["MC_E_" .. MC.Zones[zid].boss], Describe.ZoneName(zid),
                key == "heroic" and L.MC_HEROIC or L.MC_NORMAL), 1, 0.4, 0.3, true)
        end
    end
    GameTooltip:Show()
end

function Module:RefreshCollection()
    local store = self:Store()
    local view = self.views.collection
    self:TintBoard(nil)
    local locked = store.run ~= nil
    if locked then self.partySlot = nil end
    view.slotHint:SetText(locked and L.MC_PARTY_LOCKED or L.MC_PARTY_HINT)
    local inParty = {}
    for i, b in ipairs(view.slots) do
        local id = store.party[i]
        inParty[id or ""] = true
        b.role:SetTexture(id and MC.Tex("role_" .. MC.Mercs[id].role) or nil)
        b.name:SetText(id and Describe.MercName(id) or "")
        b.sub:SetText(id and L.LEVEL:format(store.mercs[id].level) or "")
        b.mark:SetShown(self.partySlot == i)
        b:SetEnabled(not locked)
    end
    self.collectionSelected = self.collectionSelected or store.party[1]
    for _, b in ipairs(view.grid) do
        local id = b.id
        local entry = store.mercs[id]
        local owned = entry and entry.owned
        b.role:SetTexture(MC.Tex("role_" .. MC.Mercs[id].role))
        b.role:SetDesaturated(not owned)
        b.name:SetText(Describe.MercName(id))
        b.name:SetTextColor(owned and 1 or 0.6, owned and (inParty[id] and 0.82 or 1) or 0.6, owned and (inParty[id] and 0 or 1) or 0.6)
        if owned then
            b.sub:SetText(L.LEVEL:format(entry.level))
        else
            b.sub:SetText(L.MC_COINS_PROGRESS:format(entry and entry.coins or 0, Bounty.RECRUIT_COST))
        end
        b.mark:SetShown(id == self.collectionSelected)
    end

    local id = self.collectionSelected
    local detail = view.detail
    local def = MC.Mercs[id]
    local entry = store.mercs[id] or Bounty.NewEntry(false)
    detail.model:SetDisplay(def.display, 0.4)
    detail.name:SetText(Describe.MercName(id))
    local c = MC.ROLE_COLORS[def.role]
    detail.role:SetText(Describe.RoleName(def.role))
    detail.role:SetTextColor(c[1], c[2], c[3])
    detail.level:SetText(L.LEVEL:format(entry.level))
    if entry.level < MC.MAX_LEVEL then
        detail.xp:SetText(L.MC_XP:format(ns.FormatNumber(entry.xp), ns.FormatNumber(Bounty.XPNeeded(entry.level))))
    else
        detail.xp:SetText("")
    end
    detail.coins:SetText(L.MC_COINS:format(entry.coins))
    detail.recruit:SetShown(not entry.owned)
    detail.recruit:SetEnabled(Bounty.CanRecruit(store, id))
    local unit = MC.PreviewUnit(store, id)
    local ROMAN = { "I", "II", "III" }
    for i, row in ipairs(detail.abilities) do
        local aid = def.abilities[i]
        local unlocked = entry.level >= MC.ABILITY_LEVELS[i]
        row.icon:SetTexture(MC.Abilities[aid].icon)
        row.icon:SetDesaturated(not unlocked)
        row.name:SetText(Describe.AbilityName(aid) .. "  " .. ROMAN[entry.ranks[i]])
        row.sub:SetText(unlocked and Describe.AbilityStats(aid, unit, i) or L.MC_UNLOCKS_AT:format(MC.ABILITY_LEVELS[i]))
        local cost = Bounty.RankCost(entry, i)
        row.up:SetShown(entry.owned and cost ~= nil)
        if cost then row.up:SetText(L.MC_RANK_UP:format(ROMAN[entry.ranks[i] + 1], cost)) end
        row.up:SetEnabled(Bounty.CanRankUp(store, id, i))
    end
    for i, b in ipairs(detail.gear) do
        b.icon:SetTexture(def.gear[i].icon)
        b.icon:SetDesaturated(not entry.gears[i])
        b.icon:SetAlpha(entry.gears[i] and 1 or 0.45)
        b.mark:SetShown(entry.gear == i)
    end
    local gear = entry.gear or 1
    detail.gearText:SetText("|cffffd100" .. L["MC_G_" .. id .. "_" .. gear] .. "|r\n" .. Describe.Mods(def.gear[gear].mods, def.abilities))
end
