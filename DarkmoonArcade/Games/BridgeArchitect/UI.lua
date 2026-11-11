-- Goblin Bridge Architect: the bars around the field (contract and budget on top, materials and
-- tools below), the foreman's speech, the result panel and the menus (contracts, pause, help).

local _, ns = ...
local BA = ns.BridgeArchitect
local P = BA.Physics
local MC = ns.Mercenaries
local Kit = MC.Kit
local Media, Widgets, L = ns.Media, ns.Widgets, ns.L
local Module = BA.Module
local Tex = BA.Tex

local W, H = BA.W, BA.H
local FW, FH = P.W, P.H
local GOLD = { 1, 0.82, 0.25 }
local CREAM = { 1, 0.92, 0.75 }
local MUTED = { 0.72, 0.64, 0.52 }
local INK = { 0.25, 0.14, 0.05 }
local GOLD_ICON = "|TInterface\\MoneyFrame\\UI-GoldIcon:0|t"
local FOREMAN_DISPLAY = 1140

local function Text(parent, size, color, flags)
    return Kit.Ink(parent, size, color or CREAM, flags or "OUTLINE")
end

local function Plate(parent, alpha)
    local f = CreateFrame("Frame", nil, parent)
    local fill = f:CreateTexture(nil, "BACKGROUND", nil, 1)
    fill:SetAllPoints()
    fill:SetColorTexture(0.06, 0.04, 0.025, alpha or 0.85)
    Widgets.Rim(f, f)
    return f
end

local function Tooltip(owner, title, text)
    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    GameTooltip:SetText(title, 1, 0.82, 0)
    if text then GameTooltip:AddLine(text, 1, 0.92, 0.75, true) end
    GameTooltip:Show()
end

local function Gold(n) return ns.FormatNumber(n) end

-- Stars: `n` of three, gold or grey.
local function Stars(parent, size)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(size * 3 + 4, size)
    row.stars = {}
    for i = 1, 3 do
        local t = row:CreateTexture(nil, "ARTWORK")
        t:SetTexture(Tex("star"))
        t:SetSize(size, size)
        t:SetPoint("LEFT", (i - 1) * (size + 2), 0)
        row.stars[i] = t
    end
    function row:Set(n)
        for i, t in ipairs(self.stars) do
            if i <= n then t:SetVertexColor(1, 0.8, 0.2) else t:SetVertexColor(0.25, 0.22, 0.2, 0.8) end
        end
    end
    return row
end
BA.Stars = Stars

-- Bars ----------------------------------------------------------------------------------------------------

function Module:BuildBars(container)
    -- Top: the contract, the budget, the vehicle.
    local top = CreateFrame("Frame", nil, container)
    top:SetPoint("TOPLEFT")
    top:SetSize(W, 40)
    top:SetFrameLevel(self.field:GetFrameLevel() + 12)
    self.topBar = top
    local shade = top:CreateTexture(nil, "BACKGROUND")
    shade:SetAllPoints()
    shade:SetTexture(Tex("gradient"))
    shade:SetTexCoord(0, 1, 1, 0)
    shade:SetVertexColor(0, 0, 0, 0.55)
    local title = Plate(top, 0.8)
    title:SetPoint("TOPLEFT", 8, -6)
    title:SetSize(250, 28)
    title.text = Text(title, 12, GOLD)
    title.text:SetPoint("LEFT", 10, 0)
    title.text:SetWidth(232)
    title.text:SetJustifyH("LEFT")
    title.text:SetWordWrap(false)
    top.title = title
    -- The budget meter: cost against budget, marks where two and three stars begin.
    local meter = Plate(top, 0.85)
    meter:SetPoint("TOP", 0, -6)
    meter:SetSize(300, 28)
    meter.fill = meter:CreateTexture(nil, "ARTWORK")
    meter.fill:SetPoint("LEFT", 3, 0)
    meter.fill:SetHeight(22)
    meter.fill:SetColorTexture(1, 1, 1, 1)
    meter.marks = {}
    for i = 1, 2 do
        local m = CreateFrame("Frame", nil, meter)
        m:SetSize(12, 28)
        m.line = m:CreateTexture(nil, "OVERLAY")
        m.line:SetPoint("TOP")
        m.line:SetPoint("BOTTOM")
        m.line:SetWidth(2)
        m.line:SetColorTexture(1, 0.85, 0.4, 0.9)
        m.star = m:CreateTexture(nil, "OVERLAY")
        m.star:SetTexture(Tex("star"))
        m.star:SetSize(11, 11)
        m.star:SetPoint("BOTTOM", m, "TOP", 0, -4)
        m.star:SetVertexColor(1, 0.8, 0.2)
        meter.marks[i] = m
    end
    meter.text = Text(meter, 13, CREAM)
    meter.text:SetPoint("CENTER", 0, 0)
    meter:EnableMouse(true)
    meter:SetScript("OnEnter", function()
        local level = self.level
        if not level then return end
        Tooltip(meter, L.GBA_BUDGET:format(Gold(P.Cost(self.build)), Gold(level.budget)),
            L.GBA_STARS_HINT:format(Gold(math.floor(level.budget * (level.star2 or 0.85))), Gold(math.floor(level.budget * (level.star3 or 0.7)))))
    end)
    meter:SetScript("OnLeave", function() GameTooltip:Hide() end)
    top.meter = meter
    local veh = Plate(top, 0.8)
    veh:SetPoint("TOPRIGHT", -8, -4)
    veh:SetSize(200, 32)
    veh.portrait = Kit.Portrait(veh, 28, 28)
    veh.portrait:SetPoint("LEFT", 3, 0)
    veh.name = Text(veh, 11, CREAM)
    veh.name:SetPoint("TOPLEFT", veh.portrait, "TOPRIGHT", 6, -1)
    veh.name:SetWidth(160)
    veh.name:SetJustifyH("LEFT")
    veh.name:SetWordWrap(false)
    veh.weight = Text(veh, 10, MUTED)
    veh.weight:SetPoint("TOPLEFT", veh.name, "BOTTOMLEFT", 0, -1)
    top.vehicle = veh

    -- Bottom: materials, tools, test.
    local bar = CreateFrame("Frame", nil, container)
    bar:SetPoint("TOPLEFT", 0, -FH)
    bar:SetSize(W, H - FH)
    bar:SetFrameLevel(self.field:GetFrameLevel() + 12)
    local wood = Kit.Wood(bar, W, H - FH, true)
    wood:SetPoint("TOPLEFT")
    self.toolBar = bar
    bar.mats = {}
    for i, mat in ipairs(BA.MATERIAL_ORDER) do
        local b = CreateFrame("Button", nil, bar)
        b:SetSize(104, 46)
        b:SetPoint("LEFT", 10 + (i - 1) * 108, 0)
        local bg = b:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.08, 0.05, 0.03, 0.9)
        Widgets.Rim(b, b)
        b.glow = b:CreateTexture(nil, "BORDER")
        b.glow:SetAllPoints()
        b.glow:SetColorTexture(1, 0.8, 0.35, 0.18)
        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 0.9, 0.6, 0.08)
        b.swatch = b:CreateTexture(nil, "ARTWORK")
        b.swatch:SetTexture(Tex(BA.BEAM_LOOK[mat].tex))
        b.swatch:SetSize(88, math.max(6, BA.BEAM_LOOK[mat].width + 2))
        b.swatch:SetPoint("TOP", 0, -8)
        b.name = Text(b, 10, CREAM)
        b.name:SetPoint("BOTTOMLEFT", 7, 6)
        b.price = Text(b, 9, GOLD)
        b.price:SetPoint("BOTTOMRIGHT", -5, 7)
        b.key = Text(b, 9, MUTED)
        b.key:SetPoint("TOPLEFT", 4, -2)
        b:SetScript("OnClick", function() self:SetMaterial(mat) end)
        b:SetScript("OnEnter", function()
            local m = BA.MATERIALS[mat]
            Tooltip(b, L["GBA_MAT_" .. mat], L["GBA_MATD_" .. mat] .. "\n\n" .. L.GBA_PER_M:format(m.cost)
                .. "  ·  max " .. m.maxLen .. " m")
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        b.mat = mat
        bar.mats[i] = b
    end
    local function Tool(icon, key, x, onClick, hotkey)
        local b = CreateFrame("Button", nil, bar)
        b:SetSize(46, 46)
        b:SetPoint("LEFT", x, 0)
        local bg = b:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.08, 0.05, 0.03, 0.9)
        Widgets.Rim(b, b)
        b.glow = b:CreateTexture(nil, "BORDER")
        b.glow:SetAllPoints()
        b.glow:SetColorTexture(1, 0.4, 0.3, 0.25)
        b.glow:Hide()
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetSize(30, 30)
        b.icon:SetPoint("CENTER", 0, 2)
        b.icon:SetTexture(icon)
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 0.9, 0.6, 0.12)
        if hotkey then
            local k = Text(b, 9, MUTED)
            k:SetPoint("TOPLEFT", 3, -2)
            k:SetText(hotkey)
        end
        b:SetScript("OnClick", onClick)
        b:SetScript("OnEnter", function() Tooltip(b, L[key] .. (hotkey and ("  |cffa09070(" .. hotkey .. ")|r") or "")) end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return b
    end
    bar.erase = Tool("Interface\\Icons\\INV_Axe_02", "GBA_ERASE", 452, function() self:ToggleErase() end, "X")
    bar.undo = Tool("Interface\\Icons\\INV_Misc_PocketWatch_01", "GBA_UNDO", 502, function() self:Undo() end, "Z")
    bar.clear = Tool("Interface\\Icons\\INV_Misc_Bomb_04", "GBA_CLEAR", 552, function() self:Clear() end)
    bar.menu = Kit.Button(bar, 80, 28, "GBA_MENU", function() self:Pause() end)
    bar.menu:SetPoint("LEFT", 612, 0)
    bar.help = Kit.Button(bar, 60, 28, "GBA_HELP_BTN", function() self:ShowHelp() end)
    bar.help:SetPoint("LEFT", bar.menu, "RIGHT", 4, 0)
    bar.test = Kit.Button(bar, 150, 40, "GBA_TEST", function()
        if self.sim then self:StopTest() else self:StartTest() end
    end, "green")
    bar.test:SetPoint("RIGHT", -10, 0)
    bar.stop = Kit.Button(bar, 150, 40, "GBA_STOP", function() self:StopTest() end, "red")
    bar.stop:SetPoint("RIGHT", -10, 0)
    bar.stop:Hide()
    -- While testing: fast forward in place of the tools.
    bar.fast = Kit.Button(bar, 146, 30, "GBA_FAST", function() self:ToggleFast() end)
    bar.fast:SetPoint("LEFT", 452, 0)
    bar.fast:Hide()
    for _, b in ipairs({ bar.test, bar.stop }) do
        b.keyHint = Text(b, 9, { 0.85, 1, 0.8 })
        b.keyHint:SetPoint("BOTTOM", b, "TOP", 0, 2)
    end

    self:BuildForeman()
    self:BuildResult()
end

function Module:RefreshBars()
    local level, top, bar = self.level, self.topBar, self.toolBar
    if not (level and top) then return end
    top.title.text:SetText(L.GBA_LEVEL:format(level.index) .. "  ·  " .. L["GBA_L_" .. level.id])
    local v = BA.VEHICLES[level.vehicle]
    top.vehicle.portrait:SetDisplay(v.display)
    top.vehicle.name:SetText(L["GBA_V_" .. level.vehicle])
    top.vehicle.weight:SetText(L.GBA_WEIGHT:format(v.mass))
    -- Materials of this level, the chosen one lit.
    local n = 0
    for _, b in ipairs(bar.mats) do
        local open = tContains(level.materials, b.mat)
        b:SetShown(open)
        if open then
            n = n + 1
            b:ClearAllPoints()
            b:SetPoint("LEFT", 10 + (n - 1) * 108, 0)
            b.key:SetText(tostring(n))
            b.name:SetText(L["GBA_MAT_" .. b.mat])
            b.price:SetText(L.GBA_PER_M:format(BA.MATERIALS[b.mat].cost))
            b.glow:SetShown(b.mat == self.material and not self.erasing)
            b:SetAlpha(self.sim and 0.5 or 1)
        end
    end
    bar.erase.glow:SetShown(self.erasing and true or false)
    local testing = self.sim ~= nil
    bar.test:SetShown(not testing)
    bar.stop:SetShown(testing)
    for _, t in ipairs({ bar.erase, bar.undo, bar.clear }) do t:SetShown(not testing) end
    bar.fast:SetShown(testing)
    bar.fast:SetText(self.fast and L.GBA_FAST_ON or L.GBA_FAST)
    bar.test.keyHint:SetText(L.GBA_KEY_SPACE)
    bar.stop.keyHint:SetText(L.GBA_KEY_SPACE)
    bar.undo:SetAlpha((testing or #(self.undo or {}) == 0) and 0.4 or 1)
    if self.clearArmed then bar.clear.glow:Show() else bar.clear.glow:Hide() end
    self:RefreshMeter()
end

function Module:RefreshMeter()
    local level, meter = self.level, self.topBar.meter
    local cost = self.sim and self.cost or P.Cost(self.build)
    local share = cost / level.budget
    local w = 294
    meter.fill:SetWidth(math.max(1, math.min(1, share) * w))
    if share > 1 then
        meter.fill:SetVertexColor(0.9, 0.2, 0.15)
    elseif share > (level.star2 or 0.85) then
        meter.fill:SetVertexColor(0.85, 0.65, 0.2)
    else
        meter.fill:SetVertexColor(0.35, 0.75, 0.3)
    end
    for i, m in ipairs(meter.marks) do
        local f = i == 1 and (level.star3 or 0.7) or (level.star2 or 0.85)
        m:ClearAllPoints()
        m:SetPoint("CENTER", meter, "LEFT", 3 + w * f, 0)
    end
    meter.text:SetText(share > 1 and (L.GBA_BUDGET:format(Gold(cost), Gold(level.budget)) .. "  " .. L.GBA_OVER)
        or L.GBA_BUDGET:format(Gold(cost), Gold(level.budget)))
end

function Module:UpdateBars()
    if self.clearArmed and self.realClock - self.clearArmed > 3 then
        self.clearArmed = nil
        self:RefreshBars()
    end
end

-- The foreman ------------------------------------------------------------------------------------------------

function Module:BuildForeman()
    local f = CreateFrame("Button", nil, self.hudLayer)
    f:SetSize(420, 74)
    f:SetPoint("TOPLEFT", 10, -46)
    f.portrait = Kit.Portrait(f, 64, 64)
    f.portrait:SetPoint("LEFT", 0, 0)
    local bubble = CreateFrame("Frame", nil, f)
    bubble:SetPoint("TOPLEFT", f.portrait, "TOPRIGHT", 8, 4)
    bubble:SetPoint("BOTTOMRIGHT")
    Kit.Parchment(bubble)
    Widgets.Rim(bubble, bubble)
    f.name = Kit.Ink(bubble, 10, { 0.5, 0.2, 0.05 })
    f.name:SetPoint("TOPLEFT", 10, -7)
    f.text = Kit.Ink(bubble, 11, INK)
    f.text:SetPoint("TOPLEFT", f.name, "BOTTOMLEFT", 0, -3)
    f.text:SetWidth(330)
    f.text:SetJustifyH("LEFT")
    f.text:SetSpacing(2)
    f:SetScript("OnClick", function() self:HideForeman() end)
    f:Hide()
    self.foreman = f
end

function Module:ShowForeman(text)
    local f = self.foreman
    f.portrait:SetDisplay(FOREMAN_DISPLAY)
    f.name:SetText(L.GBA_FOREMAN)
    f.text:SetText(text)
    f:Show()
    self.foremanAt = self.realClock
end

function Module:HideForeman()
    if self.foreman then self.foreman:Hide() end
end

-- The result ---------------------------------------------------------------------------------------------------

function Module:BuildResult()
    local r = CreateFrame("Frame", nil, self.hudLayer)
    r:SetSize(380, 176)
    r:SetPoint("TOP", 0, -48)
    r:SetFrameLevel(self.hudLayer:GetFrameLevel() + 5)
    r:EnableMouse(true)
    Kit.Parchment(r)
    Widgets.Rim(r, r)
    r.title = Kit.Ink(r, 20, { 0.35, 0.15, 0.03 })
    r.title:SetPoint("TOP", 0, -16)
    r.stars = Stars(r, 34)
    r.stars:SetPoint("TOP", r.title, "BOTTOM", 0, -8)
    r.line = Kit.Ink(r, 12, INK)
    r.line:SetPoint("TOP", r.stars, "BOTTOM", 0, -8)
    r.line:SetWidth(340)
    r.sub = Kit.Ink(r, 11, { 0.45, 0.25, 0.08 })
    r.sub:SetPoint("TOP", r.line, "BOTTOM", 0, -4)
    r.sub:SetWidth(340)
    r.next = Kit.Button(r, 150, 30, "GBA_NEXT", function()
        local i = self.level.index + 1
        if BA.LEVELS[i] then self:StartLevel(i) else self:ShowMenu() end
    end, "green")
    r.next:SetPoint("BOTTOMRIGHT", -16, 14)
    r.back = Kit.Button(r, 150, 30, "GBA_IMPROVE", function() self:StopTest() end)
    r.back:SetPoint("BOTTOMLEFT", 16, 14)
    r:Hide()
    self.resultPanel = r
end

function Module:ShowResult(info)
    local r = self.resultPanel
    self.resultShown = true
    if info.won then
        local over = info.stars == 0
        r.title:SetText(over and L.GBA_WON_OVER or L.GBA_WON)
        r.stars:Show()
        r.stars:Set(info.stars)
        r.line:SetText(L.GBA_COST:format(Gold(info.cost), Gold(info.budget)))
        local peak = L.GBA_PEAK:format(math.floor((info.peak or 0) * 100 + 0.5))
        r.sub:SetText(over and L.GBA_WON_OVER_SUB or ((info.newBest and (L.GBA_NEW_BEST .. "  ·  ") or "") .. peak))
        r.next:SetShown(not over)
        r.back:SetText(over and L.GBA_RETRY or L.GBA_IMPROVE)
        BA.UiSound(SOUNDKIT.UI_GARRISON_MISSION_COMPLETE_ENCOUNTER_CHANCE or SOUNDKIT.IG_QUEST_LIST_COMPLETE)
    else
        r.title:SetText(L.GBA_LOST)
        r.stars:Hide()
        r.line:SetText(L["GBA_LOST_" .. (info.why or "water")] or "")
        r.sub:SetText("")
        r.next:Hide()
        r.back:SetText(L.GBA_RETRY)
        BA.Play("laugh")
    end
    r:Show()
end

function Module:HideResult()
    self.resultShown = false
    if self.resultPanel then self.resultPanel:Hide() end
    self.result, self.resultAt = nil, nil
end

-- Menus -------------------------------------------------------------------------------------------------------

function Module:BuildMenus(container)
    self.overlay = Widgets.NewOverlay(container)
    self.overlay.frame:SetFrameLevel(container:GetFrameLevel() + 100)
    self:BuildLevelMenu(self.overlay:AddPage("menu"))

    local pause = self.overlay:AddPage("pause")
    local pTitle = Widgets.PageTitle(pause, "GBA_PAUSED", -150)
    local resume = Kit.Button(pause, 220, 34, "GBA_RESUME", function() self:Resume() end, "green")
    resume:SetPoint("TOP", pTitle, "BOTTOM", 0, -30)
    local levels = Kit.Button(pause, 220, 30, "GBA_TO_LEVELS", function() self:ShowMenu() end)
    levels:SetPoint("TOP", resume, "BOTTOM", 0, -12)
    local help = Kit.Button(pause, 220, 30, "GBA_HELP_BTN", function() self:ShowHelp() end)
    help:SetPoint("TOP", levels, "BOTTOM", 0, -12)

    self:BuildHelpPage(self.overlay:AddPage("help"))
end

function Module:ShowMenu()
    self.dragFrom = nil
    -- The contracts stand on their own: the bars of a level are not shown under them.
    self.topBar:Hide()
    self.toolBar:Hide()
    self:HideForeman()
    self.overlay:Show("menu")
end

-- The contracts: the logo small at the top, a chapter of eight cards, arrows between chapters.
function Module:BuildLevelMenu(page)
    local logo = page:CreateTexture(nil, "ARTWORK")
    logo:SetTexture(Tex("logo"))
    logo:SetSize(250, 125)
    logo:SetPoint("TOP", 0, 4)
    local stars = Text(page, 13, GOLD)
    stars:SetPoint("TOPRIGHT", -24, -20)
    local starIcon = page:CreateTexture(nil, "ARTWORK")
    starIcon:SetTexture(Tex("star"))
    starIcon:SetVertexColor(1, 0.8, 0.2)
    starIcon:SetSize(18, 18)
    starIcon:SetPoint("RIGHT", stars, "LEFT", -4, 0)
    -- The chapter: its name between two arrows.
    local chapter = Text(page, 16, GOLD)
    chapter:SetPoint("TOP", 0, -128)
    local sub = Text(page, 10, MUTED)
    sub:SetPoint("TOP", chapter, "BOTTOM", 0, -3)
    local prev = Kit.Arrow(page, -1, function() self:MenuChapter(-1) end)
    prev:SetPoint("RIGHT", chapter, "LEFT", -150, -6)
    local nextArrow = Kit.Arrow(page, 1, function() self:MenuChapter(1) end)
    nextArrow:SetPoint("LEFT", chapter, "RIGHT", 150, -6)
    local cards = {}
    local cw, ch, gap = 200, 150, 12
    local left = (W - (cw * 4 + gap * 3)) / 2
    for slot = 1, 8 do
        local c = CreateFrame("Button", nil, page)
        c:SetSize(cw, ch)
        local row, col = math.floor((slot - 1) / 4), (slot - 1) % 4
        c:SetPoint("TOPLEFT", left + col * (cw + gap), -176 - row * (ch + gap))
        -- A little picture of the place: sky, the rock, the river.
        c.sky = c:CreateTexture(nil, "BACKGROUND", nil, 0)
        c.sky:SetPoint("TOPLEFT")
        c.sky:SetPoint("TOPRIGHT")
        c.sky:SetHeight(ch * 0.62)
        c.horizon = c:CreateTexture(nil, "BACKGROUND", nil, 1)
        c.horizon:SetAllPoints(c.sky)
        c.horizon:SetTexture(Tex("gradient"))
        c.rockL = c:CreateTexture(nil, "BACKGROUND", nil, 2)
        c.rockR = c:CreateTexture(nil, "BACKGROUND", nil, 2)
        c.water = c:CreateTexture(nil, "BACKGROUND", nil, 1)
        c.water:SetPoint("BOTTOMLEFT")
        c.water:SetPoint("BOTTOMRIGHT")
        c.water:SetHeight(ch * 0.38)
        local shade = c:CreateTexture(nil, "BORDER")
        shade:SetAllPoints()
        shade:SetTexture(Tex("gradient"))
        shade:SetVertexColor(0, 0, 0, 0.75)
        local top = c:CreateTexture(nil, "BORDER", nil, 1)
        top:SetPoint("TOPLEFT")
        top:SetPoint("TOPRIGHT")
        top:SetHeight(34)
        top:SetColorTexture(0, 0, 0, 0.45)
        Widgets.Rim(c, c)
        c.glow = c:CreateTexture(nil, "OVERLAY")
        c.glow:SetPoint("TOPLEFT", -3, 3)
        c.glow:SetPoint("BOTTOMRIGHT", 3, -3)
        c.glow:SetTexture(MC.Tex("glow_card"))
        c.glow:SetBlendMode("ADD")
        c.glow:SetVertexColor(1, 0.8, 0.35)
        local hl = c:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 0.85, 0.5, 0.1)
        c.num = Text(c, 20, GOLD)
        c.num:SetPoint("TOPLEFT", 9, -7)
        c.name = Text(c, 12, CREAM)
        c.name:SetPoint("TOPLEFT", c.num, "TOPRIGHT", 7, -1)
        c.name:SetWidth(cw - 48)
        c.name:SetJustifyH("LEFT")
        c.name:SetWordWrap(false)
        c.zone = Text(c, 9, MUTED)
        c.zone:SetPoint("TOPLEFT", c.name, "BOTTOMLEFT", 0, -1)
        c.vehicle = Kit.Portrait(c, 38, 38)
        c.vehicle:SetPoint("BOTTOMRIGHT", -8, 8)
        c.stars = Stars(c, 20)
        c.stars:SetPoint("BOTTOMLEFT", 10, 28)
        c.best = Text(c, 10, CREAM)
        c.best:SetPoint("BOTTOMLEFT", 10, 10)
        c.lock = c:CreateTexture(nil, "OVERLAY")
        c.lock:SetSize(30, 30)
        c.lock:SetPoint("CENTER", 0, 0)
        c.lock:SetTexture("Interface\\Buttons\\LockButton-Locked-Up")
        c:SetScript("OnClick", function()
            if c.open then
                BA.UiSound(SOUNDKIT.IG_MAINMENU_OPTION)
                self:StartLevel(c.index)
            else
                BA.UiSound(SOUNDKIT.IG_QUEST_LOG_ABANDON_QUEST)
            end
        end)
        c:SetScript("OnEnter", function()
            local level = BA.LEVELS[c.index]
            Tooltip(c, L["GBA_L_" .. level.id], c.open and L["GBA_LI_" .. level.id] or L.GBA_LOCKED)
        end)
        c:SetScript("OnLeave", function() GameTooltip:Hide() end)
        cards[slot] = c
    end
    page.refresh = function()
        local store = self:Store()
        local best = store.best
        local total = self:Stars()
        stars:SetText(total .. " / " .. #BA.LEVELS * 3)
        local chapters = #BA.CHAPTERS
        -- Opening on the chapter of the next contract to do.
        if not self.menuChapter then
            local nextLevel = 1
            for i, level in ipairs(BA.LEVELS) do
                if best[level.id] then nextLevel = math.min(#BA.LEVELS, i + 1) end
            end
            self.menuChapter = BA.LEVELS[nextLevel].chapter
        end
        local chap = math.max(1, math.min(chapters, self.menuChapter))
        self.menuChapter = chap
        chapter:SetText(L["GBA_CH_" .. BA.CHAPTERS[chap]])
        sub:SetText(L.GBA_CHAPTER:format(chap, chapters))
        prev:SetEnabled(chap > 1)
        prev:SetAlpha(chap > 1 and 1 or 0.3)
        nextArrow:SetEnabled(chap < chapters)
        nextArrow:SetAlpha(chap < chapters and 1 or 0.3)
        local current = store.level
        for slot, c in ipairs(cards) do
            local i = (chap - 1) * 8 + slot
            local level = BA.LEVELS[i]
            c:SetShown(level ~= nil)
            if level then
                c.index = i
                local zone = BA.ZONES[level.zone]
                local b = best[level.id]
                c.open = i == 1 or best[BA.LEVELS[i - 1].id] ~= nil
                c.num:SetText(tostring(i))
                c.name:SetText(L["GBA_L_" .. level.id])
                c.zone:SetText(L["GBA_Z_" .. level.zone])
                local z, hz = zone.sky[2], zone.sky[1]
                c.sky:SetColorTexture(z[1], z[2], z[3], 1)
                c.horizon:SetVertexColor(hz[1], hz[2], hz[3], 1)
                local wc = zone.water
                c.water:SetColorTexture(wc[1], wc[2], wc[3], 1)
                -- The two rocks as the level has them (scaled down).
                local rocks = { c.rockL, c.rockR }
                for k, t in ipairs(rocks) do
                    local rect = k == 1 and level.terrain[1] or level.terrain[#level.terrain]
                    local l = math.max(0, rect[1]) / FW * cw
                    local r = math.min(FW, rect[2]) / FW * cw
                    local y = rect[3] / FH * ch
                    t:ClearAllPoints()
                    t:SetPoint("TOPLEFT", c, "TOPLEFT", l, -y)
                    t:SetPoint("BOTTOMRIGHT", c, "TOPLEFT", r, -ch)
                    t:SetTexture(zone.rock, "REPEAT", "REPEAT")
                    t:SetTexCoord(0, (r - l) / 64, 0, (ch - y) / 64)
                    t:SetVertexColor(zone.tint[1] * 0.8, zone.tint[2] * 0.75, zone.tint[3] * 0.72)
                end
                c.vehicle:SetDisplay(BA.VEHICLES[level.vehicle].display)
                c.stars:Set(b and b.stars or 0)
                c.stars:SetShown(c.open)
                c.best:SetText(b and L.GBA_BEST:format(Gold(b.cost)) or (c.open and L.GBA_BUDGET_ONLY:format(Gold(level.budget)) or ""))
                c.lock:SetShown(not c.open)
                c.vehicle:SetDimmed(not c.open, c.open and 1 or 0.4)
                c:SetAlpha(c.open and 1 or 0.75)
                c.num:SetTextColor(c.open and GOLD[1] or 0.5, c.open and GOLD[2] or 0.45, c.open and GOLD[3] or 0.4)
                c.glow:SetShown(c.open and not b)
                c.glow:SetAlpha(i == current and 0.9 or 0.45)
            end
        end
    end
end

function Module:MenuChapter(dir)
    self.menuChapter = (self.menuChapter or 1) + dir
    BA.UiSound(SOUNDKIT.IG_MAINMENU_OPTION)
    self.overlay.pages.menu.refresh()
end

-- Help: four steps and the materials.
function Module:BuildHelpPage(page)
    local title = Widgets.PageTitle(page, "GBA_HELP_TITLE", -24)
    local icons = { "Interface\\Icons\\INV_Hammer_20", "Interface\\Icons\\INV_Misc_Gear_01",
        "Interface\\Icons\\Ability_Mount_MechaStrider", "Interface\\Icons\\INV_Misc_Coin_01" }
    local texts = {}
    local tileW = 205
    for i = 1, 4 do
        local t = Plate(page, 0.6)
        t:SetSize(tileW, 128)
        t:SetPoint("TOPLEFT", (W - (tileW * 4 + 24)) / 2 + (i - 1) * (tileW + 8), -70)
        local ic = t:CreateTexture(nil, "ARTWORK")
        ic:SetSize(32, 32)
        ic:SetPoint("TOPLEFT", 8, -8)
        ic:SetTexture(icons[i])
        ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        local name = Text(t, 13, GOLD)
        name:SetPoint("LEFT", ic, "RIGHT", 8, 0)
        name:SetJustifyH("LEFT")
        local body = Kit.Ink(t, 10, CREAM)
        body:SetPoint("TOPLEFT", ic, "BOTTOMLEFT", 0, -6)
        body:SetWidth(tileW - 16)
        body:SetJustifyH("LEFT")
        body:SetSpacing(2)
        texts[#texts + 1] = { name, "GBA_HELP_" .. i .. "T" }
        texts[#texts + 1] = { body, "GBA_HELP_" .. i }
    end
    local mats = Plate(page, 0.6)
    mats:SetSize(tileW * 4 + 24, 230)
    mats:SetPoint("TOP", 0, -210)
    local head = Text(mats, 13, GOLD)
    head:SetPoint("TOPLEFT", 10, -8)
    texts[#texts + 1] = { head, "GBA_HELP_MATS" }
    for i, mat in ipairs(BA.MATERIAL_ORDER) do
        local m = BA.MATERIALS[mat]
        local row = CreateFrame("Frame", nil, mats)
        row:SetSize(tileW * 4, 46)
        row:SetPoint("TOPLEFT", 10, -30 - (i - 1) * 48)
        local sw = row:CreateTexture(nil, "ARTWORK")
        sw:SetTexture(Tex(BA.BEAM_LOOK[mat].tex))
        sw:SetSize(90, math.max(6, BA.BEAM_LOOK[mat].width + 2))
        sw:SetPoint("LEFT", 0, 4)
        local name = Text(row, 12, CREAM)
        name:SetPoint("LEFT", sw, "RIGHT", 12, 8)
        name:SetJustifyH("LEFT")
        local stat = Text(row, 10, GOLD)
        stat:SetPoint("LEFT", name, "RIGHT", 10, 0)
        stat:SetText(L.GBA_PER_M:format(m.cost) .. "  ·  max " .. m.maxLen .. " m")
        local desc = Kit.Ink(row, 10, CREAM)
        desc:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -3)
        desc:SetWidth(tileW * 4 - 120)
        desc:SetJustifyH("LEFT")
        texts[#texts + 1] = { name, "GBA_MAT_" .. mat }
        texts[#texts + 1] = { desc, "GBA_MATD_" .. mat }
    end
    local back = Kit.Button(page, 160, 30, "BACK", function()
        if self.helpBack == "game" and self.level then self.overlay:Hide()
        elseif self.helpBack == "pause" then self.overlay:Show("pause")
        else self:ShowMenu() end
    end, "red")
    back:SetPoint("BOTTOM", 0, 16)
    page.refresh = function()
        for _, e in ipairs(texts) do e[1]:SetText(L[e[2]]) end
    end
    local _ = title
end
