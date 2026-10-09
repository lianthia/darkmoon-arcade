-- Between bounties: the village (party and the buildings to go to), the travel point (a map of
-- Azeroth that zooms into its regions, with the chosen zone's boss on the right), the collection
-- book and a mercenary's own page.

local _, ns = ...
local MC = ns.Mercenaries
local Combat, Bounty, Describe, Kit = MC.Combat, MC.Bounty, MC.Describe, MC.Kit
local Widgets, L = ns.Widgets, ns.L
local Module = MC.Module
local W, H = MC.W, MC.H

local INK = { 0.24, 0.14, 0.06 }
local ROLES = { "protector", "fighter", "caster" }
local ROMAN = { "I", "II", "III" }

-- The camp stands at the Darkmoon Faire: its classic loading screen (1024x1024, a 4:3 picture
-- with a logo band at the top and a frame band at the bottom).
local CAMP_ART = 2821800
local CAMP_V0, CAMP_V1 = 0.255, 0.815

-- What the travel point shows of each zone: a starting-zone picture, a dungeon loading screen
-- (cropped to its painting) or, failing both, the zone's own map.
local ZONE_ART = {
    elwynn = { atlas = "charactercreate-startingzone-human" },
    dunmorogh = { atlas = "charactercreate-startingzone-dwarf" },
    tirisfal = { atlas = "charactercreate-startingzone-undead" },
    teldrassil = { atlas = "charactercreate-startingzone-nightelf" },
    durotar = { atlas = "charactercreate-startingzone-orc" },
    mulgore = { atlas = "charactercreate-startingzone-tauren" },
    westfall = { file = 131833 },
    silverpine = { file = 131869 },
    barrens = { file = 131882 },
    ashenvale = { file = 131823 },
}

-- Boss portraits from the client's dungeon journal; other zones get a fitting icon.
local BOSS_ART = {
    hogger = 607646, vancleef = 5875507, thermaplugg = 607714, whitemane = 607643, akumai = 607532,
}
local BOSS_ICON = {
    melenas = "Spell_Shadow_Metamorphosis", zalazane = "INV_Misc_Head_Troll_01", arrachea = "Ability_Mount_Kodo_01",
    lorthuna = "Spell_Nature_CallStorm", galgosh = "Ability_Warrior_PunishingBlow", arugal = "Spell_Shadow_ShadowWordDominate",
    murkdeep = "INV_Misc_Head_Murloc_01", kodobane = "INV_Spear_02", gathilzogg = "INV_Misc_Head_Orc_01",
    gerenzo = "INV_Misc_Bomb_08", stitches = "Spell_Shadow_RaiseDead", nekrosh = "INV_Misc_Head_Dragon_Black",
    burnside = "Spell_Holy_SealOfWisdom",
}
MC.BOSS_ART, MC.BOSS_ICON = BOSS_ART, BOSS_ICON

-- Regions of each continent the travel point zooms into.
local REGIONS = {
    ek = {
        { key = "lordaeron", zones = { "tirisfal", "silverpine", "hillsbrad" } },
        { key = "khazmodan", zones = { "dunmorogh", "lochmodan", "wetlands" } },
        { key = "azeroth", zones = { "elwynn", "westfall", "redridge", "duskwood" } },
    },
    kal = {
        { key = "northkal", zones = { "teldrassil", "darkshore", "ashenvale" } },
        { key = "centralkal", zones = { "stonetalon", "barrens", "durotar", "mulgore" } },
    },
    zephras = {
        { key = "zephras", zones = { "zephras" } },
    },
}

local MAP_W, MAP_H = 566, 452

-- The part of a map (u0, u1, v0, v1) that shows a rectangle with a margin at the canvas' aspect.
local function FitView(l, r, t, b, margin)
    local cu, cv = (l + r) / 2, (t + b) / 2
    local mapAspect, aspect = 1002 / 668, MAP_W / MAP_H
    local hu, hv = (r - l) / 2 + margin, (b - t) / 2 + margin
    -- Widen whichever side is short so the view keeps the canvas' aspect.
    if hu * mapAspect / hv > aspect then
        hv = hu * mapAspect / aspect
    else
        hu = hv * aspect / mapAspect
    end
    return cu - hu, cu + hu, cv - hv, cv + hv
end

local function RegionBounds(region)
    local l, r, t, b = 1, 0, 1, 0
    for _, zid in ipairs(region.zones) do
        local rect = MC.ZoneMaps[zid].rect
        l, r, t, b = math.min(l, rect[1]), math.max(r, rect[2]), math.min(t, rect[3]), math.max(b, rect[4])
    end
    return l, r, t, b
end

local function RegionView(region)
    if region.key == "zephras" then return 0.05, 0.95, 0.03, 0.97 end
    local l, r, t, b = RegionBounds(region)
    return FitView(l, r, t, b, 0.03)
end

local function ContinentView(continent)
    if continent == "zephras" then return 0.05, 0.95, 0.03, 0.97 end
    return FitView(0.36, 0.66, 0.06, 0.86, 0.02)
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
        atk = math.floor(def.atk * factor * (1 + (mods.atkPct or 0)) + 0.5),
        hp = math.floor(def.hp * factor * (1 + (mods.hpPct or 0)) + 0.5),
    }
end

local function CardExtra(store, id)
    local entry = store.mercs[id] or Bounty.NewEntry(false)
    local xp = entry.level < MC.MAX_LEVEL and entry.xp / Bounty.XPNeeded(entry.level) or 1
    return { xp = xp, coins = entry.coins, locked = not entry.owned }
end

-- A "!" above something worth a look.
local function Marker(parent)
    local t = parent:CreateTexture(nil, "OVERLAY", nil, 5)
    t:SetSize(28, 28)
    t:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")
    return t
end

-- Village -------------------------------------------------------------------------------------------

local function Hotspot(parent, icon, size, onClick)
    local b = Kit.Medallion(parent, size)
    b.icon:SetTexture(icon)
    b.plaque = Kit.Plaque(b, 168, nil, 14)
    b.plaque:SetPoint("TOP", b, "BOTTOM", 0, 12)
    b.sub = Kit.Ink(b, 11, { 1, 0.95, 0.85 }, "OUTLINE")
    b.sub:SetPoint("TOP", b.plaque, "BOTTOM", 0, 8)
    b.sub:SetWidth(200)
    b.marker = Marker(b)
    b.marker:SetPoint("BOTTOM", b, "TOP", 0, -8)
    b:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPEN)
        onClick()
    end)
    Kit.Hover(b, { grow = 1.1, lift = 4 })
    return b
end

-- Where the six party members stand: a gentle arc, names alternating high and low so long names
-- never touch.
local CAMP_X0, CAMP_GAP, CAMP_FEET = W / 2 - 2.5 * 92, 92, 462

function Module:BuildCamp()
    local view = self:AddView("camp", CreateFrame("Frame", nil, self.container))
    local art = view:CreateTexture(nil, "BACKGROUND")
    art:SetAllPoints()
    art:SetTexture(CAMP_ART)
    -- The painting is 1024 wide and (v1 - v0) * 768 high on screen; show the middle at our aspect.
    local share = (W / H) * (CAMP_V1 - CAMP_V0) * 768 / 1024
    art:SetTexCoord(0.5 - share / 2 + 0.06, 0.5 + share / 2 + 0.06, CAMP_V0, CAMP_V1)
    local dusk = view:CreateTexture(nil, "BACKGROUND", nil, 2)
    dusk:SetAllPoints()
    dusk:SetTexture(MC.Tex("vignette"))
    dusk:SetAlpha(0.85)

    local title = Kit.Plaque(view, 300, "MC_NAME", 20)
    title:SetPoint("TOP", 0, -4)

    local stage = CreateFrame("Frame", nil, view)
    stage:SetAllPoints()
    stage:SetFrameLevel(view:GetFrameLevel() + 2)
    local plates = CreateFrame("Frame", nil, view)
    plates:SetAllPoints()
    plates:SetFrameLevel(stage:GetFrameLevel() + 10)
    self.campSlots = {}
    for i = 1, Bounty.PARTY_SIZE do
        local x = CAMP_X0 + (i - 1) * CAMP_GAP
        local feet = CAMP_FEET - math.abs(i - 3.5) * 6
        local shadow = stage:CreateTexture(nil, "BACKGROUND")
        shadow:SetTexture(MC.Tex("node_glow"))
        shadow:SetVertexColor(0, 0, 0, 0.75)
        shadow:SetSize(84, 22)
        shadow:SetPoint("CENTER", view, "TOPLEFT", x, -feet)
        local model = MC.Model(stage, nil)
        model:SetSize(118, 200)
        model:SetPoint("BOTTOM", view, "TOPLEFT", x, -(feet + 6))
        local plate = Kit.Banner(plates, 140, 28, 10)
        plate:SetPoint("TOP", view, "TOPLEFT", x, -(feet + (i % 2 == 1 and 4 or 32)))
        self.campSlots[i] = { model = model, plate = plate, shadow = shadow }
    end

    view.travel = Hotspot(view, "Interface\\Icons\\Spell_Arcane_PortalStormwind", 88, function()
        if self:Store().run then self:Route() else self:ShowView("travel") end
    end)
    Kit.Place(view.travel, 112, 150)
    view.collection = Hotspot(view, "Interface\\Icons\\INV_Misc_Book_11", 88, function() self:ShowView("collection") end)
    Kit.Place(view.collection, W - 112, 150)
    view.scores = Hotspot(view, "Interface\\Icons\\INV_Misc_Ribbon_01", 64, function() self.overlay:Show("scores") end)
    view.scores.plaque:ClearAllPoints()
    view.scores.plaque:SetPoint("LEFT", view.scores, "RIGHT", -14, 0)
    view.scores.sub:ClearAllPoints()
    view.scores.sub:SetPoint("TOP", view.scores.plaque, "BOTTOM", 0, 6)
    Kit.Place(view.scores, 50, 50)

    view.refresh = function() self:RefreshCamp() end
end

function Module:RefreshCamp()
    local store = self:Store()
    local view = self.views.camp
    local run = store.run
    self:SetScene(nil)
    for i, slot in ipairs(self.campSlots) do
        local id = store.party[i]
        slot.model:SetShown(id ~= nil)
        slot.plate:SetShown(id ~= nil)
        slot.shadow:SetShown(id ~= nil)
        if id then
            slot.model:SetDisplay(MC.Mercs[id].display, (i - 3.5) * -0.16)
            slot.plate.text:SetText(Describe.MercName(id))
        end
    end
    view.travel.plaque.text:SetText(run and L.MC_CONTINUE_RUN or L.MC_TRAVEL_POINT)
    view.travel.sub:SetText(run and (Describe.ZoneName(run.zone) .. (run.heroic and (" (" .. L.MC_HEROIC .. ")") or "")) or L.MC_BOUNTIES_SUB)
    view.travel.marker:SetShown(run ~= nil)
    local owned, recruitable = 0, false
    for id, entry in pairs(store.mercs) do
        if MC.Mercs[id] then
            if entry.owned then owned = owned + 1 end
            if Bounty.CanRecruit(store, id) then recruitable = true end
        end
    end
    view.collection.plaque.text:SetText(L.MC_COLLECTION)
    view.collection.sub:SetText(L.MC_COLLECTION_SUB:format(owned, #MC.MERC_ORDER))
    view.collection.marker:SetShown(recruitable)
    view.scores.plaque.text:SetText(L.HIGHSCORES)
    local best = ns.Scores.Best(self.id, "default")
    view.scores.sub:SetText(best > 0 and L.BEST:format(ns.FormatNumber(best)) or "")
    view.scores.marker:Hide()
end

-- Travel point ------------------------------------------------------------------------------------

function Module:BuildTravel()
    local view = self:AddView("travel", CreateFrame("Frame", nil, self.container))
    local wood = Kit.Wood(view, W, H, true)
    wood:SetPoint("TOPLEFT")
    local title = Kit.Plaque(view, 280, "MC_TRAVEL_POINT", 18)
    title:SetPoint("TOP", view, "TOPLEFT", 14 + MAP_W / 2, -2)
    self.travelContinent = "ek"

    -- Continent tabs above the map.
    view.tabs = {}
    for i, c in ipairs({ "ek", "kal", "zephras" }) do
        local tab = Kit.Button(view, 150, 26, "MC_CONTINENT_" .. c:upper(), function()
            self.travelContinent = c
            self.travelRegion = c == "zephras" and 1 or nil
            self.travelZone = c == "zephras" and "zephras" or nil
            self.travelZoom = nil
            self:RefreshTravel(true)
        end)
        Kit.Place(tab, 14 + MAP_W / 2 + (i - 2) * 160, 66)
        view.tabs[c] = tab
    end

    local map = MC.CreateMapCanvas(view, MAP_W, MAP_H)
    map:SetPoint("TOPLEFT", 14, -84)
    Widgets.Rim(view, map)
    view.map = map
    local layer = CreateFrame("Frame", nil, view)
    layer:SetAllPoints(map)
    layer:SetFrameLevel(map:GetFrameLevel() + 5)
    view.layer = layer

    -- Region labels on the continent; a click zooms in.
    view.regions = {}
    for i = 1, 4 do
        local b = CreateFrame("Button", nil, layer)
        b:SetSize(170, 50)
        local bg = b:CreateTexture(nil, "ARTWORK")
        bg:SetAllPoints()
        Kit.Atlas(bg, "ui-frame-neutral-ribbon", MC.Tex("ribbon"))
        b.glowTex = b:CreateTexture(nil, "OVERLAY")
        b.glowTex:SetAllPoints()
        Kit.Atlas(b.glowTex, "ui-frame-neutral-ribbon", MC.Tex("ribbon"))
        b.glowTex:SetBlendMode("ADD")
        b.glowTex:SetAlpha(0)
        b.text = Kit.Ink(b, 13, INK)
        b.text:SetPoint("CENTER", 0, 2)
        b:SetScript("OnClick", function()
            PlaySound(SOUNDKIT.IG_MAINMENU_OPEN)
            self:ZoomToRegion(b.index)
        end)
        Kit.Hover(b, { grow = 1.08 })
        b:Hide()
        view.regions[i] = b
    end

    -- Zone coins.
    view.pins = {}
    for i = 1, 24 do
        local pin = Kit.Coin(layer, 50)
        pin.plate = Kit.Banner(pin, 128, 26, 10)
        pin.plate:SetPoint("TOP", pin, "BOTTOM", 0, 6)
        pin.label = pin.plate.text
        pin:SetScript("OnClick", function()
            MC.Sound("select")
            if not self.travelRegion then
                self:ZoomToRegion(pin.region, pin.zone)
            else
                self.travelZone = pin.zone
                self:RefreshTravel()
            end
        end)
        pin:HookScript("OnEnter", function()
            local zone = MC.Zones[pin.zone]
            GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
            GameTooltip:SetText(Describe.ZoneName(pin.zone), 1, 0.82, 0)
            GameTooltip:AddLine(L.MC_LEVEL_RANGE:format(zone.min, zone.max), 1, 1, 1)
            GameTooltip:AddLine(L["MC_E_" .. zone.boss], 0.8, 0.8, 0.8)
            GameTooltip:Show()
        end)
        pin:HookScript("OnLeave", GameTooltip_Hide)
        Kit.Hover(pin, { grow = 1.18, sound = false })
        pin:Hide()
        view.pins[i] = pin
    end
    view.overview = Kit.Button(view, 170, 26, "MC_OVERVIEW", function() self:ZoomToRegion(nil) end)
    Kit.Place(view.overview, 14 + 95, H - 16)

    self:BuildBossPanel(view)
    local back = Kit.Button(view, 120, 28, "BACK", function() self:ShowView("camp") end)
    Kit.Place(back, W - 76, H - 18)
    view.refresh = function() self:RefreshTravel(true) end
end

-- The right column: picture of the zone, the boss, its story, difficulty and "Choose".
function Module:BuildBossPanel(view)
    local panel = CreateFrame("Frame", nil, view)
    panel:SetPoint("TOPLEFT", 594, -8)
    panel:SetPoint("BOTTOMRIGHT", -8, 40)
    local back = panel:CreateTexture(nil, "BACKGROUND", nil, 2)
    back:SetAllPoints()
    back:SetColorTexture(0.08, 0.05, 0.03, 0.75)
    Widgets.Rim(panel, panel)
    view.boss = panel
    panel.title = Kit.Plaque(panel, 220, "MC_BOSS_INFO", 15)
    panel.title:SetPoint("TOP", 0, 4)

    local frame = CreateFrame("Frame", nil, panel)
    frame:SetSize(214, 118)
    frame:SetPoint("TOP", 0, -50)
    panel.pictureFrame = frame
    panel.picture = frame:CreateTexture(nil, "ARTWORK")
    panel.picture:SetAllPoints()
    panel.pictureMap = MC.CreateMapCanvas(frame, 214, 118)
    panel.pictureMap:SetPoint("TOPLEFT")
    Widgets.Rim(frame, frame)

    panel.token = Kit.Coin(panel, 96)
    panel.token:SetPoint("CENTER", frame, "BOTTOM", 0, -4)
    panel.token:SetFrameLevel(frame:GetFrameLevel() + 4)
    panel.token:EnableMouse(false)
    panel.level = MC.Badge(panel.token, "level", 28, 12)
    panel.level:SetPoint("CENTER", panel.token, "TOP", 0, -4)
    panel.name = Kit.Banner(panel, 210, 36, 14)
    panel.name:SetPoint("TOP", panel.token, "BOTTOM", 0, 6)
    panel.levels = Widgets.Text(panel, 11, "white")
    panel.levels:SetPoint("TOP", panel.name, "BOTTOM", 0, -2)

    local note = CreateFrame("Frame", nil, panel)
    note:SetSize(214, 92)
    note:SetPoint("TOP", panel.levels, "BOTTOM", 0, -8)
    Kit.Parchment(note)
    Widgets.Rim(note, note)
    panel.story = Kit.Ink(note, 11, INK)
    panel.story:SetPoint("TOPLEFT", 10, -8)
    panel.story:SetPoint("BOTTOMRIGHT", -10, 8)
    panel.story:SetJustifyV("MIDDLE")
    panel.story:SetSpacing(2)
    panel.note = note

    panel.normal = Kit.Button(panel, 104, 26, "MC_NORMAL", function()
        self.travelHeroic = false
        self:RefreshBossPanel()
    end)
    panel.normal:SetPoint("TOPLEFT", note, "BOTTOMLEFT", 0, -8)
    panel.heroic = Kit.Button(panel, 104, 26, "MC_HEROIC", function()
        self.travelHeroic = true
        self:RefreshBossPanel()
    end)
    panel.heroic:SetPoint("TOPRIGHT", note, "BOTTOMRIGHT", 0, -8)
    panel.heroic:HookScript("OnEnter", function(b)
        if not b:IsEnabled() then
            GameTooltip:SetOwner(b, "ANCHOR_TOP")
            GameTooltip:SetText(L.MC_HEROIC_LOCKED, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    panel.heroic:HookScript("OnLeave", GameTooltip_Hide)
    panel.choose = Kit.BigButton(panel, 82, "MC_CHOOSE", function()
        self:StartBounty(self.travelZone, self.travelHeroic or false)
    end)
    Kit.Place(panel.choose, 119, 466, panel)
    panel.hint = Kit.Ink(panel, 13, { 1, 0.9, 0.7 }, "OUTLINE")
    panel.hint:SetPoint("CENTER", 0, 0)
    panel.hint:SetWidth(190)
end

function Module:ZoomToRegion(index, zone)
    local continent = self.travelContinent
    local from = { unpack(self.views.travel.map.view) }
    local to
    if index then
        to = { RegionView(REGIONS[continent][index]) }
    else
        to = { ContinentView(continent) }
        self.travelZone = nil
    end
    self.travelRegion = index
    if zone then self.travelZone = zone end
    self.travelZoom = { from = from, to = to, t = 0 }
    self:RefreshTravel()
end

-- Eases the map from one view to the next; pins follow every frame.
function Module:UpdateTravel(dt)
    local zoom = self.travelZoom
    if not zoom then return end
    zoom.t = math.min(1, zoom.t + dt / 0.45)
    local p = zoom.t * zoom.t * (3 - 2 * zoom.t)
    local v = {}
    for i = 1, 4 do v[i] = zoom.from[i] + (zoom.to[i] - zoom.from[i]) * p end
    self.views.travel.map:SetMap(self.travelContinent, v[1], v[2], v[3], v[4])
    self:PlacePins()
    if zoom.t >= 1 then self.travelZoom = nil end
end

function Module:PlacePins()
    local view = self.views.travel
    for _, pin in ipairs(view.pins) do
        if pin:IsShown() then
            local r = MC.ZoneMaps[pin.zone].rect
            local x, y = view.map:Point((r[1] + r[2]) / 2, (r[3] + r[4]) / 2)
            Kit.Place(pin, x, y, view.layer)
        end
    end
    for _, b in ipairs(view.regions) do
        if b:IsShown() then
            local l, r, t, bt = RegionBounds(REGIONS[self.travelContinent][b.index])
            local x, y = view.map:Point((l + r) / 2, (t + bt) / 2)
            Kit.Place(b, x, y, view.layer)
        end
    end
end

function Module:RefreshTravel(resetView)
    local store = self:Store()
    local view = self.views.travel
    self:SetScene(nil)
    local continent = self.travelContinent
    for c, tab in pairs(view.tabs) do tab:SetEnabled(c ~= continent) end
    if resetView and not self.travelZoom then
        local v = self.travelRegion and { RegionView(REGIONS[continent][self.travelRegion]) } or { ContinentView(continent) }
        view.map:SetMap(continent, v[1], v[2], v[3], v[4])
    end
    local zoomed = self.travelRegion ~= nil
    view.overview:SetShown(zoomed and continent ~= "zephras")

    local regions = REGIONS[continent]
    for i, b in ipairs(view.regions) do
        local region = regions[i]
        b:SetShown(region ~= nil and not zoomed)
        if region then
            b.index = i
            local done = 0
            for _, zid in ipairs(region.zones) do
                if MC.Zones[zid] and Bounty.ZoneState(store, zid).normal > 0 then done = done + 1 end
            end
            b.text:SetText(L["MC_REGION_" .. region.key:upper()] .. "  |cff6a4a20" .. done .. "/" .. #region.zones .. "|r")
        end
    end

    local used = 0
    for ri, region in ipairs(regions) do
        for _, zid in ipairs(region.zones) do
            if MC.Zones[zid] and zoomed and ri == self.travelRegion then
                used = used + 1
                local pin = view.pins[used]
                pin.zone, pin.region = zid, ri
                local state = Bounty.ZoneState(store, zid)
                local boss = MC.Zones[zid].boss
                if not pin:SetCreature(MC.Enemies[boss].display) then
                    pin:SetIcon("Interface\\Icons\\" .. (BOSS_ICON[boss] or "INV_Misc_Bone_HumanSkull_01"))
                end
                pin:SetMetal(state.heroic > 0 and "gold" or (state.normal > 0 and "silver" or "bronze"))
                pin.check:SetShown(state.normal > 0)
                pin.label:SetText(Describe.ZoneName(zid))
                Kit.SetSelected(pin, self.travelZone == zid, true)
                pin:Show()
            end
        end
    end
    for i = used + 1, #view.pins do view.pins[i]:Hide() end
    self:PlacePins()
    self:RefreshBossPanel()
end

function Module:RefreshBossPanel()
    local store = self:Store()
    local panel = self.views.travel.boss
    local zid = self.travelZone
    local zone = zid and MC.Zones[zid]
    for _, region in ipairs({ panel.pictureFrame, panel.token, panel.name, panel.levels, panel.note, panel.normal, panel.heroic, panel.choose }) do
        region:SetShown(zone ~= nil)
    end
    panel.hint:SetShown(zone == nil)
    panel.hint:SetText(L.MC_PICK_ZONE)
    if not zone then return end
    local art = ZONE_ART[zid]
    panel.picture:SetShown(art ~= nil)
    panel.pictureMap:SetShown(art == nil)
    if art and art.atlas then
        Kit.Atlas(panel.picture, art.atlas, nil)
        panel.picture:SetTexCoord(0.1, 0.9, 0.12, 0.88)
    elseif art then
        panel.picture:SetTexture(art.file)
        -- Classic loading screens: the painting sits between the logo band and the bottom band.
        panel.picture:SetTexCoord(0.15, 0.85, 0.26, 0.74)
    else
        panel.pictureMap:SetMap(zid, MC.ZoneView(214 / 118))
    end
    local def = MC.Enemies[zone.boss]
    local bossLevel = Bounty.BossLevel(zone, self.travelHeroic)
    if not panel.token:SetCreature(def.display) then
        panel.token:SetIcon("Interface\\Icons\\" .. (BOSS_ICON[zone.boss] or "INV_Misc_Bone_HumanSkull_01"))
    end
    panel.token:SetMetal(self.travelHeroic and "gold" or "silver")
    local reference = math.floor(Bounty.PartyLevel(store) + 0.5)
    panel.level.text:SetText(MC.LevelText(bossLevel, reference))
    panel.level.text:SetTextColor(MC.ConColor(bossLevel, reference))
    panel.name.text:SetText(L["MC_E_" .. zone.boss])
    panel.levels:SetText(Describe.ZoneName(zid) .. "  ·  " .. L.MC_LEVEL_RANGE:format(zone.min, zone.max))
    panel.story:SetText(L["MC_ZD_" .. zid])
    local unlocked = Bounty.HeroicUnlocked(store, zid)
    if not unlocked then self.travelHeroic = false end
    panel.heroic:SetEnabled(unlocked)
    Kit.SetSelected(panel.normal, not self.travelHeroic)
    Kit.SetSelected(panel.heroic, self.travelHeroic or false)
    panel.choose:SetEnabled(store.run == nil)
end

-- Collection --------------------------------------------------------------------------------------

local PAGE_X, PAGE_Y, PAGE_W, PAGE_H = 14, 54, 572, 470
local CARD_SCALE = 0.86

function Module:BuildCollection()
    local view = self:AddView("collection", CreateFrame("Frame", nil, self.container))
    local wood = Kit.Wood(view, W, H, true)
    wood:SetPoint("TOPLEFT")
    self.collectionRole, self.collectionPage = "protector", 1

    -- Role tabs above the book.
    view.tabs = {}
    for i, role in ipairs(ROLES) do
        local tab = Kit.Medallion(view, 46)
        tab.icon:SetTexture(MC.Tex("role_" .. role))
        tab:SetScript("OnClick", function()
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
            self.collectionRole, self.collectionPage = role, 1
            self:RefreshCollection()
        end)
        Kit.Hover(tab, { grow = 1.12 })
        Kit.Place(tab, 40 + (i - 1) * 54, 28)
        view.tabs[role] = tab
    end

    local page = CreateFrame("Frame", nil, view)
    page:SetPoint("TOPLEFT", PAGE_X, -PAGE_Y)
    page:SetSize(PAGE_W, PAGE_H)
    Kit.Parchment(page)
    view.page = page
    view.pageTitle = Kit.Plaque(page, 230, nil, 17)
    view.pageTitle:SetPoint("TOP", 0, 2)

    view.cards = {}
    for i = 1, 6 do
        local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
        local card = Kit.MercCard(page)
        Kit.SetBaseScale(card, CARD_SCALE)
        Kit.Place(card, 130 + col * 156, 150 + row * 212)
        card:SetScript("OnClick", function() self:CollectionClicked(card.merc) end)
        view.cards[i] = card
    end
    view.prev = Kit.Arrow(page, -1, function(dir) self:TurnCollectionPage(dir) end)
    Kit.Place(view.prev, 28, PAGE_H / 2)
    view.next = Kit.Arrow(page, 1, function(dir) self:TurnCollectionPage(dir) end)
    Kit.Place(view.next, PAGE_W - 28, PAGE_H / 2)
    view.pageNumber = Kit.Ink(page, 12, INK)
    view.pageNumber:SetPoint("TOP", view.next, "BOTTOM", 0, -2)

    -- The party on the right, one garrison follower button per slot.
    local panel = CreateFrame("Frame", nil, view)
    panel:SetPoint("TOPLEFT", 596, -54)
    panel:SetPoint("BOTTOMRIGHT", -10, 44)
    local fill = panel:CreateTexture(nil, "BACKGROUND", nil, 2)
    fill:SetAllPoints()
    fill:SetColorTexture(0.08, 0.05, 0.03, 0.75)
    Widgets.Rim(panel, panel)
    local partyTitle = Kit.Plaque(panel, 210, "MC_PARTY", 15)
    partyTitle:SetPoint("TOP", 0, 6)
    view.slots = {}
    for i = 1, Bounty.PARTY_SIZE do
        local b = CreateFrame("Button", nil, panel)
        b:SetSize(216, 52)
        local bg = b:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        Kit.Atlas(bg, "GarrMission_FollowerListButton", MC.Tex("plate"))
        b.glowTex = b:CreateTexture(nil, "OVERLAY")
        b.glowTex:SetAllPoints()
        Kit.Atlas(b.glowTex, "GarrMission_FollowerListButton-Select", MC.Tex("plate"))
        b.glowTex:SetAlpha(0)
        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        Kit.Atlas(hl, "GarrMission_FollowerListButton-Highlight")
        b.level = MC.Badge(b, "level", 30, 12)
        b.level:SetPoint("LEFT", 6, 0)
        b.role = b:CreateTexture(nil, "ARTWORK")
        b.role:SetSize(20, 20)
        b.role:SetPoint("RIGHT", -10, 0)
        b.name = Widgets.Text(b, 12, "white")
        b.name:SetPoint("LEFT", b.level, "RIGHT", 6, 0)
        b.name:SetWidth(140)
        b.name:SetJustifyH("LEFT")
        b.name:SetWordWrap(false)
        b:SetScript("OnClick", function()
            if self:Store().run then return end
            self.partySlot = self.partySlot ~= i and i or nil
            MC.Sound("select")
            self:RefreshCollection()
        end)
        Kit.Place(b, 113, 58 + (i - 1) * 56, panel)
        Kit.Hover(b, { grow = 1.03, sound = false })
        view.slots[i] = b
    end
    view.hint = Widgets.Text(panel, 10, "gray")
    view.hint:SetPoint("BOTTOM", 0, 8)
    view.hint:SetWidth(204)

    local back = Kit.Button(view, 120, 28, "BACK", function()
        self.partySlot = nil
        self:ShowView("camp")
    end)
    Kit.Place(back, W - 76, H - 18)

    self:BuildMercView()
    view.refresh = function() self:RefreshCollection() end
end

function Module:CollectionMercs()
    local list = {}
    for _, id in ipairs(MC.MERC_ORDER) do
        if MC.Mercs[id].role == self.collectionRole then list[#list + 1] = id end
    end
    return list
end

function Module:TurnCollectionPage(dir)
    local pages = math.max(1, math.ceil(#self:CollectionMercs() / 6))
    local page = self.collectionPage + dir
    if page < 1 or page > pages then
        -- Past the last page of a role the book turns to the next role.
        local index = 1
        for i, role in ipairs(ROLES) do
            if role == self.collectionRole then index = i end
        end
        self.collectionRole = ROLES[(index - 1 + dir) % #ROLES + 1]
        self.collectionPage = dir > 0 and 1 or math.max(1, math.ceil(#self:CollectionMercs() / 6))
    else
        self.collectionPage = page
    end
    self:RefreshCollection()
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
    self.mercShown = id
    self:ShowView("merc")
end

function Module:RefreshCollection()
    local store = self:Store()
    local view = self.views.collection
    self:SetScene(nil)
    local locked = store.run ~= nil
    if locked then self.partySlot = nil end
    for role, tab in pairs(view.tabs) do Kit.SetSelected(tab, role == self.collectionRole) end
    view.pageTitle.text:SetText(Describe.RoleName(self.collectionRole))
    local inParty = {}
    for i, b in ipairs(view.slots) do
        local id = store.party[i]
        if id then inParty[id] = true end
        b.role:SetTexture(id and MC.Tex("role_" .. MC.Mercs[id].role) or nil)
        b.name:SetText(id and Describe.MercName(id) or "")
        b.level.text:SetText(id and store.mercs[id].level or "")
        Kit.SetSelected(b, self.partySlot == i)
    end
    view.hint:SetText(locked and L.MC_PARTY_LOCKED or (self.partySlot and L.MC_PARTY_PICK or L.MC_PARTY_HINT))
    local list = self:CollectionMercs()
    local pages = math.max(1, math.ceil(#list / 6))
    self.collectionPage = math.min(self.collectionPage, pages)
    view.pageNumber:SetText(L.MC_PAGE:format(self.collectionPage))
    for i, card in ipairs(view.cards) do
        local id = list[(self.collectionPage - 1) * 6 + i]
        card:SetShown(id ~= nil)
        if id then
            local unit = MC.PreviewUnit(store, id)
            local extra = CardExtra(store, id)
            extra.member = inParty[id] or false
            card:SetMerc(unit, extra)
            Kit.SetSelected(card, (self.partySlot ~= nil and store.mercs[id] and store.mercs[id].owned) and true or false)
        end
    end
end

-- A mercenary's page -------------------------------------------------------------------------------

function Module:BuildMercView()
    local view = self:AddView("merc", CreateFrame("Frame", nil, self.container))
    local wood = Kit.Wood(view, W, H, true)
    wood:SetPoint("TOPLEFT")
    view.card = Kit.MercCard(view)
    Kit.SetBaseScale(view.card, 1.35)
    Kit.Place(view.card, 128, 196)
    Kit.NoHover(view.card)
    view.recruit = Kit.Button(view, 200, 32, nil, function()
        local store = self:Store()
        if Bounty.Recruit(store, self.mercShown) then
            PlaySound(SOUNDKIT.IG_QUEST_LIST_COMPLETE)
            self:CheckLevels()
            self:RefreshMercView()
        end
    end)
    Kit.Place(view.recruit, 128, 440)
    view.levelText = Widgets.Text(view, 12, "gold")
    view.levelText:SetPoint("TOP", view, "TOPLEFT", 128, -470)

    local sheet = CreateFrame("Frame", nil, view)
    sheet:SetPoint("TOPLEFT", 252, -14)
    sheet:SetPoint("BOTTOMRIGHT", -12, 46)
    Kit.Parchment(sheet)
    view.sheet = sheet
    local abilities = Kit.Plaque(sheet, 220, "MC_ABILITIES", 16)
    abilities:SetPoint("TOP", 0, 4)
    view.cards, view.ups = {}, {}
    for i = 1, 3 do
        local x = 104 + (i - 1) * 182
        local card = Kit.AbilityCard(sheet)
        Kit.SetBaseScale(card, 1.18)
        Kit.Place(card, x, 168, sheet)
        card:HookScript("OnEnter", function(c)
            if not c.abilityId then return end
            local unit = MC.PreviewUnit(self:Store(), self.mercShown)
            GameTooltip:SetOwner(c, "ANCHOR_RIGHT")
            GameTooltip:SetText(Describe.AbilityName(c.abilityId), 1, 0.82, 0)
            GameTooltip:AddLine(Describe.AbilityStats(c.abilityId, unit, i), 0.7, 0.7, 0.7)
            GameTooltip:AddLine(Describe.Ability(c.abilityId, unit, i), 1, 1, 1, true)
            GameTooltip:Show()
        end)
        card:HookScript("OnLeave", GameTooltip_Hide)
        view.cards[i] = card
        local up = Kit.Button(sheet, 130, 28, nil, function()
            if Bounty.RankUp(self:Store(), self.mercShown, i) then
                PlaySound(SOUNDKIT.IG_QUEST_LIST_COMPLETE)
                self:CheckLevels()
                self:RefreshMercView()
            end
        end)
        Kit.Place(up, x, 292, sheet)
        view.ups[i] = up
    end

    local gearTitle = Kit.Plaque(sheet, 220, "MC_EQUIPMENT", 16)
    gearTitle:SetPoint("TOP", 0, -314)
    view.gear = {}
    for i = 1, 3 do
        local b = Kit.Medallion(sheet, 64, true)
        b:SetScript("OnClick", function()
            if Bounty.SetGear(self:Store(), self.mercShown, i) then
                MC.Sound("select")
                self:RefreshMercView()
            end
        end)
        b:HookScript("OnEnter", function() self:GearTooltip(b, self.mercShown, i) end)
        b:HookScript("OnLeave", GameTooltip_Hide)
        Kit.Hover(b, { grow = 1.1 })
        Kit.Place(b, 104 + (i - 1) * 182, 400, sheet)
        b.name = Kit.Ink(b, 10, INK)
        b.name:SetPoint("TOP", b, "BOTTOM", 0, -2)
        b.name:SetWidth(160)
        view.gear[i] = b
    end
    view.gearDesc = Kit.Ink(sheet, 11, INK)
    view.gearDesc:SetPoint("BOTTOM", 0, 14)
    view.gearDesc:SetWidth(520)

    local done = Kit.Button(view, 140, 30, "MC_DONE", function() self:ShowView("collection") end)
    Kit.Place(done, W - 86, H - 20)
    view.refresh = function() self:RefreshMercView() end
end

function Module:RefreshMercView()
    local store = self:Store()
    local view = self.views.merc
    local id = self.mercShown
    if not id then return end
    self:SetScene(nil)
    local def = MC.Mercs[id]
    local entry = store.mercs[id] or Bounty.NewEntry(false)
    local unit = MC.PreviewUnit(store, id)
    view.card:SetMerc(unit, CardExtra(store, id))
    view.recruit:SetShown(not entry.owned)
    view.recruit:SetEnabled(Bounty.CanRecruit(store, id))
    view.recruit:SetText(L.MC_RECRUIT_COST:format(Bounty.RECRUIT_COST))
    if entry.level < MC.MAX_LEVEL then
        view.levelText:SetText(L.MC_XP:format(ns.FormatNumber(entry.xp), ns.FormatNumber(Bounty.XPNeeded(entry.level))))
    else
        view.levelText:SetText(L.MC_MAX_LEVEL)
    end
    for i, card in ipairs(view.cards) do
        local unlocked = entry.level >= MC.ABILITY_LEVELS[i]
        card:SetAbility(def.abilities[i], unit, i, nil, def.role)
        card:SetLocked(not unlocked and MC.ABILITY_LEVELS[i] or nil)
        local cost = Bounty.RankCost(entry, i)
        view.ups[i]:SetShown(entry.owned and cost ~= nil)
        if cost then view.ups[i]:SetText(L.MC_RANK_UP:format(ROMAN[entry.ranks[i] + 1], cost)) end
        view.ups[i]:SetEnabled(Bounty.CanRankUp(store, id, i))
    end
    for i, b in ipairs(view.gear) do
        b.icon:SetTexture(def.gear[i].icon)
        b.icon:SetDesaturated(not entry.gears[i])
        b.icon:SetAlpha(entry.gears[i] and 1 or 0.5)
        b.name:SetText(L["MC_G_" .. id .. "_" .. i])
        Kit.SetSelected(b, entry.gear == i)
    end
    local gear = entry.gear or 1
    view.gearDesc:SetText(Describe.Mods(def.gear[gear].mods, def.abilities))
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
