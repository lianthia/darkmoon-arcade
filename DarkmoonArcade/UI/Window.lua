-- The arcade window, a launcher like the Battle.net app (Figma design): a header with logo, tabs,
-- the achievements bell and close button; the navigation on the left (UI/Nav.lua: discover,
-- favorites, the highlighted games, all games, options); right of it the pages (UI/Hub.lua: discover,
-- favorites, all games; what's new, statistics, options) or the open game.
--
-- On the launcher pages the navigation is wide; on all others it shrinks to its icons and opens
-- over the page under the mouse. Large games (`fullArea`, like Mercenaries) fill the whole area
-- right of it; the minigames keep their playfield plus score sidebar, scaled up to the window's
-- height, and the window narrows around them.

local ADDON, ns = ...

local Media, Widgets, Flight, Scores, Style, L = ns.Media, ns.Widgets, ns.Flight, ns.Scores, ns.Style, ns.L
local C = Style.C

local Arcade = { games = {}, order = {} }
ns.Arcade = Arcade

local Window = {}
ns.Window = Window

-- The window's grid (Figma: 1082 x 676).
local FRAME_W, FRAME_H = 1082, 676
local BORDER, HEADER_H = 2, 54
local TOP = BORDER + HEADER_H
local NAV_W, NAV_COLLAPSED = 220, 62
local INNER_H = FRAME_H - TOP - BORDER
Arcade.NAV_W, Arcade.NAV_COLLAPSED = NAV_W, NAV_COLLAPSED
-- The area right of the collapsed navigation: the pages and the large games.
Arcade.FULL_W, Arcade.FULL_H = FRAME_W - 2 * BORDER - NAV_COLLAPSED, INNER_H

-- Minigames draw into a playfield of this size with the score sidebar to its right.
Arcade.FIELD_W, Arcade.FIELD_H = 432, 462
local SIDEBAR_W, GUTTER = 204, 14
Arcade.SIDEBAR_W, Arcade.GUTTER = SIDEBAR_W, GUTTER
-- Minigames are scaled up to fill the window's height, with at least this margin.
local MINI_SCALE, MINI_MARGIN = 1.25, 16

-- Room the window needs beyond its frame: the flight plate below, a margin all around.
local FLIGHT_EXTRA, SCREEN_MARGIN = 36, 8
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

-- The version as people read it: the packager writes the tag ("v1.4.0"), this gives "1.4.0" (or "dev").
function ns.VersionNumber()
    return (ns.Version():gsub("^v", ""))
end

-- The version with exactly one "v" in front ("v1.4.0"), or "dev" for an unpackaged copy.
function ns.VersionLabel()
    local number = ns.VersionNumber()
    return number == "dev" and number or "v" .. number
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

-- The pages' size (what's new, statistics, options): right of the collapsed navigation.
function Arcade.HomeSize()
    return Arcade.FULL_W, Arcade.FULL_H
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

    local bg = f:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetAllPoints()
    bg:SetColorTexture(unpack(C.window))
    -- A two-unit near-black frame.
    local edges = CreateFrame("Frame", nil, f)
    edges:SetAllPoints()
    edges:SetFrameLevel(f:GetFrameLevel() + 80)
    local function Edge(color, a, b, w, h)
        local t = Style.Line(edges, color, "OVERLAY")
        t:SetPoint(a)
        t:SetPoint(b)
        if w then t:SetWidth(w) else t:SetHeight(h) end
    end
    Edge(C.edge, "TOPLEFT", "BOTTOMLEFT", BORDER)
    Edge(C.edge, "TOPRIGHT", "BOTTOMRIGHT", BORDER)
    Edge(C.edge, "TOPLEFT", "TOPRIGHT", nil, BORDER)
    Edge(C.edge, "BOTTOMLEFT", "BOTTOMRIGHT", nil, BORDER)

    self:CreateHeader()

    -- The launcher pages sit right of the wide navigation, the other pages right of the narrow one.
    local discover = CreateFrame("Frame", nil, f)
    discover:SetPoint("TOPLEFT", BORDER + NAV_W, -TOP)
    discover:SetSize(FRAME_W - 2 * BORDER - NAV_W, INNER_H)
    self.discoverArea = discover
    local pages = CreateFrame("Frame", nil, f)
    pages:SetPoint("TOPLEFT", BORDER + NAV_COLLAPSED, -TOP)
    pages:SetSize(Arcade.FULL_W, Arcade.FULL_H)
    self.pageArea = pages

    -- The open game: a playfield, plus the score sidebar for minigames.
    local content = CreateFrame("Frame", nil, f)
    content:SetFrameLevel(f:GetFrameLevel() + 4)
    self.content = content
    local field = CreateFrame("Frame", nil, content)
    field:SetSize(Arcade.FIELD_W, Arcade.FIELD_H)
    field:SetPoint("TOPLEFT")
    field:SetClipsChildren(true)
    self.field = field
    self:CreateSidebar()
    self:CreateFlightPanel()

    self:CreateHub()
    ns.OptionsView:Create(pages)
    ns.StatsView:Create(pages)
    ns.News:Create(pages)
    ns.Nav:Create(self)

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
        self:UpdateBell()
    end)
    f:SetScript("OnHide", function()
        if self.activeGame then self.activeGame:Pause({}) end
        ns.Bell:Close()
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE)
    end)

    self:OpenHub()
end

-- Header ------------------------------------------------------------------------

local TABS = {
    { id = "home", key = "TAB_GAMES" },
    { id = "news", key = "NEWS_TITLE" },
    { id = "stats", key = "STATISTICS" },
}
local TAB_X, TAB_GAP = 236, 32

function Window:CreateHeader()
    local f = self.frame
    local header = CreateFrame("Frame", nil, f)
    header:SetPoint("TOPLEFT", BORDER, -BORDER)
    header:SetPoint("TOPRIGHT", -BORDER, -BORDER)
    header:SetHeight(HEADER_H)
    header:SetFrameLevel(f:GetFrameLevel() + 40)
    self.header = header

    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() f:StartMoving() end)
    header:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        local point, _, relPoint, x, y = f:GetPoint()
        ns.db.position = { point, relPoint, x, y }
    end)

    local band = header:CreateTexture(nil, "BACKGROUND")
    band:SetAllPoints()
    band:SetColorTexture(unpack(C.surface))
    local rule = Style.Line(header, C.border)
    rule:SetHeight(1)
    rule:SetPoint("BOTTOMLEFT")
    rule:SetPoint("BOTTOMRIGHT")

    local logo = header:CreateTexture(nil, "ARTWORK")
    -- The logo fills 512x172 of its 512x256 texture (tools/import_art.py).
    logo:SetSize(131, 131 * 172 / 512)
    logo:SetPoint("TOPLEFT", 8, -8)
    logo:SetTexture(Media.Tex("logo"))
    logo:SetTexCoord(0, 1, 0, 172 / 256)

    self.tabButtons = {}
    for _, def in ipairs(TABS) do
        local b = CreateFrame("Button", nil, header)
        b:SetHeight(HEADER_H - 1)
        b.label = Style.Text(b, 12, C.muted)
        b.label:SetPoint("LEFT", 0, 0)
        b.line = b:CreateTexture(nil, "OVERLAY")
        b.line:SetColorTexture(unpack(C.gold))
        b.line:SetHeight(2)
        b.line:SetPoint("BOTTOMLEFT")
        b:SetScript("OnEnter", function() b.label:SetTextColor(unpack(C.text)) end)
        b:SetScript("OnLeave", function() self:UpdateTabs() end)
        b:SetScript("OnClick", function()
            PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
            if def.id == "home" then self:OpenHub()
            elseif def.id == "news" then self:OpenNews()
            else self:OpenStats() end
        end)
        self.tabButtons[def.id] = b
    end
    Widgets.OnRefresh(function() self:UpdateTabs() end)

    -- Right: the achievements bell, a divider and the close button.
    local close = CreateFrame("Button", nil, header)
    close:SetSize(38, 38)
    close:SetPoint("RIGHT", -16, 0)
    close.icon = Style.Icon(close, "close_window")
    close.icon:SetPoint("CENTER")
    close:SetScript("OnEnter", function() Style.SetIcon(close.icon, "close_window_hover") end)
    close:SetScript("OnLeave", function() Style.SetIcon(close.icon, "close_window") end)
    close:SetScript("OnClick", function() f:Hide() end)
    local divider = Style.Line(header, C.divider, "ARTWORK")
    divider:SetSize(1, 21)
    divider:SetPoint("CENTER", close, "LEFT", -25, 0)
    ns.Bell:Create(self, header, divider)
end

-- Lays the tabs out from the design's left edge and marks the active one.
function Window:UpdateTabs()
    if not self.tabButtons then return end
    local x = TAB_X
    for _, def in ipairs(TABS) do
        local b = self.tabButtons[def.id]
        b.label:SetText(L[def.key])
        local width = math.ceil(b.label:GetStringWidth() or 40)
        b:SetWidth(width)
        b:ClearAllPoints()
        b:SetPoint("LEFT", self.header, "LEFT", x, 0)
        b.line:SetWidth(width + 5)
        x = x + width + TAB_GAP
        local active = self.tab == def.id
        b.line:SetShown(active)
        b.label:SetTextColor(unpack((active or b:IsMouseOver()) and C.text or C.muted))
    end
end

-- Minigame sidebar --------------------------------------------------------------

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

local SCORE_ROW = 16

local function ScoreRows(bar, top)
    local rows = {}
    for i = 1, SIDEBAR_SCORES do
        local y = top - (i - 1) * SCORE_ROW
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

-- Score, best, achievements and the personal and guild highscores of the open minigame, with its
-- help and achievements at the bottom.
function Window:CreateSidebar()
    local bar = CreateFrame("Frame", nil, self.content)
    bar:SetSize(SIDEBAR_W, Arcade.FIELD_H)
    bar:SetPoint("TOPRIGHT")
    self.sidebar = bar

    local fill = bar:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    fill:SetColorTexture(0, 0, 0, 0.32)
    -- Fine gold edges; the field's belong to the sidebar so they show and hide with it.
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

    Separator(bar, -136)
    SectionTitle(bar, "ACHIEVEMENTS", -146)
    s.achievements = Widgets.Text(bar, 11, "white")
    s.achievements:SetPoint("TOPRIGHT", -14, -147)
    local track = bar:CreateTexture(nil, "ARTWORK")
    track:SetColorTexture(0, 0, 0, 0.5)
    track:SetPoint("TOPLEFT", 14, -166)
    track:SetPoint("TOPRIGHT", -14, -166)
    track:SetHeight(6)
    s.progress = bar:CreateTexture(nil, "ARTWORK", nil, 1)
    s.progress:SetColorTexture(RIM_COLOR[1], RIM_COLOR[2], RIM_COLOR[3], 0.95)
    s.progress:SetPoint("TOPLEFT", track, "TOPLEFT")
    s.progress:SetHeight(6)
    s.progressWidth = SIDEBAR_W - 28

    Separator(bar, -182)
    SectionTitle(bar, "HIGHSCORES", -192)
    s.personal = ScoreRows(bar, -212)
    s.personalEmpty = Widgets.LocalizedText(bar, 10, "gray", "NO_SCORES")
    s.personalEmpty:SetPoint("TOPLEFT", 14, -214)
    s.personalEmpty:SetWidth(SIDEBAR_W - 28)
    s.personalEmpty:SetJustifyH("LEFT")

    Separator(bar, -298)
    SectionTitle(bar, "GUILD_SCORES", -308)
    s.guild = ScoreRows(bar, -328)
    s.guildEmpty = Widgets.Text(bar, 10, "gray")
    s.guildEmpty:SetPoint("TOPLEFT", 14, -330)
    s.guildEmpty:SetWidth(SIDEBAR_W - 28)
    s.guildEmpty:SetJustifyH("LEFT")

    -- The game's help and achievements belong to the game: at the sidebar's foot.
    local half = (SIDEBAR_W - 28 - 6) / 2
    local help = Widgets.Button(bar, half, 24, "HELP", function()
        if self.activeGame then self.activeGame:ShowHelp() end
    end)
    help:SetPoint("BOTTOMLEFT", 14, 12)
    local achievements = Widgets.Button(bar, half, 24, "ACHIEVEMENTS", function()
        if self.activeGame then self.activeGame:ShowAchievements() end
    end)
    achievements:SetPoint("BOTTOMRIGHT", -14, 12)
    self.helpButton, self.achievementsButton = help, achievements

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
    if not game or not self.side or game.fullArea then return end
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

-- Layout --------------------------------------------------------------------------

-- Sizes the window, keeping its center where it was on screen whatever the new scale.
function Window:SetFrameSize(w, h)
    local f = self.frame
    if math.abs(f:GetWidth() - w) < 0.5 and math.abs(f:GetHeight() - h) < 0.5 and self.sizeSet then return end
    local cx, cy = f:GetCenter()
    local oldScale = f:GetScale()
    f:SetSize(w, h)
    self:ApplyScale()
    if cx and self.sizeSet then
        local ratio = oldScale / f:GetScale()
        f:ClearAllPoints()
        f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx * ratio, cy * ratio)
    end
    self.sizeSet = true
end

-- Places the open game: a large game is scaled to fill the area right of the navigation (its
-- playfield has that area's proportions); a minigame (playfield and sidebar) is scaled to the
-- window's height, and the window narrows around it.
function Window:LayoutGame(game)
    local content, field = self.content, self.field
    content:ClearAllPoints()
    if game.fullArea then
        local w, h = game.fieldWidth or Arcade.FULL_W, game.fieldHeight or Arcade.FULL_H
        local scale = math.min(Arcade.FULL_W / w, Arcade.FULL_H / h)
        content:SetScale(scale)
        content:SetSize(w, h)
        content:SetPoint("TOPLEFT", self.frame, "TOPLEFT", (BORDER + NAV_COLLAPSED + (Arcade.FULL_W - w * scale) / 2) / scale,
            -(TOP + (Arcade.FULL_H - h * scale) / 2) / scale)
        field:SetSize(w, h)
        self.sidebar:Hide()
        self:SetFrameSize(FRAME_W, FRAME_H)
        return
    end
    local w, h = game.fieldWidth or Arcade.FIELD_W, game.fieldHeight or Arcade.FIELD_H
    -- Never wider than the launcher: a wide playfield (Darkmoon Deck) gets a smaller scale.
    local contentW = w + GUTTER + SIDEBAR_W
    local scale = math.min(MINI_SCALE, (INNER_H - 2 * MINI_MARGIN) / h, (Arcade.FULL_W - 2 * MINI_MARGIN) / contentW)
    local top = (INNER_H - h * scale) / 2
    local side = math.min(top, (Arcade.FULL_W - contentW * scale) / 2)
    content:SetScale(scale)
    content:SetSize(contentW, h)
    content:SetPoint("TOPLEFT", self.frame, "TOPLEFT", (BORDER + NAV_COLLAPSED + side) / scale, -(TOP + top) / scale)
    field:SetSize(w, h)
    self.sidebar:SetHeight(h)
    self.sidebar:Show()
    self:SetFrameSize(BORDER + NAV_COLLAPSED + 2 * side + contentW * scale + BORDER, FRAME_H)
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

-- Pages ---------------------------------------------------------------------------

-- Which header tab each page belongs to.
local PAGE_TAB = { discover = "home", favorites = "home", all = "home", news = "news", stats = "stats" }
local WIDE_NAV = { discover = true, favorites = true, all = true }

function Window:LeaveGame()
    if self.activeGame then
        self.activeGame:Leave()
        self.activeGame.container:Hide()
        self.activeGame = nil
    end
end

-- Shows one page (discover, favorites, all, news, stats, options) instead of the open game.
function Window:ShowPage(page)
    self:LeaveGame()
    self.content:Hide()
    self:SetFrameSize(FRAME_W, FRAME_H)
    for name, frame in pairs(self.hubPages) do frame:SetShown(name == page) end
    self.discoverArea:SetShown(WIDE_NAV[page] == true)
    if page == "options" then ns.OptionsView:Show() else ns.OptionsView:Hide() end
    if page == "stats" then ns.StatsView:Show() else ns.StatsView:Hide() end
    if page == "news" then ns.News.frame:Show() else ns.News:Hide() end
    self.page, self.tab = page, PAGE_TAB[page]
    ns.Nav:SetWide(WIDE_NAV[page] == true)
    ns.Nav:Refresh()
    ns.Bell:Close()
    self:UpdateTabs()
end

function Window:OpenHub()
    self:ShowPage("discover")
    self:RefreshHub()
end

function Window:OpenFavorites()
    self.frame:Show()
    self:ShowPage("favorites")
    self:RefreshHub()
end

function Window:OpenAllGames()
    self.frame:Show()
    self:ShowPage("all")
    self:RefreshHub()
end

-- The news tab, on a version (default: the newest).
function Window:OpenNews(index)
    self.frame:Show()
    self:ShowPage("news")
    ns.News:Refresh(index)
end

function Window:OpenOptions()
    self.frame:Show()
    self:ShowPage("options")
end

-- The statistics tab, on a game's page when `gameId` is given.
function Window:OpenStats(gameId)
    self.frame:Show()
    self:ShowPage("stats")
    if gameId then ns.StatsView:SelectGame(gameId) end
end

function Window:OpenGame(id)
    local game = Arcade.games[id]
    if not game then return self:OpenHub() end
    if self.activeGame == game then return end
    self:LeaveGame()
    for _, frame in pairs(self.hubPages) do frame:Hide() end
    self.discoverArea:Hide()
    ns.OptionsView:Hide()
    ns.StatsView:Hide()
    ns.News:Hide()
    ns.Bell:Close()
    self:LayoutGame(game)
    self.content:Show()
    if not game.container then
        local container = CreateFrame("Frame", nil, self.field)
        container:SetAllPoints()
        game.container = container
        if not ns.SafeCall("Build " .. id, game.Build, game, container) then return end
    end
    game.container:Show()
    self.activeGame = game
    self.page, self.tab = "game", "home"
    ns.db.lastGame = id
    ns.Nav:SetWide(false)
    ns.Nav:Refresh()
    self:UpdateTabs()
    game:Enter()
    self:UpdateSidebar(true)
end

-- Shows the window with what the player chose for flights: a game, the last one played, the
-- favorites or the main menu.
function Window:OpenForFlight()
    local choice = ns.db.flightGame
    if choice == "off" then return end
    self.frame:Show()
    if choice == "last" then choice = ns.db.lastGame end
    if choice == "favorites" then
        self:OpenFavorites()
    elseif Arcade.games[choice] then
        self:OpenGame(choice)
    end
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
    ns.Nav:Refresh()
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
    fill:SetColorTexture(C.surface[1], C.surface[2], C.surface[3], 0.95)
    local ring = Style.Rounded(panel, panel, 6, C.border, "BORDER", 0, "ring")
    local icon = panel:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\TaxiFrame\\UI-Taxi-Icon-Green")
    icon:SetSize(16, 16)
    icon:SetPoint("LEFT", 12, 0)
    self.flightText = Style.Text(panel, 12, C.text)
    self.flightText:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    self.flightTime = Style.Text(panel, 12, C.gold)
    self.flightTime:SetPoint("LEFT", self.flightText, "RIGHT", 12, 0)
    panel:Hide()
    self.flightPanel = panel
    self.flightRing = ring
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
