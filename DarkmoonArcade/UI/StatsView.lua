-- The statistics tab: the arcade's totals as figures across the top, Mercenaries in its own column
-- and the minigames side by side in one table (their extra figures in each row's tooltip).

local _, ns = ...

local Widgets, Stats, L = ns.Widgets, ns.Stats, ns.L

local StatsView = {}
ns.StatsView = StatsView

local PAD, GAP = 18, 22
local CARD_H, LINE, TABLE_ROW = 66, 24, 42
local GOLD = { 1, 0.82, 0.3 }

local function Hairline(parent, alpha)
    local t = parent:CreateTexture(nil, "BORDER")
    t:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], alpha)
    return t
end

local function Heading(parent, key)
    local text = Widgets.LocalizedText(parent, 15, "gold", key)
    local rule = Hairline(parent, 0.3)
    rule:SetHeight(1)
    rule:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -6)
    rule:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
    return text
end

-- A figure of the arcade's totals: value over label, a hairline on its left.
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

-- The minigames' table: name, then one column per figure.
local COLUMNS = { { "STATS_TIME", 110 }, { "STATS_RUNS", 110 }, { "STATS_BEST", 100 }, { "ACHIEVEMENTS", 90 } }

function StatsView:Create(parent)
    local view = CreateFrame("Frame", nil, parent)
    view:SetAllPoints()
    view:SetFrameLevel(parent:GetFrameLevel() + 5)
    view:Hide()
    self.view = view

    -- Across the top: the arcade.
    local top = CreateFrame("Frame", nil, view)
    top:SetPoint("TOPLEFT", PAD, -PAD)
    top:SetPoint("TOPRIGHT", -PAD, -PAD)
    top:SetHeight(28 + CARD_H)
    Heading(top, "STATS_ARCADE"):SetPoint("TOPLEFT", 0, 0)
    self.since = Widgets.Text(top, 11, "gray")
    self.since:SetPoint("TOPRIGHT", 0, -2)
    self.cards = {}
    local width, count = ns.Arcade.HomeSize() - PAD * 2, 6
    for i = 1, count do
        local c = Card(top, math.floor(width / count), i == 1)
        c:SetPoint("TOPLEFT", (i - 1) * math.floor(width / count), -30)
        self.cards[i] = c
    end

    -- Left: Mercenaries.
    local mercs = CreateFrame("Frame", nil, view)
    mercs:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0, -GAP)
    mercs:SetPoint("BOTTOMLEFT", PAD, PAD)
    mercs:SetWidth(380)
    self.mercHeading = Heading(mercs, "MC_NAME")
    self.mercHeading:SetPoint("TOPLEFT", 0, 0)
    self.mercLines = {}
    self.mercs = mercs

    -- Right: the minigames.
    local games = CreateFrame("Frame", nil, view)
    games:SetPoint("TOPLEFT", mercs, "TOPRIGHT", GAP * 2, 0)
    games:SetPoint("BOTTOMRIGHT", -PAD, PAD)
    Heading(games, "STATS_MINIGAMES"):SetPoint("TOPLEFT", 0, 0)
    local x = 0
    self.columns = {}
    for i = #COLUMNS, 1, -1 do
        local col = COLUMNS[i]
        local head = Widgets.LocalizedText(games, 10, "gray", col[1])
        head:SetPoint("TOPRIGHT", -x, -34)
        head:SetWidth(col[2])
        head:SetJustifyH("RIGHT")
        head:SetWordWrap(false)
        self.columns[i] = x
        x = x + col[2]
    end
    self.games = games
    self.gameRows = {}
    return view
end

function StatsView:MercLine(i)
    local line = self.mercLines[i]
    if not line then
        line = {
            label = Widgets.Text(self.mercs, 12, "white"),
            value = Widgets.Text(self.mercs, 12, "gold"),
            rule = Hairline(self.mercs, 0.08),
        }
        local y = -34 - (i - 1) * LINE
        line.label:SetPoint("TOPLEFT", 2, y)
        line.value:SetPoint("TOPRIGHT", 0, y)
        line.rule:SetHeight(1)
        line.rule:SetPoint("TOPLEFT", 0, y - LINE + 5)
        line.rule:SetPoint("TOPRIGHT", 0, y - LINE + 5)
        self.mercLines[i] = line
    end
    return line
end

function StatsView:GameRow(i)
    local row = self.gameRows[i]
    if not row then
        row = CreateFrame("Frame", nil, self.games)
        row:SetHeight(TABLE_ROW)
        row:SetPoint("TOPLEFT", 0, -52 - (i - 1) * TABLE_ROW)
        row:SetPoint("TOPRIGHT", 0, -52 - (i - 1) * TABLE_ROW)
        row:EnableMouse(true)
        row.fill = row:CreateTexture(nil, "BACKGROUND")
        row.fill:SetAllPoints()
        row.fill:SetColorTexture(1, 1, 1, i % 2 == 1 and 0.035 or 0)
        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 0.85, 0.5, 0.06)
        row.name = Widgets.Text(row, 13, "gold")
        row.name:SetPoint("LEFT", 10, 0)
        row.name:SetWidth(240)
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(false)
        row.cells = {}
        for c, col in ipairs(COLUMNS) do
            local cell = Widgets.Text(row, 12, "white")
            cell:SetPoint("RIGHT", -self.columns[c], 0)
            cell:SetWidth(col[2])
            cell:SetJustifyH("RIGHT")
            cell:SetWordWrap(false)
            row.cells[c] = cell
        end
        row:SetScript("OnEnter", function()
            if not row.extra or #row.extra == 0 then return end
            GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
            GameTooltip:SetText(row.name:GetText(), 1, 0.82, 0)
            for _, extra in ipairs(row.extra) do GameTooltip:AddDoubleLine(extra[1], extra[2], 1, 1, 1, 1, 0.82, 0) end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", GameTooltip_Hide)
        self.gameRows[i] = row
    end
    return row
end

-- One game's figures: time, runs, best score, achievements.
local function Figures(game, s)
    local seconds = s.time[game.id] or 0
    local d, t = ns.Achievements.Count(game.id)
    local played = seconds >= 1 or s.runs[game.id]
    return played, {
        played and ns.FormatDuration(seconds) or "–",
        played and ns.FormatNumber(s.runs[game.id] or 0) or "–",
        played and ns.FormatNumber(game.BestScore and game:BestScore() or 0) or "–",
        ("%d / %d"):format(d, t),
    }
end

function StatsView:Refresh()
    local s = Stats.DB()
    local done, total = 0, 0
    for _, id in ipairs(ns.Arcade.order) do
        local d, t = ns.Achievements.Count(id)
        done, total = done + d, total + t
    end
    local favorite = Stats.Favorite()
    local figures = {
        { ns.FormatDuration(Stats.TotalTime()), L.STATS_TOTAL_TIME },
        { ns.FormatDuration(s.flightTime), L.STATS_FLIGHT_TIME },
        { ns.FormatNumber(Stats.TotalRuns()), L.STATS_RUNS },
        { ns.FormatNumber(s.flights), L.STATS_FLIGHTS },
        { ("%d / %d"):format(done, total), L.ACHIEVEMENTS },
        { favorite and L[ns.Arcade.games[favorite].nameKey] or "–", L.STATS_FAVORITE },
    }
    for i, card in ipairs(self.cards) do
        card.value:SetText(figures[i][1])
        card.label:SetText(figures[i][2])
    end
    self.since:SetText(L.STATS_SINCE .. ": " .. date(L.DATE_FORMAT, s.since))

    -- Mercenaries: its figures, then its own lines.
    local featured = ns.Arcade.Featured()
    self.mercHeading:SetText(L[featured.nameKey])
    local played, values = Figures(featured, s)
    local lines = {
        { L.STATS_TIME, values[1] }, { L.STATS_RUNS, values[2] }, { L.STATS_BEST, values[3] },
        { L.ACHIEVEMENTS, values[4] },
    }
    if played and featured.StatLines then
        for _, extra in ipairs(featured:StatLines()) do lines[#lines + 1] = extra end
    end
    for i, entry in ipairs(lines) do
        local line = self:MercLine(i)
        line.label:SetText(entry[1])
        line.value:SetText(entry[2])
        for _, part in pairs(line) do part:Show() end
    end
    for i = #lines + 1, #self.mercLines do
        for _, part in pairs(self.mercLines[i]) do part:Hide() end
    end

    -- The minigames.
    local index = 0
    for _, id in ipairs(ns.Arcade.order) do
        local game = ns.Arcade.games[id]
        if game ~= featured then
            index = index + 1
            local row = self:GameRow(index)
            local gamePlayed, cells = Figures(game, s)
            row.name:SetText(L[game.nameKey])
            for c, cell in ipairs(row.cells) do cell:SetText(cells[c]) end
            row.extra = gamePlayed and game.StatLines and game:StatLines() or nil
            row:Show()
        end
    end
    for i = index + 1, #self.gameRows do self.gameRows[i]:Hide() end
end

function StatsView:Show()
    self:Refresh()
    self.view:Show()
end

function StatsView:Hide()
    self.view:Hide()
end
