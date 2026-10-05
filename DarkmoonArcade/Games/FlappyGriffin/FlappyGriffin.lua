local _, ns = ...

local FG = ns.FlappyGriffin
local Game = FG.Game
local Arcade, Widgets, Scores, Media, L = ns.Arcade, ns.Widgets, ns.Scores, ns.Media, ns.L
local Achievements = ns.Achievements

local W, H = Game.WIDTH, Game.HEIGHT
local GROUND_TOP = H - Game.GROUND

-- Client assets (file data IDs).
-- Display info binds creature/gryphon/gryphon.m2 to its skin; the bare model renders untextured.
local GRYPHON_DISPLAY = 1149
local ROCK_TEXTURE = 187135 -- tileset/elwynn/elwynnrockbase.blp
local GRASS_TEXTURE = 187126 -- tileset/elwynn/elwynngrassbase.blp
local TICKET_ICON = 134481 -- interface/icons/inv_misc_ticket_darkmoon_01.blp
local VOICES = {
    aggro = { 551348, 551350 },
    attack = { 551352, 551349, 551342 },
    wound = { 551351, 551346, 551345 },
    death = { 551344 },
}

-- Model presentation; tunable in-game with /arcade fg <facing|anim|zoom> <value>.
local model = { facing = math.pi / 2, anim = 5, zoom = 0, size = 128 }

local FLAP_KEYS = { SPACE = true, W = true, UP = true }

local Module = {
    id = "flappygriffin",
    nameKey = "FG_NAME",
    descKey = "FG_DESC",
    helpKey = "FG_HELP",
    tile = "tiles/flappygriffin",
    defaults = { runs = 0 },
}

local FLIGHT_ICON = "Interface\\TaxiFrame\\UI-Taxi-Icon-Green"

Achievements.Register("flappygriffin", {
    { id = "fg_first", nameKey = "FG_ACH_FIRST", descKey = "FG_ACH_FIRST_DESC", icon = FLIGHT_ICON },
    { id = "fg_tickets", nameKey = "FG_ACH_TICKETS", descKey = "FG_ACH_TICKETS_DESC", icon = 134481 },
    { id = "fg_bronze", nameKey = "FG_ACH_BRONZE", descKey = "FG_ACH_BRONZE_DESC", icon = Media.Tex("flappy/medal_bronze") },
    { id = "fg_silver", nameKey = "FG_ACH_SILVER", descKey = "FG_ACH_SILVER_DESC", icon = Media.Tex("flappy/medal_silver") },
    { id = "fg_gold", nameKey = "FG_ACH_GOLD", descKey = "FG_ACH_GOLD_DESC", icon = Media.Tex("flappy/medal_gold") },
    { id = "fg_darkmoon", nameKey = "FG_ACH_DARKMOON", descKey = "FG_ACH_DARKMOON_DESC", icon = Media.Tex("portrait") },
    { id = "fg_runs", nameKey = "FG_ACH_RUNS", descKey = "FG_ACH_RUNS_DESC", icon = FLIGHT_ICON },
})
local RUNS_FOR_ACHIEVEMENT, TICKETS_FOR_ACHIEVEMENT = 25, 5

local function Tex(name) return Media.Tex("flappy/" .. name) end
local function Sound(name) Media.Play("flappy/" .. name) end
local function Voice(kind, force) Media.Voice(VOICES[kind], force) end

local function Place(region, x, y)
    region:ClearAllPoints()
    region:SetPoint("CENTER", region:GetParent(), "TOPLEFT", x, -y)
end

local function ShareMessage(entry)
    return L.FG_SHARE:format(ns.FormatNumber(entry.score))
end

function Module:BestScore()
    return Scores.Best(self.id, "default")
end

local function ApplyModel(m)
    pcall(m.SetDisplayInfo, m, GRYPHON_DISPLAY)
    pcall(m.SetFacing, m, model.facing)
    pcall(m.SetPortraitZoom, m, model.zoom)
    pcall(m.SetAnimation, m, model.anim)
end

-- Scenery ---------------------------------------------------------------------------

function Module:BuildScenery(world)
    local sky = world:CreateTexture(nil, "BACKGROUND", nil, 0)
    sky:SetAllPoints(self.container)
    sky:SetTexture(Tex("sky"))
    sky:SetTexCoord(0, W / 512, 0, H / 512)

    local clouds = world:CreateTexture(nil, "BACKGROUND", nil, 1)
    clouds:SetTexture(Tex("clouds"), "REPEAT", "CLAMP")
    clouds:SetPoint("TOPLEFT", self.container, "TOPLEFT", 0, -10)
    clouds:SetSize(W, 170)
    self.clouds = clouds

    local mountains = world:CreateTexture(nil, "BACKGROUND", nil, 2)
    mountains:SetTexture(Tex("mountains"), "REPEAT", "CLAMP")
    mountains:SetPoint("BOTTOMLEFT", self.container, "TOPLEFT", 0, -GROUND_TOP - 4)
    mountains:SetSize(W, 190)
    self.mountains = mountains

    local ground = world:CreateTexture(nil, "ARTWORK", nil, 5)
    ground:SetTexture(GRASS_TEXTURE, "REPEAT", "REPEAT")
    ground:SetPoint("TOPLEFT", self.container, "TOPLEFT", 0, -GROUND_TOP)
    ground:SetSize(W, Game.GROUND)
    ground:SetVertexColor(0.85, 0.95, 0.75)
    self.ground = ground

    local lip = world:CreateTexture(nil, "ARTWORK", nil, 6)
    lip:SetTexture(Tex("ground_lip"), "REPEAT", "CLAMP")
    lip:SetPoint("TOPLEFT", ground, "TOPLEFT", 0, 10)
    lip:SetSize(W, 28)
    self.lip = lip
end

function Module:CreatePillarVisual()
    local layer = self.pillarLayer
    local v = {}
    local function Segment()
        local body = layer:CreateTexture(nil, "ARTWORK", nil, 0)
        body:SetTexture(ROCK_TEXTURE, "REPEAT", "REPEAT")
        body:SetVertexColor(0.92, 0.86, 0.78)
        local shade = layer:CreateTexture(nil, "ARTWORK", nil, 1)
        shade:SetTexture(Tex("pillar_shade"))
        shade:SetBlendMode("MOD")
        local cap = layer:CreateTexture(nil, "ARTWORK", nil, 2)
        cap:SetTexture(Tex("pillar_cap"))
        return { body = body, shade = shade, cap = cap }
    end
    v.top, v.bottom = Segment(), Segment()
    v.glow = layer:CreateTexture(nil, "ARTWORK", nil, 3)
    v.glow:SetTexture(Media.Tex("glow"))
    v.glow:SetBlendMode("ADD")
    v.glow:SetVertexColor(1, 0.75, 0.35)
    v.glow:SetSize(52, 52)
    v.ticket = layer:CreateTexture(nil, "ARTWORK", nil, 4)
    v.ticket:SetTexture(TICKET_ICON)
    v.ticket:SetSize(26, 26)
    v.ticket:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    return v
end

local function HideVisual(v)
    for _, seg in ipairs({ v.top, v.bottom }) do
        seg.body:Hide(); seg.shade:Hide(); seg.cap:Hide()
    end
    v.ticket:Hide()
    v.glow:Hide()
end

local function DrawSegment(seg, x, top, bottom, capAtBottom)
    local w = Game.PILLAR_W
    local h = bottom - top
    if h <= 0 then
        seg.body:Hide(); seg.shade:Hide(); seg.cap:Hide()
        return
    end
    for _, tex in ipairs({ seg.body, seg.shade }) do
        tex:ClearAllPoints()
        tex:SetPoint("TOPLEFT", tex:GetParent(), "TOPLEFT", x - w / 2, -top)
        tex:SetSize(w, h)
        tex:Show()
    end
    -- Anchor the rock pattern to the gap edge so it does not crawl while the pillar moves.
    local v1 = capAtBottom and -h / 128 or 0
    seg.body:SetTexCoord(0, w / 128, v1, v1 + h / 128)
    seg.cap:ClearAllPoints()
    seg.cap:SetSize(w + 14, 24)
    local capY = capAtBottom and (bottom - 10) or (top + 10)
    seg.cap:SetPoint("CENTER", seg.cap:GetParent(), "TOPLEFT", x, -capY)
    if capAtBottom then seg.cap:SetTexCoord(0, 1, 1, 0) else seg.cap:SetTexCoord(0, 1, 0, 1) end
    seg.cap:Show()
end

function Module:DrawPillar(pillar)
    local v = self.visuals[pillar]
    if not v then return end
    local gapTop = pillar.gapY - pillar.gap / 2
    local gapBottom = pillar.gapY + pillar.gap / 2
    DrawSegment(v.top, pillar.x, -20, gapTop, true)
    DrawSegment(v.bottom, pillar.x, gapBottom, GROUND_TOP + 4, false)
    local ticket = pillar.ticket
    if ticket and not ticket.taken then
        local bob = math.sin(self.game.time * 5 + pillar.x * 0.05) * 3
        Place(v.ticket, pillar.x, ticket.y + bob)
        Place(v.glow, pillar.x, ticket.y + bob)
        v.glow:SetAlpha(0.55 + 0.25 * math.sin(self.game.time * 6))
        v.ticket:Show()
        v.glow:Show()
    else
        v.ticket:Hide()
        v.glow:Hide()
    end
end

-- Effects ---------------------------------------------------------------------------

function Module:AddEffect(update)
    self.effects[#self.effects + 1] = { t = 0, update = update }
end

function Module:SpawnFeathers(x, y, count, color)
    for _ = 1, count do
        local tex = self.fxPool.Acquire()
        tex:SetTexture(Media.Tex(math.random() < 0.5 and "spark" or "dot"))
        tex:SetBlendMode("ADD")
        local c = color or { 1, 0.95, 0.8 }
        tex:SetVertexColor(c[1], c[2], c[3])
        tex:Show()
        local px, py = x, y
        local vx, vy = -60 - math.random() * 90, (math.random() - 0.3) * 120
        local life = 0.4 + math.random() * 0.3
        self:AddEffect(function(e, dt)
            local p = e.t / life
            if p >= 1 then
                self.fxPool.Release(tex)
                return false
            end
            vy = vy + 200 * dt
            px, py = px + vx * dt, py + vy * dt
            Place(tex, px, py)
            local s = 10 * (1 - p * 0.5)
            tex:SetSize(s, s)
            tex:SetAlpha(1 - p)
            return true
        end)
    end
end

function Module:SpawnText(x, y, text, size, r, g, b)
    local fs = self.textPool.Acquire()
    fs:SetFont(Media.FontFile(), size, "OUTLINE")
    fs:SetTextColor(r, g, b)
    fs:SetText(text)
    fs:Show()
    self:AddEffect(function(e)
        local p = e.t / 0.8
        if p >= 1 then
            self.textPool.Release(fs)
            return false
        end
        Place(fs, x, y - 30 * (1 - (1 - p) ^ 3))
        fs:SetAlpha(p < 0.6 and 1 or (1 - (p - 0.6) / 0.4))
        return true
    end)
end

-- Build -----------------------------------------------------------------------------

function Module:Build(container)
    self.container = container
    self.effects = {}
    self.visuals = {}

    local world = CreateFrame("Frame", nil, container)
    world:SetSize(W, H)
    world:SetPoint("TOPLEFT")
    self.world = world
    self:BuildScenery(world)

    local pillarLayer = CreateFrame("Frame", nil, world)
    pillarLayer:SetAllPoints()
    pillarLayer:SetFrameLevel(world:GetFrameLevel() + 1)
    self.pillarLayer = pillarLayer
    self.visualPool = Media.Pool(function() return self:CreatePillarVisual() end, HideVisual)

    local griffin = CreateFrame("PlayerModel", nil, world)
    griffin:SetSize(model.size, model.size)
    griffin:SetFrameLevel(world:GetFrameLevel() + 4)
    ApplyModel(griffin)
    self.griffin = griffin

    local fx = CreateFrame("Frame", nil, world)
    fx:SetAllPoints()
    fx:SetFrameLevel(world:GetFrameLevel() + 6)
    self.fxPool = Media.Pool(function() return fx:CreateTexture(nil, "OVERLAY") end, function(tex) tex:Hide() end)
    self.textPool = Media.Pool(function()
        local fs = fx:CreateFontString(nil, "OVERLAY")
        fs:SetFont(Media.FontFile(), 16, "OUTLINE")
        return fs
    end, function(fs) fs:Hide() end)

    self.bigScore = fx:CreateFontString(nil, "OVERLAY")
    self.bigScore:SetFont(Media.FontFile(), 40, "THICKOUTLINE")
    self.bigScore:SetPoint("TOP", container, "TOP", 0, -26)
    self.hint = Widgets.LocalizedText(fx, 14, "white", "FG_TAP")
    self.hint:SetPoint("TOP", container, "TOP", 0, -150)

    container:EnableMouse(true)
    container:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then self.game:Flap() end
    end)

    local game = Game.New()
    game.onEvent = function(name, data) self:OnGameEvent(name, data) end
    self.game = game

    self.overlay = Widgets.NewOverlay(container)
    self:CreatePages()
    Widgets.ScoresPage(self.overlay, W, {
        gameId = self.id,
        detail = function(entry) return self:ScoreDetail(entry) end,
        shareMessage = ShareMessage,
        onBack = function() self.overlay:Show("menu") end,
    })
    Widgets.AchievementsPage(self.overlay, W, self.id, function()
        self.overlay:Show(self.achievementsBack or "menu", self.achievementsBackData)
    end)
    self:ResetRun()
    self.overlay:Show("menu")
end

function Module:CreatePages()
    local menu = self.overlay:AddPage("menu")
    local title = Widgets.PageTitle(menu, "FG_NAME", -60)
    local tagline = Widgets.LocalizedText(menu, 14, "blue", "FG_TAGLINE")
    tagline:SetPoint("TOP", title, "BOTTOM", 0, -6)
    local play = Widgets.Button(menu, 200, 26, "NEW_GAME", function() self:NewRun() end)
    local scores = Widgets.Button(menu, 200, 26, "HIGHSCORES", function() self.overlay:Show("scores") end)
    Widgets.Stack(menu, { play, scores }, -190)

    local pause = self.overlay:AddPage("pause")
    local pauseTitle = Widgets.PageTitle(pause, "PAUSED", -100)
    local landed = Widgets.Text(pause, 14, "blue")
    landed:SetPoint("TOP", pauseTitle, "BOTTOM", 0, -8)
    local resume = Widgets.Button(pause, 200, 26, "RESUME", function() self:Resume() end)
    local pauseMenu = Widgets.Button(pause, 200, 26, "MENU", function()
        self:ResetRun()
        self.overlay:Show("menu")
    end)
    Widgets.Stack(pause, { resume, pauseMenu }, -190)
    pause.refresh = function(data)
        landed:SetText((data and data.landed) and L.LANDED or "")
    end

    local over = self.overlay:AddPage("over")
    local overTitle = Widgets.PageTitle(over, "GAME_OVER", -50)
    local final = Widgets.Text(over, 18, "white")
    final:SetPoint("TOP", overTitle, "BOTTOM", 0, -10)
    local medalIcon = over:CreateTexture(nil, "ARTWORK")
    medalIcon:SetSize(72, 72)
    medalIcon:SetPoint("TOP", final, "BOTTOM", 0, -10)
    local medalText = Widgets.Text(over, 13, "gold")
    medalText:SetPoint("TOP", medalIcon, "BOTTOM", 0, -4)
    local record = Widgets.Text(over, 14, "gold")
    record:SetPoint("TOP", medalText, "BOTTOM", 0, -6)
    local share = Widgets.ShareRow(over, function()
        return self.lastScore and self.lastScore > 0 and ShareMessage({ score = self.lastScore })
    end)
    share:SetPoint("TOP", 0, -268)
    local again = Widgets.Button(over, 200, 26, "AGAIN", function() self:NewRun() end)
    local overMenu = Widgets.Button(over, 200, 26, "MENU", function()
        self:ResetRun()
        self.overlay:Show("menu")
    end)
    Widgets.Stack(over, { again, overMenu }, -306)
    over.refresh = function(data)
        final:SetText(L.FG_POINTS:format(ns.FormatNumber(data.score)))
        medalText:ClearAllPoints()
        if data.medal then
            medalText:SetPoint("TOP", medalIcon, "BOTTOM", 0, -4)
            medalIcon:SetTexture(data.medal == "darkmoon" and Media.Tex("portrait") or Tex("medal_" .. data.medal))
            medalIcon:Show()
            medalText:SetText(L.FG_MEDAL:format(L["FG_MEDAL_" .. data.medal]))
        else
            medalIcon:Hide()
            medalText:SetPoint("TOP", final, "BOTTOM", 0, -14)
            local nextMedal = Game.NextMedal(data.score)
            medalText:SetText(nextMedal and L.FG_NEXT_MEDAL:format(L["FG_MEDAL_" .. nextMedal.key], nextMedal.score) or "")
        end
        record:SetText(data.rank == 1 and L.NEW_RECORD or "")
    end
end

-- Game flow ---------------------------------------------------------------------------

function Module:ResetRun()
    for pillar, v in pairs(self.visuals) do
        self.visualPool.Release(v)
        self.visuals[pillar] = nil
    end
    self.game:Reset()
    self.shakeTime = 0
    self:UpdateHud()
end

function Module:NewRun()
    self:ResetRun()
    self.overlay:Hide()
end

function Module:Resume()
    self.game:Resume()
    self.overlay:Hide()
end

function Module:Pause(info)
    local game = self.game
    if not game then return end
    if game.state == "PLAYING" or game.state == "READY" then
        if game.state == "READY" and self.overlay.current then return end
        game:Pause()
        self.overlay:Show("pause", info)
    elseif info.landed and game.state == "PAUSED" then
        self.overlay:Show("pause", info)
    end
end

function Module:Sidebar()
    local score = self.game.score
    local medal, nextMedal = Game.Medal(score), Game.NextMedal(score)
    local lines = {}
    if medal then lines[#lines + 1] = L.FG_MEDAL:format(L["FG_MEDAL_" .. medal]) end
    if nextMedal then lines[#lines + 1] = L.FG_NEXT_MEDAL:format(L["FG_MEDAL_" .. nextMedal.key], nextMedal.score) end
    return { score = score, bucket = "default", info = table.concat(lines, "\n") }
end

function Module:ScoreDetail(entry)
    return entry.medal and L["FG_MEDAL_" .. entry.medal] or date(L.DATE_FORMAT, entry.time)
end

function Module:UpdateHud()
    ns.Window:UpdateSidebar()
end

function Module:OnGameEvent(name, data)
    if name == "start" then
        Voice("aggro", true)
        self.runTickets = 0
        local settings = Arcade.Settings(self)
        settings.runs = settings.runs + 1
        if settings.runs >= RUNS_FOR_ACHIEVEMENT then Achievements.Unlock("fg_runs") end
    elseif name == "flap" then
        Sound("flap")
        self:SpawnFeathers(Game.GRIFFIN_X - 18, self.game.y + 6, 3)
    elseif name == "spawn" then
        self.visuals[data] = self.visualPool.Acquire()
    elseif name == "despawn" then
        local v = self.visuals[data]
        if v then
            self.visualPool.Release(v)
            self.visuals[data] = nil
        end
    elseif name == "score" then
        Sound("point")
        self:UpdateHud()
        Achievements.Unlock("fg_first")
        if data.score % 10 == 0 then Voice("attack") end
    elseif name == "ticket" then
        if ns.db.sound then PlaySound(SOUNDKIT.LOOT_WINDOW_COIN_SOUND) end
        self:SpawnFeathers(data.x, data.y, 10, { 1, 0.8, 0.3 })
        self:SpawnText(data.x, data.y - 10, "+" .. Game.TICKET_POINTS, 16, 1, 0.85, 0.3)
        self.runTickets = (self.runTickets or 0) + 1
        if self.runTickets >= TICKETS_FOR_ACHIEVEMENT then Achievements.Unlock("fg_tickets") end
        self:UpdateHud()
    elseif name == "hit" then
        Sound("hit")
        Voice("wound", true)
        self.shakeTime = 0.35
        self:SpawnFeathers(Game.GRIFFIN_X, self.game.y, 12)
    elseif name == "over" then
        Voice("death", true)
        self.lastScore = data.score
        for _, medal in ipairs(Game.MEDALS) do
            if data.score >= medal.score then Achievements.Unlock("fg_" .. medal.key) end
        end
        local rank = Scores.Record(self.id, "default", { score = data.score, medal = data.medal })
        self:UpdateHud()
        C_Timer.After(0.9, function()
            if self.game.state ~= "OVER" then return end
            if data.medal then Sound("medal") end
            self.overlay:Show("over", { score = data.score, medal = data.medal, rank = rank })
        end)
    end
end

-- Arcade hooks ------------------------------------------------------------------------

function Module:ShowAchievements()
    Widgets.ShowAchievements(self)
end

function Module:Enter()
    self:UpdateHud()
    self.overlay:Refresh()
end

function Module:Leave()
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
    if FLAP_KEYS[key] and (game.state == "PLAYING" or (game.state == "READY" and not self.overlay.current)) then
        game:Flap()
        return true
    end
    return false
end

function Module:OnUpdate(dt)
    local game = self.game
    game:Update(dt)

    local d = game.distance
    self.clouds:SetTexCoord(d * 0.12 / 512, (d * 0.12 + W) / 512, 0, 1)
    self.mountains:SetTexCoord(d * 0.35 / 512, (d * 0.35 + W) / 512, 0, 1)
    self.ground:SetTexCoord(d / 128, (d + W) / 128, 0, Game.GROUND / 128)
    self.lip:SetTexCoord(d / 512, (d + W) / 512, 0, 1)

    for _, pillar in ipairs(game.pillars) do self:DrawPillar(pillar) end

    local tilt = math.max(-0.5, math.min(0.9, game.vy / 700))
    if game.state == "READY" then tilt = 0 end
    Place(self.griffin, Game.GRIFFIN_X, game.y)
    pcall(self.griffin.SetPitch, self.griffin, tilt)

    local ox, oy = 0, 0
    if (self.shakeTime or 0) > 0 then
        self.shakeTime = self.shakeTime - dt
        ox, oy = (math.random() - 0.5) * 8, (math.random() - 0.5) * 8
    end
    self.world:ClearAllPoints()
    self.world:SetPoint("TOPLEFT", self.container, "TOPLEFT", ox, oy)

    self.bigScore:SetText((game.state == "PLAYING" or game.state == "DYING") and game.score or "")
    self.hint:SetShown(game.state == "READY" and not self.overlay.current)

    for i = #self.effects, 1, -1 do
        local e = self.effects[i]
        e.t = e.t + dt
        if not e.update(e, dt) then table.remove(self.effects, i) end
    end
end

function Module:DecorateTile(tile, art)
    local m = CreateFrame("PlayerModel", nil, tile)
    m:SetSize(120, 120)
    m:SetPoint("CENTER", art, "CENTER", -56, 6)
    ApplyModel(m)
    self.tileModel = m
end

-- /arcade fg <facing|anim|zoom|size> <number> tunes the gryphon model in-game.
function Module:Debug(key, value)
    if model[key] == nil or not value then return false end
    model[key] = value
    if self.griffin then
        self.griffin:SetSize(model.size, model.size)
        ApplyModel(self.griffin)
    end
    if self.tileModel then ApplyModel(self.tileModel) end
    ns.Print(("gryphon %s = %s"):format(key, tostring(value)))
    return true
end

FG.Module = Module
Arcade.RegisterGame(Module)
