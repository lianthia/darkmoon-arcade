local _, ns = ...

local Media, L = ns.Media, ns.L

local Widgets = {}
ns.Widgets = Widgets

local refreshers = {}

-- Registers a function that re-applies localized texts; runs on every language change.
function Widgets.OnRefresh(fn)
    refreshers[#refreshers + 1] = fn
    fn()
end

function Widgets.RefreshAll()
    for _, fn in ipairs(refreshers) do fn() end
end

function Widgets.Text(parent, size, color)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject(Media.Font(size, color))
    return fs
end

function Widgets.LocalizedText(parent, size, color, key)
    local fs = Widgets.Text(parent, size, color)
    Widgets.OnRefresh(function() fs:SetText(L[key]) end)
    return fs
end

function Widgets.Button(parent, width, height, key, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width or 200, height or 26)
    b:SetNormalFontObject(Media.Font(12, "gold", ""))
    b:SetHighlightFontObject(Media.Font(12, "white", ""))
    b:SetDisabledFontObject(Media.Font(12, "gray", ""))
    if onClick then b:SetScript("OnClick", onClick) end
    if key then Widgets.OnRefresh(function() b:SetText(L[key]) end) end
    return b
end

function Widgets.Stack(parent, buttons, top, spacing)
    for i, b in ipairs(buttons) do
        b:ClearAllPoints()
        b:SetPoint("TOP", parent, "TOP", 0, top - (i - 1) * (spacing or 32))
    end
end

-- A "< label >" selector built from Blizzard's pager arrows.
function Widgets.Cycler(parent, width, onStep)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(width, 26)
    local function Arrow(dir, point)
        local b = CreateFrame("Button", nil, f)
        b:SetSize(26, 26)
        b:SetPoint(point)
        local page = dir < 0 and "Prev" or "Next"
        b:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. page .. "Page-Up")
        b:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. page .. "Page-Down")
        b:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
        b:SetScript("OnClick", function()
            PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
            onStep(dir)
        end)
    end
    Arrow(-1, "LEFT")
    Arrow(1, "RIGHT")
    f.label = Widgets.Text(f, 13, "white")
    f.label:SetPoint("CENTER")
    return f
end

function Widgets.Cycle(list, current, dir)
    local index = 1
    for i, v in ipairs(list) do
        if v == current then index = i end
    end
    return list[(index - 1 + dir) % #list + 1]
end

-- Overlay with switchable pages, drawn over a game's playfield ------------------

local Overlay = {}
Overlay.__index = Overlay

function Widgets.NewOverlay(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints()
    frame:SetFrameLevel(parent:GetFrameLevel() + 20)
    frame:EnableMouse(true)
    local shade = frame:CreateTexture(nil, "BACKGROUND")
    shade:SetAllPoints()
    shade:SetColorTexture(0, 0.02, 0.05, 0.72)
    return setmetatable({ frame = frame, pages = {} }, Overlay)
end

function Overlay:AddPage(name)
    local page = CreateFrame("Frame", nil, self.frame)
    page:SetAllPoints()
    page:Hide()
    self.pages[name] = page
    return page
end

function Overlay:Show(name, data)
    for pageName, page in pairs(self.pages) do
        page:SetShown(pageName == name)
    end
    self.current, self.data = name, data
    local page = self.pages[name]
    if page.refresh then page.refresh(data) end
    self.frame:Show()
end

function Overlay:Refresh()
    local page = self.current and self.pages[self.current]
    if page and page.refresh then page.refresh(self.data) end
end

function Overlay:Hide()
    self.frame:Hide()
    self.current = nil
end

function Widgets.PageTitle(page, key, y)
    local fs = Widgets.Text(page, 28, "gold")
    fs:SetPoint("TOP", 0, y or -60)
    if key then Widgets.OnRefresh(function() fs:SetText(L[key]) end) end
    return fs
end

function Widgets.HelpText(page, key, width)
    local fs = Widgets.LocalizedText(page, 10, "gray", key)
    fs:SetPoint("BOTTOM", 0, 56)
    fs:SetWidth(width)
    return fs
end

-- Sharing ---------------------------------------------------------------------

function Widgets.Share(channel, message)
    if not message then return end
    if channel == "PARTY" then
        if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
            channel = "INSTANCE_CHAT"
        elseif IsInRaid() then
            channel = "RAID"
        elseif not IsInGroup() then
            ns.Print(L.NOT_IN_GROUP)
            return
        end
    elseif channel == "GUILD" and not IsInGuild() then
        ns.Print(L.NOT_IN_GUILD)
        return
    end
    SendChatMessage(message, channel)
end

-- `getMessage` returns the chat line to post, or nil when there is nothing to share.
function Widgets.ShareRow(parent, getMessage)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(330, 24)
    local label = Widgets.LocalizedText(row, 12, "white", "SHARE")
    label:SetPoint("LEFT")
    local last
    for _, channel in ipairs({ "SAY", "PARTY", "GUILD" }) do
        local b = Widgets.Button(row, 78, 22, channel, function()
            Widgets.Share(channel, getMessage())
        end)
        if last then b:SetPoint("LEFT", last, "RIGHT", 4, 0) else b:SetPoint("LEFT", label, "RIGHT", 8, 0) end
        last = b
    end
    return row
end

-- Highscore page ----------------------------------------------------------------
-- opts: gameId, buckets (list) or nil, bucketName(bucket), detail(entry), shareMessage(entry, bucket), onBack

function Widgets.ScoresPage(overlay, width, opts)
    local page = overlay:AddPage("scores")
    local title = Widgets.PageTitle(page, "HIGHSCORES", -30)
    page.bucket = opts.buckets and opts.buckets[1] or "default"

    local listTop = -80
    local cycler
    if opts.buckets then
        cycler = Widgets.Cycler(page, 200, function(dir)
            page.bucket = Widgets.Cycle(opts.buckets, page.bucket, dir)
            page.refresh()
        end)
        cycler:SetPoint("TOP", title, "BOTTOM", 0, -8)
        listTop = -112
    end

    local left = (width - 330) / 2
    local rows = {}
    for i = 1, ns.Scores.MAX do
        local y = listTop - (i - 1) * 20
        local row = {
            rank = Widgets.Text(page, 12, "gray"),
            score = Widgets.Text(page, 13, "gold"),
            detail = Widgets.Text(page, 12, "white"),
            date = Widgets.Text(page, 11, "gray"),
        }
        row.rank:SetPoint("TOPRIGHT", page, "TOPLEFT", left + 26, y)
        row.score:SetPoint("TOPRIGHT", page, "TOPLEFT", left + 140, y)
        row.detail:SetPoint("TOPLEFT", page, "TOPLEFT", left + 160, y)
        row.date:SetPoint("TOPLEFT", page, "TOPLEFT", left + 262, y)
        rows[i] = row
    end
    local empty = Widgets.Text(page, 12, "gray")
    empty:SetPoint("TOP", 0, listTop - 40)
    empty:SetWidth(width - 60)

    local share = Widgets.ShareRow(page, function()
        local best = ns.Scores.List(opts.gameId, page.bucket)[1]
        return best and opts.shareMessage(best, page.bucket)
    end)
    share:SetPoint("TOP", 0, listTop - 10 * 20 - 16)
    local back = Widgets.Button(page, 200, 26, "BACK", opts.onBack)
    back:SetPoint("TOP", share, "BOTTOM", 0, -12)

    page.refresh = function(data)
        if data and data.bucket then page.bucket = data.bucket end
        if cycler then cycler.label:SetText(opts.bucketName(page.bucket)) end
        local list = ns.Scores.List(opts.gameId, page.bucket)
        for i, row in ipairs(rows) do
            local entry = list[i]
            if entry then
                row.rank:SetText(i .. ".")
                row.score:SetText(ns.FormatNumber(entry.score))
                row.detail:SetText(opts.detail and opts.detail(entry) or "")
                row.date:SetText(date(L.DATE_FORMAT, entry.time))
            end
            for _, fs in pairs(row) do fs:SetShown(entry ~= nil) end
        end
        empty:SetText(#list == 0 and L.NO_SCORES or "")
    end
    return page
end

-- Achievement list page --------------------------------------------------------------

function Widgets.AchievementsPage(overlay, width, gameId, onBack)
    local page = overlay:AddPage("achievements")
    local title = Widgets.PageTitle(page, "ACHIEVEMENTS", -26)
    local count = Widgets.Text(page, 12, "gray")
    count:SetPoint("TOP", title, "BOTTOM", 0, -4)

    local defs = ns.Achievements.ForGame(gameId)
    local rowHeight = math.min(44, math.floor(300 / math.max(1, #defs)))
    local rows = {}
    for i, def in ipairs(defs) do
        local y = -84 - (i - 1) * rowHeight
        local icon = page:CreateTexture(nil, "ARTWORK")
        icon:SetSize(rowHeight - 8, rowHeight - 8)
        icon:SetPoint("TOPLEFT", 36, y)
        icon:SetTexture(def.icon)
        local name = Widgets.LocalizedText(page, 13, "gold", def.nameKey)
        name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, -1)
        local desc = Widgets.LocalizedText(page, 10, "white", def.descKey)
        desc:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -2)
        desc:SetWidth(width - 140)
        desc:SetJustifyH("LEFT")
        local check = page:CreateTexture(nil, "ARTWORK")
        check:SetSize(20, 20)
        check:SetPoint("TOPRIGHT", page, "TOPRIGHT", -36, y - (rowHeight - 28) / 2)
        check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
        rows[i] = { def = def, icon = icon, name = name, desc = desc, check = check }
    end

    local back = Widgets.Button(page, 200, 26, "BACK", onBack)
    back:SetPoint("BOTTOM", 0, 18)

    page.refresh = function()
        local done, total = ns.Achievements.Count(gameId)
        count:SetText(("%d / %d"):format(done, total))
        for _, row in ipairs(rows) do
            local unlocked = ns.Achievements.IsDone(row.def.id)
            row.icon:SetDesaturated(not unlocked)
            row.icon:SetAlpha(unlocked and 1 or 0.45)
            row.name:SetAlpha(unlocked and 1 or 0.6)
            row.desc:SetAlpha(unlocked and 1 or 0.6)
            row.check:SetShown(unlocked)
        end
    end
    return page
end
