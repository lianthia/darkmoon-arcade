-- The arcade window: Blizzard's panel frame with a header (logo and tabs, as in the Battle.net
-- app), the home tabs (main menu in UI/Hub.lua, what's new, statistics, options) at the featured
-- game's size, and a playfield plus sidebar for whichever game is active.

local ADDON, ns = ...

local Media, Widgets, Flight, Scores, L = ns.Media, ns.Widgets, ns.Flight, ns.Scores, ns.L

local Arcade = { games = {}, order = {} }
ns.Arcade = Arcade

local Window = {}
ns.Window = Window

-- Every game draws into a playfield of this size; the sidebar sits to its right.
Arcade.FIELD_W, Arcade.FIELD_H = 432, 462
local SIDEBAR_W, GUTTER = 204, 14
Arcade.SIDEBAR_W, Arcade.GUTTER = SIDEBAR_W, GUTTER
local CONTENT_W = Arcade.FIELD_W + GUTTER + SIDEBAR_W
local CONTENT_H = Arcade.FIELD_H

-- Playfield and sidebar are framed panels on one grid; the footer buttons align with their edges.
-- The home tabs fill the window from edge to edge below the header.
local HEADER_H, INSET_BOTTOM, INSET_SIDE, EDGE = 56, 48, 18, 3
-- A game sits a little below the header, with a narrow margin at the sides.
local GAME_TOP, GAME_SIDE = 12, 12
local FRAME_W = CONTENT_W + INSET_SIDE * 2
local FRAME_H = CONTENT_H + HEADER_H + INSET_BOTTOM
local LOGO_H = 40
local TAB_GAP = 28
-- Room the window needs beyond its frame: the flight plate below, a margin all around.
local FLIGHT_EXTRA, SCREEN_MARGIN = 36, 8

-- Panel templates without a title bar first; the portrait frame is the known-good fallback.
local CHROME_TEMPLATES = { "SimplePanelTemplate", "PortraitFrameTemplateNoCloseButton" }

local function TemplateExists(name)
    return C_XMLUtil and C_XMLUtil.GetTemplateInfo and C_XMLUtil.GetTemplateInfo(name) ~= nil
end
local SIDEBAR_SCORES = 5
local SIDEBAR_INTERVAL = 0.25
local RIM_COLOR = { 0.86, 0.66, 0.3, 0.9 }

-- The packaged version; an unpackaged copy still carries the packager's placeholder.
function ns.Version()
    local version = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version")
        or GetAddOnMetadata and GetAddOnMetadata(ADDON, "Version") or "?"
    if version:find("@") then version = "dev" end
    return version
end

-- Games are listed by `rank`, the most popular first.
function Arcade.RegisterGame(game)
    Arcade.games[game.id] = game
    Arcade.order[#Arcade.order + 1] = game.id
    table.sort(Arcade.order, function(a, b)
        return (Arcade.games[a].rank or 99) < (Arcade.games[b].rank or 99)
    end)
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

    self:CreateHeader()

    -- One continuous surface behind header, content and footer; the panel border draws on top.
    local surface = chrome:CreateTexture(nil, "BACKGROUND", nil, 2)
    -- The panel border is thicker at the top than at the sides.
    surface:SetPoint("TOPLEFT", 2, -4)
    surface:SetPoint("BOTTOMRIGHT", -2, 3)
    surface:SetTexture(Media.Tex("hub_background"))

    local content = CreateFrame("Frame", nil, chrome)
    content:SetSize(CONTENT_W, CONTENT_H)
    content:SetPoint("TOPLEFT", INSET_SIDE, -HEADER_H)
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
    ns.OptionsView:Create(content)
    ns.StatsView:Create(content)
    ns.News:Create(content)

    self:ApplyScale()
    self:RestorePosition()

    self:CreateFader()

    -- A new resolution or UI scale may leave the window too large for the screen.
    local events = CreateFrame("Frame", nil, f)
    events:RegisterEvent("DISPLAY_SIZE_CHANGED")
    events:RegisterEvent("UI_SCALE_CHANGED")
    events:SetScript("OnEvent", function() self:ApplyScale() end)

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

-- Header ------------------------------------------------------------------------

-- The tabs of the home view. While a game is open the header shows the way back and the game's name
-- instead.
local TABS = {
    { id = "home", key = "TAB_HOME" },
    { id = "news", key = "NEWS_TITLE" },
    { id = "stats", key = "STATISTICS" },
    { id = "options", key = "OPTIONS" },
}

function Window:CreateHeader()
    local chrome, f = self.chrome, self.frame
    local header = CreateFrame("Frame", nil, chrome)
    header:SetPoint("TOPLEFT", EDGE, -EDGE)
    header:SetPoint("TOPRIGHT", -EDGE, -EDGE)
    header:SetHeight(HEADER_H - EDGE)
    header:SetFrameLevel(chrome:GetFrameLevel() + 8)
    self.header = header

    local function StartMove() f:StartMoving() end
    local function StopMove()
        f:StopMovingOrSizing()
        local point, _, relPoint, x, y = f:GetPoint()
        ns.db.position = { point, relPoint, x, y }
    end
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", StartMove)
    header:SetScript("OnDragStop", StopMove)

    local band = header:CreateTexture(nil, "BACKGROUND")
    band:SetAllPoints()
    band:SetColorTexture(0, 0, 0, 0.3)
    local rule = header:CreateTexture(nil, "BORDER")
    rule:SetColorTexture(RIM_COLOR[1], RIM_COLOR[2], RIM_COLOR[3], 0.3)
    rule:SetHeight(1)
    rule:SetPoint("BOTTOMLEFT")
    rule:SetPoint("BOTTOMRIGHT")

    local logo = header:CreateTexture(nil, "ARTWORK")
    -- The logo fills 512x172 of its 512x256 texture (tools/import_art.py).
    logo:SetSize(LOGO_H * 512 / 172, LOGO_H)
    logo:SetPoint("LEFT", 14, -6)
    logo:SetTexture(Media.Tex("logo"))
    logo:SetTexCoord(0, 1, 0, 172 / 256)
    self.headerLogo = logo

    self.tabButtons = {}
    for _, def in ipairs(TABS) do
        local b = CreateFrame("Button", nil, header)
        b:SetHeight(HEADER_H - EDGE)
        b.label = Widgets.Text(b, 14, "white")
        b.label:SetPoint("CENTER", 0, -1)
        b.line = b:CreateTexture(nil, "OVERLAY")
        b.line:SetColorTexture(1, 0.82, 0.3, 1)
        b.line:SetHeight(2)
        b.line:SetPoint("BOTTOMLEFT", 0, 0)
        b.line:SetPoint("BOTTOMRIGHT", 0, 0)
        b:SetScript("OnEnter", function() if self.tab ~= def.id then b.label:SetTextColor(1, 1, 1) end end)
        b:SetScript("OnLeave", function() self:UpdateTabs() end)
        b:SetScript("OnClick", function()
            PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
            if def.id == "home" then self:OpenHub()
            elseif def.id == "news" then self:OpenNews()
            elseif def.id == "stats" then self:OpenStats()
            elseif def.id == "options" then self:OpenOptions() end
        end)
        b.def = def
        self.tabButtons[def.id] = b
    end
    -- In a game: "< Main menu", a thin divider and the game's name.
    local back = CreateFrame("Button", nil, header)
    back:SetHeight(HEADER_H - EDGE)
    back.label = Widgets.Text(back, 14, "white")
    back.label:SetPoint("LEFT", 0, -1)
    back.label:SetTextColor(0.72, 0.68, 0.62)
    back:SetScript("OnEnter", function() back.label:SetTextColor(1, 1, 1) end)
    back:SetScript("OnLeave", function() back.label:SetTextColor(0.72, 0.68, 0.62) end)
    back:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
        self:OpenHub()
    end)
    self.backButton = back
    local divider = header:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(RIM_COLOR[1], RIM_COLOR[2], RIM_COLOR[3], 0.35)
    divider:SetSize(1, 22)
    self.headerDivider = divider
    self.gameTitle = Widgets.Text(header, 16, "gold")
    Widgets.OnRefresh(function() self:UpdateTabs() end)

    local close = CreateFrame("Button", nil, header, "UIPanelCloseButtonNoScripts")
    close:SetPoint("RIGHT", -6, 0)
    close:SetFrameLevel(header:GetFrameLevel() + 4)
    close:SetScript("OnClick", function() f:Hide() end)
end

-- Places the tabs after the logo and marks the active one. With a game open: the way back and its name.
function Window:UpdateTabs()
    if not self.tabButtons then return end
    local x = 14 + self.headerLogo:GetWidth() + 26
    local game = self.activeGame
    self.backButton:SetShown(game ~= nil)
    self.headerDivider:SetShown(game ~= nil)
    self.gameTitle:SetShown(game ~= nil)
    if game then
        self.backButton.label:SetText("‹  " .. L.MAIN_MENU)
        self.backButton:SetWidth(math.ceil(self.backButton.label:GetStringWidth() or 100) + 8)
        self.backButton:ClearAllPoints()
        self.backButton:SetPoint("LEFT", self.header, "LEFT", x, 0)
        x = x + self.backButton:GetWidth() + 18
        self.headerDivider:ClearAllPoints()
        self.headerDivider:SetPoint("LEFT", self.header, "LEFT", x, 0)
        self.gameTitle:SetText(L[game.nameKey])
        self.gameTitle:ClearAllPoints()
        self.gameTitle:SetPoint("LEFT", self.header, "LEFT", x + 19, -1)
    end
    for _, def in ipairs(TABS) do
        local b = self.tabButtons[def.id]
        local shown = game == nil
        b:SetShown(shown)
        if shown then
            b.label:SetText(L[def.key])
            local width = math.ceil(b.label:GetStringWidth() or 60) + 8
            b:SetWidth(width)
            b:ClearAllPoints()
            b:SetPoint("LEFT", self.header, "LEFT", x, 0)
            x = x + width + TAB_GAP
            local active = self.tab == def.id
            b.line:SetShown(active)
            if active then b.label:SetTextColor(1, 0.82, 0.3) else b.label:SetTextColor(0.72, 0.68, 0.62) end
        end
    end
end

-- Sidebar ----------------------------------------------------------------------

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
    -- Fine gold edges like the main menu's; the field's belong to the sidebar so they show and
    -- hide with the game view.
    local function Edges(region)
        -- On a frame of their own above the region, so a game's content never covers them.
        local holder = CreateFrame("Frame", nil, bar)
        holder:SetAllPoints(region)
        holder:SetFrameLevel(region:GetFrameLevel() + 60)
        for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
            local t = holder:CreateTexture(nil, "OVERLAY")
            t:SetColorTexture(RIM_COLOR[1], RIM_COLOR[2], RIM_COLOR[3], 0.4)
            if side == "TOP" or side == "BOTTOM" then
                t:SetPoint(side .. "LEFT", region, side .. "LEFT", 0, 0)
                t:SetPoint(side .. "RIGHT", region, side .. "RIGHT", 0, 0)
                t:SetHeight(1)
            else
                t:SetPoint("TOP" .. side, region, "TOP" .. side, 0, 0)
                t:SetPoint("BOTTOM" .. side, region, "BOTTOM" .. side, 0, 0)
                t:SetWidth(1)
            end
        end
    end
    Edges(bar)
    Edges(self.field)

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

    Separator(bar, -316)
    SectionTitle(bar, "GUILD_SCORES", -326)
    s.guild = ScoreRows(bar, -346)
    s.guildEmpty = Widgets.Text(bar, 10, "gray")
    s.guildEmpty:SetPoint("TOPLEFT", 14, -348)
    s.guildEmpty:SetWidth(SIDEBAR_W - 28)
    s.guildEmpty:SetJustifyH("LEFT")

    self.side = s
end

-- Rebuilding the score lists is costly; games ask often, so refreshes run at most every SIDEBAR_INTERVAL.
function Window:UpdateSidebar(now)
    if not now then
        self.sidebarDirty = true
        return
    end
    self.sidebarDirty = false
    self.sidebarTimer = SIDEBAR_INTERVAL
    local game = self.activeGame
    if not game or not self.side then return end
    local s, info = self.side, game:Sidebar()
    s.name:SetText(L[game.nameKey])
    s.score:SetText(ns.FormatNumber(info.score or 0))
    s.best:SetText(L.BEST:format(ns.FormatNumber(Scores.Best(game.id, info.bucket))))
    s.info:SetText(info.info or "")
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
    self:CreateFlightPanel()

    -- Games: help and achievements on the right; the header's tabs lead everywhere else.
    local achievements = Widgets.Button(chrome, 124, 26, "ACHIEVEMENTS", function()
        if self.activeGame then self.activeGame:ShowAchievements() end
    end)
    achievements:SetPoint("BOTTOMRIGHT", -GAME_SIDE, 12)
    self.achievementsButton = achievements
    local help = Widgets.Button(chrome, 96, 26, "HELP", function()
        if self.activeGame then self.activeGame:ShowHelp() end
    end)
    help:SetPoint("RIGHT", achievements, "LEFT", -8, 0)
    self.helpButton = help
end

-- The home tabs' size: exactly the featured game's window, so the window keeps its size when the
-- game opens; the game's margins, gap and footer become room for the home tabs.
function Arcade.HomeSize()
    local featured = Arcade.Featured()
    local w = (featured.fieldWidth or Arcade.FIELD_W) + GUTTER + SIDEBAR_W + 2 * (GAME_SIDE - EDGE)
    local h = (featured.fieldHeight or Arcade.FIELD_H) + GAME_TOP + INSET_BOTTOM - EDGE
    return w, h
end

-- Games may ask for a larger playfield (`fieldWidth`, `fieldHeight`); the home tabs use the home
-- size from edge to edge. The window grows around its center and shrinks its scale whenever it
-- would no longer fit on the screen.
function Window:SetFieldSize(width, height, home)
    width, height = width or Arcade.FIELD_W, height or Arcade.FIELD_H
    local key = (home and "home" or "game") .. width .. "x" .. height
    if self.sizeKey == key then return end
    local contentW, contentH, side, top, bottom
    if home then
        contentW, contentH = Arcade.HomeSize()
        side, top, bottom = EDGE, HEADER_H, EDGE
    else
        contentW, contentH = width + GUTTER + SIDEBAR_W, height
        side, top, bottom = GAME_SIDE, HEADER_H + GAME_TOP, INSET_BOTTOM
    end
    local f = self.frame
    local cx, cy = f:GetCenter()
    local oldScale = f:GetScale()
    f:SetSize(contentW + side * 2, top + contentH + bottom)
    self.content:SetSize(contentW, contentH)
    self.content:ClearAllPoints()
    self.content:SetPoint("TOPLEFT", side, -top)
    self.field:SetSize(width, height)
    self.sidebar:SetHeight(height)
    self.sizeKey = key
    self:ApplyScale()
    if cx and self.fieldSizeSet then
        -- Keep the center where it was on screen, whatever the new scale.
        local ratio = oldScale / f:GetScale()
        f:ClearAllPoints()
        f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx * ratio, cy * ratio)
    end
    self.fieldSizeSet = true
end

-- The window never grows past the screen: the chosen scale gives way where it would.
function Window:FitScale()
    local f = self.frame
    local screenW, screenH = UIParent:GetWidth(), UIParent:GetHeight()
    if not screenW or screenW <= 0 or not screenH or screenH <= 0 then return 1 end
    local needW = f:GetWidth() + SCREEN_MARGIN * 2
    local needH = f:GetHeight() + FLIGHT_EXTRA + SCREEN_MARGIN * 2
    return math.min(screenW / needW, screenH / needH)
end

function Window:LeaveGame()
    if self.activeGame then
        self.activeGame:Leave()
        self.activeGame.container:Hide()
        self.activeGame = nil
    end
end

-- Switches to one of the home tabs: home (main menu), news, stats or options.
function Window:ShowHome(tab)
    self:LeaveGame()
    local featured = self.featured
    self:SetFieldSize(featured.fieldWidth, featured.fieldHeight, true)
    self.hub:SetShown(tab == "home")
    if tab == "options" then ns.OptionsView:Show() else ns.OptionsView:Hide() end
    if tab == "stats" then ns.StatsView:Show() else ns.StatsView:Hide() end
    if tab == "news" then ns.News.frame:Show() else ns.News:Hide() end
    self.sidebar:Hide()
    self.achievementsButton:Hide()
    self.helpButton:Hide()
    self.tab = tab
    self:UpdateTabs()
end

function Window:OpenHub()
    self:ShowHome("home")
    self:RefreshHub()
end

-- The news tab, on a version (default: the newest).
function Window:OpenNews(index)
    self.frame:Show()
    self:ShowHome("news")
    ns.News:Refresh(index)
end

function Window:OpenOptions()
    self.frame:Show()
    self:ShowHome("options")
end

function Window:OpenStats()
    self.frame:Show()
    self:ShowHome("stats")
end

function Window:OpenGame(id)
    local game = Arcade.games[id]
    if not game then return self:OpenHub() end
    if self.activeGame == game then return end
    if self.activeGame then
        self.activeGame:Leave()
        self.activeGame.container:Hide()
    end
    self:SetFieldSize(game.fieldWidth, game.fieldHeight)
    if not game.container then
        local container = CreateFrame("Frame", nil, self.field)
        container:SetAllPoints()
        game.container = container
        if not ns.SafeCall("Build " .. id, game.Build, game, container) then return end
    end
    self.hub:Hide()
    ns.OptionsView:Hide()
    ns.StatsView:Hide()
    ns.News:Hide()
    self.sidebar:Show()
    game.container:Show()
    self.activeGame = game
    self.achievementsButton:Show()
    self.helpButton:Show()
    self.tab = "game"
    self:UpdateTabs()
    game:Enter()
    self:UpdateSidebar(true)
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
    self.frame:SetScale(math.min(ns.db.scale, self:FitScale()))
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

-- See-through while moving: the arcade's windows fade to the chosen visibility while the character
-- walks or rides, so they can stay open. Under the mouse and on flights they stay fully visible.
local FADE_SPEED = 4

function Window:CreateFader()
    local fader = CreateFrame("Frame")
    fader:RegisterEvent("PLAYER_STARTED_MOVING")
    fader:RegisterEvent("PLAYER_STOPPED_MOVING")
    fader:SetScript("OnEvent", function(_, event) self.moving = event == "PLAYER_STARTED_MOVING" end)
    fader:SetScript("OnUpdate", function(_, elapsed) self:UpdateFade(elapsed) end)
    self.moving = IsPlayerMoving and IsPlayerMoving() or false
    self.fader = fader
end

function Window:FadeTarget(frame)
    local db = ns.db
    if not (db and db.fadeMoving and self.moving) then return 1 end
    if frame:IsMouseOver() or (UnitOnTaxi and UnitOnTaxi("player")) then return 1 end
    return math.max(0.05, math.min(1, db.fadeAlpha or 0.4))
end

function Window:UpdateFade(elapsed)
    local frames = { self.frame }
    for _, frame in pairs(frames) do
        if frame and frame:IsShown() then
            local target, alpha = self:FadeTarget(frame), frame:GetAlpha()
            if alpha ~= target then
                local step = elapsed * FADE_SPEED
                frame:SetAlpha(target > alpha and math.min(target, alpha + step) or math.max(target, alpha - step))
            end
        end
    end
end

-- A small plate below the window, shown only during flights.
function Window:CreateFlightPanel()
    local panel = CreateFrame("Frame", nil, self.frame)
    panel:SetHeight(30)
    panel:SetPoint("TOP", self.frame, "BOTTOM", 0, -6)
    local fill = panel:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    fill:SetColorTexture(0.05, 0.02, 0.08, 0.92)
    Widgets.Rim(panel, panel)
    local icon = panel:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\TaxiFrame\\UI-Taxi-Icon-Green")
    icon:SetSize(16, 16)
    icon:SetPoint("LEFT", 12, 0)
    self.flightText = Widgets.Text(panel, 12, "blue")
    self.flightText:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    self.flightTime = Widgets.Text(panel, 12, "gold")
    self.flightTime:SetPoint("LEFT", self.flightText, "RIGHT", 12, 0)
    panel:Hide()
    self.flightPanel = panel
end

function Window:UpdateFlightInfo()
    local dest, seconds, exact, isEstimate = Flight:Status()
    if not dest or not ns.db.flightTime then
        self.flightPanel:Hide()
        return
    end
    self.flightText:SetText(dest ~= "" and L.FLIGHT_TO:format(dest) or L.IN_FLIGHT)
    if isEstimate then
        self.flightTime:SetText(L.FLIGHT_LEFT:format((exact and "" or "~") .. ns.FormatTime(seconds)))
    else
        self.flightTime:SetText(L.FLIGHT_MEASURING)
    end
    self.flightPanel:SetWidth(12 + 16 + 6 + self.flightText:GetStringWidth() + 12 + self.flightTime:GetStringWidth() + 16)
    self.flightPanel:Show()
end

function Window:OnUpdate(dt)
    local game = self.activeGame
    if game then
        game:OnUpdate(dt)
        -- Only time with the game in front counts, not menus or pause screens.
        if not (game.overlay and game.overlay.current) then ns.Stats.AddTime(game.id, dt, Flight.current ~= nil) end
    end
    local flight = Flight.current
    if flight and not flight.counted then
        flight.counted = true
        ns.Stats.AddFlight()
    end
    if self.sidebarDirty then
        self.sidebarTimer = (self.sidebarTimer or 0) - dt
        if self.sidebarTimer <= 0 then self:UpdateSidebar(true) end
    end
    self.infoTimer = (self.infoTimer or 0) - dt
    if self.infoTimer <= 0 then
        self.infoTimer = 0.25
        self:UpdateFlightInfo()
    end
end
