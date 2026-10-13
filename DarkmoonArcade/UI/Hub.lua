-- The main menu (the "home" tab): the featured game (the newest highlight, today Mercenaries) on a
-- large stage with its painting, its heroes, the player's progress and the latest news; the other
-- games in a quiet list beside it. A star on every game picks the one that opens on flights.

local _, ns = ...

local Media, Widgets, L = ns.Media, ns.Widgets, ns.L
local Arcade, Window = ns.Arcade, ns.Window

local LIST_W, COLUMN_GAP, SIDE_PAD = 344, 14, 14
local BANNER_H, PANEL_GAP = 340, 10
-- Under the stage: the play column on the left, the news lines on the right.
local PLAY_COLUMN, NEWS_LINES, NEWS_LINE_H = 300, 4, 29
local ROW_GAP, LIST_TOP = 9, 34
local THUMB_W, CARD_W = 136, 300
local GOLD = { 1, 0.82, 0.3 }

-- The featured game: the first one that asks for it, otherwise the first in the list.
function Arcade.Featured()
    for _, id in ipairs(Arcade.order) do
        if Arcade.games[id].featured then return Arcade.games[id] end
    end
    return Arcade.games[Arcade.order[1]]
end

-- A vertical gradient where the client has one; a plain colour otherwise.
local function Gradient(tex, top, bottom)
    tex:SetColorTexture(1, 1, 1, 1)
    local ok = CreateColor and pcall(tex.SetGradient, tex, "VERTICAL", CreateColor(unpack(bottom)), CreateColor(unpack(top)))
    if not ok then tex:SetColorTexture(bottom[1], bottom[2], bottom[3], (top[4] + bottom[4]) / 2) end
end

-- Hairlines round a frame: a faint gold edge, a little brighter along the top.
local function Hairlines(f, alpha)
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local t = f:CreateTexture(nil, "BORDER")
        local a = side == "TOP" and alpha * 1.6 or alpha
        t:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], a)
        if side == "TOP" or side == "BOTTOM" then
            t:SetPoint(side .. "LEFT")
            t:SetPoint(side .. "RIGHT")
            t:SetHeight(1)
        else
            t:SetPoint("TOP" .. side)
            t:SetPoint("BOTTOM" .. side)
            t:SetWidth(1)
        end
    end
end

-- A dark glass panel with hairline edges.
local function Glass(parent, alpha)
    local f = CreateFrame("Frame", nil, parent)
    f.fill = f:CreateTexture(nil, "BACKGROUND")
    f.fill:SetAllPoints()
    Gradient(f.fill, { 0.09, 0.04, 0.13, alpha }, { 0.03, 0.01, 0.05, alpha + 0.15 })
    Hairlines(f, 0.22)
    return f
end

local function HasAtlas(name)
    return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) ~= nil
end

-- The call to action: the client's large gold-framed red button (as in the Trading Post), in three
-- slices so it takes any width. Without those atlases, a plain gold gradient.
local BUTTON_ATLAS = { left = { "128-goldredbutton-left", 114 }, center = { "_128-goldredbutton-center", 64 },
    right = { "128-goldredbutton-right", 292 } }

local function PlayButton(parent, w, h, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w, h)
    local k = h / 128
    local slices = {}
    if HasAtlas(BUTTON_ATLAS.left[1]) then
        local left = b:CreateTexture(nil, "BACKGROUND")
        left:SetPoint("TOPLEFT")
        left:SetPoint("BOTTOMLEFT")
        left:SetWidth(BUTTON_ATLAS.left[2] * k)
        local right = b:CreateTexture(nil, "BACKGROUND")
        right:SetPoint("TOPRIGHT")
        right:SetPoint("BOTTOMRIGHT")
        right:SetWidth(BUTTON_ATLAS.right[2] * k)
        local center = b:CreateTexture(nil, "BACKGROUND")
        center:SetPoint("TOPLEFT", left, "TOPRIGHT")
        center:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
        slices = { left = left, center = center, right = right }
        local function Look(suffix)
            for part, tex in pairs(slices) do tex:SetAtlas(BUTTON_ATLAS[part][1] .. suffix) end
        end
        b.Look = Look
        Look("")
        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetAtlas("128-goldredbutton-highlight")
        hl:SetBlendMode("ADD")
    else
        local fill = b:CreateTexture(nil, "BACKGROUND")
        fill:SetAllPoints()
        Gradient(fill, { 0.62, 0.1, 0.08, 1 }, { 0.36, 0.04, 0.03, 1 })
        Widgets.Rim(b, b)
        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 0.8, 0.5, 0.15)
    end
    b.label = Widgets.Text(b, 17, "gold")
    b.label:SetPoint("CENTER", 0, 2)
    b:SetScript("OnClick", onClick)
    b:SetScript("OnMouseDown", function()
        if b.Look then b.Look("-pressed") end
        b.label:SetPoint("CENTER", 1, 1)
    end)
    b:SetScript("OnMouseUp", function()
        if b.Look then b.Look("") end
        b.label:SetPoint("CENTER", 0, 2)
    end)
    return b
end

-- One of the four progress figures under the banner: a large value, its label and a thin bar;
-- hairlines between the figures instead of boxes.
local function Stat(parent, w, first)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(w, 62)
    if not first then
        local line = f:CreateTexture(nil, "BORDER")
        line:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.18)
        line:SetPoint("TOPLEFT", 0, -6)
        line:SetPoint("BOTTOMLEFT", 0, 6)
        line:SetWidth(1)
    end
    f.value = Widgets.Text(f, 24, "gold")
    f.value:SetPoint("TOPLEFT", 16, -4)
    f.label = Widgets.Text(f, 10, "gray")
    f.label:SetPoint("TOPLEFT", f.value, "BOTTOMLEFT", 0, -2)
    f.label:SetWidth(w - 24)
    f.label:SetJustifyH("LEFT")
    f.label:SetWordWrap(false)
    local track = f:CreateTexture(nil, "ARTWORK")
    track:SetPoint("BOTTOMLEFT", 16, 6)
    track:SetPoint("BOTTOMRIGHT", -16, 6)
    track:SetHeight(2)
    track:SetColorTexture(1, 1, 1, 0.08)
    f.bar = f:CreateTexture(nil, "ARTWORK", nil, 1)
    f.bar:SetPoint("TOPLEFT", track, "TOPLEFT")
    f.bar:SetHeight(2)
    f.bar:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.9)
    f.barWidth = w - 32
    return f
end

-- The star that makes a game the one to open on flights (ns.db.flightGame). Filled for the chosen
-- game, an outline for the others; a click on the filled star turns it off.
function Window:CreateFlightStar(parent, game)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(22, 22)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.game = game
    b:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        ns.db.flightGame = ns.db.flightGame == game.id and "off" or game.id
        self:RefreshHub()
        if b:IsMouseOver() then b:GetScript("OnEnter")(b) end
    end)
    b:SetScript("OnEnter", function()
        GameTooltip:SetOwner(b, "ANCHOR_LEFT")
        GameTooltip:SetText(L[game.nameKey], 1, 0.82, 0)
        GameTooltip:AddLine(ns.db.flightGame == game.id and L.HUB_STAR_ON or L.HUB_STAR_OFF, 1, 1, 1, true)
        GameTooltip:Show()
        b.icon:SetAlpha(1)
    end)
    b:SetScript("OnLeave", function()
        GameTooltip:Hide()
        self:UpdateStar(b)
    end)
    self.stars = self.stars or {}
    self.stars[#self.stars + 1] = b
    return b
end

local STAR_ON, STAR_OFF = "auctionhouse-icon-favorite", "auctionhouse-icon-favorite-off"

function Window:UpdateStar(b)
    local on = ns.db.flightGame == b.game.id
    if HasAtlas(STAR_ON) then
        b.icon:SetAtlas(on and STAR_ON or STAR_OFF)
        b.icon:SetVertexColor(1, 1, 1)
    else
        b.icon:SetTexture("Interface\\Common\\ReputationStar")
        b.icon:SetTexCoord(on and 0 or 0.5, on and 0.5 or 1, 0, 0.5)
    end
    b.icon:SetAlpha(on and 1 or 0.55)
end

function Window:CreateHub()
    local featured = Arcade.Featured()
    local hubW, hubH = Arcade.HomeSize()
    local stageW = hubW - LIST_W - COLUMN_GAP - SIDE_PAD
    local panelH = hubH - BANNER_H - PANEL_GAP

    local hub = CreateFrame("Frame", nil, self.content)
    hub:SetPoint("TOPLEFT")
    hub:SetSize(hubW, hubH)
    hub:SetFrameLevel(self.content:GetFrameLevel() + 5)
    self.hub, self.featured = hub, featured

    -- The stage: the featured game's painting, slowly drifting, with its logo and heroes. It runs
    -- from the window's left edge, without a margin.
    local banner = CreateFrame("Button", nil, hub)
    banner:SetSize(stageW, BANNER_H)
    banner:SetPoint("TOPLEFT")
    banner:SetClipsChildren(true)
    local hero = featured.hero or {}
    local art = banner:CreateTexture(nil, "BACKGROUND")
    art:SetAllPoints()
    art:SetTexture(hero.art or Media.Tex(featured.tile))
    self.heroArt = { tex = art, v0 = hero.v0 or 0, v1 = hero.v1 or 1, aspect = hero.aspect or 2, t = 0 }
    local dusk = banner:CreateTexture(nil, "BORDER")
    dusk:SetAllPoints()
    dusk:SetTexture(Media.Tex("mercs/vignette"))
    dusk:SetAlpha(0.75)
    local fade = banner:CreateTexture(nil, "BORDER", nil, 1)
    fade:SetPoint("BOTTOMLEFT")
    fade:SetPoint("BOTTOMRIGHT")
    fade:SetHeight(BANNER_H * 0.55)
    Gradient(fade, { 0.03, 0.01, 0.05, 0 }, { 0.03, 0.01, 0.05, 0.92 })
    if featured.DecorateHero then ns.SafeCall("DecorateHero", featured.DecorateHero, featured, banner) end

    local top = CreateFrame("Frame", nil, banner)
    top:SetAllPoints()
    top:SetFrameLevel(banner:GetFrameLevel() + 20)
    if hero.logo then
        local logoW = hero.logoW or 300
        for i, name in ipairs({ hero.logoShadow, hero.logo }) do
            local t = top:CreateTexture(nil, "ARTWORK", nil, i)
            t:SetSize(logoW, logoW * (hero.logoRatio or 0.34))
            t:SetPoint("TOPLEFT", 24, -40)
            t:SetTexture(Media.Tex(name))
            t:SetTexCoord(0, 1, 0, hero.logoV or 1)
        end
    else
        local name = Widgets.LocalizedText(top, 28, "gold", featured.nameKey)
        name:SetPoint("TOPLEFT", 28, -52)
    end
    -- A small "featured" tag in the corner: a dark pill with a gold edge on its left.
    local tag = CreateFrame("Frame", nil, top)
    tag:SetPoint("TOPLEFT", 20, -18)
    tag:SetHeight(20)
    local tagFill = tag:CreateTexture(nil, "BACKGROUND")
    tagFill:SetAllPoints()
    tagFill:SetColorTexture(0.03, 0.01, 0.05, 0.7)
    local tagEdge = tag:CreateTexture(nil, "ARTWORK")
    tagEdge:SetPoint("TOPLEFT")
    tagEdge:SetPoint("BOTTOMLEFT")
    tagEdge:SetWidth(2)
    tagEdge:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
    tag.text = Widgets.LocalizedText(tag, 10, "gold", "HUB_FEATURED")
    tag.text:SetPoint("LEFT", 10, 0)
    Widgets.OnRefresh(function() tag:SetWidth((tag.text:GetStringWidth() or 60) + 20) end)
    local star = self:CreateFlightStar(top, featured)
    star:SetSize(26, 26)
    star:SetPoint("TOPRIGHT", -16, -16)
    local desc = Widgets.LocalizedText(top, 13, "white", featured.descKey)
    desc:SetPoint("BOTTOMLEFT", 26, 22)
    desc:SetWidth(stageW * 0.5)
    desc:SetJustifyH("LEFT")
    desc:SetSpacing(3)
    banner:SetScript("OnClick", function() self:PlayFeatured() end)

    -- Under the stage: the player's progress, the way in, and what is new.
    local panel = Glass(hub, 0.5)
    panel:SetPoint("TOPLEFT", banner, "BOTTOMLEFT", 0, -PANEL_GAP)
    panel:SetSize(stageW, panelH)
    local statW = math.floor((stageW - 16) / 4)
    self.heroStats = {}
    for i = 1, 4 do
        local s = Stat(panel, statW, i == 1)
        s:SetPoint("TOPLEFT", 8 + (i - 1) * statW, -14)
        self.heroStats[i] = s
    end
    local divider = panel:CreateTexture(nil, "BORDER")
    divider:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.14)
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", 24, -88)
    divider:SetPoint("TOPRIGHT", -24, -88)

    -- Left: where the run stands, the big button (bottom left, as in the Battle.net app), the version.
    local statusIcon = panel:CreateTexture(nil, "ARTWORK")
    statusIcon:SetSize(16, 16)
    statusIcon:SetPoint("TOPLEFT", 22, -104)
    statusIcon:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")
    self.heroStatus = Widgets.Text(panel, 12, "white")
    self.heroStatus:SetPoint("TOPLEFT", statusIcon, "TOPRIGHT", 8, -1)
    self.heroStatus:SetWidth(PLAY_COLUMN - 50)
    self.heroStatus:SetJustifyH("LEFT")
    if self.heroStatus.SetMaxLines then self.heroStatus:SetMaxLines(2) end
    self.heroPlay = PlayButton(panel, PLAY_COLUMN - 28, 58, function() self:PlayFeatured() end)
    self.heroPlay:SetPoint("BOTTOMLEFT", 14, 30)
    self.heroVersion = Widgets.Text(panel, 10, "gray")
    self.heroVersion:SetPoint("BOTTOMLEFT", 24, 12)
    Widgets.OnRefresh(function() self.heroVersion:SetText(L.VERSION:format(ns.Version())) end)

    -- Right: the latest version's highlights; the link opens the news tab.
    local split = panel:CreateTexture(nil, "BORDER")
    split:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.14)
    split:SetWidth(1)
    split:SetPoint("TOPLEFT", PLAY_COLUMN, -100)
    split:SetPoint("BOTTOMLEFT", PLAY_COLUMN, 14)
    local newsX, newsW = PLAY_COLUMN + 20, stageW - PLAY_COLUMN - 38
    self.heroNewsTitle = Widgets.Text(panel, 12, "gold")
    self.heroNewsTitle:SetPoint("TOPLEFT", newsX, -102)
    local all = CreateFrame("Button", nil, panel)
    all:SetSize(160, 18)
    all:SetPoint("TOPRIGHT", -18, -100)
    all.text = Widgets.LocalizedText(all, 11, "gray", "HUB_ALL_NEWS")
    all.text:SetPoint("RIGHT")
    all.text:SetTextColor(0.85, 0.75, 0.5)
    all:SetScript("OnClick", function() self:OpenNews() end)
    all:SetScript("OnEnter", function() all.text:SetTextColor(1, 0.9, 0.6) end)
    all:SetScript("OnLeave", function() all.text:SetTextColor(0.85, 0.75, 0.5) end)
    self.heroNews = {}
    for i = 1, NEWS_LINES do
        local line = CreateFrame("Button", nil, panel)
        line:SetSize(newsW, NEWS_LINE_H)
        line:SetPoint("TOPLEFT", newsX, -124 - (i - 1) * NEWS_LINE_H)
        line.icon = line:CreateTexture(nil, "ARTWORK")
        line.icon:SetSize(22, 22)
        line.icon:SetPoint("TOPLEFT", 0, -1)
        line.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        line.title = Widgets.Text(line, 11, "white")
        line.title:SetPoint("TOPLEFT", line.icon, "TOPRIGHT", 8, 1)
        line.title:SetWidth(newsW - 32)
        line.title:SetJustifyH("LEFT")
        line.title:SetWordWrap(false)
        line.title:SetTextColor(1, 0.86, 0.5)
        line.text = Widgets.Text(line, 10, "gray")
        line.text:SetPoint("TOPLEFT", line.title, "BOTTOMLEFT", 0, -2)
        line.text:SetWidth(newsW - 32)
        line.text:SetJustifyH("LEFT")
        line.text:SetWordWrap(false)
        line:SetScript("OnClick", function() self:OpenNews() end)
        self.heroNews[i] = line
    end

    -- The other games: a quiet list on the right.
    local column = CreateFrame("Frame", nil, hub)
    column:SetPoint("TOPRIGHT", -SIDE_PAD, -12)
    column:SetSize(LIST_W, hubH - 24)
    local heading = Widgets.LocalizedText(column, 14, "gold", "HUB_MORE_GAMES")
    heading:SetPoint("TOPLEFT", 4, -6)
    heading:SetWidth(LIST_W - 8)
    heading:SetJustifyH("LEFT")
    local rule = column:CreateTexture(nil, "ARTWORK")
    rule:SetColorTexture(0.86, 0.66, 0.3, 0.35)
    rule:SetHeight(1)
    rule:SetPoint("TOPLEFT", 0, -26)
    rule:SetPoint("TOPRIGHT", 0, -26)

    local others = {}
    for _, id in ipairs(Arcade.order) do
        if Arcade.games[id] ~= featured then others[#others + 1] = Arcade.games[id] end
    end
    local listH = hubH - 24
    local rowH = math.floor((listH - LIST_TOP - ROW_GAP * math.max(0, #others - 1)) / math.max(1, #others))
    rowH = math.min(rowH, 96)
    self.tiles = {}
    for i, game in ipairs(others) do
        local row = self:CreateGameRow(column, game, LIST_W, rowH)
        row:SetPoint("TOPLEFT", 0, -LIST_TOP - (i - 1) * (rowH + ROW_GAP))
        self.tiles[#self.tiles + 1] = row
    end

    -- The painting drifts slowly while the menu is open.
    hub:SetScript("OnUpdate", function(_, elapsed) self:DriftHero(elapsed) end)
    self:DriftHero(0)
end

-- A slow pan and zoom over the featured painting.
function Window:DriftHero(elapsed)
    local h = self.heroArt
    h.t = h.t + elapsed
    local banner = h.tex:GetParent()
    local w, height = banner:GetWidth() or 1, banner:GetHeight() or 1
    -- Show the painting's middle at the banner's aspect, then zoom in a little and pan.
    local spanV = h.v1 - h.v0
    local frameAspect = w / math.max(1, height)
    local spanU = math.min(1, frameAspect / h.aspect)
    local zoom = 1.06 + 0.04 * math.sin(h.t * 0.11)
    local du, dv = spanU / zoom, spanV / zoom
    local cu = 0.5 + (1 - du) * 0.45 * math.sin(h.t * 0.07)
    local cv = (h.v0 + h.v1) / 2 + (spanV - dv) * 0.4 * math.cos(h.t * 0.09)
    cu = math.max(du / 2, math.min(1 - du / 2, cu))
    h.tex:SetTexCoord(cu - du / 2, cu + du / 2, cv - dv / 2, cv + dv / 2)
end

-- One game of the list: its card art, name, a short description and the best score.
function Window:CreateGameRow(parent, game, w, h)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(w, h)
    row:RegisterForClicks("LeftButtonUp")
    local fill = row:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    fill:SetColorTexture(0.06, 0.03, 0.09, 0.55)
    local glow = row:CreateTexture(nil, "BACKGROUND", nil, 1)
    glow:SetAllPoints()
    Gradient(glow, { 0.55, 0.32, 0.72, 0.0 }, { 0.55, 0.32, 0.72, 0.28 })
    glow:SetAlpha(0)
    local accent = row:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT")
    accent:SetPoint("BOTTOMLEFT")
    accent:SetWidth(3)
    accent:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
    accent:SetAlpha(0)

    -- The game's card at full size, scaled down: its own decorations (models, icons) come along.
    local thumbW = math.min(THUMB_W, (h - 12) * 2)
    local scale = thumbW / CARD_W
    local thumb = CreateFrame("Frame", nil, row)
    thumb:SetSize(CARD_W, CARD_W / 2)
    thumb:SetScale(scale)
    thumb:SetPoint("LEFT", row, "LEFT", 8 / scale, 0)
    local mask = thumb:CreateMaskTexture()
    mask:SetTexture(Media.Tex("card_mask"), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints()
    local art = thumb:CreateTexture(nil, "ARTWORK")
    art:SetAllPoints()
    art:SetTexture(Media.Tex(game.tile))
    art:AddMaskTexture(mask)
    local frameArt = thumb:CreateTexture(nil, "OVERLAY")
    frameArt:SetAllPoints()
    frameArt:SetTexture(Media.Tex("card_frame"))
    frameArt:SetAlpha(0.8)
    if game.DecorateTile then ns.SafeCall("DecorateTile", game.DecorateTile, game, thumb, art) end

    local textX = 8 + thumbW + 12
    local name = Widgets.LocalizedText(row, 14, "gold", game.nameKey)
    name:SetPoint("TOPLEFT", textX, -10)
    name:SetWidth(w - textX - 36)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    local desc = Widgets.LocalizedText(row, 10, "gray", game.descKey)
    desc:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -4)
    desc:SetWidth(w - textX - 10)
    desc:SetJustifyH("LEFT")
    if desc.SetMaxLines then desc:SetMaxLines(3) end
    local star = self:CreateFlightStar(row, game)
    star:SetPoint("TOPRIGHT", -8, -8)
    star:SetFrameLevel(row:GetFrameLevel() + 12)
    row.best = Widgets.Text(row, 10, "white")
    row.best:SetPoint("BOTTOMRIGHT", -10, 8)
    row.best:SetTextColor(0.85, 0.75, 0.5)

    -- Light up under the mouse: a soft glow, the gold accent and a brighter picture.
    row.hover = 0
    row:SetScript("OnUpdate", function(_, elapsed)
        local target = row:IsMouseOver() and 1 or 0
        if row.hover ~= target then
            local step = elapsed * 7
            row.hover = target > row.hover and math.min(target, row.hover + step) or math.max(target, row.hover - step)
            glow:SetAlpha(row.hover)
            accent:SetAlpha(row.hover)
            art:SetVertexColor(0.8 + 0.2 * row.hover, 0.8 + 0.2 * row.hover, 0.8 + 0.2 * row.hover)
        end
    end)
    art:SetVertexColor(0.8, 0.8, 0.8)
    row:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
        self:OpenGame(game.id)
    end)
    row.game = game
    return row
end

function Window:PlayFeatured()
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
    self:OpenGame(self.featured.id)
end

function Window:RefreshHub()
    if not self.hub then return end
    for _, star in ipairs(self.stars or {}) do self:UpdateStar(star) end
    for _, row in ipairs(self.tiles) do
        local best = row.game.BestScore and row.game:BestScore()
        row.best:SetText(best and best > 0 and L.BEST:format(ns.FormatNumber(best)) or "")
    end

    -- The featured game's progress and status.
    local featured = self.featured
    local info = featured.HubInfo and select(2, ns.SafeCall("HubInfo", featured.HubInfo, featured)) or {}
    for i, s in ipairs(self.heroStats) do
        local stat = info.stats and info.stats[i]
        s:SetShown(stat ~= nil)
        if stat then
            s.value:SetText(stat.value)
            s.label:SetText(stat.label)
            local share = math.max(0, math.min(1, stat.share or 0))
            s.bar:SetWidth(math.max(1, s.barWidth * share))
            s.bar:SetShown(share > 0)
        end
    end
    self.heroStatus:SetText(info.status or "")
    self.heroPlay.label:SetText(info.resume and L.HUB_CONTINUE or L.PLAY)

    local latest = ns.News and ns.News.VERSIONS and ns.News.VERSIONS[1]
    if latest then
        self.heroNewsTitle:SetText(L.HUB_NEWS:format(latest.version))
        for i, line in ipairs(self.heroNews) do
            local item = latest.items[i]
            line:SetShown(item ~= nil)
            if item then
                line.icon:SetTexture("Interface\\Icons\\" .. item.icon)
                line.title:SetText(L[ns.News.Key(latest, item.key .. "_TITLE")])
                line.text:SetText(L[ns.News.Key(latest, item.key .. "_TEXT")])
            end
        end
    end
end
