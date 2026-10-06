local _, ns = ...

local SB = ns.Spellbounce
local Game, Maps = SB.Game, SB.Maps
local Arcade, Widgets, Scores, Media, Achievements, L = ns.Arcade, ns.Widgets, ns.Scores, ns.Media, ns.Achievements, ns.L

local W, H = Game.WIDTH, Game.HEIGHT
local LX, LY = Game.LAUNCH_X, Game.LAUNCH_Y
local KEY_TURN_SPEED = 1.6
local AIM_LEFT = { LEFT = true, A = true }
local AIM_RIGHT = { RIGHT = true, D = true }
local SHOOT = { SPACE = true, ENTER = true, UP = true, W = true }
local SLOWMO_TIME, SLOWMO_SCALE = 1.4, 0.35

local KIND_COLORS = {
    blue = { 0.45, 0.65, 1 },
    target = { 1, 0.36, 0.28 },
    power = { 0.35, 1, 0.45 },
    gold = { 1, 0.82, 0.25 },
}
local FIREWORK_COLORS = {
    { 1, 0.4, 0.35 }, { 1, 0.85, 0.3 }, { 0.4, 1, 0.5 }, { 0.4, 0.7, 1 }, { 0.85, 0.45, 1 }, { 1, 1, 1 },
}

-- Class colors follow the game's own class colors; icons are the matching spells.
local CLASS_INFO = {
    mage = { color = { 0.41, 0.8, 0.94 }, icon = "Interface\\Icons\\Spell_Nature_WispSplode" },
    hunter = { color = { 0.67, 0.83, 0.45 }, icon = "Interface\\Icons\\Ability_UpgradeMoonGlaive" },
    priest = { color = { 1, 1, 1 }, icon = "Interface\\Icons\\Spell_Holy_PowerWordShield" },
    shaman = { color = { 0.2, 0.55, 1 }, icon = "Interface\\Icons\\Spell_Nature_ChainLightning" },
    warlock = { color = { 0.58, 0.51, 0.79 }, icon = "Interface\\Icons\\Spell_Shadow_RainOfFire" },
    rogue = { color = { 1, 0.96, 0.41 }, icon = "Interface\\Icons\\Ability_Vanish" },
    warrior = { color = { 0.78, 0.61, 0.43 }, icon = "Interface\\Icons\\Ability_Whirlwind" },
    paladin = { color = { 0.96, 0.55, 0.73 }, icon = "Interface\\Icons\\Spell_Holy_Excorcism_02" },
    druid = { color = { 1, 0.49, 0.04 }, icon = "Interface\\Icons\\Spell_Nature_Cyclone" },
}
-- Hits lit by a power arrive in bursts; only this many play a sound per frame.
local MAX_HIT_SOUNDS = 2

local Module = {
    id = "spellbounce",
    rank = 1,
    nameKey = "SB_NAME",
    descKey = "SB_DESC",
    helpKey = "SB_HELP",
    tile = "tiles/spellbounce",
    defaults = { class = "mage", reached = 1, guide = true, pegs = 0, classesCleared = {} },
}

local function Tex(name) return Media.Tex("spellbounce/" .. name) end
local function Sound(name) Media.Play("spellbounce/" .. name) end
local function Settings() return Arcade.Settings(Module) end

Achievements.Register("spellbounce", {
    { id = "sb_first", nameKey = "SB_ACH_FIRST", descKey = "SB_ACH_FIRST_DESC", icon = Tex("orb") },
    { id = "sb_power", nameKey = "SB_ACH_POWER", descKey = "SB_ACH_POWER_DESC", icon = CLASS_INFO.mage.icon },
    { id = "sb_well", nameKey = "SB_ACH_WELL", descKey = "SB_ACH_WELL_DESC", icon = "Interface\\Icons\\Spell_Nature_Starfall" },
    { id = "sb_ricochet", nameKey = "SB_ACH_RICOCHET", descKey = "SB_ACH_RICOCHET_DESC", icon = CLASS_INFO.hunter.icon },
    { id = "sb_surge", nameKey = "SB_ACH_SURGE", descKey = "SB_ACH_SURGE_DESC", icon = CLASS_INFO.shaman.icon },
    { id = "sb_map5", nameKey = "SB_ACH_MAP5", descKey = "SB_ACH_MAP5_DESC", icon = Tex("bumper") },
    { id = "sb_saver", nameKey = "SB_ACH_SAVER", descKey = "SB_ACH_SAVER_DESC", icon = CLASS_INFO.priest.icon },
    { id = "sb_lastorb", nameKey = "SB_ACH_LASTORB", descKey = "SB_ACH_LASTORB_DESC", icon = CLASS_INFO.rogue.icon },
    { id = "sb_map10", nameKey = "SB_ACH_MAP10", descKey = "SB_ACH_MAP10_DESC", icon = Tex("launcher") },
    { id = "sb_overload", nameKey = "SB_ACH_OVERLOAD", descKey = "SB_ACH_OVERLOAD_DESC", icon = CLASS_INFO.warlock.icon },
    { id = "sb_classes", nameKey = "SB_ACH_CLASSES", descKey = "SB_ACH_CLASSES_DESC", icon = "Interface\\Icons\\Spell_Holy_MagicalSentry" },
    { id = "sb_score", nameKey = "SB_ACH_SCORE", descKey = "SB_ACH_SCORE_DESC", icon = "Interface\\Icons\\INV_Misc_Coin_01" },
    { id = "sb_lap2", nameKey = "SB_ACH_LAP2", descKey = "SB_ACH_LAP2_DESC", icon = Tex("bumper") },
    { id = "sb_pegs", nameKey = "SB_ACH_PEGS", descKey = "SB_ACH_PEGS_DESC", icon = Tex("peg") },
    { id = "sb_flight", nameKey = "SB_ACH_FLIGHT", descKey = "SB_ACH_FLIGHT_DESC", icon = "Interface\\TaxiFrame\\UI-Taxi-Icon-Green" },
})
local GOALS = { ricochet = 15, surge = 2000, overload = 5000, saver = 5, score = 100000, pegs = 10000 }

local function ClassName(class) return L["SB_CLASS_" .. class] end
local function MapName(level) return L["SB_MAP_" .. Maps.Get(level).key] end

local function ShareMessage(entry)
    return L.SB_SHARE:format(ns.FormatNumber(entry.score), entry.level or 1, ClassName(entry.class or "mage"))
end

local function Place(region, x, y)
    region:ClearAllPoints()
    region:SetPoint("CENTER", region:GetParent(), "TOPLEFT", x, -y)
end

-- The selected class, falling back to the first one if it is still locked.
local function CurrentClass()
    local settings = Settings()
    if not Game.IsUnlocked(settings.class, settings.reached) then settings.class = Game.CLASSES[1] end
    return settings.class
end

local function UnlockedClasses()
    local list = {}
    for _, class in ipairs(Game.CLASSES) do
        if Game.IsUnlocked(class, Settings().reached) then list[#list + 1] = class end
    end
    return list
end

local function NextLockedClass(progress)
    for _, class in ipairs(Game.CLASSES) do
        if not Game.IsUnlocked(class, progress) then return class end
    end
end

function Module:BestScore()
    return Scores.Best(self.id, "default")
end

-- Build ----------------------------------------------------------------------------------

function Module:Build(container)
    self.container = container
    self.pegVisuals, self.effects, self.ballVisuals, self.keysHeld = {}, {}, {}, {}
    self.slowmo, self.hitSounds = 0, 0

    local field = CreateFrame("Frame", nil, container)
    field:SetSize(W, H)
    field:SetPoint("TOPLEFT")
    field:SetClipsChildren(true)
    self.field = field

    self.bg = field:CreateTexture(nil, "BACKGROUND")
    self.bg:SetAllPoints()
    self.bg:SetTexCoord(0, W / 512, 0, H / 512)

    local level = field:GetFrameLevel()
    local function Layer(offset)
        local f = CreateFrame("Frame", nil, field)
        f:SetAllPoints()
        f:SetFrameLevel(level + offset)
        return f
    end
    self.pegLayer, self.ballLayer, self.fxLayer, self.hudLayer = Layer(1), Layer(3), Layer(5), Layer(6)

    self.pegPool = Media.Pool(function()
        local v = {
            glow = self.pegLayer:CreateTexture(nil, "ARTWORK", nil, 0),
            tex = self.pegLayer:CreateTexture(nil, "ARTWORK", nil, 1),
        }
        v.glow:SetTexture(Media.Tex("glow"))
        v.glow:SetBlendMode("ADD")
        return v
    end, function(v)
        v.tex:Hide()
        v.glow:Hide()
        v.tex:SetAlpha(1)
    end)
    self.ballPool = Media.Pool(function()
        local v = {
            glow = self.ballLayer:CreateTexture(nil, "ARTWORK", nil, 0),
            tex = self.ballLayer:CreateTexture(nil, "ARTWORK", nil, 1),
        }
        v.glow:SetTexture(Media.Tex("glow"))
        v.glow:SetBlendMode("ADD")
        v.glow:SetSize(44, 44)
        v.tex:SetTexture(Tex("orb"))
        v.tex:SetSize(22, 22)
        v.aura = self.ballLayer:CreateTexture(nil, "ARTWORK", nil, 2)
        v.aura:SetTexture(Media.Tex("ring"))
        v.aura:SetBlendMode("ADD")
        return v
    end, function(v)
        v.tex:Hide()
        v.glow:Hide()
        v.aura:Hide()
    end)
    self.fxPool = Media.Pool(function() return self.fxLayer:CreateTexture(nil, "OVERLAY") end, function(t)
        t:Hide()
        t:SetRotation(0)
        t:SetAlpha(1)
    end)
    self.linePool = Media.Pool(function() return self.fxLayer:CreateLine(nil, "OVERLAY") end, function(l) l:Hide() end)
    self.textPool = Media.Pool(function() return self.fxLayer:CreateFontString(nil, "OVERLAY") end, function(fs) fs:Hide() end)

    self:CreateLauncher()
    self:CreateHud()

    self.well = self.ballLayer:CreateTexture(nil, "ARTWORK", nil, -1)
    self.well:SetTexture(Tex("well"))
    self.well:SetSize(Game.WELL_W + 8, 23)
    self.shield = self.ballLayer:CreateTexture(nil, "ARTWORK", nil, -2)
    self.shield:SetTexture(Media.Tex("glow"))
    self.shield:SetBlendMode("ADD")
    self.shield:SetVertexColor(1, 0.95, 0.6)
    self.shield:SetSize(W + 80, 26)
    Place(self.shield, W / 2, H - 4)
    self.shield:Hide()

    self.dots = {}
    for i = 1, 36 do
        local dot = self.ballLayer:CreateTexture(nil, "ARTWORK", nil, -3)
        dot:SetTexture(Media.Tex("dot"))
        dot:SetSize(6, 6)
        dot:SetBlendMode("ADD")
        dot:Hide()
        self.dots[i] = dot
    end

    field:EnableMouse(true)
    field:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" and self.game.state == "PLAYING" then
            self:AimAtCursor()
            self.game:Shoot()
        end
    end)

    local game = Game.New()
    game.class = CurrentClass()
    game.onEvent = function(name, data) self:OnGameEvent(name, data) end
    self.game = game

    self.overlay = Widgets.NewOverlay(container)
    self:CreateMenuPage()
    self:CreatePausePage()
    self:CreateClearPage()
    self:CreateOverPage()
    Widgets.ScoresPage(self.overlay, W, {
        gameId = self.id,
        detail = function(entry) return self:ScoreDetail(entry) end,
        shareMessage = ShareMessage,
        onBack = function() self.overlay:Show("menu") end,
    })
    Widgets.AchievementsPage(self.overlay, W, self.id, function() Widgets.BackFromSubPage(self) end)
    Widgets.HelpPage(self.overlay, W, "SB_RULES", "SB_HELP", function() Widgets.BackFromSubPage(self) end)
    self:ShowMenu()
end

function Module:CreateLauncher()
    local layer = self.hudLayer
    local ring = layer:CreateTexture(nil, "ARTWORK", nil, 0)
    ring:SetTexture(Tex("launcher"))
    ring:SetSize(60, 60)
    Place(ring, LX, LY)
    self.classIcon = layer:CreateTexture(nil, "ARTWORK", nil, 1)
    self.classIcon:SetSize(26, 26)
    self.classIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    Place(self.classIcon, LX, LY)
    self.arrow = layer:CreateTexture(nil, "ARTWORK", nil, -1)
    self.arrow:SetTexture(Media.Tex("murlocblast/arrow"))
    self.arrow:SetSize(96, 96)
    Place(self.arrow, LX, LY)
end

function Module:CreateHud()
    local layer = self.hudLayer
    local orbIcon = layer:CreateTexture(nil, "ARTWORK")
    orbIcon:SetTexture(Tex("orb"))
    orbIcon:SetSize(22, 22)
    Place(orbIcon, 22, 20)
    self.orbIcon = orbIcon
    self.orbText = Widgets.Text(layer, 16, "white")
    self.orbText:SetPoint("LEFT", orbIcon, "RIGHT", 2, 0)

    local targetIcon = layer:CreateTexture(nil, "ARTWORK")
    targetIcon:SetTexture(Tex("peg"))
    targetIcon:SetVertexColor(unpack(KIND_COLORS.target))
    targetIcon:SetSize(18, 18)
    Place(targetIcon, W - 58, 20)
    self.targetText = Widgets.Text(layer, 16, "white")
    self.targetText:SetPoint("LEFT", targetIcon, "RIGHT", 4, 0)
    self.multText = Widgets.Text(layer, 14, "gold")
    self.multText:SetPoint("TOPRIGHT", layer, "TOPRIGHT", -12, -32)
end

-- Class picker shared by the menu and the map-clear page.
function Module:ClassPicker(page, top)
    local label = Widgets.LocalizedText(page, 11, "gray", "SB_CLASS")
    label:SetPoint("TOP", 0, top)
    local cycler = Widgets.Cycler(page, 200, function(dir)
        local settings = Settings()
        settings.class = Widgets.Cycle(UnlockedClasses(), CurrentClass(), dir)
        self.game.class = settings.class
        page.refresh(page.data)
        self:UpdateHud()
    end)
    cycler:SetPoint("TOP", label, "BOTTOM", 0, -2)
    local icon = page:CreateTexture(nil, "ARTWORK")
    icon:SetSize(24, 24)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetPoint("RIGHT", cycler, "LEFT", -6, 0)
    local power = Widgets.Text(page, 12, "gold")
    power:SetPoint("TOP", cycler, "BOTTOM", 0, -6)
    local desc = Widgets.Text(page, 11, "white")
    desc:SetPoint("TOP", power, "BOTTOM", 0, -3)
    desc:SetWidth(W - 60)
    return function()
        local class = CurrentClass()
        local c = CLASS_INFO[class].color
        cycler.label:SetText(ClassName(class))
        cycler.label:SetTextColor(c[1], c[2], c[3])
        icon:SetTexture(CLASS_INFO[class].icon)
        power:SetText(L["SB_POWER_" .. class])
        desc:SetText(L["SB_POWERDESC_" .. class])
    end
end

function Module:CreateMenuPage()
    local page = self.overlay:AddPage("menu")
    local title = Widgets.PageTitle(page, "SB_NAME", -40)
    local tagline = Widgets.LocalizedText(page, 14, "blue", "SB_TAGLINE")
    tagline:SetPoint("TOP", title, "BOTTOM", 0, -6)
    local refreshClass = self:ClassPicker(page, -112)
    local newGame = Widgets.Button(page, 200, 26, "NEW_GAME", function() self:StartGame(1) end)
    local continue = Widgets.Button(page, 200, 26, nil, function() self:StartGame(Settings().reached) end)
    local scores = Widgets.Button(page, 200, 26, "HIGHSCORES", function() self.overlay:Show("scores") end)
    Widgets.Stack(page, { newGame, continue, scores }, -224)
    local nextClass = Widgets.Text(page, 11, "gray")
    nextClass:SetPoint("TOP", 0, -330)
    page.refresh = function()
        refreshClass()
        local progress = Settings().reached
        continue:SetText(L.SB_CONTINUE:format(progress))
        continue:SetEnabled(progress > 1)
        local locked = NextLockedClass(progress)
        nextClass:SetText(locked and L.SB_NEXT_CLASS:format(Game.UNLOCK[locked], ClassName(locked)) or L.SB_ALL_CLASSES)
    end
end

function Module:CreatePausePage()
    local page = self.overlay:AddPage("pause")
    local title = Widgets.PageTitle(page, "PAUSED", -90)
    local landed = Widgets.Text(page, 14, "blue")
    landed:SetPoint("TOP", title, "BOTTOM", 0, -8)
    local resume = Widgets.Button(page, 200, 26, "RESUME", function() self:Resume() end)
    local menu = Widgets.Button(page, 200, 26, "MENU", function() self:AbandonRun() end)
    Widgets.Stack(page, { resume, menu }, -190)
    page.refresh = function(data) landed:SetText((data and data.landed) and L.LANDED or "") end
end

function Module:CreateClearPage()
    local page = self.overlay:AddPage("clear")
    local title = Widgets.PageTitle(page, "SB_MAP_CLEAR", -44)
    local pegBonus = Widgets.Text(page, 14, "white")
    pegBonus:SetPoint("TOP", title, "BOTTOM", 0, -10)
    local orbBonus = Widgets.Text(page, 14, "white")
    orbBonus:SetPoint("TOP", pegBonus, "BOTTOM", 0, -4)
    local total = Widgets.Text(page, 16, "gold")
    total:SetPoint("TOP", orbBonus, "BOTTOM", 0, -8)
    local unlocked = Widgets.Text(page, 13, "blue")
    unlocked:SetPoint("TOP", total, "BOTTOM", 0, -8)
    local refreshClass = self:ClassPicker(page, -190)
    local nextMap = Widgets.Button(page, 200, 26, "SB_NEXT_MAP", function() self:NextMap() end)
    local menu = Widgets.Button(page, 200, 26, "MENU", function() self:AbandonRun() end)
    Widgets.Stack(page, { nextMap, menu }, -300)
    page.refresh = function(data)
        page.data = data
        refreshClass()
        if not data then return end
        pegBonus:SetText(L.SB_PEG_BONUS:format(ns.FormatNumber(data.pegBonus)))
        orbBonus:SetText(L.SB_ORB_BONUS:format(ns.FormatNumber(data.orbBonus)))
        total:SetText(L.FINAL_SCORE:format(ns.FormatNumber(self.game.score)))
        unlocked:SetText(data.unlocked and L.SB_UNLOCKED:format(ClassName(data.unlocked)) or "")
    end
end

function Module:CreateOverPage()
    local page = self.overlay:AddPage("over")
    local title = Widgets.PageTitle(page, "GAME_OVER", -80)
    local reason = Widgets.LocalizedText(page, 14, "blue", "SB_NO_ORBS")
    reason:SetPoint("TOP", title, "BOTTOM", 0, -6)
    local final = Widgets.Text(page, 18, "white")
    final:SetPoint("TOP", reason, "BOTTOM", 0, -12)
    local record = Widgets.Text(page, 14, "gold")
    record:SetPoint("TOP", final, "BOTTOM", 0, -8)
    local share = Widgets.ShareRow(page, function() return self.lastEntry and ShareMessage(self.lastEntry) end)
    share:SetPoint("TOP", 0, -220)
    local again = Widgets.Button(page, 200, 26, "AGAIN", function() self:StartGame(self.runStart or 1) end)
    local menu = Widgets.Button(page, 200, 26, "MENU", function() self:ShowMenu() end)
    Widgets.Stack(page, { again, menu }, -262)
    page.refresh = function(data)
        if not data then return end
        final:SetText(L.FINAL_SCORE:format(ns.FormatNumber(data.score)))
        record:SetText(data.rank == 1 and L.NEW_RECORD or "")
    end
end

-- Pegs and effects ---------------------------------------------------------------------

function Module:DrawPeg(v)
    local peg = v.peg
    if peg.bumper then
        v.tex:SetTexture(Tex("bumper"))
        v.tex:SetVertexColor(1, 1, 1)
        v.tex:SetSize(30, 30)
        v.glow:Hide()
    else
        local c = KIND_COLORS[peg.kind]
        v.tex:SetTexture(Tex("peg"))
        v.tex:SetSize(20, 20)
        if peg.lit then
            v.tex:SetVertexColor(0.55 + c[1] * 0.45, 0.55 + c[2] * 0.45, 0.55 + c[3] * 0.45)
            v.glow:SetVertexColor(c[1], c[2], c[3])
            v.glow:SetSize(44, 44)
            Place(v.glow, peg.x, peg.y)
            v.glow:Show()
        else
            v.tex:SetVertexColor(c[1] * 0.85, c[2] * 0.85, c[3] * 0.85)
            v.glow:Hide()
        end
    end
    Place(v.tex, peg.x, peg.y)
    v.tex:Show()
end

function Module:RebuildPegs()
    for id, v in pairs(self.pegVisuals) do
        self.pegPool.Release(v)
        self.pegVisuals[id] = nil
    end
    for _, peg in ipairs(self.game.pegs) do
        if not peg.gone then
            local v = self.pegPool.Acquire()
            v.peg = peg
            self:DrawPeg(v)
            self.pegVisuals[peg.id] = v
        end
    end
    self.traceDirty = true
end

function Module:AddEffect(update, finish)
    self.effects[#self.effects + 1] = { t = 0, update = update, finish = finish }
end

function Module:ClearEffects()
    for i = #self.effects, 1, -1 do
        local e = self.effects[i]
        if e.finish then e.finish(e) end
    end
    wipe(self.effects)
end

function Module:Burst(x, y, color, count, speed, size, gravity)
    for _ = 1, count do
        local tex = self.fxPool.Acquire()
        tex:SetTexture(Media.Tex("spark"))
        tex:SetBlendMode("ADD")
        tex:SetVertexColor(color[1], color[2], color[3])
        tex:Show()
        local angle = math.random() * math.pi * 2
        local v = (speed or 120) * (0.5 + math.random() * 0.7)
        local px, py = x, y
        local vx, vy = math.cos(angle) * v, math.sin(angle) * v
        local life = 0.5 + math.random() * 0.4
        tex:SetSize(size or 14, size or 14)
        self:AddEffect(function(e, dt)
            local p = e.t / life
            if p >= 1 then return false end
            vy = vy + (gravity or 0) * dt
            px, py = px + vx * dt, py + vy * dt
            Place(tex, px, py)
            tex:SetAlpha(1 - p)
            return true
        end, function() self.fxPool.Release(tex) end)
    end
end

function Module:Ring(x, y, color, from, to, duration)
    local tex = self.fxPool.Acquire()
    tex:SetTexture(Media.Tex("ring"))
    tex:SetBlendMode("ADD")
    tex:SetVertexColor(color[1], color[2], color[3])
    tex:Show()
    self:AddEffect(function(e)
        local p = e.t / duration
        if p >= 1 then return false end
        local s = from + (to - from) * p
        tex:SetSize(s, s)
        tex:SetAlpha(1 - p)
        Place(tex, x, y)
        return true
    end, function() self.fxPool.Release(tex) end)
end

function Module:Bolt(x1, y1, x2, y2, color, delay)
    local line = self.linePool.Acquire()
    line:SetThickness(3)
    line:SetColorTexture(color[1], color[2], color[3], 1)
    line:SetStartPoint("TOPLEFT", self.fxLayer, x1, -y1)
    line:SetEndPoint("TOPLEFT", self.fxLayer, x2, -y2)
    line:Hide()
    self:AddEffect(function(e)
        if e.t < delay then return true end
        local p = (e.t - delay) / 0.45
        if p >= 1 then return false end
        line:SetAlpha(1 - p)
        line:Show()
        return true
    end, function() self.linePool.Release(line) end)
end

-- A falling flame from above the field onto a peg.
function Module:Meteor(x, y, delay, color)
    color = color or { 1, 0.5, 0.15 }
    local tex = self.fxPool.Acquire()
    tex:SetTexture(Media.Tex("glow"))
    tex:SetBlendMode("ADD")
    tex:SetVertexColor(color[1], color[2], color[3])
    tex:SetSize(26, 26)
    tex:Hide()
    local startX = x - 60
    self:AddEffect(function(e)
        if e.t < delay then return true end
        local p = (e.t - delay) / 0.3
        if p >= 1 then
            self:Burst(x, y, color, 5, 90, 14)
            return false
        end
        Place(tex, startX + 60 * p, -20 + (y + 20) * p)
        tex:Show()
        return true
    end, function() self.fxPool.Release(tex) end)
end

function Module:Popup(x, y, text, size, color, duration)
    local fs = self.textPool.Acquire()
    fs:SetFont(Media.FontFile(), size, "OUTLINE")
    fs:SetTextColor(color[1], color[2], color[3])
    fs:SetText(text)
    fs:Show()
    x = math.max(70, math.min(W - 70, x))
    duration = duration or 0.9
    self:AddEffect(function(e)
        local p = e.t / duration
        if p >= 1 then return false end
        Place(fs, x, y - 26 * (1 - (1 - p) ^ 3))
        fs:SetAlpha(p < 0.65 and 1 or (1 - (p - 0.65) / 0.35))
        return true
    end, function() self.textPool.Release(fs) end)
end

function Module:PopPeg(peg, delay)
    local v = self.pegVisuals[peg.id]
    if not v then return end
    self.pegVisuals[peg.id] = nil
    local color = KIND_COLORS[peg.kind] or { 1, 1, 1 }
    self:AddEffect(function(e)
        if e.t < delay then return true end
        local p = (e.t - delay) / 0.2
        if p >= 1 then return false end
        v.tex:SetSize(20 * (1 + p * 0.6), 20 * (1 + p * 0.6))
        v.tex:SetAlpha(1 - p)
        v.glow:SetAlpha(1 - p)
        return true
    end, function() self.pegPool.Release(v) end)
    self:AddEffect(function(e)
        if e.t < delay then return true end
        self:Burst(peg.x, peg.y, color, 3, 70, 10)
        return false
    end)
end

-- Fireworks: a rocket climbs from the bottom and bursts into colored sparks.
function Module:Rocket(x, apex, color, delay)
    local tex = self.fxPool.Acquire()
    tex:SetTexture(Media.Tex("spark"))
    tex:SetBlendMode("ADD")
    tex:SetVertexColor(color[1], color[2], color[3])
    tex:SetSize(14, 14)
    tex:Hide()
    local launched = false
    self:AddEffect(function(e)
        if e.t < delay then return true end
        local p = (e.t - delay) / 0.7
        if not launched then
            launched = true
            Sound("rocket")
        end
        if p >= 1 then
            self:Burst(x, apex, color, 18, 150, 16, 90)
            self:Ring(x, apex, color, 20, 180, 0.5)
            Sound("firework")
            return false
        end
        local ease = 1 - (1 - p) ^ 2
        Place(tex, x + math.sin(p * 6) * 4, H + 10 - (H + 10 - apex) * ease)
        tex:Show()
        return true
    end, function() self.fxPool.Release(tex) end)
end

-- Game events ------------------------------------------------------------------------------

function Module:OnGameEvent(name, data)
    local game = self.game
    if name == "level" then
        self:ClearEffects()
        self.bg:SetTexture(Tex("background" .. Maps.Get(data.level).background))
        self:RebuildPegs()
        if self.previewing then return end
        self:Popup(W / 2, H * 0.48, L.SB_MAP_TITLE:format(data.level, MapName(data.level)), 20, { 1, 0.85, 0.4 }, 2.2)
        if data.level >= 5 then Achievements.Unlock("sb_map5") end
        self:UpdateHud()
    elseif name == "shoot" then
        Sound("launch")
        self:UpdateHud()
    elseif name == "hit" then
        local peg = data.peg
        local v = self.pegVisuals[peg.id]
        if v then self:DrawPeg(v) end
        if self.hitSounds < MAX_HIT_SOUNDS then
            self.hitSounds = self.hitSounds + 1
            Sound("hit" .. math.min(data.chain, 12))
            if peg.kind == "target" then Sound("target") end
        end
        local color = KIND_COLORS[peg.kind]
        self:Burst(peg.x, peg.y, color, 2, 80, 10)
        if peg.kind ~= "blue" then
            self:Popup(peg.x, peg.y - 12, "+" .. ns.FormatNumber(data.points), 13, color, 0.8)
        end
        self.traceDirty = true
        local settings = Settings()
        settings.pegs = settings.pegs + 1
        if settings.pegs >= GOALS.pegs then Achievements.Unlock("sb_pegs") end
        if data.chain >= GOALS.ricochet then Achievements.Unlock("sb_ricochet") end
        self:UpdateHud()
    elseif name == "bump" then
        Sound("bump")
        self:Ring(data.peg.x, data.peg.y, { 1, 0.85, 0.5 }, 24, 60, 0.25)
    elseif name == "power" then
        self:OnPower(data)
    elseif name == "lastTarget" then
        self.slowmo = SLOWMO_TIME
        self:Popup(W / 2, H * 0.4, L.SB_LAST_TARGET, 22, { 1, 0.5, 0.35 }, 1.4)
    elseif name == "catch" then
        Sound("catch")
        self:Ring(data.x, Game.WELL_Y, { 0.5, 0.9, 1 }, 30, 120, 0.5)
        self:Popup(data.x, Game.WELL_Y - 24, L.SB_FREE_ORB, 16, { 0.6, 0.9, 1 }, 1.2)
        Achievements.Unlock("sb_well")
        self:UpdateHud()
    elseif name == "lost" then
        Sound("lost")
    elseif name == "shield" then
        Sound("shield")
        self:Ring(data.x, H - 8, { 1, 0.95, 0.6 }, 30, 140, 0.4)
    elseif name == "unstick" then
        for i, peg in ipairs(data.pegs) do self:PopPeg(peg, (i - 1) * 0.02) end
        self.traceDirty = true
    elseif name == "shotEnd" then
        self:OnShotEnd(data)
    elseif name == "clear" then
        self:OnClear(data)
    elseif name == "over" then
        local rank = self:Record()
        Media.Play("murlocblast/gameover")
        self:UpdateHud()
        C_Timer.After(1.1, function()
            if game.state == "OVER" then self.overlay:Show("over", { score = game.score, rank = rank }) end
        end)
    end
end

function Module:OnPower(data)
    local class = data.class
    local color = CLASS_INFO[class].color
    Sound("power")
    Achievements.Unlock("sb_power")
    self:Popup(data.x, data.y - 22, L["SB_POWER_" .. class] .. "!", 16, color, 1.3)
    self:Ring(data.x, data.y, color, 20, 90, 0.45)
    if class == "mage" then
        self:Ring(data.x, data.y, color, 30, 200, 0.55)
        self:Burst(data.x, data.y, color, 18, 160, 14)
    elseif class == "shaman" then
        local x, y = data.x, data.y
        for i, peg in ipairs(data.pegs) do
            self:Bolt(x, y, peg.x, peg.y, color, (i - 1) * 0.06)
            x, y = peg.x, peg.y
        end
    elseif class == "warlock" then
        for i, peg in ipairs(data.pegs) do self:Meteor(peg.x, peg.y, (i - 1) * 0.07) end
    elseif class == "paladin" then
        for i, peg in ipairs(data.pegs) do
            self:Meteor(peg.x, peg.y, (i - 1) * 0.12, { 1, 0.9, 0.55 })
            self:Ring(peg.x, peg.y, { 1, 0.9, 0.55 }, 20, 80, 0.5)
        end
    end
    self.traceDirty = true
end

function Module:OnShotEnd(data)
    for i, peg in ipairs(data.pegs) do self:PopPeg(peg, (i - 1) * 0.03) end
    if data.points > 0 then
        self:Popup(W / 2, H - 70, L.SB_SHOT:format(ns.FormatNumber(data.points)), 15, { 1, 0.9, 0.5 }, 1.2)
    end
    if data.bonusOrb then
        self:Popup(W / 2, H - 96, L.SB_BONUS_ORB, 17, { 0.6, 0.9, 1 }, 1.4)
        Sound("catch")
    end
    if data.points >= GOALS.surge then Achievements.Unlock("sb_surge") end
    if data.points >= GOALS.overload then Achievements.Unlock("sb_overload") end
    if self.game.score >= GOALS.score then Achievements.Unlock("sb_score") end
    self.traceDirty = true
    self:UpdateHud()
end

-- The finale: rockets over the field while the leftover pegs burst one by one.
function Module:OnClear(data)
    local game = self.game
    Sound("clear")
    for i, peg in ipairs(data.pegs) do
        local delay = 0.4 + (i - 1) * 0.04
        local v = self.pegVisuals[peg.id]
        if v then
            self.pegVisuals[peg.id] = nil
            self:AddEffect(function(e)
                if e.t < delay then return true end
                self:Burst(peg.x, peg.y, FIREWORK_COLORS[math.random(#FIREWORK_COLORS)], 5, 130, 12, 60)
                return false
            end, function() self.pegPool.Release(v) end)
        end
    end
    for i = 1, 7 do
        self:Rocket(50 + math.random() * (W - 100), 90 + math.random() * 160, FIREWORK_COLORS[(i - 1) % #FIREWORK_COLORS + 1], 0.2 + i * 0.32)
    end

    local settings = Settings()
    local before = settings.reached
    settings.reached = math.max(settings.reached, data.level + 1)
    settings.classesCleared[game.class] = true
    ns.Stats.Bump(self.id, "maps")
    ns.Stats.Bump(self.id, "class_" .. game.class)
    local unlocked
    for _, class in ipairs(Game.CLASSES) do
        if not Game.IsUnlocked(class, before) and Game.IsUnlocked(class, settings.reached) then unlocked = class end
    end
    local cleared = 0
    for _ in pairs(settings.classesCleared) do cleared = cleared + 1 end
    Achievements.Unlock("sb_first")
    if cleared >= #Game.CLASSES then Achievements.Unlock("sb_classes") end
    if data.level >= 10 then Achievements.Unlock("sb_map10") end
    if data.level >= 20 then Achievements.Unlock("sb_lap2") end
    if data.orbsLeft >= GOALS.saver then Achievements.Unlock("sb_saver") end
    if data.orbsLeft == 0 then Achievements.Unlock("sb_lastorb") end
    if game.score >= GOALS.score then Achievements.Unlock("sb_score") end
    if ns.Flight.current then Achievements.Unlock("sb_flight") end
    self:UpdateHud()
    C_Timer.After(3.4, function()
        if game.state == "CLEAR" then
            self.overlay:Show("clear", { pegBonus = data.pegBonus, orbBonus = data.orbBonus, unlocked = unlocked })
        end
    end)
end

-- Game flow ----------------------------------------------------------------------------

function Module:ShowMenu()
    local game = self.game
    self:ClearEffects()
    game.class = CurrentClass()
    -- The first map stays visible behind the menu.
    self.previewing = true
    game:LoadLevel(1)
    self.previewing = false
    game.state = "READY"
    game.score = 0
    self:UpdateHud()
    self.overlay:Show("menu")
end

function Module:StartGame(level)
    self.runStart = level
    self.finished = false
    self.game:StartRun(level, CurrentClass())
    self.overlay:Hide()
    self:UpdateHud()
end

function Module:NextMap()
    self.game.class = CurrentClass()
    self.game:LoadLevel(self.game.level + 1)
    self.overlay:Hide()
end

function Module:Record()
    local game = self.game
    self.finished = true
    self.lastEntry = { score = game.score, level = game.level, class = game.class }
    return Scores.Record(self.id, "default", { score = game.score, level = game.level, class = game.class })
end

-- Leaving a run early still counts towards the highscores.
function Module:AbandonRun()
    local state = self.game.state
    if self.game.score > 0 and not self.finished and (state == "PAUSED" or state == "CLEAR") then self:Record() end
    self:ShowMenu()
end

function Module:Pause(info)
    local game = self.game
    if not game then return end
    if game.state == "PLAYING" then
        game:Pause()
        self.overlay:Show("pause", info)
    elseif info.landed and game.state == "PAUSED" then
        self.overlay:Show("pause", info)
    end
end

function Module:Resume()
    self.game:Resume()
    self.overlay:Hide()
end

-- Arcade hooks ----------------------------------------------------------------------------

function Module:Sidebar()
    local game = self.game
    return {
        score = game.score,
        bucket = "default",
        info = L.SB_MAP:format(game.level) .. "  ·  " .. ClassName(game.class),
    }
end

function Module:ScoreDetail(entry)
    local text = L.SB_MAP:format(entry.level or 1)
    if entry.class and L["SB_CLASS_" .. entry.class] then text = text .. "  ·  " .. ClassName(entry.class) end
    return text
end

function Module:UpdateHud()
    local game = self.game
    local playing = game.state ~= "READY"
    self.orbText:SetText(playing and ("x" .. game.orbs) or "")
    self.orbIcon:SetShown(playing)
    self.targetText:SetText(playing and tostring(game:TargetsLeft()) or "")
    self.multText:SetText(playing and ("x" .. game:Multiplier()) or "")
    local info = CLASS_INFO[game.class]
    self.classIcon:SetTexture(info.icon)
    self.orbIcon:SetVertexColor(info.color[1], info.color[2], info.color[3])
    ns.Window:UpdateSidebar()
end

function Module:ShowAchievements()
    Widgets.ShowSubPage(self, "achievements")
end

function Module:ShowHelp()
    Widgets.ShowSubPage(self, "help")
end

function Module:Enter()
    self:UpdateHud()
    self.overlay:Refresh()
end

function Module:Leave()
    wipe(self.keysHeld)
    self:Pause({})
end

function Module:RefreshTexts()
    self.overlay:Refresh()
    self:UpdateHud()
end

function Module:OnKey(key)
    local game = self.game
    if key == "P" and (game.state == "PLAYING" or (game.state == "PAUSED" and self.overlay.current == "pause")) then
        if game.state == "PLAYING" then self:Pause({}) else self:Resume() end
        return true
    end
    if game.state ~= "PLAYING" then return false end
    if AIM_LEFT[key] or AIM_RIGHT[key] then
        self.keysHeld[key] = true
        return true
    elseif SHOOT[key] then
        game:Shoot()
        return true
    end
    return false
end

function Module:OnKeyUp(key)
    self.keysHeld[key] = nil
end

function Module:AimAtCursor()
    local field = self.field
    local left, top = field:GetLeft(), field:GetTop()
    if not left then return end
    local scale = field:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    self.game:AimAt(cx / scale - left, top - cy / scale)
end

function Module:UpdateAim(dt)
    local game = self.game
    if game.state == "PLAYING" then
        local turn = 0
        for key in pairs(self.keysHeld) do
            if AIM_LEFT[key] then turn = turn + 1 elseif AIM_RIGHT[key] then turn = turn - 1 end
        end
        if turn ~= 0 then
            game:SetAim(game.angle + turn * KEY_TURN_SPEED * dt)
        elseif self.field:IsMouseOver() then
            local cx, cy = GetCursorPosition()
            if cx ~= self.lastCursorX or cy ~= self.lastCursorY then
                self.lastCursorX, self.lastCursorY = cx, cy
                self:AimAtCursor()
            end
        end
    end
    -- The arrow texture points up; screen angles grow clockwise.
    self.arrow:SetRotation(-game.angle - math.pi / 2)
    self.arrow:SetAlpha(game:CanShoot() and 1 or 0.35)

    local showGuide = Settings().guide and game:CanShoot()
    if not showGuide then
        for _, dot in ipairs(self.dots) do dot:Hide() end
        return
    end
    if self.traceDirty or self.traceAngle ~= game.angle then
        self.traceDirty, self.traceAngle = false, game.angle
        self.trace = game:Trace(1.2)
    end
    local points = self.trace
    local spacing, offset = 14, 30 - (GetTime() * 28) % 14
    local index, travelled = 1, 0
    local c = CLASS_INFO[game.class].color
    for seg = 1, #points - 1 do
        local x1, y1, x2, y2 = points[seg][1], points[seg][2], points[seg + 1][1], points[seg + 1][2]
        local len = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
        while len > 0 and offset <= travelled + len and index <= #self.dots do
            local t = (offset - travelled) / len
            local dot = self.dots[index]
            Place(dot, x1 + (x2 - x1) * t, y1 + (y2 - y1) * t)
            dot:SetVertexColor(c[1], c[2], c[3])
            dot:SetAlpha(0.9 * (1 - index / #self.dots))
            dot:Show()
            index, offset = index + 1, offset + spacing
        end
        travelled = travelled + len
    end
    for i = index, #self.dots do self.dots[i]:Hide() end
end

function Module:DrawBalls()
    local game = self.game
    local color = CLASS_INFO[game.class].color
    for i, ball in ipairs(game.balls) do
        local v = self.ballVisuals[i]
        if not v then
            v = self.ballPool.Acquire()
            self.ballVisuals[i] = v
        end
        local alpha = ball.ghost > 0 and 0.4 or 1
        v.tex:SetVertexColor(0.75 + color[1] * 0.25, 0.75 + color[2] * 0.25, 0.75 + color[3] * 0.25)
        v.glow:SetVertexColor(color[1], color[2], color[3])
        v.tex:SetAlpha(alpha)
        v.glow:SetAlpha(alpha * 0.8)
        Place(v.tex, ball.x, ball.y)
        Place(v.glow, ball.x, ball.y)
        v.tex:Show()
        v.glow:Show()
        -- Whirlwind shows its reach, Hurricane a smaller swirl.
        if ball.whirl > 0 or ball.steer > 0 then
            local size = ball.whirl > 0 and 98 or 54
            v.aura:SetSize(size, size)
            v.aura:SetVertexColor(color[1], color[2], color[3])
            v.aura:SetAlpha(0.35 + 0.25 * math.sin(GetTime() * 12))
            Place(v.aura, ball.x, ball.y)
            v.aura:Show()
        else
            v.aura:Hide()
        end
    end
    for i = #self.ballVisuals, #game.balls + 1, -1 do
        self.ballPool.Release(self.ballVisuals[i])
        self.ballVisuals[i] = nil
    end
    local inPlay = game.state ~= "READY"
    Place(self.well, game:WellX(), Game.WELL_Y + 6)
    self.well:SetShown(inPlay)
    self.shield:SetShown(game.shot ~= nil and game.shot.shields > 0)
    if game.shot and game.shot.shields > 0 then self.shield:SetAlpha(0.6 + 0.3 * math.sin(GetTime() * 8)) end
end

function Module:OnUpdate(dt)
    local game = self.game
    local scale = 1
    if self.slowmo > 0 then
        self.slowmo = self.slowmo - dt
        scale = SLOWMO_SCALE
    end
    self.hitSounds = 0
    self:UpdateAim(dt)
    game:Update(dt * scale)
    self:DrawBalls()
    for i = #self.effects, 1, -1 do
        local e = self.effects[i]
        e.t = e.t + dt
        if not e.update(e, dt) then
            if e.finish then e.finish(e) end
            table.remove(self.effects, i)
        end
    end
end

function Module:DecorateTile(tile, art)
    for i, class in ipairs(Game.CLASSES) do
        local icon = tile:CreateTexture(nil, "OVERLAY")
        icon:SetTexture(CLASS_INFO[class].icon)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        icon:SetSize(22, 22)
        icon:SetPoint("TOPLEFT", art, "TOPLEFT", 14 + (i - 1) * 26, -14)
    end
end

function Module:ResetProgress()
    local settings = Settings()
    settings.reached = 1
    settings.classesCleared = {}
end

function Module:Options()
    return {
        { kind = "check", tbl = Settings(), key = "guide", label = "SB_OPT_GUIDE", tip = "SB_OPT_GUIDE_TIP", default = true },
    }
end

function Module:StatLines()
    local favorite, most = nil, 0
    for _, class in ipairs(Game.CLASSES) do
        local maps = ns.Stats.Get(self.id, "class_" .. class)
        if maps > most then favorite, most = class, maps end
    end
    return {
        { L.SB_STAT_RUNES, ns.FormatNumber(Settings().pegs or 0) },
        { L.SB_STAT_MAPS, ns.FormatNumber(ns.Stats.Get(self.id, "maps")) },
        { L.SB_STAT_CLASS, favorite and ClassName(favorite) or "–" },
    }
end

SB.Module = Module
Arcade.RegisterGame(Module)
