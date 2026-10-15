-- The statistics tab, laid out like "What's new": the arcade, Mercenaries and every minigame in a
-- list on the left; the chosen one's figures on the right. The arcade's page also shows how the play
-- time splits between the games.

local _, ns = ...

local Style, Stats, L = ns.Style, ns.Stats, ns.L
local C = Style.C

local StatsView = {}
ns.StatsView = StatsView

local PAD = Style.PAGE_PAD
local CELL_H, LINE, BAR_ROW = 62, 28, 28

-- A plate of figures: value on the left, its label on the right, `perRow` to a row.
local function Figures(page, count, perRow, width)
    local rows = math.ceil(count / perRow)
    local plate = Style.Panel(page)
    plate:SetSize(width, rows * CELL_H + 8)
    plate.cells = {}
    local cellW = width / perRow
    for i = 1, count do
        local col, row = (i - 1) % perRow, math.floor((i - 1) / perRow)
        local left, right = col * cellW + 24, (col + 1) * cellW - 24
        local cell = {}
        cell.value = Style.Text(plate, 22, C.text)
        cell.value:SetPoint("TOPLEFT", left, -18 - row * CELL_H)
        cell.label = Style.Text(plate, 11, C.muted)
        cell.label:SetPoint("TOPRIGHT", plate, "TOPLEFT", right, -28 - row * CELL_H)
        cell.label:SetJustifyH("RIGHT")
        if col > 0 then
            local rule = Style.Line(plate, C.border, "ARTWORK")
            rule:SetWidth(1)
            rule:SetPoint("TOPLEFT", col * cellW, -14 - row * CELL_H)
            rule:SetHeight(CELL_H - 20)
        end
        plate.cells[i] = cell
    end
    return plate
end

function StatsView:Create(parent)
    local view = CreateFrame("Frame", nil, parent)
    view:SetAllPoints()
    view:SetFrameLevel(parent:GetFrameLevel() + 5)
    view:Hide()
    self.view = view

    -- Left: the arcade, the spotlight game, then the minigames under their own caption.
    local list = Style.SideList(view, "STATISTICS")
    self.entries = {}
    local featured = ns.Arcade.Featured()
    local pages = { { id = "arcade" }, { id = featured.id, game = featured } }
    for _, id in ipairs(ns.Arcade.order) do
        if ns.Arcade.games[id] ~= featured then pages[#pages + 1] = { id = id, game = ns.Arcade.games[id], minigame = true } end
    end
    self.pages = pages
    local y = list.top
    for i, page in ipairs(pages) do
        if page.minigame and not pages[i - 1].minigame then
            local caption = Style.Caption(list, "STATS_MINIGAMES")
            caption:SetPoint("TOPLEFT", 16, -y - 8)
            y = y + 28
        end
        local b = Style.ListItem(list, function()
            PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
            self:Select(i)
        end, true)
        b:SetPoint("TOPLEFT", 8, -y)
        self.entries[i] = b
        y = y + 50
    end

    -- Right: title, figures, then the game's own lines or the play time per game.
    local page = CreateFrame("Frame", nil, view)
    page:SetPoint("TOPLEFT", Style.CONTENT_X, -PAD)
    page:SetPoint("BOTTOMRIGHT", -PAD, PAD)
    self.page = page
    local width = ns.Arcade.HomeSize() - Style.CONTENT_X - PAD
    self.title = Style.Text(page, 22, C.text)
    self.title:SetPoint("TOPLEFT", 4, -4)
    self.note = Style.Text(page, 10, C.dim)
    self.note:SetPoint("TOPRIGHT", -4, -12)
    -- A game's four figures in one row; the arcade's six in two rows of three.
    self.figures = { [4] = Figures(page, 4, 4, width), [6] = Figures(page, 6, 3, width) }
    for _, plate in pairs(self.figures) do plate:SetPoint("TOPLEFT", 0, -40) end

    local details = Style.Panel(page)
    details:SetPoint("LEFT")
    details:SetPoint("RIGHT")
    self.details = details
    self.detailTitle = Style.Text(details, 13, C.text)
    self.detailTitle:SetPoint("TOPLEFT", 24, -18)
    self.lines, self.bars = {}, {}
    self.selected = 1
    return view
end

function StatsView:Line(i)
    local line = self.lines[i]
    if not line then
        local y = -48 - (i - 1) * LINE
        local d = self.details
        line = {
            label = Style.Text(d, 11, C.muted),
            value = Style.Text(d, 11, C.text),
            rule = Style.Line(d, C.border, "ARTWORK"),
        }
        line.label:SetPoint("TOPLEFT", 24, y)
        line.value:SetPoint("TOPRIGHT", -24, y)
        line.value:SetJustifyH("RIGHT")
        line.rule:SetHeight(1)
        line.rule:SetPoint("TOPLEFT", 24, y + 8)
        line.rule:SetPoint("TOPRIGHT", -24, y + 8)
        self.lines[i] = line
    end
    return line
end

-- The arcade's page: one bar per game, as long as its share of the play time.
function StatsView:Bar(i)
    local bar = self.bars[i]
    if not bar then
        local y = -48 - (i - 1) * BAR_ROW
        local d = self.details
        bar = {
            name = Style.Text(d, 11, C.text),
            track = Style.Line(d, C.border, "ARTWORK"),
            fill = d:CreateTexture(nil, "ARTWORK", nil, 1),
            value = Style.Text(d, 10, C.muted),
        }
        bar.name:SetPoint("TOPLEFT", 24, y)
        bar.name:SetWidth(180)
        bar.track:SetPoint("TOPLEFT", 220, y - 4)
        bar.track:SetPoint("TOPRIGHT", -120, y - 4)
        bar.track:SetHeight(4)
        bar.fill:SetColorTexture(unpack(C.gold))
        bar.fill:SetPoint("TOPLEFT", bar.track, "TOPLEFT")
        bar.fill:SetHeight(4)
        bar.value:SetPoint("TOPRIGHT", -24, y)
        bar.value:SetJustifyH("RIGHT")
        self.bars[i] = bar
    end
    return bar
end

local function GameFigures(game, s)
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
            b.label:SetText(L[page.game.nameKey])
            b.sub:SetText(seconds >= 1 and ns.FormatDuration(seconds) or L.STATS_NONE)
        else
            b.label:SetText(L.STATS_ARCADE)
            b.sub:SetText(L.STATS_TOTAL_TIME .. ": " .. ns.FormatDuration(Stats.TotalTime()))
        end
    end
    self:Select(self.selected)
end

function StatsView:SelectGame(id)
    for i, page in ipairs(self.pages) do
        if page.id == id then return self:Select(i) end
    end
end

function StatsView:Select(index)
    self.selected = index
    for i, b in ipairs(self.entries) do b:SetActive(i == index) end
    local s, page = Stats.DB(), self.pages[index]
    local plate, figures, rows
    HideAll(self.lines)
    HideAll(self.bars)
    if page.game then
        local played
        played, figures = GameFigures(page.game, s)
        self.title:SetText(L[page.game.nameKey])
        self.note:SetText("")
        plate = self.figures[4]
        local extra = played and page.game.StatLines and page.game:StatLines() or {}
        self.detailTitle:SetText(L.STATS_DETAILS)
        for i, entry in ipairs(extra) do
            local line = self:Line(i)
            line.label:SetText(entry[1])
            line.value:SetText(entry[2])
            for _, part in pairs(line) do part:Show() end
            line.rule:SetShown(i > 1)
        end
        rows = #extra
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
        plate = self.figures[6]
        self.detailTitle:SetText(L.STATS_TIME_SPLIT)
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
        rows = #ns.Arcade.order
    end
    for _, other in pairs(self.figures) do other:SetShown(other == plate) end
    for i, cell in ipairs(plate.cells) do
        cell.value:SetText(figures[i][1])
        cell.label:SetText(figures[i][2])
    end
    -- The details plate below the figures, as tall as its lines (hidden without any).
    self.details:ClearAllPoints()
    self.details:SetPoint("TOPLEFT", plate, "BOTTOMLEFT", 0, -8)
    self.details:SetPoint("TOPRIGHT", plate, "BOTTOMRIGHT", 0, -8)
    self.details:SetHeight(48 + rows * LINE + 6)
    self.details:SetShown(rows > 0)
end

function StatsView:Show()
    self:Refresh()
    self.view:Show()
end

function StatsView:Hide()
    self.view:Hide()
end
