-- The camp between bounties: the party on stage, the travel board (a map of Azeroth with a
-- wanted poster per zone) and the collection of mercenary cards.

local _, ns = ...
local MC = ns.Mercenaries
local Combat, Bounty, Describe = MC.Combat, MC.Bounty, MC.Describe
local Widgets, Media, L = ns.Widgets, ns.Media, ns.L
local Module = MC.Module
local W, H = MC.W, MC.H

local CONTINENTS = { "ek", "kal", "zephras" }
-- Which part of each continent's map the travel board shows (u0, u1, v0, v1).
local MAP_W, MAP_H = 570, 440
local function Crop(cu, cv, heightShare)
    local v = heightShare
    local u = v * (MAP_W / MAP_H) / (1002 / 668)
    return cu - u / 2, cu + u / 2, cv - v / 2, cv + v / 2
end
local CONTINENT_VIEW = {
    ek = { Crop(0.47, 0.5, 0.86) },
    kal = { Crop(0.49, 0.5, 0.86) },
    zephras = { Crop(0.5, 0.5, 1) },
}
local CARD_COLUMNS, CARD_ROWS = 4, 2
local POSTER_RED = { 0.45, 0.06, 0.04 }
local INK = { 0.2, 0.12, 0.05 }

local function Ink(parent, size, color)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(Media.FontFile(), size, "")
    fs:SetTextColor(color[1], color[2], color[3])
    fs:SetShadowOffset(0, 0)
    return fs
end

-- What the collection shows of a mercenary: its level, equipment and ranks applied.
function MC.PreviewUnit(store, id)
    local def, entry = MC.Mercs[id], store.mercs[id] or Bounty.NewEntry(false)
    local mods = {}
    local gear = def.gear[entry.gear or 1]
    if gear then Bounty.AddMods(mods, gear.mods) end
    local abilities = {}
    for i = 1, 3 do abilities[i] = { id = def.abilities[i], rank = entry.ranks[i] or 1, cd = 0 } end
    local factor = Combat.LevelFactor(entry.level)
    return {
        kind = "merc", id = id, side = "ally", role = def.role, level = entry.level, mods = mods, abilities = abilities,
        atk = def.atk * factor * (1 + (mods.atkPct or 0)),
        hp = math.floor(def.hp * factor * (1 + (mods.hpPct or 0)) + 0.5),
    }
end

-- A big button of the camp: framed wood, an icon, a title and a line below.
local function MenuCard(parent, icon, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(250, 62)
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(MC.Tex("menu_card"))
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetPoint("TOPLEFT", 6, -6)
    hl:SetPoint("BOTTOMRIGHT", -6, 6)
    hl:SetColorTexture(1, 0.85, 0.45, 0.12)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(42, 42)
    b.icon:SetPoint("LEFT", 12, 0)
    b.icon:SetTexture(icon)
    b.title = Widgets.Text(b, 15, "gold")
    b.title:SetPoint("TOPLEFT", b.icon, "TOPRIGHT", 10, -3)
    b.sub = Widgets.Text(b, 10, "white")
    b.sub:SetPoint("TOPLEFT", b.title, "BOTTOMLEFT", 0, -4)
    b.sub:SetWidth(176)
    b.sub:SetJustifyH("LEFT")
    b:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
        onClick()
    end)
    return b
end

-- Camp ----------------------------------------------------------------------------------------------

function Module:BuildCamp()
    local view = self:AddView("camp", CreateFrame("Frame", nil, self.container))
    local ribbon = MC.CreateRibbon(view, 440, "MC_NAME", 24)
    ribbon:SetPoint("TOP", 0, -8)
    local tagline = Widgets.LocalizedText(view, 13, "white", "MC_TAGLINE")
    tagline:SetPoint("TOP", ribbon, "BOTTOM", 0, -2)

    -- The party on stage; plates and shadows sit on their own layers around the models.
    local floor = CreateFrame("Frame", nil, view)
    floor:SetAllPoints()
    local stage = CreateFrame("Frame", nil, view)
    stage:SetAllPoints()
    stage:SetFrameLevel(floor:GetFrameLevel() + 2)
    local plates = CreateFrame("Frame", nil, view)
    plates:SetAllPoints()
    plates:SetFrameLevel(stage:GetFrameLevel() + 10)
    self.campSlots = {}
    for i = 1, Bounty.PARTY_SIZE do
        local x = W / 2 + (i - 3.5) * 128
        local shadow = floor:CreateTexture(nil, "ARTWORK")
        shadow:SetTexture(MC.Tex("node_glow"))
        shadow:SetVertexColor(0, 0, 0, 0.8)
        shadow:SetSize(110, 34)
        shadow:SetPoint("CENTER", view, "TOPLEFT", x, -352)
        local model = MC.Model(stage, nil)
        model:SetSize(130, 220)
        model:SetPoint("BOTTOM", view, "TOPLEFT", x, -362)
        local plate = MC.CreatePlate(plates, 124, 30, 11)
        plate:SetPoint("TOP", view, "TOPLEFT", x, -362)
        plate.text:SetPoint("CENTER", 8, 5)
        plate.text:SetWidth(98)
        plate.role = plate:CreateTexture(nil, "ARTWORK")
        plate.role:SetSize(18, 18)
        plate.role:SetPoint("LEFT", 6, 0)
        plate.level = Widgets.Text(plate, 9, "gray")
        plate.level:SetPoint("BOTTOM", 8, 4)
        self.campSlots[i] = { model = model, plate = plate, shadow = shadow }
    end

    view.travel = MenuCard(view, "Interface\\Icons\\INV_Misc_Map_01", function()
        if self:Store().run then self:Route() else self:ShowView("travel") end
    end)
    view.collection = MenuCard(view, "Interface\\Icons\\INV_Misc_Book_11", function() self:ShowView("collection") end)
    view.scores = MenuCard(view, "Interface\\Icons\\INV_Misc_Ribbon_01", function() self.overlay:Show("scores") end)
    for i, card in ipairs({ view.travel, view.collection, view.scores }) do
        card:SetPoint("CENTER", view, "TOPLEFT", W / 2 + (i - 2) * 266, -(H - 64))
    end

    view.refresh = function()
        local store = self:Store()
        local run = store.run
        self:SetScene(run and run.zone or "elwynn", 0.42)
        for i, slot in ipairs(self.campSlots) do
            local id = store.party[i]
            slot.model:SetShown(id ~= nil)
            slot.plate:SetShown(id ~= nil)
            slot.shadow:SetShown(id ~= nil)
            if id then
                local def = MC.Mercs[id]
                slot.model:SetDisplay(def.display, (i - 3.5) * -0.12)
                slot.plate.text:SetText(Describe.MercName(id))
                slot.plate.role:SetTexture(MC.Tex("role_" .. def.role))
                slot.plate.level:SetText(L.LEVEL:format(store.mercs[id].level))
            end
        end
        if run then
            view.travel.title:SetText(L.MC_CONTINUE_RUN)
            view.travel.sub:SetText(Describe.ZoneName(run.zone) .. (run.heroic and (" (" .. L.MC_HEROIC .. ")") or ""))
        else
            view.travel.title:SetText(L.MC_BOUNTIES)
            view.travel.sub:SetText(L.MC_BOUNTIES_SUB)
        end
        view.collection.title:SetText(L.MC_COLLECTION)
        local owned = 0
        for id, entry in pairs(store.mercs) do
            if entry.owned and MC.Mercs[id] then owned = owned + 1 end
        end
        view.collection.sub:SetText(L.MC_COLLECTION_SUB:format(owned, #MC.MERC_ORDER))
        view.scores.title:SetText(L.HIGHSCORES)
        local best = ns.Scores.Best(self.id, "default")
        view.scores.sub:SetText(best > 0 and L.BEST:format(ns.FormatNumber(best)) or L.MC_NO_SCORE)
    end
end

-- Travel board ----------------------------------------------------------------------------------------

function Module:BuildTravel()
    local view = self:AddView("travel", CreateFrame("Frame", nil, self.container))
    local ribbon = MC.CreateRibbon(view, 300, "MC_BOUNTIES", 18)
    ribbon:SetPoint("TOPLEFT", 4, -2)
    view.party = Widgets.Text(view, 12, "white")
    view.party:SetPoint("TOPRIGHT", -20, -20)
    self.travelContinent = "ek"

    view.tabs = {}
    for i, c in ipairs(CONTINENTS) do
        local tab = Widgets.Button(view, 150, 22, "MC_CONTINENT_" .. c:upper(), function()
            self.travelContinent, self.travelZone = c, nil
            view.refresh()
        end)
        tab:SetPoint("TOPLEFT", 330 + (i - 1) * 156, -24)
        view.tabs[c] = tab
    end

    local map = MC.CreateMapCanvas(view, MAP_W, MAP_H)
    map:SetPoint("TOPLEFT", 14, -62)
    Widgets.Rim(view, map)
    view.map = map
    local pinLayer = CreateFrame("Frame", nil, view)
    pinLayer:SetAllPoints(map)
    pinLayer:SetFrameLevel(map:GetFrameLevel() + 5)
    view.pins = {}
    for i = 1, 24 do
        local pin = CreateFrame("Button", nil, pinLayer)
        pin:SetSize(28, 28)
        pin.glow = pin:CreateTexture(nil, "BACKGROUND")
        pin.glow:SetTexture(MC.Tex("node_glow"))
        pin.glow:SetSize(54, 54)
        pin.glow:SetPoint("CENTER")
        pin.glow:SetBlendMode("ADD")
        pin.icon = pin:CreateTexture(nil, "ARTWORK")
        pin.icon:SetSize(23, 23)
        pin.icon:SetPoint("CENTER")
        local mask = pin:CreateMaskTexture()
        mask:SetTexture(MC.Tex("circle_mask"), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(pin.icon)
        pin.icon:AddMaskTexture(mask)
        pin.ring = pin:CreateTexture(nil, "OVERLAY")
        pin.ring:SetTexture(MC.Tex("node_ring"))
        pin.ring:SetSize(33, 33)
        pin.ring:SetPoint("CENTER")
        pin.check = pin:CreateTexture(nil, "OVERLAY", nil, 1)
        pin.check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
        pin.check:SetSize(14, 14)
        pin.check:SetPoint("BOTTOMRIGHT", 4, -4)
        -- Names only show for the hovered or chosen zone; the south of the map is crowded.
        pin.label = Widgets.Text(pin, 11, "white")
        pin.label:SetPoint("TOP", pin, "BOTTOM", 0, -1)
        pin:SetScript("OnClick", function()
            self.travelZone = pin.zone
            MC.Sound("select")
            view.refresh()
        end)
        pin:SetScript("OnEnter", function()
            pin.glow:Show()
            pin.label:Show()
            local zone = MC.Zones[pin.zone]
            GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
            GameTooltip:SetText(Describe.ZoneName(pin.zone), 1, 0.82, 0)
            GameTooltip:AddLine(L.MC_LEVEL_RANGE:format(zone.min, zone.max), 1, 1, 1)
            GameTooltip:AddLine(L["MC_E_" .. zone.boss], 0.8, 0.8, 0.8)
            GameTooltip:Show()
        end)
        pin:SetScript("OnLeave", function()
            pin.glow:SetShown(self.travelZone == pin.zone)
            pin.label:SetShown(self.travelZone == pin.zone)
            GameTooltip:Hide()
        end)
        pin:Hide()
        view.pins[i] = pin
    end

    -- The wanted poster of the chosen zone.
    local poster = CreateFrame("Frame", nil, view)
    poster:SetSize(236, 490)
    poster:SetPoint("TOPRIGHT", -8, -52)
    local paper = poster:CreateTexture(nil, "BACKGROUND")
    paper:SetAllPoints()
    paper:SetTexture(MC.Tex("poster"))
    paper:SetTexCoord(0, 1, 0, 490 / 512)
    view.poster = poster
    poster.wanted = Ink(poster, 26, POSTER_RED)
    poster.wanted:SetPoint("TOP", 0, -34)
    poster.frame = CreateFrame("Frame", nil, poster)
    poster.frame:SetSize(176, 168)
    poster.frame:SetPoint("TOP", 0, -72)
    local back = poster.frame:CreateTexture(nil, "BACKGROUND")
    back:SetAllPoints()
    back:SetColorTexture(0.1, 0.07, 0.05, 0.9)
    Widgets.Rim(poster.frame, poster.frame)
    poster.model = MC.Model(poster.frame, 0.55)
    poster.model:SetAllPoints()
    poster.boss = Ink(poster, 16, INK)
    poster.boss:SetPoint("TOP", poster.frame, "BOTTOM", 0, -10)
    poster.boss:SetWidth(210)
    poster.zone = Ink(poster, 12, INK)
    poster.zone:SetPoint("TOP", poster.boss, "BOTTOM", 0, -4)
    poster.levels = Ink(poster, 12, INK)
    poster.levels:SetPoint("TOP", poster.zone, "BOTTOM", 0, -6)
    poster.reward = Ink(poster, 11, INK)
    poster.reward:SetPoint("TOP", poster.levels, "BOTTOM", 0, -12)
    poster.reward:SetWidth(200)
    poster.reward:SetSpacing(3)
    poster.status = Ink(poster, 11, INK)
    poster.status:SetPoint("BOTTOM", 0, 64)
    poster.hint = Ink(poster, 13, INK)
    poster.hint:SetPoint("CENTER", 0, 20)
    poster.hint:SetWidth(180)
    poster.normal = Widgets.Button(poster, 100, 24, "MC_NORMAL", function() self:StartBounty(self.travelZone, false) end)
    poster.normal:SetPoint("BOTTOMLEFT", 16, 30)
    poster.heroic = Widgets.Button(poster, 100, 24, "MC_HEROIC", function() self:StartBounty(self.travelZone, true) end)
    poster.heroic:SetPoint("BOTTOMRIGHT", -16, 30)
    poster.heroic:SetMotionScriptsWhileDisabled(true)
    poster.heroic:SetScript("OnEnter", function(b)
        if not b:IsEnabled() then
            GameTooltip:SetOwner(b, "ANCHOR_TOP")
            GameTooltip:SetText(L.MC_HEROIC_LOCKED, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    poster.heroic:SetScript("OnLeave", GameTooltip_Hide)

    local backButton = Widgets.Button(view, 140, 22, "BACK", function() self:ShowView("camp") end)
    backButton:SetPoint("BOTTOMLEFT", 14, 8)

    view.refresh = function() self:RefreshTravel() end
end

function Module:RefreshTravel()
    local store = self:Store()
    local view = self.views.travel
    self:SetScene(nil)
    local reference = math.floor(Bounty.PartyLevel(store) + 0.5)
    view.party:SetText(L.MC_PARTY_LEVEL:format(reference))
    local continent = self.travelContinent
    for c, tab in pairs(view.tabs) do tab:SetEnabled(c ~= continent) end
    local crop = CONTINENT_VIEW[continent]
    view.map:SetMap(continent, crop[1], crop[2], crop[3], crop[4])

    local used = 0
    for _, zid in ipairs(MC.ZONE_ORDER) do
        local place = MC.ZoneMaps[zid]
        if place and place.continent == continent then
            used = used + 1
            local pin = view.pins[used]
            local r = place.rect
            local x, y = view.map:Point((r[1] + r[2]) / 2, (r[3] + r[4]) / 2)
            pin:ClearAllPoints()
            pin:SetPoint("CENTER", view.map, "TOPLEFT", x, -y)
            pin.zone = zid
            local state = Bounty.ZoneState(store, zid)
            local zone = MC.Zones[zid]
            pin.icon:SetTexture(state.heroic > 0 and "Interface\\Icons\\INV_Misc_Head_Dragon_01" or "Interface\\Icons\\INV_Misc_Bone_HumanSkull_01")
            pin.ring:SetVertexColor(state.heroic > 0 and 0.8 or 1, state.heroic > 0 and 0.5 or 1, 1)
            pin.check:SetShown(state.normal > 0)
            local cr, cg, cb = MC.ConColor(Bounty.BossLevel(zone, false), reference)
            pin.label:SetText(("%s |cff%02x%02x%02x(%d-%d)|r"):format(Describe.ZoneName(zid), cr * 255, cg * 255, cb * 255, zone.min, zone.max))
            pin.glow:SetShown(self.travelZone == zid)
            pin.label:SetShown(self.travelZone == zid)
            pin:SetFrameLevel(pin:GetParent():GetFrameLevel() + (self.travelZone == zid and 5 or 1))
            pin:Show()
        end
    end
    for i = used + 1, #view.pins do view.pins[i]:Hide() end
    if continent == "zephras" and not self.travelZone then self.travelZone = "zephras" end
    self:RefreshPoster()
end

function Module:RefreshPoster()
    local store = self:Store()
    local poster = self.views.travel.poster
    local zid = self.travelZone
    local zone = zid and MC.Zones[zid]
    poster.wanted:SetText(L.MC_WANTED)
    for _, region in ipairs({ poster.frame, poster.boss, poster.zone, poster.levels, poster.reward, poster.status, poster.normal, poster.heroic }) do
        region:SetShown(zone ~= nil)
    end
    poster.hint:SetShown(zone == nil)
    poster.hint:SetText(L.MC_PICK_ZONE)
    if not zone then return end
    local boss = MC.Enemies[zone.boss]
    poster.model:SetDisplay(boss.display, 0.35)
    poster.boss:SetText(L["MC_E_" .. zone.boss])
    poster.zone:SetText(Describe.ZoneName(zid))
    local reference = math.floor(Bounty.PartyLevel(store) + 0.5)
    local bossLevel = Bounty.BossLevel(zone, false)
    local r, g, b = MC.ConColor(bossLevel, reference)
    poster.levels:SetText(L.MC_LEVEL_RANGE:format(zone.min, zone.max)
        .. ("  ·  |cff%02x%02x%02x%s|r"):format(r * 200, g * 160, b * 120, L.MC_BOSS_LEVEL:format(bossLevel)))
    local reward = { L.MC_REWARD }
    for _, id in ipairs(zone.loot) do
        reward[#reward + 1] = ("|T%s:14:14|t %s"):format(MC.Tex("role_" .. MC.Mercs[id].role), Describe.MercName(id))
    end
    poster.reward:SetText(table.concat(reward, "\n"))
    local state = Bounty.ZoneState(store, zid)
    local status = {}
    if state.normal > 0 then status[#status + 1] = L.MC_DONE_NORMAL end
    if state.heroic > 0 then status[#status + 1] = L.MC_DONE_HEROIC end
    poster.status:SetText(table.concat(status, "  ·  "))
    local running = store.run ~= nil
    poster.normal:SetEnabled(not running)
    poster.heroic:SetEnabled(not running and Bounty.HeroicUnlocked(store, zid))
end

-- Collection -------------------------------------------------------------------------------------------

function Module:BuildCollection()
    local view = self:AddView("collection", CreateFrame("Frame", nil, self.container))
    local ribbon = MC.CreateRibbon(view, 300, "MC_COLLECTION", 18)
    ribbon:SetPoint("TOPLEFT", 4, -2)
    self.collectionPage = 1

    -- Cards: the mercenary's token with its name on a plate below.
    view.cards = {}
    local plates = CreateFrame("Frame", nil, view)
    plates:SetAllPoints()
    plates:SetFrameLevel(view:GetFrameLevel() + 20)
    for i = 1, CARD_COLUMNS * CARD_ROWS do
        local col, row = (i - 1) % CARD_COLUMNS, math.floor((i - 1) / CARD_COLUMNS)
        local x, y = 86 + col * 140, 140 + row * 206
        local token = MC.CreateToken(view)
        token:SetScale(1.1)
        token:SetPoint("CENTER", view, "TOPLEFT", x / 1.1, -y / 1.1)
        local plate = MC.CreatePlate(plates, 132, 26, 11)
        plate:SetPoint("TOP", view, "TOPLEFT", x, -(y + 76))
        plate.sub = Widgets.Text(plate, 9, "gray")
        plate.sub:SetPoint("TOP", plate, "BOTTOM", 0, -1)
        token:SetScript("OnClick", function() self:CollectionClicked(token.merc) end)
        token:SetScript("OnEnter", function() token.glow:Show() end)
        token:SetScript("OnLeave", function() token.glow:Hide() end)
        token.plate = plate
        view.cards[i] = token
    end
    view.pager = Widgets.Cycler(view, 140, function(dir)
        local pages = math.ceil(#MC.MERC_ORDER / #view.cards)
        self.collectionPage = (self.collectionPage - 1 + dir) % pages + 1
        view.refresh()
    end)
    view.pager:SetPoint("BOTTOM", view, "BOTTOMLEFT", 296, 14)

    -- The party on the right.
    local panel = CreateFrame("Frame", nil, view)
    panel:SetPoint("TOPLEFT", 604, -56)
    panel:SetPoint("BOTTOMRIGHT", -10, 44)
    local fill = panel:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    fill:SetColorTexture(0.05, 0.03, 0.02, 0.82)
    Widgets.Rim(panel, panel)
    local title = Widgets.LocalizedText(panel, 14, "gold", "MC_PARTY")
    title:SetPoint("TOP", 0, -10)
    view.slots = {}
    for i = 1, Bounty.PARTY_SIZE do
        local b = CreateFrame("Button", nil, panel)
        b:SetSize(204, 50)
        b:SetPoint("TOP", 0, -34 - (i - 1) * 56)
        b.bg = b:CreateTexture(nil, "BACKGROUND")
        b.bg:SetAllPoints()
        b.bg:SetTexture(MC.Tex("plate"))
        b.mark = b:CreateTexture(nil, "BORDER")
        b.mark:SetPoint("TOPLEFT", 4, -4)
        b.mark:SetPoint("BOTTOMRIGHT", -4, 4)
        b.mark:SetColorTexture(0.3, 1, 0.3, 0.2)
        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetPoint("TOPLEFT", 4, -4)
        hl:SetPoint("BOTTOMRIGHT", -4, 4)
        hl:SetColorTexture(1, 0.85, 0.4, 0.12)
        b.role = b:CreateTexture(nil, "ARTWORK")
        b.role:SetSize(26, 26)
        b.role:SetPoint("LEFT", 10, 0)
        b.name = Widgets.Text(b, 12, "white")
        b.name:SetPoint("TOPLEFT", b.role, "TOPRIGHT", 8, 0)
        b.name:SetWidth(150)
        b.name:SetJustifyH("LEFT")
        b.name:SetWordWrap(false)
        b.level = Widgets.Text(b, 10, "gray")
        b.level:SetPoint("TOPLEFT", b.name, "BOTTOMLEFT", 0, -2)
        b:SetScript("OnClick", function()
            if self:Store().run then return end
            self.partySlot = self.partySlot ~= i and i or nil
            MC.Sound("select")
            view.refresh()
        end)
        view.slots[i] = b
    end
    view.hint = Widgets.Text(panel, 10, "gray")
    view.hint:SetPoint("BOTTOM", 0, 10)
    view.hint:SetWidth(200)

    local back = Widgets.Button(view, 140, 22, "BACK", function()
        self.partySlot = nil
        self:ShowView("camp")
    end)
    back:SetPoint("BOTTOMLEFT", 14, 8)

    self:CreateMercPage()
    view.refresh = function() self:RefreshCollection() end
end

function Module:CollectionClicked(id)
    if not id then return end
    local store = self:Store()
    local entry = store.mercs[id]
    if self.partySlot and entry and entry.owned then
        if Bounty.SetPartySlot(store, self.partySlot, id) then MC.Sound("select") end
        self.partySlot = nil
        self:RefreshCollection()
        return
    end
    self.overlay:Show("merc", id)
end

function Module:RefreshCollection()
    local store = self:Store()
    local view = self.views.collection
    self:SetScene("ek", 0.3)
    local locked = store.run ~= nil
    if locked then self.partySlot = nil end
    local inParty = {}
    for i, b in ipairs(view.slots) do
        local id = store.party[i]
        if id then inParty[id] = true end
        b.role:SetTexture(id and MC.Tex("role_" .. MC.Mercs[id].role) or nil)
        b.name:SetText(id and Describe.MercName(id) or "")
        b.level:SetText(id and L.LEVEL:format(store.mercs[id].level) or "")
        b.mark:SetShown(self.partySlot == i)
    end
    view.hint:SetText(locked and L.MC_PARTY_LOCKED or (self.partySlot and L.MC_PARTY_PICK or L.MC_PARTY_HINT))

    local perPage = #view.cards
    local pages = math.ceil(#MC.MERC_ORDER / perPage)
    view.pager.label:SetText(("%d / %d"):format(self.collectionPage, pages))
    for i, token in ipairs(view.cards) do
        local id = MC.MERC_ORDER[(self.collectionPage - 1) * perPage + i]
        token:SetShown(id ~= nil)
        token.plate:SetShown(id ~= nil)
        token.merc = id
        if id then
            local entry = store.mercs[id]
            local owned = entry and entry.owned
            local unit = MC.PreviewUnit(store, id)
            token:SetData({
                kind = "merc", id = id, side = "ally", role = unit.role, level = unit.level,
                atk = math.floor(unit.atk + 0.5), hp = unit.hp, maxHp = unit.hp,
            })
            token:SetLocked(not owned)
            token.select:SetShown(inParty[id] or false)
            token.select:SetVertexColor(1, 0.82, 0.3)
            token.name:SetText("")
            token.plate.text:SetText(Describe.MercName(id))
            if owned then
                token.plate.sub:SetText(inParty[id] and L.MC_IN_PARTY or "")
            else
                token.plate.sub:SetText(L.MC_COINS_PROGRESS:format(entry and entry.coins or 0, Bounty.RECRUIT_COST))
            end
        end
    end
end

-- Mercenary page --------------------------------------------------------------------------------------

function Module:CreateMercPage()
    local page = self.overlay:AddPage("merc")
    local ribbon = MC.CreateRibbon(page, 360, nil, 20)
    ribbon:SetPoint("TOPLEFT", 10, -6)
    page.token = MC.CreateToken(page)
    page.token:SetScale(1.9)
    page.token:SetPoint("CENTER", page, "TOPLEFT", 140 / 1.9, -210 / 1.9)
    page.token:EnableMouse(false)
    page.role = Widgets.Text(page, 13, "white")
    page.role:SetPoint("TOP", page, "TOPLEFT", 140, -340)
    page.level = Widgets.Text(page, 13, "gold")
    page.level:SetPoint("TOP", page.role, "BOTTOM", 0, -6)
    local bar = CreateFrame("StatusBar", nil, page)
    bar:SetSize(200, 12)
    bar:SetPoint("TOP", page.level, "BOTTOM", 0, -6)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(0.58, 0.0, 0.55)
    local barBg = bar:CreateTexture(nil, "BACKGROUND")
    barBg:SetAllPoints()
    barBg:SetColorTexture(0, 0, 0, 0.6)
    Widgets.Rim(page, bar)
    page.xpBar = bar
    page.xp = Widgets.Text(bar, 9, "white")
    page.xp:SetPoint("CENTER")
    page.coins = Widgets.Text(page, 13, "gold")
    page.coins:SetPoint("TOP", bar, "BOTTOM", 0, -12)
    page.recruit = Widgets.Button(page, 180, 26, "MC_RECRUIT", function()
        local store = self:Store()
        if Bounty.Recruit(store, page.merc) then
            PlaySound(SOUNDKIT.IG_QUEST_LIST_COMPLETE)
            self:CheckLevels()
            page.refresh(page.merc)
        end
    end)
    page.recruit:SetPoint("TOP", page.coins, "BOTTOM", 0, -8)

    local abilitiesTitle = Widgets.LocalizedText(page, 15, "gold", "MC_ABILITIES")
    abilitiesTitle:SetPoint("TOPLEFT", 300, -60)
    page.cards, page.ups, page.locks = {}, {}, {}
    for i = 1, 3 do
        local x = 352 + (i - 1) * 140
        local card = MC.CreateAbilityCard(page)
        card:SetPoint("CENTER", page, "TOPLEFT", x, -160)
        card:SetScript("OnEnter", function(c)
            if not c.abilityId then return end
            local unit = MC.PreviewUnit(self:Store(), page.merc)
            GameTooltip:SetOwner(c, "ANCHOR_RIGHT")
            GameTooltip:SetText(Describe.AbilityName(c.abilityId), 1, 0.82, 0)
            GameTooltip:AddLine(Describe.AbilityStats(c.abilityId, unit, i), 0.7, 0.7, 0.7)
            GameTooltip:AddLine(Describe.Ability(c.abilityId, unit, i), 1, 1, 1, true)
            GameTooltip:Show()
        end)
        card:SetScript("OnLeave", GameTooltip_Hide)
        page.cards[i] = card
        local lock = Widgets.Text(page, 11, "white")
        lock:SetPoint("CENTER", card, "CENTER", 0, 0)
        page.locks[i] = lock
        local up = Widgets.Button(page, 120, 22, nil, function()
            if Bounty.RankUp(self:Store(), page.merc, i) then
                PlaySound(SOUNDKIT.IG_QUEST_LIST_COMPLETE)
                self:CheckLevels()
                page.refresh(page.merc)
            end
        end)
        up:SetPoint("TOP", card, "BOTTOM", 0, -6)
        page.ups[i] = up
    end

    local gearTitle = Widgets.LocalizedText(page, 15, "gold", "MC_EQUIPMENT")
    gearTitle:SetPoint("TOPLEFT", 300, -282)
    page.gear = {}
    for i = 1, 3 do
        local b = CreateFrame("Button", nil, page)
        b:SetSize(46, 46)
        b:SetPoint("TOPLEFT", 300 + (i - 1) * 56, -306)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetAllPoints()
        b.border = b:CreateTexture(nil, "OVERLAY")
        b.border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        b.border:SetBlendMode("ADD")
        b.border:SetPoint("CENTER")
        b.border:SetSize(82, 82)
        b:SetScript("OnClick", function()
            if Bounty.SetGear(self:Store(), page.merc, i) then
                MC.Sound("select")
                page.refresh(page.merc)
            end
        end)
        b:SetScript("OnEnter", function() self:GearTooltip(b, page.merc, i) end)
        b:SetScript("OnLeave", GameTooltip_Hide)
        page.gear[i] = b
    end
    page.gearName = Widgets.Text(page, 13, "gold")
    page.gearName:SetPoint("TOPLEFT", 480, -310)
    page.gearDesc = Widgets.Text(page, 11, "white")
    page.gearDesc:SetPoint("TOPLEFT", page.gearName, "BOTTOMLEFT", 0, -4)
    page.gearDesc:SetWidth(330)
    page.gearDesc:SetJustifyH("LEFT")

    local back = Widgets.Button(page, 180, 26, "BACK", function()
        self.overlay:Hide()
        self:RefreshCollection()
    end)
    back:SetPoint("BOTTOM", 0, 18)

    local ROMAN = { "I", "II", "III" }
    page.refresh = function(id)
        id = id or page.merc
        page.merc = id
        local store = self:Store()
        local def = MC.Mercs[id]
        local entry = store.mercs[id] or Bounty.NewEntry(false)
        local unit = MC.PreviewUnit(store, id)
        ribbon.text:SetText(Describe.MercName(id))
        page.token:SetData({
            kind = "merc", id = id, side = "ally", role = def.role, level = entry.level,
            atk = math.floor(unit.atk + 0.5), hp = unit.hp, maxHp = unit.hp,
        })
        page.token:SetLocked(not entry.owned)
        page.token.name:SetText("")
        local c = MC.ROLE_COLORS[def.role]
        page.role:SetText(Describe.RoleName(def.role))
        page.role:SetTextColor(c[1], c[2], c[3])
        page.level:SetText(L.LEVEL:format(entry.level))
        if entry.level < MC.MAX_LEVEL then
            local need = Bounty.XPNeeded(entry.level)
            page.xpBar:SetMinMaxValues(0, need)
            page.xpBar:SetValue(entry.xp)
            page.xp:SetText(L.MC_XP:format(ns.FormatNumber(entry.xp), ns.FormatNumber(need)))
        else
            page.xpBar:SetMinMaxValues(0, 1)
            page.xpBar:SetValue(1)
            page.xp:SetText(L.MC_MAX_LEVEL)
        end
        page.coins:SetText(L.MC_COINS:format(entry.coins))
        page.recruit:SetShown(not entry.owned)
        page.recruit:SetEnabled(Bounty.CanRecruit(store, id))
        page.recruit:SetText(L.MC_RECRUIT_COST:format(Bounty.RECRUIT_COST))
        for i, card in ipairs(page.cards) do
            local unlocked = entry.level >= MC.ABILITY_LEVELS[i]
            card:SetAbility(def.abilities[i], unit, i)
            card.shade:SetShown(not unlocked)
            card.icon:SetDesaturated(not unlocked)
            page.locks[i]:SetText(unlocked and "" or L.MC_UNLOCKS_AT:format(MC.ABILITY_LEVELS[i]))
            local cost = Bounty.RankCost(entry, i)
            page.ups[i]:SetShown(entry.owned and cost ~= nil)
            if cost then page.ups[i]:SetText(L.MC_RANK_UP:format(ROMAN[entry.ranks[i] + 1], cost)) end
            page.ups[i]:SetEnabled(Bounty.CanRankUp(store, id, i))
        end
        for i, b in ipairs(page.gear) do
            b.icon:SetTexture(def.gear[i].icon)
            b.icon:SetDesaturated(not entry.gears[i])
            b.icon:SetAlpha(entry.gears[i] and 1 or 0.45)
            b.border:SetShown(entry.gear == i)
        end
        local gear = entry.gear or 1
        page.gearName:SetText(L["MC_G_" .. id .. "_" .. gear])
        page.gearDesc:SetText(Describe.Mods(def.gear[gear].mods, def.abilities))
    end
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
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
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
