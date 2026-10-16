-- The launcher's navigation on the left (Figma design): discover and favorites, the highlighted
-- games, all games, and options with the version at its foot. Wide on the launcher pages; on all
-- others only its icons show, and it opens over the page while the mouse is on it.
--
-- An open game that is not among the highlighted ones gets a place of its own below them while it
-- is open, so the navigation always shows where the player is.

local _, ns = ...

local Style, Media, L = ns.Style, ns.Media, ns.L
local C = Style.C
local Arcade = ns.Arcade

local Nav = {}
ns.Nav = Nav

-- The games the navigation always lists, in this order.
Nav.HIGHLIGHTED = { "mercenaries", "spellbounce", "darkmoondeck", "murlocblast", "jewelsofuldum" }

local WIDE, NARROW = Arcade.NAV_W, Arcade.NAV_COLLAPSED
local PAD, ITEM_H, STEP = 8, 44, 54
local ITEM_WIDE, ITEM_NARROW = WIDE - 1 - 2 * PAD, NARROW - 2 * PAD - 1
local BORDER, TOP = 2, 56
-- How long the mouse rests on the narrow navigation before it opens, and the opening's speed.
local OPEN_DELAY, OPEN_SPEED = 0.12, 12

-- One entry: an icon (discover, favorites, all games) or a game's picture, and its name.
local function Item(nav, opts)
    local b = CreateFrame("Button", nil, nav.frame)
    b:SetHeight(ITEM_H)
    b.bg = Style.Rounded(b, b, 8, C.item)
    if opts.game then
        local thumb = b:CreateTexture(nil, "ARTWORK")
        thumb:SetSize(28, 28)
        thumb:SetPoint("LEFT", 8, 0)
        Style.SetThumb(thumb, opts.game)
        b.thumb = thumb
        local holder = CreateFrame("Frame", nil, b)
        holder:SetAllPoints(thumb)
        b.corners = Style.CutCorners(holder, thumb, 8, C.item, nil, "ARTWORK")
        b.ring = Style.Rounded(holder, thumb, 8, C.surface, "OVERLAY", 7, "ring")
    else
        b.icon = Style.Icon(b, opts.icon, 28)
        b.icon:SetPoint("LEFT", 8, 0)
    end
    b.label = Style.Text(b, 11, C.muted)
    b.label:SetPoint("LEFT", 46, 0)
    b.opts, b.hover = opts, false
    b:SetScript("OnEnter", function() b.hover = true; nav:Paint(b) end)
    b:SetScript("OnLeave", function() b.hover = false; nav:Paint(b) end)
    b:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
        opts.onClick()
    end)
    return b
end

function Nav:Create(window)
    self.window = window
    local frame = CreateFrame("Frame", nil, window.frame)
    frame:SetPoint("TOPLEFT", BORDER, -TOP)
    frame:SetSize(WIDE, 618)
    -- Far above the pages and games (which raise their own frames), so it opens over them.
    frame:SetFrameLevel(window.frame:GetFrameLevel() + 500)
    frame:EnableMouse(true)
    frame:SetClipsChildren(true)
    self.frame = frame
    local fill = frame:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    fill:SetColorTexture(unpack(C.surface))
    local rule = Style.Line(frame, C.border, "BORDER")
    rule:SetWidth(1)
    rule:SetPoint("TOPRIGHT")
    rule:SetPoint("BOTTOMRIGHT")

    self.discover = Item(self, { icon = "discover", key = "NAV_DISCOVER", page = "discover",
        onClick = function() window:OpenHub() end })
    self.favorites = Item(self, { icon = "favorites", key = "NAV_FAVORITES", page = "favorites",
        onClick = function() window:OpenFavorites() end })
    self.gamesLabel = Style.LocalizedText(frame, 10, C.dim, "NAV_GAMES")
    self.games = {}
    for _, id in ipairs(Nav.HIGHLIGHTED) do
        if Arcade.games[id] then
            self.games[#self.games + 1] = Item(self, { game = id, onClick = function() window:OpenGame(id) end })
        end
    end
    -- The open game when it is not highlighted: one item per game, shown while it is open.
    self.extra = {}
    for _, id in ipairs(Arcade.order) do
        local highlighted = false
        for _, other in ipairs(Nav.HIGHLIGHTED) do highlighted = highlighted or other == id end
        if not highlighted then
            local item = Item(self, { game = id, onClick = function() window:OpenGame(id) end })
            item:Hide()
            self.extra[id] = item
        end
    end
    self.extraRule = Style.Line(frame, C.border, "ARTWORK")
    self.extraRule:SetHeight(1)
    self.all = Item(self, { icon = "more_games", key = "NAV_ALL_GAMES", page = "all",
        onClick = function() window:OpenAllGames() end })

    -- Options and the version at the foot.
    local options = CreateFrame("Button", nil, frame)
    options:SetHeight(16)
    options.hover = false
    options.icon = Style.Icon(options, "settings", 16)
    options.icon:SetPoint("LEFT")
    options.label = Style.LocalizedText(options, 11, C.muted, "OPTIONS")
    options.label:SetPoint("LEFT", 28, 0)
    options:SetScript("OnEnter", function() options.hover = true; self:PaintOptions() end)
    options:SetScript("OnLeave", function() options.hover = false; self:PaintOptions() end)
    options:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
        window:OpenOptions()
    end)
    self.options = options
    self.footRule = Style.Line(frame, C.border, "ARTWORK")
    self.footRule:SetHeight(1)
    self.version = Style.Text(frame, 10, C.dim)
    self.version:SetJustifyH("CENTER")
    self.version:SetText("v" .. ns.Version())

    self.width, self.wide = WIDE, true
    self.hoverTime = 0
    frame:SetScript("OnUpdate", function(_, elapsed) self:OnUpdate(elapsed) end)
    ns.Widgets.OnRefresh(function() self:Refresh() end)
end

-- Wide on the launcher pages, narrow elsewhere.
function Nav:SetWide(wide)
    self.wide = wide
    self:SetWidth(wide and WIDE or NARROW)
end

function Nav:SetWidth(width)
    self.width = width
    self.frame:SetWidth(width)
    self:Layout()
end

-- While narrow, the navigation opens over the page when the mouse rests on it, and closes again
-- when the mouse leaves.
function Nav:OnUpdate(elapsed)
    if self.wide then return end
    local over = self.frame:IsMouseOver()
    self.hoverTime = over and (self.hoverTime + elapsed) or 0
    local target = (over and self.hoverTime >= OPEN_DELAY) and WIDE or NARROW
    if self.width ~= target then
        local step = (WIDE - NARROW) * OPEN_SPEED * elapsed
        local width = target > self.width and math.min(target, self.width + step) or math.max(target, self.width - step)
        self:SetWidth(width)
    end
end

-- Places the entries from the top; labels show once the navigation is wide enough for them.
function Nav:Layout()
    local open = self.width >= WIDE - 1
    local itemW = math.max(ITEM_NARROW, self.width - 1 - 2 * PAD)
    local y = -PAD
    local function Place(item)
        item:ClearAllPoints()
        item:SetPoint("TOPLEFT", PAD, y)
        item:SetWidth(itemW)
        item.label:SetShown(open)
        y = y - STEP
    end
    Place(self.discover)
    Place(self.favorites)
    self.gamesLabel:ClearAllPoints()
    self.gamesLabel:SetPoint("TOPLEFT", PAD, y - 8)
    y = y - 30
    for _, item in ipairs(self.games) do Place(item) end
    local extra = self.openExtra
    self.extraRule:SetShown(extra ~= nil)
    for _, item in pairs(self.extra) do item:SetShown(item == extra) end
    if extra then
        self.extraRule:ClearAllPoints()
        self.extraRule:SetPoint("TOPLEFT", PAD + 4, y + 4)
        self.extraRule:SetWidth(itemW - 8)
        y = y - 2
        Place(extra)
    end
    Place(self.all)

    local o = self.options
    o:ClearAllPoints()
    o.label:SetShown(open)
    if open then
        o:SetPoint("BOTTOMLEFT", PAD + 16, 45)
        o:SetWidth(28 + (o.label:GetStringWidth() or 40))
    else
        o:SetPoint("BOTTOMLEFT", PAD + 14.5, 45)
        o:SetWidth(16)
    end
    local footX, footW = open and (PAD + 16) or (PAD + 8), open and (itemW - 32) or 29
    self.footRule:ClearAllPoints()
    self.footRule:SetPoint("BOTTOMLEFT", footX, 34)
    self.footRule:SetWidth(footW)
    self.version:ClearAllPoints()
    self.version:SetPoint("BOTTOMLEFT", footX, 12)
    self.version:SetWidth(footW)
end

-- The state of one entry: active (gold, darker plate), under the mouse (white) or at rest.
function Nav:Paint(b)
    local window = self.window
    local active
    if b.opts.game then
        active = window.page == "game" and window.activeGame and window.activeGame.id == b.opts.game
    else
        active = window.page == b.opts.page
    end
    local plate = active and C.itemActive or (b.hover and C.itemHover or C.item)
    b.bg:SetColor(plate)
    b.label:SetTextColor(unpack(active and C.gold or (b.hover and C.text or C.muted)))
    if b.opts.game then
        b.corners:SetColor(plate)
        b.ring:SetColor(active and C.gold or (b.hover and C.text or C.surface))
    else
        Style.SetIcon(b.icon, b.opts.icon .. (active and "_active" or "") .. (b.hover and "_hover" or ""), 28)
    end
end

function Nav:PaintOptions()
    local o = self.options
    local active = self.window.page == "options"
    Style.SetIcon(o.icon, "settings" .. (active and "_active" or "") .. (o.hover and "_hover" or ""), 16)
    o.label:SetTextColor(unpack(active and C.gold or (o.hover and C.text or C.muted)))
end

function Nav:Refresh()
    if not self.frame then return end
    local window = self.window
    local game = window.page == "game" and window.activeGame
    self.openExtra = game and self.extra[game.id] or nil
    for _, item in ipairs({ self.discover, self.favorites, self.all }) do item.label:SetText(L[item.opts.key]) end
    for _, item in ipairs(self.games) do item.label:SetText(L[Arcade.games[item.opts.game].nameKey]) end
    for _, item in pairs(self.extra) do item.label:SetText(L[Arcade.games[item.opts.game].nameKey]) end
    for _, item in ipairs({ self.discover, self.favorites, self.all }) do self:Paint(item) end
    for _, item in ipairs(self.games) do self:Paint(item) end
    for _, item in pairs(self.extra) do self:Paint(item) end
    self:PaintOptions()
    self:Layout()
end
