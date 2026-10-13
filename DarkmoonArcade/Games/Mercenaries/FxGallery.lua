-- The effect gallery (dev copy only, /arcade fx): plays every spell effect of Effects.lua between
-- two tokens, lets the tester tune and rate it, and keeps it all in DarkmoonArcadeDB.fxGallery so the
-- values can be read from the SavedVariables and moved into Effects.lua. Where the client has
-- them, Blizzard's own UI effects follow the spell models (kind "scripted").

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
    { "scale", "Scale", 1.15, "mul", 2 },
    { "x", "Shift X px", 4, "add", 0 },
    { "y", "Shift Y px", 4, "add", 0 },
    { "rx", "Turn X", 15, "add", 0 },
    { "ry", "Turn Y", 15, "add", 0 },
    { "rz", "Turn Z", 15, "add", 0 },
    { "dur", "Seconds", 0.1, "add", 1 },
}
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

-- A thin cross where an effect should sit, to see whether the scene's camera lines up.
local function Cross(parent, x, y)
    for _, horizontal in ipairs({ true, false }) do
        local t = parent:CreateTexture(nil, "OVERLAY", nil, 7)
        t:SetColorTexture(0.3, 1, 0.3, 0.7)
        t:SetSize(horizontal and 24 or 2, horizontal and 2 or 24)
        t:SetPoint("CENTER", parent, "TOPLEFT", x, -y)
    end
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
    local marks = CreateFrame("Frame", nil, view)
    marks:SetAllPoints()
    marks:SetFrameLevel(view:GetFrameLevel() + 20)
    view.marks = marks
    Cross(marks, ALLY_X, ALLY_Y - 10)
    Cross(marks, ENEMY_X, ENEMY_Y - 10)

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

    view.rows = {}
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
        view.rows[row[1]] = { name = name, minus = minus, value = value, plus = plus }
    end
    local y = top + #ROWS * ROW_H + 2
    -- Camera settings for all effects.
    local camLabel = Label(panel, 11, 0.6, 0.85, 1)
    camLabel:SetPoint("TOPLEFT", 10, -(y + 4))
    camLabel:SetText("All: px per yard")
    local camMinus = SmallButton(panel, 26, 20, "-", function() self:TuneFxCamera(-5) end)
    camMinus:SetPoint("TOPLEFT", 120, -y)
    view.ppy = Label(panel, 11, 0.6, 0.85, 1)
    view.ppy:SetPoint("LEFT", camMinus, "RIGHT", 4, 0)
    view.ppy:SetWidth(52)
    view.ppy:SetJustifyH("CENTER")
    local camPlus = SmallButton(panel, 26, 20, "+", function() self:TuneFxCamera(5) end)
    camPlus:SetPoint("LEFT", view.ppy, "RIGHT", 4, 0)
    y = y + ROW_H
    local function Toggle(x, key)
        local b = SmallButton(panel, 112, 20, "", function() self:ToggleFxSetting(key) end)
        b:SetPoint("TOPLEFT", x, -y)
        return b
    end
    view.fovButton = Toggle(10, "fovAxis")
    view.mirrorButton = Toggle(128, "mirror")
    y = y + ROW_H
    view.pitchButton = Toggle(10, "pitchSign")
    view.dirButton = Toggle(128, "down")
    y = y + ROW_H
    local reset = SmallButton(panel, 112, 20, "Reset values", function() self:ResetFx() end)
    reset:SetPoint("TOPLEFT", 10, -y)
    view.loopButton = Toggle(128, "loop")

    y = y + ROW_H + 6
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
    y = y + 30
    view.progress = Label(panel, 10, 0.75, 0.75, 0.75)
    view.progress:SetPoint("TOPLEFT", 10, -y)
    view.progress:SetWidth(PANEL_W - 20)

    -- Bottom: browse (by one or by ten), play and back.
    local bottom = H - 20 - 66
    local buttons = {
        { "<<", function() self:StepFx(-10) end }, { "<", function() self:StepFx(-1) end },
        { "Play", function() self:PlayGalleryFx() end },
        { ">", function() self:StepFx(1) end }, { ">>", function() self:StepFx(10) end },
    }
    local xs = { 10, 52, 94, 162, 204 }
    for i, spec in ipairs(buttons) do
        local b = SmallButton(panel, i == 3 and 62 or 38, 26, spec[1], spec[2])
        b:SetPoint("TOPLEFT", xs[i], -bottom)
    end
    local close = SmallButton(panel, 72, 22, "Close", function()
        self:ClearEffects()
        self:ClearScriptedFx()
        self:Route()
    end)
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
    MC.AddScriptedFx()
    self:FxScene()
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

local RATING_NAME = { good = "good", ok = "okay", bad = "bad" }

function Module:ShowFx()
    local view, def = self.views.fxgallery, self:GalleryFx()
    local t = MC.FxTuning(def.id)
    local store = MC.FxStore()
    local saved = store.v3[def.id] or {}
    local scripted = def.kind == "scripted"
    view.title:SetText(("%d/%d  %s"):format(self.fxIndex, #MC.FX_LIST, def.id))
    local loaded = store.loaded and store.loaded[def.id]
    local old = store.v2 and store.v2[def.id] and store.v2[def.id].rating
    view.info:SetText(("%s  |  %s  |  file %d%s%s%s"):format(def.kind, def.name, def.file,
        def.impact and ("  ->  " .. def.impact) or "",
        loaded == false and "  |cffff5050(did not load)|r" or "",
        old and ("  |cff999999(2nd round: " .. RATING_NAME[old] .. ")|r") or ""))
    for _, row in ipairs(ROWS) do
        local r = view.rows[row[1]]
        r.value:SetText(scripted and "-" or ("%." .. row[5] .. "f"):format(t[row[1]]))
        local changed = saved[row[1]] ~= nil
        r.value:SetTextColor(changed and 0.4 or 1, 1, changed and 0.4 or 1)
        r.minus:SetEnabled(not scripted)
        r.plus:SetEnabled(not scripted)
        r.name:SetAlpha(scripted and 0.4 or 1)
    end
    local cam = MC.FxCamera()
    view.ppy:SetText(cam.ppy)
    view.fovButton.label:SetText("FOV: " .. cam.fovAxis)
    view.mirrorButton.label:SetText(cam.mirror < 0 and "Mirror: on" or "Mirror: off")
    view.pitchButton.label:SetText(cam.pitchSign < 0 and "Aim tilt: A" or "Aim tilt: B")
    view.dirButton.label:SetText(self.fxDown and "Shot: downwards" or "Shot: upwards")
    view.loopButton.label:SetText(self.fxLoop and "Repeat: on" or "Repeat: off")
    for _, b in ipairs(view.rateButtons) do b.sel:SetShown(saved.rating == b.key) end
    local rated = 0
    for _, e in ipairs(MC.FX_LIST) do
        if store.v3[e.id] and store.v3[e.id].rating then rated = rated + 1 end
    end
    view.progress:SetText(("Rated: %d of %d. %s Green crosses: where effects should sit. /reload saves."):format(
        rated, #MC.FX_LIST, store.info and store.info.modelScene == false and "|cffff5050No ModelScene!|r" or ""))
end

local function Entry(id)
    local store = MC.FxStore()
    store.v3[id] = store.v3[id] or {}
    return store.v3[id]
end

function Module:TuneFx(row, dir)
    local def = self:GalleryFx()
    if def.kind == "scripted" then return end
    local v = MC.FxTuning(def.id)[row[1]]
    if row[4] == "mul" then v = dir > 0 and v * row[3] or v / row[3] else v = v + dir * row[3] end
    if row[1] == "dur" then v = math.max(0.1, v) end
    Entry(def.id)[row[1]] = math.floor(v * 1000 + 0.5) / 1000
    self:ShowFx()
    self:PlayGalleryFx()
end

function Module:TuneFxCamera(step)
    local store = MC.FxStore()
    store.cam.ppy = math.max(5, MC.FxCamera().ppy + step)
    self:AimFxCamera()
    self:ShowFx()
    self:PlayGalleryFx()
end

function Module:ToggleFxSetting(key)
    local store = MC.FxStore()
    local cam = store.cam
    if key == "fovAxis" then
        local next = { vertical = "horizontal", horizontal = "diagonal", diagonal = "vertical" }
        cam.fovAxis = next[MC.FxCamera().fovAxis]
    elseif key == "mirror" then
        cam.mirror = not cam.mirror or nil
    elseif key == "pitchSign" then
        cam.pitchSign = -MC.FxCamera().pitchSign
    elseif key == "down" then
        self.fxDown = not self.fxDown
    elseif key == "loop" then
        self.fxLoop = not self.fxLoop
    end
    self:AimFxCamera()
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
    self:ClearScriptedFx()
    local view, def = self.views.fxgallery, self:GalleryFx()
    local fromX, fromY, toX, toY = ALLY_X, ALLY_Y - 10, ENEMY_X, ENEMY_Y - 10
    local source, target = view.ally, view.enemy
    if self.fxDown then
        fromX, fromY, toX, toY = toX, toY, fromX, fromY
        source, target = target, source
    end
    local length
    if def.kind == "scripted" then
        length = self:PlayScriptedFx(def.id, source, target)
    elseif def.kind == "missile" then
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
