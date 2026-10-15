-- The launcher pages (Figma design): "discover" with the spotlight game, its progress and the
-- recently updated games; "favorites" with the games marked with a star; "all games".
--
-- Every game has one card, moved to whichever page shows it: its picture (the game's own tile and
-- decorations), genre, name, a two-line tagline and the best score, with a star to mark it as a
-- favorite.

local _, ns = ...

local Media, Widgets, Style, L = ns.Media, ns.Widgets, ns.Style, ns.L
local C = Style.C
local Arcade, Window = ns.Arcade, ns.Window

local PAD, GAP = 16, 16
local SPOT_H, METRICS_H = 252, 79
local COLUMNS = 5
local CARD_H, PREVIEW_H = 187.66, 76.43
-- Card pictures are the games' 300x150 tiles, scaled down.
local TILE_W = 300

-- The spotlight game: the first one that asks for it, otherwise the first in the list.
function Arcade.Featured()
    for _, id in ipairs(Arcade.order) do
        if Arcade.games[id].featured then return Arcade.games[id] end
    end
    return Arcade.games[Arcade.order[1]]
end

-- "1.10.0" after "1.9.2": versions compared part by part.
local function Newer(a, b)
    local pa, pb = {}, {}
    for n in (a or "0"):gmatch("%d+") do pa[#pa + 1] = tonumber(n) end
    for n in (b or "0"):gmatch("%d+") do pb[#pb + 1] = tonumber(n) end
    for i = 1, math.max(#pa, #pb) do
        if (pa[i] or 0) ~= (pb[i] or 0) then return (pa[i] or 0) > (pb[i] or 0) end
    end
    return false
end

-- The games for "explore": all but the spotlight game, the most recently updated first.
function Arcade.RecentlyUpdated()
    local featured = Arcade.Featured()
    local list = {}
    for _, id in ipairs(Arcade.order) do
        if Arcade.games[id] ~= featured then list[#list + 1] = Arcade.games[id] end
    end
    table.sort(list, function(a, b)
        if a.updated ~= b.updated then return Newer(a.updated, b.updated) end
        return (a.rank or 99) < (b.rank or 99)
    end)
    return list
end

function Arcade.IsFavorite(id)
    return ns.db.favorites[id] == true
end

-- Buttons -------------------------------------------------------------------------

-- A button on a rounded plate: the gold call to action or the quiet secondary one.
local function ActionButton(parent, primary, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(38)
    b.plate = Style.Rounded(b, b, 4.75, primary and C.gold or C.secondary)
    local x = 19
    if primary then
        b.icon = Style.Icon(b, "play")
        b.icon:SetPoint("LEFT", 19 + 2.4, 0)
        x = 19 + 14.25 + 7.9
    end
    b.label = Style.Text(b, 12, primary and C.ink or C.text)
    b.label:SetPoint("LEFT", x, 0)
    b.textX = x
    b:SetScript("OnEnter", function()
        b.plate:SetColor(primary and C.goldHover or C.secondaryHover)
        if b.icon then Style.SetIcon(b.icon, "play_hover") end
    end)
    b:SetScript("OnLeave", function()
        b.plate:SetColor(primary and C.gold or C.secondary)
        if b.icon then Style.SetIcon(b.icon, "play") end
    end)
    b:SetScript("OnClick", onClick)
    return b
end

local function SetButtonText(b, text)
    b.label:SetText(text)
    b:SetWidth(math.ceil(b.textX + (b.label:GetStringWidth() or 60) + 19))
end

-- The star that marks a game as a favorite: filled for favorites, an outline otherwise.
function Window:CreateFavoriteStar(parent, game, size)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size, size)
    b.icon = Style.Icon(b, "favorite", size)
    b.icon:SetPoint("CENTER")
    b.game, b.hover = game, false
    b:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        ns.db.favorites[game.id] = not Arcade.IsFavorite(game.id) or nil
        self:RefreshHub()
        if b:IsMouseOver() then b:GetScript("OnEnter")(b) end
    end)
    b:SetScript("OnEnter", function()
        b.hover = true
        self:PaintStar(b)
        GameTooltip:SetOwner(b, "ANCHOR_LEFT")
        GameTooltip:SetText(L[game.nameKey], 1, 1, 1)
        GameTooltip:AddLine(Arcade.IsFavorite(game.id) and L.HUB_FAVORITE_ON or L.HUB_FAVORITE_OFF, 0.64, 0.64, 0.68, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function()
        b.hover = false
        self:PaintStar(b)
        GameTooltip:Hide()
    end)
    self.stars = self.stars or {}
    self.stars[#self.stars + 1] = b
    return b
end

function Window:PaintStar(b)
    local on = Arcade.IsFavorite(b.game.id)
    Style.SetIcon(b.icon, "favorite" .. (on and "_active" or "") .. (b.hover and "_hover" or ""), b:GetWidth())
end

-- A heading with a quiet count beside it, and optionally a gold link on the right.
local function Heading(parent, key, y)
    local h = {}
    h.title = Style.LocalizedText(parent, 16, C.text, key)
    h.title:SetPoint("TOPLEFT", PAD, y)
    h.note = Style.Text(parent, 10, C.dim)
    h.note:SetPoint("BOTTOMLEFT", h.title, "BOTTOMRIGHT", 9, 1)
    return h
end

-- Cards -------------------------------------------------------------------------

function Window:CreateCard(game, w)
    local card = CreateFrame("Button", nil, self.discoverArea)
    card:SetSize(w, CARD_H)
    card:RegisterForClicks("LeftButtonUp")
    card.game = game
    Style.Rounded(card, card, 6.18, C.surface)

    -- The picture: the game's tile with its decorations, or the key art where the game has one.
    local preview = CreateFrame("Frame", nil, card)
    preview:SetPoint("TOPLEFT")
    preview:SetSize(w, PREVIEW_H)
    preview:SetClipsChildren(true)
    local spot = game.spotlight
    if spot and spot.card then
        local holder = CreateFrame("Frame", nil, preview)
        holder:SetAllPoints()
        local art = holder:CreateTexture(nil, "ARTWORK")
        art:SetAllPoints()
        art:SetTexture(Media.Tex(spot.art))
        art:SetTexCoord(unpack(spot.card))
    else
        local scale = w / TILE_W
        local tile = CreateFrame("Frame", nil, preview)
        tile:SetSize(TILE_W, TILE_W / 2)
        tile:SetScale(scale)
        tile:SetPoint("TOPLEFT")
        local art = tile:CreateTexture(nil, "ARTWORK")
        art:SetAllPoints()
        art:SetTexture(Media.Tex(game.tile))
        if game.DecorateTile then ns.SafeCall("DecorateTile", game.DecorateTile, game, tile, art) end
    end
    -- Above the picture (and any model in it): round corners, the hover ring and the star.
    local top = CreateFrame("Frame", nil, card)
    top:SetAllPoints()
    top:SetFrameLevel(card:GetFrameLevel() + 20)
    Style.CutCorners(top, preview, 6.18, C.window, { "TOPLEFT", "TOPRIGHT" })
    card.ring = Style.Rounded(top, card, 6.18, C.text, "OVERLAY", 6, "ring")
    card.ring:SetShown(false)
    local star = self:CreateFavoriteStar(top, game, 20)
    star:SetPoint("TOPRIGHT", -8.4, -8)
    star:SetFrameLevel(top:GetFrameLevel() + 2)

    local x = 10.8
    card.genre = Style.Text(card, 8, C.dim)
    card.genre:SetPoint("TOPLEFT", x, -(PREVIEW_H + 10.8))
    card.name = Style.Text(card, 11, C.text)
    card.name:SetPoint("TOPLEFT", x, -(PREVIEW_H + 27))
    card.name:SetWidth(w - 2 * x)
    card.desc = Style.Text(card, 10, C.muted)
    card.desc:SetPoint("TOPLEFT", x, -(PREVIEW_H + 46.2))
    card.desc:SetWidth(w - 2 * x)
    card.desc:SetWordWrap(true)
    card.desc:SetSpacing(3)
    if card.desc.SetMaxLines then card.desc:SetMaxLines(2) end
    card.best = Style.Text(card, 9, C.muted)
    card.best:SetPoint("TOPLEFT", x, -(PREVIEW_H + 89.4))
    card.go = Style.Icon(card, "go_to")
    card.go:SetPoint("TOPRIGHT", -x, -(PREVIEW_H + 89.5))

    card:SetScript("OnEnter", function()
        card.ring:SetShown(true)
        Style.SetIcon(card.go, "go_to_hover")
    end)
    card:SetScript("OnLeave", function()
        card.ring:SetShown(false)
        Style.SetIcon(card.go, "go_to")
    end)
    card:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
        self:OpenGame(game.id)
    end)
    Widgets.OnRefresh(function()
        card.genre:SetText(game.genreKey and L[game.genreKey]:upper() or "")
        card.name:SetText(L[game.nameKey])
        card.desc:SetText(L[game.taglineKey or game.descKey])
    end)
    return card
end

-- Lays `games` out as a grid of cards on `page`, from `top` down.
function Window:PlaceCards(page, games, top)
    for _, card in pairs(self.cards) do
        if card:GetParent() == page then card:Hide() end
    end
    for i, game in ipairs(games) do
        local card = self.cards[game.id]
        local col, row = (i - 1) % COLUMNS, math.floor((i - 1) / COLUMNS)
        card:SetParent(page)
        card:SetFrameLevel(page:GetFrameLevel() + 2)
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", PAD + col * (self.cardW + GAP), top - row * (CARD_H + GAP))
        card:Show()
    end
end

-- Pages ---------------------------------------------------------------------------

function Window:CreateHub()
    local area = self.discoverArea
    local areaW = area:GetWidth()
    local innerW = areaW - 2 * PAD
    self.cardW = (innerW - (COLUMNS - 1) * GAP) / COLUMNS
    self.featured = Arcade.Featured()
    self.hubPages = {}

    local function Page(name)
        local page = CreateFrame("Frame", nil, area)
        page:SetAllPoints()
        page:Hide()
        self.hubPages[name] = page
        return page
    end

    self.cards = {}
    for _, id in ipairs(Arcade.order) do
        local card = self:CreateCard(Arcade.games[id], self.cardW)
        card:Hide()
        self.cards[id] = card
    end

    self:CreateDiscover(Page("discover"), innerW)

    -- Favorites: the starred games, or a hint where to find the star.
    local favorites = Page("favorites")
    self.favoritesHeading = Heading(favorites, "NAV_FAVORITES", -24)
    local empty = CreateFrame("Frame", nil, favorites)
    empty:SetSize(innerW, 120)
    empty:SetPoint("TOP", 0, -170)
    local emptyIcon = Style.Icon(empty, "favorites_active", 28)
    emptyIcon:SetPoint("TOP")
    local emptyTitle = Style.LocalizedText(empty, 14, C.text, "HUB_NO_FAVORITES")
    emptyTitle:SetPoint("TOP", emptyIcon, "BOTTOM", 0, -12)
    local emptyHint = Style.LocalizedText(empty, 11, C.muted, "HUB_NO_FAVORITES_HINT")
    emptyHint:SetPoint("TOP", emptyTitle, "BOTTOM", 0, -8)
    emptyHint:SetWidth(innerW - 120)
    emptyHint:SetJustifyH("CENTER")
    emptyHint:SetWordWrap(true)
    self.favoritesEmpty = empty

    local all = Page("all")
    self.allHeading = Heading(all, "NAV_ALL_GAMES", -24)
end

function Window:CreateDiscover(page, innerW)
    local game = self.featured
    local spot = game.spotlight or {}

    -- The spotlight: the game's picture on the right, fading into the plate behind the text.
    local card = CreateFrame("Frame", nil, page)
    card:SetSize(innerW, SPOT_H)
    card:SetPoint("TOPLEFT", PAD, -PAD)
    card:SetClipsChildren(true)
    Style.Rounded(card, card, 8, C.surface)
    if spot.art then
        local art = card:CreateTexture(nil, "BORDER")
        art:SetPoint("TOPLEFT", innerW - 413, 4)
        art:SetSize(417, 258.33)
        art:SetTexture(Media.Tex(spot.art))
        art:SetTexCoord(unpack(spot.banner))
    end
    -- Plain to half the width, then the picture shows through more and more.
    local x1, x2 = innerW * 0.5124, innerW * 0.74
    local solid = card:CreateTexture(nil, "ARTWORK")
    solid:SetPoint("TOPLEFT")
    solid:SetPoint("BOTTOMLEFT")
    solid:SetWidth(x1)
    solid:SetColorTexture(unpack(C.surface))
    local s = C.surface
    local fadeA = card:CreateTexture(nil, "ARTWORK")
    fadeA:SetPoint("TOPLEFT", x1, 0)
    fadeA:SetPoint("BOTTOMLEFT", x1, 0)
    fadeA:SetWidth(x2 - x1)
    Style.Gradient(fadeA, { s[1], s[2], s[3], 1 }, { s[1], s[2], s[3], 0.31 })
    local fadeB = card:CreateTexture(nil, "ARTWORK")
    fadeB:SetPoint("TOPLEFT", x2, 0)
    fadeB:SetPoint("BOTTOMRIGHT")
    Style.Gradient(fadeB, { s[1], s[2], s[3], 0.31 }, { s[1], s[2], s[3], 0.7 })
    local top = CreateFrame("Frame", nil, card)
    top:SetAllPoints()
    top:SetFrameLevel(card:GetFrameLevel() + 10)
    Style.CutCorners(top, card, 8, C.window)

    local tag = Style.LocalizedText(top, 10, C.gold, "HUB_SPOTLIGHT")
    tag:SetPoint("TOPLEFT", 24, -24)
    local dot = top:CreateTexture(nil, "ARTWORK")
    dot:SetTexture(Media.Tex("dot"))
    dot:SetVertexColor(unpack(C.dim))
    dot:SetSize(2.4, 2.4)
    dot:SetPoint("LEFT", tag, "RIGHT", 9.5, 0)
    local genre = Style.Text(top, 10, C.muted)
    genre:SetPoint("LEFT", dot, "RIGHT", 9.5, 0)
    local title = Style.LocalizedText(top, 44, C.text, game.nameKey)
    title:SetPoint("TOPLEFT", 24, -48.7)
    title:SetWidth(380)
    local desc = Style.LocalizedText(top, 12, C.body, game.descKey)
    desc:SetPoint("TOPLEFT", 24, -108.3)
    -- Wider than the design's 348: the game's font runs wider than the design's.
    desc:SetWidth(400)
    desc:SetWordWrap(true)
    desc:SetSpacing(5)
    local ready = top:CreateTexture(nil, "ARTWORK")
    ready:SetTexture(Media.Tex("dot"))
    ready:SetVertexColor(unpack(C.ready))
    ready:SetSize(4, 4)
    ready:SetPoint("TOPLEFT", 24, -163)
    self.spotStatus = Style.Text(top, 10, C.text)
    self.spotStatus:SetPoint("LEFT", ready, "RIGHT", 6.3, 0)
    self.spotStatus:SetWidth(innerW * 0.5 - 40)
    self.spotPlay = ActionButton(top, true, function() self:PlayFeatured() end)
    self.spotPlay:SetPoint("TOPLEFT", 24, -190)
    self.spotDetails = ActionButton(top, false, function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
        self:OpenStats(game.id)
    end)
    self.spotDetails:SetPoint("LEFT", self.spotPlay, "RIGHT", 9.5, 0)
    local star = self:CreateFavoriteStar(top, game, 28)
    star:SetPoint("TOPRIGHT", -24, -24)
    Widgets.OnRefresh(function()
        genre:SetText(game.genreKey and L[game.genreKey] or "")
        SetButtonText(self.spotDetails, L.HUB_DETAILS)
    end)

    -- The player's progress in four figures with bars.
    local metrics = CreateFrame("Frame", nil, page)
    metrics:SetSize(innerW, METRICS_H)
    metrics:SetPoint("TOPLEFT", PAD, -(PAD + SPOT_H + 8))
    Style.Rounded(metrics, metrics, 8, C.surface)
    local colW = innerW / 4
    self.metrics = {}
    for i = 1, 4 do
        local m = {}
        local left = (i - 1) * colW + 24
        local width = colW - 48
        m.value = Style.Text(metrics, 24, C.text)
        m.value:SetPoint("TOPLEFT", left, -18)
        m.label = Style.Text(metrics, 11, C.muted)
        m.label:SetPoint("TOPRIGHT", metrics, "TOPLEFT", left + width, -30)
        m.label:SetJustifyH("RIGHT")
        local track = Style.Line(metrics, C.border, "ARTWORK")
        track:SetPoint("TOPLEFT", left, -59)
        track:SetSize(width, 2)
        m.bar = metrics:CreateTexture(nil, "ARTWORK", nil, 1)
        m.bar:SetColorTexture(unpack(C.gold))
        m.bar:SetPoint("TOPLEFT", track, "TOPLEFT")
        m.bar:SetHeight(2)
        m.width = width
        self.metrics[i] = m
    end

    -- The most recently updated games.
    local y = -(PAD + SPOT_H + 8 + METRICS_H + 16 + 8)
    self.exploreHeading = Heading(page, "HUB_EXPLORE", y)
    local link = CreateFrame("Button", nil, page)
    link:SetSize(120, 14)
    link:SetPoint("TOPRIGHT", -PAD, y - 3)
    link.arrow = Style.Icon(link, "go_to")
    link.arrow:SetRotation(-math.pi / 4)
    link.arrow:SetPoint("RIGHT")
    link.text = Style.LocalizedText(link, 10, C.gold, "HUB_VIEW_ALL")
    link.text:SetPoint("RIGHT", link.arrow, "LEFT", -6, 0)
    link:SetScript("OnEnter", function()
        link.text:SetTextColor(unpack(C.goldHover))
        Style.SetIcon(link.arrow, "go_to_hover")
    end)
    link:SetScript("OnLeave", function()
        link.text:SetTextColor(unpack(C.gold))
        Style.SetIcon(link.arrow, "go_to")
    end)
    link:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
        self:OpenAllGames()
    end)
    self.exploreTop = y - 27
end

function Window:PlayFeatured()
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
    self:OpenGame(self.featured.id)
end

function Window:RefreshHub()
    if not self.hubPages then return end
    for _, star in ipairs(self.stars or {}) do self:PaintStar(star) end
    for _, card in pairs(self.cards) do
        local best = card.game.BestScore and card.game:BestScore()
        card.best:SetText(best and best > 0 and L.HUB_BEST:format(ns.FormatNumber(best)) or "")
    end

    -- The spotlight game's progress and status.
    local game = self.featured
    local info = game.HubInfo and select(2, ns.SafeCall("HubInfo", game.HubInfo, game)) or {}
    for i, m in ipairs(self.metrics) do
        local stat = info.stats and info.stats[i]
        m.value:SetShown(stat ~= nil)
        m.label:SetShown(stat ~= nil)
        if stat then
            m.value:SetText(stat.value)
            m.label:SetText(stat.label)
            local share = math.max(0, math.min(1, stat.share or 0))
            m.bar:SetWidth(math.max(1, m.width * share))
            m.bar:SetShown(share > 0)
        else
            m.bar:Hide()
        end
    end
    self.spotStatus:SetText(info.status or "")
    SetButtonText(self.spotPlay, info.resume and L.HUB_CONTINUE or L.HUB_PLAY_GAME:format(L[game.nameKey]))

    -- Whichever launcher page is open gets the cards.
    local page = self.page
    if page == "discover" then
        local recent = Arcade.RecentlyUpdated()
        local shown = {}
        for i = 1, math.min(COLUMNS, #recent) do shown[i] = recent[i] end
        self.exploreHeading.note:SetText(L.HUB_MORE_WAYS:format(#recent))
        self:PlaceCards(self.hubPages.discover, shown, self.exploreTop)
    elseif page == "favorites" then
        local list = {}
        for _, id in ipairs(Arcade.order) do
            if Arcade.IsFavorite(id) then list[#list + 1] = Arcade.games[id] end
        end
        self.favoritesHeading.note:SetText(#list > 0 and L.HUB_GAME_COUNT:format(#list) or "")
        self.favoritesEmpty:SetShown(#list == 0)
        self:PlaceCards(self.hubPages.favorites, list, -51)
    elseif page == "all" then
        local list = {}
        for _, id in ipairs(Arcade.order) do list[#list + 1] = Arcade.games[id] end
        self.allHeading.note:SetText(L.HUB_GAME_COUNT:format(#list))
        self:PlaceCards(self.hubPages.all, list, -51)
    end
end
