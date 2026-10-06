-- Statistics page inside the arcade window: arcade totals and one block per game.

local _, ns = ...

local Widgets, Stats, L = ns.Widgets, ns.Stats, ns.L

local StatsView = {}
ns.StatsView = StatsView

local LINE = 18

function StatsView:Create(parent)
    local view = CreateFrame("Frame", nil, parent)
    view:SetAllPoints()
    view:SetFrameLevel(parent:GetFrameLevel() + 5)
    view:Hide()
    self.view = view

    local title = Widgets.LocalizedText(view, 20, "gold", "STATISTICS")
    title:SetPoint("TOP", 0, -10)

    local panel = CreateFrame("Frame", nil, view)
    panel:SetPoint("TOPLEFT", 70, -44)
    panel:SetPoint("BOTTOMRIGHT", -70, 6)
    local fill = panel:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    fill:SetColorTexture(0, 0, 0, 0.32)
    Widgets.Rim(panel, panel)

    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, -6)
    scroll:SetPoint("BOTTOMRIGHT", -26, 6)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(panel:GetWidth() > 0 and panel:GetWidth() - 26 or 474)
    scroll:SetScrollChild(content)
    scroll:SetScript("OnSizeChanged", function(_, width) content:SetWidth(width) end)
    self.content = content
    self.lines = {}
    return view
end

-- Rows are reused between refreshes: a label on the left, a value on the right.
function StatsView:Line(index)
    local line = self.lines[index]
    if not line then
        line = {
            label = Widgets.Text(self.content, 12, "white"),
            value = Widgets.Text(self.content, 12, "white"),
            rule = self.content:CreateTexture(nil, "ARTWORK"),
        }
        line.rule:SetColorTexture(0.86, 0.66, 0.3, 0.25)
        line.rule:SetHeight(1)
        self.lines[index] = line
    end
    return line
end

function StatsView:Refresh()
    local s = Stats.DB()
    local rows = {}
    local function Section(text) rows[#rows + 1] = { section = text } end
    local function Row(label, value) rows[#rows + 1] = { label = label, value = value } end

    local done, total = 0, 0
    for _, id in ipairs(ns.Arcade.order) do
        local d, t = ns.Achievements.Count(id)
        done, total = done + d, total + t
    end
    local favorite = Stats.Favorite()

    Section(L.STATS_ARCADE)
    Row(L.STATS_TOTAL_TIME, ns.FormatDuration(Stats.TotalTime()))
    Row(L.STATS_FLIGHT_TIME, ns.FormatDuration(s.flightTime))
    Row(L.STATS_RUNS, ns.FormatNumber(Stats.TotalRuns()))
    Row(L.STATS_FLIGHTS, ns.FormatNumber(s.flights))
    Row(L.ACHIEVEMENTS, ("%d / %d"):format(done, total))
    Row(L.STATS_FAVORITE, favorite and L[ns.Arcade.games[favorite].nameKey] or "–")
    Row(L.STATS_SINCE, date(L.DATE_FORMAT, s.since))

    for _, id in ipairs(ns.Arcade.order) do
        local game = ns.Arcade.games[id]
        Section(L[game.nameKey])
        local seconds = s.time[id] or 0
        if seconds < 1 and not s.runs[id] then
            Row(L.STATS_NONE, "")
        else
            local best = game.BestScore and game:BestScore() or 0
            local d, t = ns.Achievements.Count(id)
            Row(L.STATS_TIME, ns.FormatDuration(seconds))
            Row(L.STATS_RUNS, ns.FormatNumber(s.runs[id] or 0))
            Row(L.STATS_BEST, ns.FormatNumber(best))
            Row(L.ACHIEVEMENTS, ("%d / %d"):format(d, t))
            if game.StatLines then
                for _, extra in ipairs(game:StatLines()) do Row(extra[1], extra[2]) end
            end
        end
    end

    local y = -6
    for i, row in ipairs(rows) do
        local line = self:Line(i)
        line.label:ClearAllPoints()
        line.value:ClearAllPoints()
        if row.section then
            y = y - (i > 1 and 10 or 0)
            line.label:SetFontObject(ns.Media.Font(14, "gold"))
            line.label:SetText(row.section)
            line.label:SetPoint("TOPLEFT", 18, y)
            line.value:SetText("")
            line.rule:ClearAllPoints()
            line.rule:SetPoint("TOPLEFT", 18, y - 18)
            line.rule:SetPoint("TOPRIGHT", -8, y - 18)
            line.rule:Show()
            y = y - 24
        else
            line.label:SetFontObject(ns.Media.Font(12, "white"))
            line.label:SetText(row.label)
            line.label:SetPoint("TOPLEFT", 26, y)
            line.value:SetFontObject(ns.Media.Font(12, "gold"))
            line.value:SetText(row.value)
            line.value:SetPoint("TOPRIGHT", -14, y)
            line.rule:Hide()
            y = y - LINE
        end
        line.label:Show()
        line.value:Show()
    end
    for i = #rows + 1, #self.lines do
        local line = self.lines[i]
        line.label:Hide()
        line.value:Hide()
        line.rule:Hide()
    end
    self.content:SetHeight(-y + 8)
end

function StatsView:Show()
    self:Refresh()
    self.view:Show()
end

function StatsView:Hide()
    self.view:Hide()
end
