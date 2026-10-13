-- The main menu: the featured game (the newest highlight, today Mercenaries) on a large stage with
-- its painting, its heroes and the player's progress; the other games in a quiet list beside it.
-- The menu takes the featured game's window size.

local _, ns = ...

local Media, Widgets, L = ns.Media, ns.Widgets, ns.L
local Arcade, Window = ns.Arcade, ns.Window

local LIST_W, COLUMN_GAP = 344, 14
local BANNER_H, PANEL_GAP = 344, 12
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

function Window:CreateHub()
    local featured = Arcade.Featured()
    local hubW = (featured.fieldWidth or Arcade.FIELD_W) + Arcade.GUTTER + Arcade.SIDEBAR_W
    local hubH = featured.fieldHeight or Arcade.FIELD_H
    local stageW = hubW - LIST_W - COLUMN_GAP

    local hub = CreateFrame("Frame", nil, self.content)
    hub:SetPoint("TOPLEFT")
    hub:SetSize(hubW, hubH)
    hub:SetFrameLevel(self.content:GetFrameLevel() + 5)
    self.hub, self.featured = hub, featured

    -- The stage: the featured game's painting, slowly drifting, with its logo and heroes.
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
            t:SetPoint("TOPLEFT", 24, -34)
            t:SetTexture(Media.Tex(name))
            t:SetTexCoord(0, 1, 0, hero.logoV or 1)
        end
    else
        local name = Widgets.LocalizedText(top, 28, "gold", featured.nameKey)
        name:SetPoint("TOPLEFT", 28, -48)
    end
    -- A small "featured" tag in the corner: a dark pill with a gold edge on its left.
    local tag = CreateFrame("Frame", nil, top)
    tag:SetPoint("TOPLEFT", 18, -16)
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
    local desc = Widgets.LocalizedText(top, 13, "white", featured.descKey)
    desc:SetPoint("BOTTOMLEFT", 26, 20)
    desc:SetWidth(stageW * 0.5)
    desc:SetJustifyH("LEFT")
    desc:SetSpacing(3)
    banner:SetScript("OnClick", function() self:PlayFeatured() end)
    Hairlines(banner, 0.3)

    -- Under the stage: the player's progress, what is new, and the way in.
    local panel = Glass(hub, 0.5)
    panel:SetPoint("TOPLEFT", banner, "BOTTOMLEFT", 0, -PANEL_GAP)
    panel:SetSize(stageW, hubH - BANNER_H - PANEL_GAP)
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

    local BUTTON_W, TEXT_W = 236, stageW - 236 - 64
    local statusIcon = panel:CreateTexture(nil, "ARTWORK")
    statusIcon:SetSize(16, 16)
    statusIcon:SetPoint("TOPLEFT", 22, -108)
    statusIcon:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")
    self.heroStatus = Widgets.Text(panel, 13, "white")
    self.heroStatus:SetPoint("LEFT", statusIcon, "RIGHT", 8, 0)
    self.heroStatus:SetWidth(TEXT_W - 24)
    self.heroStatus:SetJustifyH("LEFT")
    self.heroStatus:SetWordWrap(false)
    -- What's new: the latest version's highlights in one line; a click opens the window.
    local news = CreateFrame("Button", nil, panel)
    news:SetPoint("TOPLEFT", 22, -132)
    news:SetSize(TEXT_W, 18)
    news.text = Widgets.Text(news, 11, "gray")
    news.text:SetPoint("LEFT", 0, 0)
    news.text:SetWidth(TEXT_W)
    news.text:SetJustifyH("LEFT")
    news.text:SetWordWrap(false)
    news:SetScript("OnClick", function() ns.News:Show() end)
    news:SetScript("OnEnter", function() news.text:SetTextColor(1, 0.9, 0.6) end)
    news:SetScript("OnLeave", function() news.text:SetTextColor(0.75, 0.72, 0.68) end)
    news.text:SetTextColor(0.75, 0.72, 0.68)
    self.heroNews = news
    self.hubHint = Widgets.Text(panel, 10, "gray")
    self.hubHint:SetPoint("BOTTOMLEFT", 22, 16)
    self.hubHint:SetWidth(TEXT_W)
    self.hubHint:SetJustifyH("LEFT")
    self.heroPlay = PlayButton(panel, BUTTON_W, 58, function() self:PlayFeatured() end)
    self.heroPlay:SetPoint("TOPRIGHT", -18, -100)

    -- The other games: a quiet list on the right.
    local column = CreateFrame("Frame", nil, hub)
    column:SetPoint("TOPRIGHT")
    column:SetSize(LIST_W, hubH)
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
    local rowH = math.floor((hubH - LIST_TOP - ROW_GAP * math.max(0, #others - 1)) / math.max(1, #others))
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
    name:SetWidth(w - textX - 10)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    local desc = Widgets.LocalizedText(row, 10, "gray", game.descKey)
    desc:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -4)
    desc:SetWidth(w - textX - 10)
    desc:SetJustifyH("LEFT")
    if desc.SetMaxLines then desc:SetMaxLines(3) end
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
    local choice = ns.db.flightGame
    local target = choice == "off" and L.FLIGHT_OFF or choice == "hub" and L.FLIGHT_HUB
        or (Arcade.games[choice] and L[Arcade.games[choice].nameKey]) or L.FLIGHT_OFF
    self.hubHint:SetText(L.HUB_FLIGHT_HINT:format(target))
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
        local titles = {}
        for i = 1, math.min(2, #latest.items) do
            titles[i] = L[ns.News.Key(latest, latest.items[i].key .. "_TITLE")]
        end
        self.heroNews.text:SetText("|cffffd100" .. L.HUB_NEWS:format(latest.version) .. "|r  " .. table.concat(titles, "  ·  "))
    end
end
