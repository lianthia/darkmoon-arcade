-- The effect gallery (dev copy only, /arcade fx): plays every spell effect of Effects.lua between
-- two tokens, lets the tester tune and rate it, and keeps it all in DarkmoonArcadeDB.fxGallery so the
-- values can be read from the SavedVariables and moved into Effects.lua.

local _, ns = ...
local MC = ns.Mercenaries
local Kit = MC.Kit
local Widgets, Media = ns.Widgets, ns.Media
local Module = MC.Module
local W, H = MC.W, MC.H

local ALLY_X, ALLY_Y, ENEMY_X, ENEMY_Y = 170, 400, 400, 150
local PANEL_X, PANEL_W = 580, W - 590
local ROW_H = 24
-- Tunable values: key, label, step, how a step applies ("add" or "mul"), digits shown.
local ROWS = {
    { "size", "Frame px", 20, "add", 0 },
    { "scale", "Scale", 1.15, "mul", 2 },
    { "x", "X", 0.1, "add", 2 },
    { "y", "Y", 0.1, "add", 2 },
    { "z", "Z", 0.1, "add", 2 },
    { "rx", "Turn X", 15, "add", 0 },
    { "ry", "Turn Y", 15, "add", 0 },
    { "rz", "Turn Z", 15, "add", 0 },
    { "dur", "Seconds", 0.1, "add", 1 },
}
local AIM_NAMES = { [0] = "off", "X", "Y", "Z" }
local RATINGS = {
    { "good", "Good", { 0.3, 1, 0.3 } },
    { "ok", "Okay", { 1, 0.85, 0.3 } },
    { "bad", "Bad", { 1, 0.35, 0.3 } },
}

local function SmallButton(parent, w, h, text, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w, h)
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.18, 0.13, 0.08, 0.95)
    Widgets.Rim(b, b)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 0.85, 0.4, 0.18)
    b.label = b:CreateFontString(nil, "OVERLAY")
    b.label:SetFont(Media.FontFile(), 11, "OUTLINE")
    b.label:SetPoint("CENTER")
    b.label:SetText(text)
    b:SetScript("OnClick", onClick)
    return b
end

local function Label(parent, size, r, g, b)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(Media.FontFile(), size, "OUTLINE")
    fs:SetTextColor(r or 1, g or 1, b or 1)
    fs:SetJustifyH("LEFT")
    return fs
end

function Module:BuildFxGallery()
    local view = self:AddView("fxgallery", CreateFrame("Frame", nil, self.container))
    local board = view:CreateTexture(nil, "BACKGROUND", nil, 0)
    board:SetAllPoints()
    Kit.Atlas(board, "heavybronze-frame-background-c60", nil)
    if not Kit.HasAtlas("heavybronze-frame-background-c60") then board:SetColorTexture(0.12, 0.09, 0.07, 1) end
    local stage = view:CreateTexture(nil, "BACKGROUND", nil, 1)
    stage:SetPoint("TOPLEFT", 10, -10)
    stage:SetPoint("BOTTOMRIGHT", view, "TOPLEFT", PANEL_X - 10, -(H - 10))
    stage:SetColorTexture(0, 0, 0, 0.25)

    -- Two tokens to shoot between: a mercenary below, a foe above.
    view.ally = MC.CreateToken(view)
    view.enemy = MC.CreateToken(view)
    for _, t in ipairs({ view.ally, view.enemy }) do t:EnableMouse(false) end
    view.ally:SetPoint("CENTER", view, "TOPLEFT", ALLY_X, -ALLY_Y)
    view.enemy:SetPoint("CENTER", view, "TOPLEFT", ENEMY_X, -ENEMY_Y)

    local panel = CreateFrame("Frame", nil, view)
    panel:SetPoint("TOPLEFT", PANEL_X, -10)
    panel:SetSize(PANEL_W, H - 20)
    local fill = panel:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    fill:SetColorTexture(0.08, 0.05, 0.03, 0.85)
    Widgets.Rim(panel, panel)

    view.title = Label(panel, 14, 1, 0.82, 0)
    view.title:SetPoint("TOPLEFT", 10, -10)
    view.title:SetWidth(PANEL_W - 20)
    view.info = Label(panel, 10, 0.75, 0.75, 0.75)
    view.info:SetPoint("TOPLEFT", view.title, "BOTTOMLEFT", 0, -4)
    view.info:SetWidth(PANEL_W - 20)

    view.values = {}
    local top = 64
    for i, row in ipairs(ROWS) do
        local y = top + (i - 1) * ROW_H
        local name = Label(panel, 11, 0.9, 0.9, 0.9)
        name:SetPoint("TOPLEFT", 10, -(y + 4))
        name:SetText(row[2])
        local minus = SmallButton(panel, 26, 20, "-", function() self:TuneFx(row, -1) end)
        minus:SetPoint("TOPLEFT", 120, -y)
        local value = Label(panel, 11)
        value:SetPoint("LEFT", minus, "RIGHT", 4, 0)
        value:SetWidth(52)
        value:SetJustifyH("CENTER")
        local plus = SmallButton(panel, 26, 20, "+", function() self:TuneFx(row, 1) end)
        plus:SetPoint("LEFT", value, "RIGHT", 4, 0)
        view.values[row[1]] = value
    end
    local y = top + #ROWS * ROW_H + 4
    view.aimButton = SmallButton(panel, 112, 20, "", function() self:TuneFxAim() end)
    view.aimButton:SetPoint("TOPLEFT", 10, -y)
    view.apiButton = SmallButton(panel, 112, 20, "", function() self:ToggleFxApi() end)
    view.apiButton:SetPoint("TOPLEFT", 128, -y)
    y = y + ROW_H
    view.dirButton = SmallButton(panel, 112, 20, "", function()
        self.fxDown = not self.fxDown
        self:ShowFx()
    end)
    view.dirButton:SetPoint("TOPLEFT", 10, -y)
    local reset = SmallButton(panel, 112, 20, "Reset values", function() self:ResetFx() end)
    reset:SetPoint("TOPLEFT", 128, -y)

    y = y + ROW_H + 10
    local rateLabel = Label(panel, 11, 1, 0.82, 0)
    rateLabel:SetPoint("TOPLEFT", 10, -y)
    rateLabel:SetText("How does it look?")
    y = y + 18
    view.rateButtons = {}
    for i, r in ipairs(RATINGS) do
        local b = SmallButton(panel, 72, 24, r[2], function() self:RateFx(r[1]) end)
        b:SetPoint("TOPLEFT", 10 + (i - 1) * 78, -y)
        b.label:SetTextColor(r[3][1], r[3][2], r[3][3])
        b.sel = b:CreateTexture(nil, "OVERLAY")
        b.sel:SetPoint("TOPLEFT", -2, 2)
        b.sel:SetPoint("BOTTOMRIGHT", 2, -2)
        b.sel:SetColorTexture(r[3][1], r[3][2], r[3][3], 0.35)
        b.sel:Hide()
        b.key = r[1]
        view.rateButtons[i] = b
    end
    y = y + 32
    view.progress = Label(panel, 10, 0.75, 0.75, 0.75)
    view.progress:SetPoint("TOPLEFT", 10, -y)
    view.progress:SetWidth(PANEL_W - 20)

    -- Bottom: browse, play, loop and back.
    local bottom = H - 20 - 70
    local prev = SmallButton(panel, 72, 26, "< Prev", function() self:StepFx(-1) end)
    prev:SetPoint("TOPLEFT", 10, -bottom)
    local play = SmallButton(panel, 72, 26, "Play", function() self:PlayGalleryFx() end)
    play:SetPoint("TOPLEFT", 88, -bottom)
    local nextB = SmallButton(panel, 72, 26, "Next >", function() self:StepFx(1) end)
    nextB:SetPoint("TOPLEFT", 166, -bottom)
    view.loopButton = SmallButton(panel, 150, 22, "", function()
        self.fxLoop = not self.fxLoop
        self:ShowFx()
    end)
    view.loopButton:SetPoint("TOPLEFT", 10, -(bottom + 34))
    local close = SmallButton(panel, 72, 22, "Close", function() self:Route() end)
    close:SetPoint("TOPLEFT", 166, -(bottom + 34))

    self.fxIndex, self.fxLoop, self.fxDown, self.fxTimer = 1, true, false, 0
    view.refresh = function() self:RefreshFxGallery() end
end

function Module:OpenFxGallery()
    self.overlay:Hide()
    self:ShowView("fxgallery")
end

function Module:RefreshFxGallery()
    self:SetScene(nil)
    local view = self.views.fxgallery
    local merc = MC.Mercs[MC.MERC_ORDER[1]]
    view.ally:SetData({ kind = "merc", id = MC.MERC_ORDER[1], role = merc.role, level = 60, atk = 10, hp = 60, maxHp = 60 })
    local foe = MC.Enemies.kobold_tunneler and "kobold_tunneler" or next(MC.Enemies)
    view.enemy:SetData({ kind = "enemy", id = foe, role = MC.Enemies[foe].role, level = 60, atk = 6, hp = 72, maxHp = 72 })
    self:ShowFx()
    self:PlayGalleryFx()
end

function Module:GalleryFx()
    return MC.FX_LIST[self.fxIndex]
end

function Module:ShowFx()
    local view, def = self.views.fxgallery, self:GalleryFx()
    local t = MC.FxTuning(def.id)
    local store = MC.FxStore()
    local saved = store[def.id] or {}
    view.title:SetText(("%d/%d  %s"):format(self.fxIndex, #MC.FX_LIST, def.id))
    local loaded = store.loaded and store.loaded[def.id]
    view.info:SetText(("%s  |  %s  |  file %d%s%s"):format(def.kind, def.name, def.file,
        def.impact and ("  ->  " .. def.impact) or "",
        loaded == false and "  |cffff5050(did not load)|r" or ""))
    for _, row in ipairs(ROWS) do
        local v = t[row[1]]
        view.values[row[1]]:SetText(("%." .. row[5] .. "f"):format(v))
        local changed = saved[row[1]] ~= nil
        view.values[row[1]]:SetTextColor(changed and 0.4 or 1, 1, changed and 0.4 or 1)
    end
    view.aimButton.label:SetText("Aim axis: " .. AIM_NAMES[t.aim])
    view.apiButton.label:SetText("API: " .. (store.api or "transform"))
    view.dirButton.label:SetText(self.fxDown and "Shot: downwards" or "Shot: upwards")
    view.loopButton.label:SetText(self.fxLoop and "Repeat: on" or "Repeat: off")
    for _, b in ipairs(view.rateButtons) do b.sel:SetShown(saved.rating == b.key) end
    local rated = 0
    for _, e in ipairs(MC.FX_LIST) do
        if store[e.id] and store[e.id].rating then rated = rated + 1 end
    end
    view.progress:SetText(("Rated: %d of %d. Values are kept per effect; /reload saves them."):format(rated, #MC.FX_LIST))
end

local function Entry(id)
    local store = MC.FxStore()
    store[id] = store[id] or {}
    return store[id]
end

function Module:TuneFx(row, dir)
    local def = self:GalleryFx()
    local t = MC.FxTuning(def.id)
    local key, step, how = row[1], row[3], row[4]
    local v = t[key]
    if how == "mul" then v = dir > 0 and v * step or v / step else v = v + dir * step end
    if key == "size" then v = math.max(40, math.min(500, v)) end
    if key == "dur" then v = math.max(0.1, v) end
    Entry(def.id)[key] = math.floor(v * 1000 + 0.5) / 1000
    self:ShowFx()
    self:PlayGalleryFx()
end

function Module:TuneFxAim()
    local def = self:GalleryFx()
    Entry(def.id).aim = (MC.FxTuning(def.id).aim + 1) % 4
    self:ShowFx()
    self:PlayGalleryFx()
end

function Module:ToggleFxApi()
    local store = MC.FxStore()
    store.api = (store.api or "transform") == "transform" and "position" or "transform"
    self:ShowFx()
    self:PlayGalleryFx()
end

function Module:ResetFx()
    local entry = Entry(self:GalleryFx().id)
    for k in pairs(MC.FX_DEFAULTS) do entry[k] = nil end
    self:ShowFx()
    self:PlayGalleryFx()
end

function Module:RateFx(rating)
    local entry = Entry(self:GalleryFx().id)
    entry.rating = entry.rating ~= rating and rating or nil
    self:ShowFx()
end

function Module:StepFx(dir)
    self.fxIndex = (self.fxIndex - 1 + dir) % #MC.FX_LIST + 1
    self:ShowFx()
    self:PlayGalleryFx()
end

function Module:PlayGalleryFx()
    self:ClearEffects()
    local def = self:GalleryFx()
    local fromX, fromY, toX, toY = ALLY_X, ALLY_Y - 10, ENEMY_X, ENEMY_Y - 10
    if self.fxDown then fromX, fromY, toX, toY = toX, toY, fromX, fromY end
    local length
    if def.kind == "missile" then
        length = self:PlayFx(def.id, fromX, fromY, toX, toY)
    elseif def.kind == "impact" then
        length = self:PlayFx(def.id, toX, toY)
    else
        length = self:PlayFx(def.id, fromX, fromY)
    end
    self.fxTimer = length + 0.6
    self:ShowFx()
end

function Module:UpdateFxGallery(dt)
    if not self.fxLoop then return end
    self.fxTimer = self.fxTimer - dt
    if self.fxTimer <= 0 then self:PlayGalleryFx() end
end
