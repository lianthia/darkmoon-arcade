-- The statistics tab, laid out like "What's new": the arcade, Mercenaries and every minigame in a
-- list on the left; the chosen one's figures on the right. The arcade's page also shows how the play
-- time splits between the games.

local _, ns = ...

local Widgets, Stats, L = ns.Widgets, ns.Stats, ns.L

local StatsView = {}
ns.StatsView = StatsView

local PAD, LIST_W, LIST_ROW = 18, 250, 50
local CARD_H, LINE, BAR_ROW = 66, 26, 30
local GOLD = { 1, 0.82, 0.3 }

local function Hairline(parent, alpha)
    local t = parent:CreateTexture(nil, "BORDER")
    t:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], alpha)
    return t
end

-- One entry of the list: name and a short line under it.
local function Entry(parent, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(LIST_W, LIST_ROW)
    b.fill = b:CreateTexture(nil, "BACKGROUND")
    b.fill:SetAllPoints()
    b.fill:SetColorTexture(1, 1, 1, 0.06)
    b.edge = b:CreateTexture(nil, "ARTWORK")
    b.edge:SetPoint("TOPLEFT")
    b.edge:SetPoint("BOTTOMLEFT")
    b.edge:SetWidth(3)
    b.edge:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 0.85, 0.5, 0.06)
    b.name = Widgets.Text(b, 14, "gold")
    b.name:SetPoint("TOPLEFT", 18, -9)
    b.name:SetWidth(LIST_W - 30)
    b.name:SetJustifyH("LEFT")
    b.name:SetWordWrap(false)
    b.sub = Widgets.Text(b, 10, "gray")
    b.sub:SetPoint("TOPLEFT", b.name, "BOTTOMLEFT", 0, -3)
    b.sub:SetWidth(LIST_W - 30)
    b.sub:SetJustifyH("LEFT")
    b.sub:SetWordWrap(false)
    b:SetScript("OnClick", onClick)
    return b
end

-- A figure on the right: value over label, a hairline on its left.
local function Card(parent, w, first)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(w, CARD_H)
    if not first then
        local line = Hairline(f, 0.18)
        line:SetWidth(1)
        line:SetPoint("TOPLEFT", 0, -8)
        line:SetPoint("BOTTOMLEFT", 0, 8)
    end
    f.value = Widgets.Text(f, 20, "gold")
    f.value:SetPoint("TOPLEFT", 16, -10)
    f.value:SetWidth(w - 24)
    f.value:SetJustifyH("LEFT")
    f.value:SetWordWrap(false)
    f.label = Widgets.Text(f, 10, "gray")
    f.label:SetPoint("TOPLEFT", f.value, "BOTTOMLEFT", 0, -4)
    f.label:SetWidth(w - 24)
    f.label:SetJustifyH("LEFT")
    f.label:SetWordWrap(false)
    return f
end

function StatsView:Create(parent)
    local view = CreateFrame("Frame", nil, parent)
    view:SetAllPoints()
    view:SetFrameLevel(parent:GetFrameLevel() + 5)
    view:Hide()
    self.view = view

    -- Left: the arcade, the featured game, then the minigames under their own heading.
    local list = CreateFrame("Frame", nil, view)
    list:SetPoint("TOPLEFT", PAD, -PAD)
    list:SetPoint("BOTTOMLEFT", PAD, PAD)
    list:SetWidth(LIST_W)
    self.entries = {}
    local featured = ns.Arcade.Featured()
    local pages = { { id = "arcade" }, { id = featured.id, game = featured } }
    for _, id in ipairs(ns.Arcade.order) do
        if ns.Arcade.games[id] ~= featured then pages[#pages + 1] = { id = id, game = ns.Arcade.games[id], minigame = true } end
    end
    self.pages = pages
    local y = 0
    for i, page in ipairs(pages) do
        if page.minigame and not pages[i - 1].minigame then
            local heading = Widgets.LocalizedText(list, 12, "gold", "STATS_MINIGAMES")
            heading:SetPoint("TOPLEFT", 4, -y - 10)
            local rule = Hairline(list, 0.3)
            rule:SetHeight(1)
            rule:SetPoint("TOPLEFT", 0, -y - 28)
            rule:SetPoint("TOPRIGHT", 0, -y - 28)
            y = y + 34
        end
        local b = Entry(list, function()
            PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
            self:Select(i)
        end)
        b:SetPoint("TOPLEFT", 0, -y)
        self.entries[i] = b
        y = y + LIST_ROW + 2
    end

    local divider = Hairline(view, 0.18)
    divider:SetWidth(1)
    divider:SetPoint("TOPLEFT", PAD + LIST_W + PAD, -PAD)
    divider:SetPoint("BOTTOMLEFT", PAD + LIST_W + PAD, PAD)

    -- Right: title, figures, then the game's own lines or the play time per game.
    local page = CreateFrame("Frame", nil, view)
    page:SetPoint("TOPLEFT", PAD + LIST_W + PAD * 2, -PAD)
    page:SetPoint("BOTTOMRIGHT", -PAD, PAD)
    self.page = page
    self.title = Widgets.Text(page, 20, "gold")
    self.title:SetPoint("TOPLEFT", 4, 0)
    self.note = Widgets.Text(page, 11, "gray")
    self.note:SetPoint("TOPRIGHT", 0, -4)
    local rule = Hairline(page, 0.3)
    rule:SetHeight(1)
    rule:SetPoint("TOPLEFT", 0, -30)
    rule:SetPoint("TOPRIGHT", 0, -30)
    local width = ns.Arcade.HomeSize() - PAD * 4 - LIST_W
    self.cardRow = {}
    -- A game's four figures in one row; the arcade's six in two rows of three.
    for _, count in ipairs({ 4, 6 }) do
        local row, perRow = {}, count == 6 and 3 or 4
        local w = math.floor(width / perRow)
        for i = 1, count do
            local column = (i - 1) % perRow
            local c = Card(page, w, column == 0)
            c:SetPoint("TOPLEFT", column * w, -40 - math.floor((i - 1) / perRow) * CARD_H)
            row[i] = c
        end
        self.cardRow[count] = row
    end
    self.lines, self.bars = {}, {}
    self.detailTitle = Widgets.Text(page, 13, "gold")
    self.detailTitle:SetPoint("TOPLEFT", 4, -40 - CARD_H - 22)
    self.selected = 1
    return view
end

function StatsView:Line(i)
    local line = self.lines[i]
    if not line then
        local y = -40 - CARD_H - 48 - (i - 1) * LINE
        line = {
            label = Widgets.Text(self.page, 12, "white"),
            value = Widgets.Text(self.page, 12, "gold"),
            rule = Hairline(self.page, 0.08),
        }
        line.label:SetPoint("TOPLEFT", 6, y)
        line.value:SetPoint("TOPLEFT", 360, y)
        line.rule:SetHeight(1)
        line.rule:SetPoint("TOPLEFT", 0, y - LINE + 6)
        line.rule:SetPoint("TOPRIGHT", 0, y - LINE + 6)
        self.lines[i] = line
    end
    return line
end

-- The arcade's page: one bar per game, as long as its share of the play time.
function StatsView:Bar(i)
    local bar = self.bars[i]
    if not bar then
        local y = -40 - CARD_H * 2 - 48 - (i - 1) * BAR_ROW
        bar = {
            name = Widgets.Text(self.page, 12, "white"),
            track = self.page:CreateTexture(nil, "ARTWORK"),
            fill = self.page:CreateTexture(nil, "ARTWORK", nil, 1),
            value = Widgets.Text(self.page, 11, "gray"),
        }
        bar.name:SetPoint("TOPLEFT", 6, y)
        bar.name:SetWidth(200)
        bar.name:SetJustifyH("LEFT")
        bar.name:SetWordWrap(false)
        bar.track:SetColorTexture(1, 1, 1, 0.06)
        bar.track:SetPoint("TOPLEFT", 220, y - 2)
        bar.track:SetPoint("TOPRIGHT", -110, y - 2)
        bar.track:SetHeight(10)
        bar.fill:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.85)
        bar.fill:SetPoint("TOPLEFT", bar.track, "TOPLEFT")
        bar.fill:SetHeight(10)
        bar.value:SetPoint("TOPRIGHT", 0, y)
        self.bars[i] = bar
    end
    return bar
end

local function Figures(game, s)
    local seconds = s.time[game.id] or 0
    local d, t = ns.Achievements.Count(game.id)
    local played = seconds >= 1 or s.runs[game.id] ~= nil
    return played, {
        { played and ns.FormatDuration(seconds) or "–", L.STATS_TIME },
        { played and ns.FormatNumber(s.runs[game.id] or 0) or "–", L.STATS_RUNS },
        { played and ns.FormatNumber(game.BestScore and game:BestScore() or 0) or "–", L.STATS_BEST },
        { ("%d / %d"):format(d, t), L.ACHIEVEMENTS },
    }
end

local function HideAll(list)
    for _, entry in ipairs(list) do
        for _, part in pairs(entry) do part:Hide() end
    end
end

function StatsView:Refresh()
    local s = Stats.DB()
    for i, page in ipairs(self.pages) do
        local b = self.entries[i]
        if page.game then
            local seconds = s.time[page.id] or 0
            b.name:SetText(L[page.game.nameKey])
            b.sub:SetText(seconds >= 1 and ns.FormatDuration(seconds) or L.STATS_NONE)
        else
            b.name:SetText(L.STATS_ARCADE)
            b.sub:SetText(L.STATS_TOTAL_TIME .. ": " .. ns.FormatDuration(Stats.TotalTime()))
        end
    end
    self:Select(self.selected)
end

function StatsView:Select(index)
    self.selected = index
    for i, b in ipairs(self.entries) do
        local chosen = i == index
        b.fill:SetShown(chosen)
        b.edge:SetShown(chosen)
        if chosen then b.name:SetTextColor(1, 0.82, 0.3) else b.name:SetTextColor(0.85, 0.78, 0.62) end
    end
    local s, page = Stats.DB(), self.pages[index]
    local cards, figures
    HideAll(self.lines)
    HideAll(self.bars)
    if page.game then
        local played
        played, figures = Figures(page.game, s)
        self.title:SetText(L[page.game.nameKey])
        self.note:SetText("")
        cards = self.cardRow[4]
        local extra = played and page.game.StatLines and page.game:StatLines() or {}
        self.detailTitle:SetText(#extra > 0 and L.STATS_DETAILS or "")
        self.detailTitle:SetPoint("TOPLEFT", 4, -40 - CARD_H - 22)
        for i, entry in ipairs(extra) do
            local line = self:Line(i)
            line.label:SetText(entry[1])
            line.value:SetText(entry[2])
            for _, part in pairs(line) do part:Show() end
        end
    else
        local done, total = 0, 0
        for _, id in ipairs(ns.Arcade.order) do
            local d, t = ns.Achievements.Count(id)
            done, total = done + d, total + t
        end
        local favorite = Stats.Favorite()
        figures = {
            { ns.FormatDuration(Stats.TotalTime()), L.STATS_TOTAL_TIME },
            { ns.FormatDuration(s.flightTime), L.STATS_FLIGHT_TIME },
            { ns.FormatNumber(Stats.TotalRuns()), L.STATS_RUNS },
            { ns.FormatNumber(s.flights), L.STATS_FLIGHTS },
            { ("%d / %d"):format(done, total), L.ACHIEVEMENTS },
            { favorite and L[ns.Arcade.games[favorite].nameKey] or "–", L.STATS_FAVORITE },
        }
        self.title:SetText(L.STATS_ARCADE)
        self.note:SetText(L.STATS_SINCE .. ": " .. date(L.DATE_FORMAT, s.since))
        cards = self.cardRow[6]
        self.detailTitle:SetText(L.STATS_TIME_SPLIT)
        self.detailTitle:SetPoint("TOPLEFT", 4, -40 - CARD_H * 2 - 22)
        local most = 1
        for _, id in ipairs(ns.Arcade.order) do most = math.max(most, s.time[id] or 0) end
        for i, id in ipairs(ns.Arcade.order) do
            local bar = self:Bar(i)
            local seconds = s.time[id] or 0
            bar.name:SetText(L[ns.Arcade.games[id].nameKey])
            bar.value:SetText(seconds >= 1 and ns.FormatDuration(seconds) or "–")
            for _, part in pairs(bar) do part:Show() end
            local width = (bar.track:GetWidth() or 300) * seconds / most
            bar.fill:SetWidth(math.max(1, width))
            bar.fill:SetShown(seconds >= 1)
        end
    end
    for _, row in pairs(self.cardRow) do
        for i, card in ipairs(row) do
            card:SetShown(row == cards)
            if row == cards then
                card.value:SetText(figures[i][1])
                card.label:SetText(figures[i][2])
            end
        end
    end
end

function StatsView:Show()
    self:Refresh()
    self.view:Show()
end

function StatsView:Hide()
    self.view:Hide()
end
