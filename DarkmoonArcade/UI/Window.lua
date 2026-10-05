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
local SIDEBAR_W, GUTTER = 204, 14
local CONTENT_W = Arcade.FIELD_W + GUTTER + SIDEBAR_W
local CONTENT_H = Arcade.FIELD_H

-- Playfield and sidebar are framed panels on one grid; the footer buttons align with their edges.
local INSET_TOP, INSET_BOTTOM, INSET_SIDE = 58, 48, 18
local FRAME_W = CONTENT_W + INSET_SIDE * 2
local FRAME_H = CONTENT_H + INSET_TOP + INSET_BOTTOM
local LOGO_W, LOGO_H = 150, 97
-- Half of the logo sits inside the frame, the content starts just below it.
local LOGO_OVERLAP = 48
local TILE_W, TILE_H, TILE_GAP, TILE_COLUMNS = 300, 150, 20, 2

-- Panel templates without a title bar first; the portrait frame is the known-good fallback.
local CHROME_TEMPLATES = { "SimplePanelTemplate", "PortraitFrameTemplateNoCloseButton" }

local function TemplateExists(name)
    return C_XMLUtil and C_XMLUtil.GetTemplateInfo and C_XMLUtil.GetTemplateInfo(name) ~= nil
end
local SIDEBAR_SCORES = 3
local RIM_COLOR = { 0.86, 0.66, 0.3, 0.9 }

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
    f:SetClampRectInsets(0, 0, LOGO_H - LOGO_OVERLAP, 0)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:Hide()
    tinsert(UISpecialFrames, "DarkmoonArcadeFrame")
    self.frame = f

    -- Content is parented to the chrome so it always draws above the chrome's background.
    local template = CHROME_TEMPLATES[#CHROME_TEMPLATES]
    for _, name in ipairs(CHROME_TEMPLATES) do
        if TemplateExists(name) then
            template = name
            break
        end
    end
    local chrome = CreateFrame("Frame", nil, f, template)
    chrome:SetAllPoints()
    if template:find("^Portrait") then
        if ButtonFrameTemplate_HidePortrait then pcall(ButtonFrameTemplate_HidePortrait, chrome) end
        if chrome.SetTitle then chrome:SetTitle("") end
    end
    -- The templates bring their own inner inset and title streaks; the arcade draws its own surface.
    for _, key in ipairs({ "Inset", "TopTileStreaks", "Bg" }) do
        local part = chrome[key]
        if type(part) == "table" and part.Hide then part:Hide() end
    end
    self.chrome = chrome
    ns.Debug("chrome", template)
    local parts = {}
    for key, value in pairs(chrome) do
        if type(value) == "table" and value.GetObjectType then parts[#parts + 1] = key end
    end
    table.sort(parts)
    ns.Debug("chromeParts", table.concat(parts, ","))

    local close = CreateFrame("Button", nil, chrome, "UIPanelCloseButtonNoScripts")
    close:SetPoint("TOPRIGHT", -2, -2)
    close:SetScript("OnClick", function() f:Hide() end)

    local function StartMove() f:StartMoving() end
    local function StopMove()
        f:StopMovingOrSizing()
        local point, _, relPoint, x, y = f:GetPoint()
        ns.db.position = { point, relPoint, x, y }
    end

    local dragArea = CreateFrame("Frame", nil, chrome)
    dragArea:SetPoint("TOPLEFT", 4, 0)
    dragArea:SetPoint("TOPRIGHT", -30, 0)
    dragArea:SetHeight(INSET_TOP + 4)
    dragArea:EnableMouse(true)
    dragArea:RegisterForDrag("LeftButton")
    dragArea:SetScript("OnDragStart", StartMove)
    dragArea:SetScript("OnDragStop", StopMove)

    -- The logo crowns the frame; its own high frame level keeps it above the panel border.
    local logoFrame = CreateFrame("Frame", nil, f)
    logoFrame:SetSize(LOGO_W, LOGO_H)
    logoFrame:SetPoint("BOTTOM", f, "TOP", 0, -LOGO_OVERLAP)
    logoFrame:SetFrameLevel(f:GetFrameLevel() + 1000)
    logoFrame:EnableMouse(true)
    logoFrame:RegisterForDrag("LeftButton")
    logoFrame:SetScript("OnDragStart", StartMove)
    logoFrame:SetScript("OnDragStop", StopMove)
    local logo = logoFrame:CreateTexture(nil, "ARTWORK")
    logo:SetAllPoints()
    logo:SetTexture(Media.Tex("logo"))
    logo:SetTexCoord(0, 1, 0, 330 / 512)

    -- One continuous surface behind header, content and footer; the panel border draws on top.
    local surface = chrome:CreateTexture(nil, "BACKGROUND", nil, 2)
    surface:SetPoint("TOPLEFT", 4, -4)
    surface:SetPoint("BOTTOMRIGHT", -4, 4)
    surface:SetTexture(Media.Tex("hub_background"))

    local content = CreateFrame("Frame", nil, chrome)
    content:SetSize(CONTENT_W, CONTENT_H)
    content:SetPoint("TOPLEFT", INSET_SIDE, -INSET_TOP)
    content:SetFrameLevel(chrome:GetFrameLevel() + 4)
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

-- Thin gold rim with a dark outline just outside `region`.
local function Rim(parent, region)
    local function Line(r, g, b, a, offset, thickness)
        for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
            local t = parent:CreateTexture(nil, "OVERLAY")
            t:SetColorTexture(r, g, b, a)
            if side == "TOP" or side == "BOTTOM" then
                t:SetPoint(side .. "LEFT", region, side .. "LEFT", -offset, side == "TOP" and offset or -offset)
                t:SetPoint(side .. "RIGHT", region, side .. "RIGHT", offset, side == "TOP" and offset or -offset)
                t:SetHeight(thickness)
            else
                t:SetPoint("TOP" .. side, region, "TOP" .. side, side == "LEFT" and -offset or offset, offset)
                t:SetPoint("BOTTOM" .. side, region, "BOTTOM" .. side, side == "LEFT" and -offset or offset, -offset)
                t:SetWidth(thickness)
            end
        end
    end
    Line(0, 0, 0, 0.85, 3, 1)
    Line(RIM_COLOR[1], RIM_COLOR[2], RIM_COLOR[3], RIM_COLOR[4], 2, 2)
end

local function Separator(bar, y)
    local line = bar:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(RIM_COLOR[1], RIM_COLOR[2], RIM_COLOR[3], 0.25)
    line:SetPoint("TOPLEFT", 14, y)
    line:SetPoint("TOPRIGHT", -14, y)
    line:SetHeight(1)
end

local function SectionTitle(bar, key, y)
    local fs = Widgets.LocalizedText(bar, 12, "gold", key)
    fs:SetPoint("TOPLEFT", 14, y)
    return fs
end

local function ScoreRows(bar, top)
    local rows = {}
    for i = 1, SIDEBAR_SCORES do
        local y = top - (i - 1) * 17
        local row = {
            rank = Widgets.Text(bar, 11, "gray"),
            label = Widgets.Text(bar, 11, "white"),
            score = Widgets.Text(bar, 12, "gold"),
        }
        row.rank:SetPoint("TOPRIGHT", bar, "TOPLEFT", 30, y)
        row.label:SetPoint("TOPLEFT", bar, "TOPLEFT", 36, y)
        row.label:SetWidth(96)
        row.label:SetJustifyH("LEFT")
        row.label:SetWordWrap(false)
        row.score:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -14, y)
        rows[i] = row
    end
    return rows
end

local function FillRows(rows, entries, labelFn)
    for i, row in ipairs(rows) do
        local entry = entries[i]
        if entry then
            row.rank:SetText(i .. ".")
            row.label:SetText(labelFn(entry))
            row.score:SetText(ns.FormatNumber(entry.score))
        end
        for _, fs in pairs(row) do fs:SetShown(entry ~= nil) end
    end
end

function Window:CreateSidebar()
    local bar = CreateFrame("Frame", nil, self.content)
    bar:SetSize(SIDEBAR_W, CONTENT_H)
    bar:SetPoint("TOPRIGHT")
    self.sidebar = bar

    local fill = bar:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    fill:SetColorTexture(0, 0, 0, 0.32)
    Rim(bar, bar)
    -- Owned by the sidebar so it shows and hides with the game view.
    Rim(bar, self.field)

    local s = {}
    s.name = Widgets.Text(bar, 16, "gold")
    s.name:SetPoint("TOP", 0, -14)
    s.scoreLabel = Widgets.LocalizedText(bar, 10, "gray", "SCORE")
    s.scoreLabel:SetPoint("TOP", 0, -42)
    s.score = Widgets.Text(bar, 26, "gold")
    s.score:SetPoint("TOP", 0, -56)
    s.best = Widgets.Text(bar, 11, "white")
    s.best:SetPoint("TOP", 0, -88)
    s.info = Widgets.Text(bar, 11, "blue")
    s.info:SetPoint("TOP", 0, -106)
    s.info:SetWidth(SIDEBAR_W - 24)

    Separator(bar, -142)
    SectionTitle(bar, "ACHIEVEMENTS", -152)
    s.achievements = Widgets.Text(bar, 11, "white")
    s.achievements:SetPoint("TOPRIGHT", -14, -153)
    local track = bar:CreateTexture(nil, "ARTWORK")
    track:SetColorTexture(0, 0, 0, 0.5)
    track:SetPoint("TOPLEFT", 14, -172)
    track:SetPoint("TOPRIGHT", -14, -172)
    track:SetHeight(6)
    s.progress = bar:CreateTexture(nil, "ARTWORK", nil, 1)
    s.progress:SetColorTexture(RIM_COLOR[1], RIM_COLOR[2], RIM_COLOR[3], 0.95)
    s.progress:SetPoint("TOPLEFT", track, "TOPLEFT")
    s.progress:SetHeight(6)
    s.progressWidth = SIDEBAR_W - 28

    Separator(bar, -190)
    SectionTitle(bar, "HIGHSCORES", -200)
    s.personal = ScoreRows(bar, -220)
    s.personalEmpty = Widgets.LocalizedText(bar, 10, "gray", "NO_SCORES")
    s.personalEmpty:SetPoint("TOPLEFT", 14, -222)
    s.personalEmpty:SetWidth(SIDEBAR_W - 28)
    s.personalEmpty:SetJustifyH("LEFT")

    Separator(bar, -278)
    SectionTitle(bar, "GUILD_SCORES", -288)
    s.guild = ScoreRows(bar, -308)
    s.guildEmpty = Widgets.Text(bar, 10, "gray")
    s.guildEmpty:SetPoint("TOPLEFT", 14, -310)
    s.guildEmpty:SetWidth(SIDEBAR_W - 28)
    s.guildEmpty:SetJustifyH("LEFT")

    Separator(bar, -366)
    s.help = Widgets.Text(bar, 10, "gray")
    s.help:SetPoint("TOPLEFT", 14, -378)
    s.help:SetWidth(SIDEBAR_W - 28)
    s.help:SetJustifyH("LEFT")
    self.side = s
end

function Window:UpdateSidebar()
    local game = self.activeGame
    if not game or not self.side then return end
    local s, info = self.side, game:Sidebar()
    s.name:SetText(L[game.nameKey])
    s.score:SetText(ns.FormatNumber(info.score or 0))
    s.best:SetText(L.BEST:format(ns.FormatNumber(Scores.Best(game.id, info.bucket))))
    s.info:SetText(info.info or "")
    s.help:SetText((L[game.helpKey]:gsub("%s+·%s+", "\n")))
    local done, total = ns.Achievements.Count(game.id)
    s.achievements:SetText(("%d / %d"):format(done, total))
    s.progress:SetWidth(math.max(1, s.progressWidth * (total > 0 and done / total or 0)))
    s.progress:SetShown(done > 0)

    local list = Scores.List(game.id, info.bucket)
    FillRows(s.personal, list, function(entry)
        return game.ScoreDetail and game:ScoreDetail(entry) or ""
    end)
    s.personalEmpty:SetShown(#list == 0)

    local guildList = IsInGuild() and ns.Guild.Top(game.id, info.bucket, SIDEBAR_SCORES) or {}
    FillRows(s.guild, guildList, function(entry)
        return entry.own and ("|cffffd100" .. entry.name .. "|r") or entry.name
    end)
    s.guildEmpty:SetText(not IsInGuild() and L.NO_GUILD or (#guildList == 0 and L.NO_GUILD_SCORES or ""))
end

-- Footer -------------------------------------------------------------------------

function Window:CreateFooter()
    local chrome = self.chrome
    self.flightText = Widgets.Text(chrome, 12, "blue")
    self.flightText:SetPoint("BOTTOM", 8, 19)
    local icon = chrome:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\TaxiFrame\\UI-Taxi-Icon-Green")
    icon:SetSize(16, 16)
    icon:SetPoint("RIGHT", self.flightText, "LEFT", -6, 0)
    self.flightIcon = icon

    -- Hub: options on the right. Games: main menu on the left, achievements on the right.
    local options = Widgets.Button(chrome, 124, 26, "OPTIONS", function() ns.Settings:Open() end)
    options:SetPoint("BOTTOMRIGHT", -INSET_SIDE, 12)
    self.optionsButton = options
    local achievements = Widgets.Button(chrome, 124, 26, "ACHIEVEMENTS", function()
        if self.activeGame then self.activeGame:ShowAchievements() end
    end)
    achievements:SetPoint("BOTTOMRIGHT", -INSET_SIDE, 12)
    self.achievementsButton = achievements
    local mainMenu = Widgets.Button(chrome, 124, 26, "MAIN_MENU", function() self:OpenHub() end)
    mainMenu:SetPoint("BOTTOMLEFT", INSET_SIDE, 12)
    self.gamesButton = mainMenu
end

-- Hub ------------------------------------------------------------------------------

function Window:CreateHub()
    local hub = CreateFrame("Frame", nil, self.content)
    hub:SetAllPoints()
    hub:SetFrameLevel(self.content:GetFrameLevel() + 5)
    self.hub = hub

    -- Title, cards and flight hint form one block, centered in the hub.
    local columns = math.min(TILE_COLUMNS, #Arcade.order)
    local rows = math.ceil(#Arcade.order / TILE_COLUMNS)
    local rowWidth = columns * TILE_W + (columns - 1) * TILE_GAP
    local gridHeight = rows * TILE_H + (rows - 1) * TILE_GAP
    local blockHeight = 44 + gridHeight + 40
    local left = (CONTENT_W - rowWidth) / 2
    local blockTop = math.max(24, (CONTENT_H - blockHeight) / 2)
    local top = blockTop + 44

    local subtitle = Widgets.LocalizedText(hub, 18, "gold", "PICK_GAME")
    subtitle:SetPoint("TOP", 0, -blockTop)

    self.hubHint = Widgets.Text(hub, 11, "gray")
    self.hubHint:SetPoint("TOP", 0, -(top + gridHeight + 18))
    self.tiles = {}
    for i, id in ipairs(Arcade.order) do
        local tile = self:CreateTile(hub, Arcade.games[id])
        local column = (i - 1) % TILE_COLUMNS
        local row = math.floor((i - 1) / TILE_COLUMNS)
        tile:SetPoint("TOPLEFT", hub, "TOPLEFT", left + column * (TILE_W + TILE_GAP), -top - row * (TILE_H + TILE_GAP))
        self.tiles[#self.tiles + 1] = tile
    end
end

-- A game card: artwork with rounded corners and a gold rim; details fade in on hover.
function Window:CreateTile(parent, game)
    local tile = CreateFrame("Button", nil, parent)
    tile:SetSize(TILE_W, TILE_H)
    tile:RegisterForClicks("LeftButtonUp")

    local mask = tile:CreateMaskTexture()
    mask:SetTexture(Media.Tex("card_mask"), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints()

    local art = tile:CreateTexture(nil, "ARTWORK", nil, 0)
    art:SetAllPoints()
    art:SetTexture(Media.Tex(game.tile))
    art:AddMaskTexture(mask)

    local shade = tile:CreateTexture(nil, "ARTWORK", nil, 1)
    shade:SetAllPoints()
    shade:SetTexture(Media.Tex("card_shade"))
    shade:AddMaskTexture(mask)

    local name = Widgets.LocalizedText(tile, 18, "gold", game.nameKey)
    name:SetPoint("BOTTOMLEFT", 14, 12)
    tile.best = Widgets.Text(tile, 11, "white")
    tile.best:SetPoint("TOPRIGHT", -14, -12)

    local frameArt = tile:CreateTexture(nil, "OVERLAY")
    frameArt:SetAllPoints()
    frameArt:SetTexture(Media.Tex("card_frame"))

    -- Details sit on their own frame so they draw above decorative 3D models.
    local details = CreateFrame("Frame", nil, tile)
    details:SetAllPoints()
    details:SetFrameLevel(tile:GetFrameLevel() + 10)
    details:SetAlpha(0)
    local veil = details:CreateTexture(nil, "BACKGROUND")
    veil:SetAllPoints()
    veil:SetTexture(Media.Tex("card_mask"))
    veil:SetVertexColor(0.03, 0.01, 0.06, 0.8)
    local title = Widgets.LocalizedText(details, 18, "gold", game.nameKey)
    title:SetPoint("TOP", 0, -18)
    local desc = Widgets.LocalizedText(details, 12, "white", game.descKey)
    desc:SetPoint("TOP", title, "BOTTOM", 0, -10)
    desc:SetWidth(TILE_W - 40)
    desc:SetJustifyH("CENTER")
    local play = Widgets.Button(details, 140, 26, "PLAY", function() self:OpenGame(game.id) end)
    play:SetPoint("BOTTOM", 0, 14)
    local rim = details:CreateTexture(nil, "OVERLAY")
    rim:SetAllPoints()
    rim:SetTexture(Media.Tex("card_glow"))
    rim:SetBlendMode("ADD")

    -- Hover by mouse position, so moving onto the play button keeps the details visible.
    tile:SetScript("OnUpdate", function(_, elapsed)
        local target = tile:IsMouseOver() and 1 or 0
        local alpha = details:GetAlpha()
        if alpha ~= target then
            local step = elapsed * 6
            details:SetAlpha(target > alpha and math.min(target, alpha + step) or math.max(target, alpha - step))
        end
    end)
    tile:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
        self:OpenGame(game.id)
    end)
    tile.game = game
    if game.DecorateTile then ns.SafeCall("DecorateTile", game.DecorateTile, game, tile, art) end
    return tile
end

function Window:RefreshHub()
    local choice = ns.db.flightGame
    local target = choice == "off" and L.FLIGHT_OFF or choice == "hub" and L.FLIGHT_HUB
        or (Arcade.games[choice] and L[Arcade.games[choice].nameKey]) or L.FLIGHT_OFF
    self.hubHint:SetText(L.HUB_FLIGHT_HINT:format(target))
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
    self.achievementsButton:Hide()
    self.optionsButton:Show()
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
    self.achievementsButton:Show()
    self.optionsButton:Hide()
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
