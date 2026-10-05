-- The arcade window: Blizzard's panel frame crowned by the logo, a hub with one tile per
-- game, and a playfield plus sidebar for whichever game is active.

local _, ns = ...

local Media, Widgets, Flight, Scores, L = ns.Media, ns.Widgets, ns.Flight, ns.Scores, ns.L

local Arcade = { games = {}, order = {} }
ns.Arcade = Arcade

local Window = {}
ns.Window = Window

-- Every game draws into a playfield of this size; the sidebar sits to its right.
Arcade.FIELD_W, Arcade.FIELD_H = 432, 462
local SIDEBAR_W, GUTTER = 200, 8
local CONTENT_W = Arcade.FIELD_W + GUTTER + SIDEBAR_W
local CONTENT_H = Arcade.FIELD_H

local INSET_TOP, INSET_BOTTOM, INSET_LEFT, INSET_RIGHT, INSET_PAD = 30, 30, 4, 6, 3
local FRAME_W = CONTENT_W + INSET_LEFT + INSET_RIGHT + INSET_PAD * 2
local FRAME_H = CONTENT_H + INSET_TOP + INSET_BOTTOM + INSET_PAD * 2
local LOGO_W, LOGO_H = 280, 180
local TILE_W, TILE_H, TILE_GAP = 200, 236, 10
local SIDEBAR_SCORES = 5

function Arcade.RegisterGame(game)
    Arcade.games[game.id] = game
    Arcade.order[#Arcade.order + 1] = game.id
end

-- Per-game saved settings, created with the game's defaults on first use.
function Arcade.Settings(game)
    local store = ns.db.games
    store[game.id] = store[game.id] or {}
    for k, v in pairs(game.defaults or {}) do
        if store[game.id][k] == nil then store[game.id][k] = v end
    end
    return store[game.id]
end

function Window:Create()
    local f = CreateFrame("Frame", "DarkmoonArcadeFrame", UIParent)
    f:SetSize(FRAME_W, FRAME_H)
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetClampRectInsets(0, 0, LOGO_H - 30, 0)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:Hide()
    tinsert(UISpecialFrames, "DarkmoonArcadeFrame")
    self.frame = f

    -- Content is parented to the chrome so it always draws above the chrome's background.
    local chrome = CreateFrame("Frame", nil, f, "PortraitFrameTemplateNoCloseButton")
    chrome:SetAllPoints()
    if ButtonFrameTemplate_HidePortrait then pcall(ButtonFrameTemplate_HidePortrait, chrome) end
    if chrome.SetTitle then chrome:SetTitle("") end
    self.chrome = chrome

    local close = CreateFrame("Button", nil, chrome, "UIPanelCloseButtonNoScripts")
    close:SetPoint("TOPRIGHT")
    close:SetScript("OnClick", function() f:Hide() end)

    local function StartMove() f:StartMoving() end
    local function StopMove()
        f:StopMovingOrSizing()
        local point, _, relPoint, x, y = f:GetPoint()
        ns.db.position = { point, relPoint, x, y }
    end

    local titleBar = CreateFrame("Frame", nil, chrome)
    titleBar:SetPoint("TOPLEFT", 4, 0)
    titleBar:SetPoint("TOPRIGHT", -28, 0)
    titleBar:SetHeight(24)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", StartMove)
    titleBar:SetScript("OnDragStop", StopMove)

    -- The logo replaces the title text and rises above the frame.
    local logoFrame = CreateFrame("Frame", nil, chrome)
    logoFrame:SetSize(LOGO_W, LOGO_H)
    logoFrame:SetPoint("BOTTOM", f, "TOP", 0, -26)
    logoFrame:SetFrameLevel(chrome:GetFrameLevel() + 20)
    logoFrame:EnableMouse(true)
    logoFrame:RegisterForDrag("LeftButton")
    logoFrame:SetScript("OnDragStart", StartMove)
    logoFrame:SetScript("OnDragStop", StopMove)
    local logo = logoFrame:CreateTexture(nil, "ARTWORK")
    logo:SetAllPoints()
    logo:SetTexture(Media.Tex("logo"))
    logo:SetTexCoord(0, 1, 0, 330 / 512)

    local inset = CreateFrame("Frame", nil, chrome, "InsetFrameTemplate")
    inset:SetPoint("TOPLEFT", INSET_LEFT, -INSET_TOP)
    inset:SetPoint("BOTTOMRIGHT", -INSET_RIGHT, INSET_BOTTOM)
    inset:SetFrameLevel(chrome:GetFrameLevel() + 2)

    local content = CreateFrame("Frame", nil, inset)
    content:SetSize(CONTENT_W, CONTENT_H)
    content:SetPoint("TOPLEFT", INSET_PAD, -INSET_PAD)
    content:SetFrameLevel(inset:GetFrameLevel() + 2)
    self.content = content

    local field = CreateFrame("Frame", nil, content)
    field:SetSize(Arcade.FIELD_W, Arcade.FIELD_H)
    field:SetPoint("TOPLEFT")
    field:SetClipsChildren(true)
    self.field = field

    self:CreateSidebar()
    self:CreateFooter()
    self:CreateHub()

    self:ApplyScale()
    self:RestorePosition()

    f:EnableKeyboard(true)
    f:SetScript("OnKeyDown", function(frame, key)
        local game = self.activeGame
        local handled = false
        if game and game.OnKey then
            local ok, result = ns.SafeCall("OnKey", game.OnKey, game, key)
            handled = ok and result or false
        end
        if not InCombatLockdown() then frame:SetPropagateKeyboardInput(not handled) end
    end)
    f:SetScript("OnKeyUp", function(_, key)
        local game = self.activeGame
        if game and game.OnKeyUp then game:OnKeyUp(key) end
    end)
    f:SetScript("OnUpdate", function(_, elapsed)
        ns.SafeCall("OnUpdate", self.OnUpdate, self, math.min(elapsed, 0.05))
    end)
    f:SetScript("OnShow", function()
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN)
        self:RefreshHub()
    end)
    f:SetScript("OnHide", function()
        if self.activeGame then self.activeGame:Pause({}) end
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE)
    end)

    self:OpenHub()
end

-- Sidebar ----------------------------------------------------------------------

function Window:CreateSidebar()
    local bar = CreateFrame("Frame", nil, self.content)
    bar:SetSize(SIDEBAR_W, CONTENT_H)
    bar:SetPoint("TOPRIGHT")
    self.sidebar = bar

    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(Media.Tex("hub_background"))
    bg:SetTexCoord(0, SIDEBAR_W / 512, 0, CONTENT_H / 512)

    local divider = bar:CreateTexture(nil, "BORDER")
    divider:SetColorTexture(0, 0, 0, 0.8)
    divider:SetPoint("TOPRIGHT", bar, "TOPLEFT", 0, 0)
    divider:SetPoint("BOTTOMRIGHT", bar, "BOTTOMLEFT", 0, 0)
    divider:SetWidth(GUTTER)

    local s = {}
    s.name = Widgets.Text(bar, 16, "gold")
    s.name:SetPoint("TOP", 0, -14)
    s.scoreLabel = Widgets.LocalizedText(bar, 11, "gray", "SCORE")
    s.scoreLabel:SetPoint("TOP", s.name, "BOTTOM", 0, -14)
    s.score = Widgets.Text(bar, 28, "gold")
    s.score:SetPoint("TOP", s.scoreLabel, "BOTTOM", 0, -4)
    s.best = Widgets.Text(bar, 12, "white")
    s.best:SetPoint("TOP", s.score, "BOTTOM", 0, -6)
    s.info = Widgets.Text(bar, 12, "blue")
    s.info:SetPoint("TOP", s.best, "BOTTOM", 0, -10)
    s.info:SetWidth(SIDEBAR_W - 20)

    s.scoresTitle = Widgets.LocalizedText(bar, 12, "gold", "HIGHSCORES")
    s.scoresTitle:SetPoint("TOP", 0, -170)
    s.rows = {}
    for i = 1, SIDEBAR_SCORES do
        local y = -192 - (i - 1) * 18
        local row = {
            rank = Widgets.Text(bar, 11, "gray"),
            score = Widgets.Text(bar, 12, "gold"),
            detail = Widgets.Text(bar, 10, "white"),
        }
        row.rank:SetPoint("TOPRIGHT", bar, "TOPLEFT", 30, y)
        row.score:SetPoint("TOPRIGHT", bar, "TOPLEFT", 110, y)
        row.detail:SetPoint("TOPLEFT", bar, "TOPLEFT", 120, y)
        s.rows[i] = row
    end
    s.empty = Widgets.LocalizedText(bar, 10, "gray", "NO_SCORES")
    s.empty:SetPoint("TOP", 0, -196)
    s.empty:SetWidth(SIDEBAR_W - 24)

    s.help = Widgets.Text(bar, 10, "gray")
    s.help:SetPoint("BOTTOM", 0, 14)
    s.help:SetWidth(SIDEBAR_W - 20)
    s.help:SetJustifyH("CENTER")
    self.side = s
end

function Window:UpdateSidebar()
    local game = self.activeGame
    if not game then return end
    local s, info = self.side, game:Sidebar()
    s.name:SetText(L[game.nameKey])
    s.score:SetText(ns.FormatNumber(info.score or 0))
    s.best:SetText(L.BEST:format(ns.FormatNumber(Scores.Best(game.id, info.bucket))))
    s.info:SetText(info.info or "")
    s.help:SetText(L[game.helpKey])
    local list = Scores.List(game.id, info.bucket)
    for i, row in ipairs(s.rows) do
        local entry = list[i]
        if entry then
            row.rank:SetText(i .. ".")
            row.score:SetText(ns.FormatNumber(entry.score))
            row.detail:SetText(game.ScoreDetail and game:ScoreDetail(entry) or "")
        end
        for _, fs in pairs(row) do fs:SetShown(entry ~= nil) end
    end
    s.empty:SetShown(#list == 0)
end

-- Footer -------------------------------------------------------------------------

function Window:CreateFooter()
    local chrome = self.chrome
    local icon = chrome:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\TaxiFrame\\UI-Taxi-Icon-Green")
    icon:SetSize(16, 16)
    icon:SetPoint("BOTTOMLEFT", 10, 7)
    self.flightIcon = icon
    self.flightText = Widgets.Text(chrome, 11, "blue")
    self.flightText:SetPoint("LEFT", icon, "RIGHT", 4, 0)

    local options = Widgets.Button(chrome, 110, 22, "OPTIONS", function() ns.Settings:Open() end)
    options:SetPoint("BOTTOMRIGHT", -8, 5)
    local games = Widgets.Button(chrome, 110, 22, "GAMES", function() self:OpenHub() end)
    games:SetPoint("RIGHT", options, "LEFT", -4, 0)
    self.gamesButton = games
end

-- Hub ------------------------------------------------------------------------------

function Window:CreateHub()
    local hub = CreateFrame("Frame", nil, self.content)
    hub:SetAllPoints()
    hub:SetFrameLevel(self.content:GetFrameLevel() + 5)
    self.hub = hub

    local bg = hub:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(Media.Tex("hub_background"))
    bg:SetTexCoord(0, 1, 0, CONTENT_H / 512)

    local subtitle = Widgets.LocalizedText(hub, 16, "gold", "PICK_GAME")
    subtitle:SetPoint("TOP", 0, -26)

    local columns = math.min(3, #Arcade.order)
    local rowWidth = columns * TILE_W + (columns - 1) * TILE_GAP
    local left = (CONTENT_W - rowWidth) / 2
    self.tiles = {}
    for i, id in ipairs(Arcade.order) do
        local tile = self:CreateTile(hub, Arcade.games[id])
        local column = (i - 1) % 3
        local row = math.floor((i - 1) / 3)
        tile:SetPoint("TOPLEFT", hub, "TOPLEFT", left + column * (TILE_W + TILE_GAP), -70 - row * (TILE_H + TILE_GAP))
        self.tiles[#self.tiles + 1] = tile
    end
end

function Window:CreateTile(parent, game)
    local tile = CreateFrame("Button", nil, parent, "InsetFrameTemplate")
    tile:SetSize(TILE_W, TILE_H)
    tile:RegisterForClicks("LeftButtonUp")

    local art = tile:CreateTexture(nil, "ARTWORK")
    art:SetTexture(Media.Tex(game.tile))
    art:SetTexCoord(0, 1, 0, 0.5)
    art:SetPoint("TOPLEFT", 4, -4)
    art:SetPoint("TOPRIGHT", -4, -4)
    art:SetHeight((TILE_W - 8) / 2)

    local name = Widgets.LocalizedText(tile, 16, "gold", game.nameKey)
    name:SetPoint("TOP", art, "BOTTOM", 0, -8)
    local desc = Widgets.LocalizedText(tile, 11, "white", game.descKey)
    desc:SetPoint("TOP", name, "BOTTOM", 0, -6)
    desc:SetWidth(TILE_W - 18)
    desc:SetJustifyH("CENTER")
    tile.best = Widgets.Text(tile, 11, "gray")
    tile.best:SetPoint("BOTTOM", 0, 40)

    local play = Widgets.Button(tile, 120, 24, "PLAY", function() self:OpenGame(game.id) end)
    play:SetPoint("BOTTOM", 0, 10)

    local highlight = tile:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight2")
    highlight:SetBlendMode("ADD")
    highlight:SetVertexColor(1, 0.8, 0.3, 0.3)
    highlight:SetPoint("TOPLEFT", 3, -3)
    highlight:SetPoint("BOTTOMRIGHT", -3, 3)

    tile:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
        self:OpenGame(game.id)
    end)
    tile.game = game
    if game.DecorateTile then ns.SafeCall("DecorateTile", game.DecorateTile, game, tile, art) end
    return tile
end

function Window:RefreshHub()
    for _, tile in ipairs(self.tiles) do
        local best = tile.game.BestScore and tile.game:BestScore()
        tile.best:SetText(best and best > 0 and L.BEST:format(ns.FormatNumber(best)) or "")
    end
end

function Window:OpenHub()
    if self.activeGame then
        self.activeGame:Leave()
        self.activeGame.container:Hide()
        self.activeGame = nil
    end
    self.hub:Show()
    self.sidebar:Hide()
    self.gamesButton:Hide()
    self:RefreshHub()
end

function Window:OpenGame(id)
    local game = Arcade.games[id]
    if not game then return self:OpenHub() end
    if self.activeGame == game then return end
    if self.activeGame then
        self.activeGame:Leave()
        self.activeGame.container:Hide()
    end
    if not game.container then
        local container = CreateFrame("Frame", nil, self.field)
        container:SetAllPoints()
        game.container = container
        if not ns.SafeCall("Build " .. id, game.Build, game, container) then return end
    end
    self.hub:Hide()
    self.sidebar:Show()
    game.container:Show()
    self.activeGame = game
    self.gamesButton:Show()
    game:Enter()
    self:UpdateSidebar()
end

-- Shows the window and the game chosen for flights.
function Window:OpenForFlight()
    local choice = ns.db.flightGame
    if choice == "off" then return end
    self.frame:Show()
    if Arcade.games[choice] then self:OpenGame(choice) end
end

function Window:OnLanded()
    if self.frame:IsShown() and self.activeGame then self.activeGame:Pause({ landed = true }) end
end

function Window:Toggle()
    self.frame:SetShown(not self.frame:IsShown())
end

function Window:ApplyScale()
    self.frame:SetScale(ns.db.scale)
end

function Window:RestorePosition()
    local f, pos = self.frame, ns.db.position
    f:ClearAllPoints()
    if pos then
        f:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 0, -40)
    end
end

function Window:ApplyLanguage()
    ns.SetLanguage(ns.db.language)
    Media.ApplyLanguageFonts()
    Widgets.RefreshAll()
    for _, id in ipairs(Arcade.order) do
        local game = Arcade.games[id]
        if game.container and game.RefreshTexts then game:RefreshTexts() end
    end
    self:RefreshHub()
    self:UpdateSidebar()
end

function Window:UpdateFlightInfo()
    local dest, seconds, exact, isEstimate = Flight:Status()
    if not dest or not ns.db.flightTime then
        self.flightIcon:Hide()
        self.flightText:SetText("")
        return
    end
    self.flightIcon:Show()
    local timeText = isEstimate and ((exact and "" or "~") .. ns.FormatTime(seconds)) or ns.FormatTime(seconds)
    local label = dest ~= "" and L.FLIGHT_TO:format(dest) or L.IN_FLIGHT
    self.flightText:SetText(label .. "  ·  " .. timeText)
end

function Window:OnUpdate(dt)
    if self.activeGame then self.activeGame:OnUpdate(dt) end
    self.infoTimer = (self.infoTimer or 0) - dt
    if self.infoTimer <= 0 then
        self.infoTimer = 0.25
        self:UpdateFlightInfo()
    end
end
