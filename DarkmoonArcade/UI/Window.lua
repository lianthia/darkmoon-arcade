-- The arcade window: Blizzard's portrait frame, a hub with one tile per game, and a
-- playfield area that hosts whichever game is active.

local _, ns = ...

local Media, Widgets, Flight, L = ns.Media, ns.Widgets, ns.Flight, ns.L

local Arcade = { games = {}, order = {} }
ns.Arcade = Arcade

local Window = {}
ns.Window = Window

-- Every game draws into a playfield of this size.
Arcade.FIELD_W, Arcade.FIELD_H = 432, 462

local INSET_TOP, INSET_BOTTOM, INSET_LEFT, INSET_RIGHT, INSET_PAD = 60, 30, 4, 6, 3
local FRAME_W = Arcade.FIELD_W + INSET_LEFT + INSET_RIGHT + INSET_PAD * 2
local FRAME_H = Arcade.FIELD_H + INSET_TOP + INSET_BOTTOM + INSET_PAD * 2
local TILE_W, TILE_H = 206, 190

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
    f:SetMovable(true)
    f:EnableMouse(true)
    f:Hide()
    tinsert(UISpecialFrames, "DarkmoonArcadeFrame")
    self.frame = f

    local chrome = CreateFrame("Frame", nil, f, "PortraitFrameTemplateNoCloseButton")
    chrome:SetAllPoints()
    if not pcall(chrome.SetPortraitToAsset, chrome, Media.Tex("portrait")) and chrome.GetPortrait then
        chrome:GetPortrait():SetTexture(Media.Tex("portrait"))
    end
    self.chrome = chrome

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButtonNoScripts")
    close:SetPoint("TOPRIGHT")
    close:SetScript("OnClick", function() f:Hide() end)

    -- The title bar is the drag handle, like on Blizzard's own panels.
    local drag = CreateFrame("Frame", nil, f)
    drag:SetPoint("TOPLEFT", 60, 0)
    drag:SetPoint("TOPRIGHT", -28, 0)
    drag:SetHeight(24)
    drag:EnableMouse(true)
    drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function() f:StartMoving() end)
    drag:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        local point, _, relPoint, x, y = f:GetPoint()
        ns.db.position = { point, relPoint, x, y }
    end)

    local inset = CreateFrame("Frame", nil, f, "InsetFrameTemplate")
    inset:SetPoint("TOPLEFT", INSET_LEFT, -INSET_TOP)
    inset:SetPoint("BOTTOMRIGHT", -INSET_RIGHT, INSET_BOTTOM)

    local field = CreateFrame("Frame", nil, inset)
    field:SetSize(Arcade.FIELD_W, Arcade.FIELD_H)
    field:SetPoint("TOPLEFT", INSET_PAD, -INSET_PAD)
    field:SetClipsChildren(true)
    self.field = field

    self:CreateHud()
    self:CreateFooter()
    self:CreateHub()

    self:ApplyScale()
    self:RestorePosition()

    f:EnableKeyboard(true)
    f:SetScript("OnKeyDown", function(frame, key)
        local game = self.activeGame
        local handled = game and game.OnKey and game:OnKey(key) or false
        if not InCombatLockdown() then frame:SetPropagateKeyboardInput(not handled) end
    end)
    f:SetScript("OnKeyUp", function(_, key)
        local game = self.activeGame
        if game and game.OnKeyUp then game:OnKeyUp(key) end
    end)
    f:SetScript("OnUpdate", function(_, elapsed) self:OnUpdate(math.min(elapsed, 0.05)) end)
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

function Window:CreateHud()
    local f = self.frame
    self.hudLeft = Widgets.Text(f, 12, "white")
    self.hudLeft:SetPoint("LEFT", f, "TOPLEFT", 66, -42)
    self.hudCenter = Widgets.Text(f, 18, "gold")
    self.hudCenter:SetPoint("CENTER", f, "TOP", 0, -42)
    self.hudRight = Widgets.Text(f, 12, "gray")
    self.hudRight:SetPoint("RIGHT", f, "TOPRIGHT", -12, -42)
end

function Window:SetHud(left, center, right)
    self.hudLeft:SetText(left or "")
    self.hudCenter:SetText(center or "")
    self.hudRight:SetText(right or "")
end

function Window:CreateFooter()
    local f = self.frame
    local icon = f:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\TaxiFrame\\UI-Taxi-Icon-Green")
    icon:SetSize(16, 16)
    icon:SetPoint("BOTTOMLEFT", 10, 7)
    self.flightIcon = icon
    self.flightText = Widgets.Text(f, 11, "blue")
    self.flightText:SetPoint("LEFT", icon, "RIGHT", 4, 0)

    local options = Widgets.Button(f, 100, 22, "OPTIONS", function() ns.Settings:Open() end)
    options:SetPoint("BOTTOMRIGHT", -8, 5)
    local games = Widgets.Button(f, 100, 22, "GAMES", function() self:OpenHub() end)
    games:SetPoint("RIGHT", options, "LEFT", -4, 0)
    self.gamesButton = games
end

-- Hub ------------------------------------------------------------------------

function Window:CreateHub()
    local hub = CreateFrame("Frame", nil, self.field)
    hub:SetAllPoints()
    self.hub = hub

    local bg = hub:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(Media.Tex("hub_background"))
    bg:SetTexCoord(0, Arcade.FIELD_W / 512, 0, Arcade.FIELD_H / 512)

    local logo = hub:CreateTexture(nil, "ARTWORK")
    logo:SetTexture(Media.Tex("logo"))
    logo:SetTexCoord(0, 1, 0, 341 / 512)
    logo:SetSize(354, 236)
    logo:SetPoint("TOP", 0, -2)

    local subtitle = Widgets.LocalizedText(hub, 13, "gold", "PICK_GAME")
    subtitle:SetPoint("TOP", logo, "BOTTOM", 0, -2)

    self.tiles = {}
    for i, id in ipairs(Arcade.order) do
        local tile = self:CreateTile(hub, Arcade.games[id])
        local column = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        tile:SetPoint("TOPLEFT", hub, "TOPLEFT", 8 + column * (TILE_W + 4), -258 - row * (TILE_H + 6))
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
    tile.art = art

    local name = Widgets.LocalizedText(tile, 15, "gold", game.nameKey)
    name:SetPoint("TOP", art, "BOTTOM", 0, -6)
    local desc = Widgets.LocalizedText(tile, 10, "white", game.descKey)
    desc:SetPoint("TOP", name, "BOTTOM", 0, -4)
    desc:SetWidth(TILE_W - 16)
    desc:SetJustifyH("CENTER")
    tile.best = Widgets.Text(tile, 10, "gray")
    tile.best:SetPoint("BOTTOM", 0, 8)

    local highlight = tile:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight2")
    highlight:SetBlendMode("ADD")
    highlight:SetVertexColor(1, 0.8, 0.3, 0.35)
    highlight:SetPoint("TOPLEFT", 3, -3)
    highlight:SetPoint("BOTTOMRIGHT", -3, 3)

    tile:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
        self:OpenGame(game.id)
    end)
    tile.game = game
    if game.DecorateTile then game:DecorateTile(tile, art) end
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
    self.gamesButton:Hide()
    self.chrome:SetTitle(L.TITLE)
    self:SetHud()
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
        game:Build(container)
    end
    self.hub:Hide()
    game.container:Show()
    self.activeGame = game
    self.gamesButton:Show()
    self.chrome:SetTitle(L.TITLE .. " – " .. L[game.nameKey])
    game:Enter()
end

-- Shows the window and the game chosen for flights.
function Window:OpenForFlight()
    local choice = ns.db.flightGame
    if choice == "off" then return end
    self.frame:Show()
    if Arcade.games[choice] then self:OpenGame(choice) end
    if self.activeGame and self.activeGame.OnFlightStarted then self.activeGame:OnFlightStarted() end
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
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    end
end

function Window:ApplyLanguage()
    ns.SetLanguage(ns.db.language)
    Media.ApplyLanguageFonts()
    Widgets.RefreshAll()
    if self.activeGame then
        self.chrome:SetTitle(L.TITLE .. " – " .. L[self.activeGame.nameKey])
    else
        self.chrome:SetTitle(L.TITLE)
    end
    for _, id in ipairs(Arcade.order) do
        local game = Arcade.games[id]
        if game.container and game.RefreshTexts then game:RefreshTexts() end
    end
    self:RefreshHub()
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
