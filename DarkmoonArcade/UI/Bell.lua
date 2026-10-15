-- The bell in the header: the latest achievements of all games at a glance. It turns gold while
-- there are achievements the player has not looked at yet; a click opens the list below it, and a
-- click on an entry opens that game's achievements.

local _, ns = ...

local Style, L = ns.Style, ns.L
local C = Style.C

local Bell = {}
ns.Bell = Bell

local ROWS, ROW_H, PANEL_W = 6, 40, 300

function Bell:Create(window, header, divider)
    self.window = window
    local b = CreateFrame("Button", nil, header)
    b:SetSize(28, 28)
    b.hover = false
    b:SetPoint("CENTER", divider, "CENTER", -33, 0)
    b.icon = Style.Icon(b, "notification", 28)
    b.icon:SetPoint("CENTER")
    b:SetScript("OnEnter", function()
        b.hover = true
        self:Update()
        GameTooltip:SetOwner(b, "ANCHOR_BOTTOMLEFT")
        GameTooltip:SetText(L.ACHIEVEMENTS, 1, 1, 1)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function()
        b.hover = false
        self:Update()
        GameTooltip:Hide()
    end)
    b:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
        if self.panel and self.panel:IsShown() then self:Close() else self:Open() end
    end)
    self.button = b
end

-- Newest first.
local function Unlocked()
    local list = {}
    for _, def in ipairs(ns.Achievements.list) do
        local at = ns.db.achievements[def.id]
        if at then list[#list + 1] = { def = def, at = at } end
    end
    table.sort(list, function(a, b) return a.at > b.at end)
    return list
end

function Bell:HasNew()
    local seen = ns.db.achievementsSeen or 0
    for _, at in pairs(ns.db.achievements) do
        if at > seen then return true end
    end
    return false
end

function Bell:Update()
    local b = self.button
    if not b then return end
    local new = self:HasNew()
    Style.SetIcon(b.icon, "notification" .. (new and "_active" or "") .. (b.hover and "_hover" or ""), 28)
end

function Bell:CreatePanel()
    local window = self.window
    local f = window.frame
    -- A click anywhere else in the window closes the list.
    local catcher = CreateFrame("Button", nil, f)
    catcher:SetAllPoints()
    catcher:SetFrameLevel(f:GetFrameLevel() + 88)
    catcher:SetScript("OnClick", function() self:Close() end)
    catcher:Hide()
    self.catcher = catcher

    local panel = CreateFrame("Frame", nil, f)
    panel:SetSize(PANEL_W, 52 + ROWS * ROW_H)
    panel:SetPoint("TOPRIGHT", window.header, "BOTTOMRIGHT", -16, -6)
    panel:SetFrameLevel(f:GetFrameLevel() + 90)
    panel:EnableMouse(true)
    panel:Hide()
    self.panel = panel
    Style.Rounded(panel, panel, 8, C.surface)
    Style.Rounded(panel, panel, 8, C.border, "BORDER", 0, "ring")

    local title = Style.LocalizedText(panel, 12, C.text, "ACHIEVEMENTS")
    title:SetPoint("TOPLEFT", 16, -16)
    self.count = Style.Text(panel, 10, C.dim)
    self.count:SetPoint("TOPRIGHT", -16, -17)
    local rule = Style.Line(panel, C.border, "ARTWORK")
    rule:SetHeight(1)
    rule:SetPoint("TOPLEFT", 12, -38)
    rule:SetPoint("TOPRIGHT", -12, -38)
    self.empty = Style.LocalizedText(panel, 11, C.muted, "BELL_EMPTY")
    self.empty:SetPoint("TOP", 0, -60)

    self.rows = {}
    for i = 1, ROWS do
        local row = CreateFrame("Button", nil, panel)
        row:SetSize(PANEL_W - 16, ROW_H - 4)
        row:SetPoint("TOPLEFT", 8, -44 - (i - 1) * ROW_H)
        row.bg = Style.Rounded(row, row, 6, C.item)
        row.bg:SetShown(false)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(28, 28)
        row.icon:SetPoint("LEFT", 8, 0)
        row.name = Style.Text(row, 11, C.text)
        row.name:SetPoint("TOPLEFT", 46, -5)
        row.name:SetWidth(PANEL_W - 90)
        row.sub = Style.Text(row, 9, C.dim)
        row.sub:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -4)
        row.sub:SetWidth(PANEL_W - 90)
        row.dot = row:CreateTexture(nil, "OVERLAY")
        row.dot:SetSize(6, 6)
        row.dot:SetPoint("RIGHT", -10, 0)
        row.dot:SetTexture(ns.Media.Tex("dot"))
        row.dot:SetVertexColor(unpack(C.gold))
        row:SetScript("OnEnter", function()
            row.bg:SetShown(true)
            row.name:SetTextColor(unpack(C.gold))
        end)
        row:SetScript("OnLeave", function()
            row.bg:SetShown(false)
            row.name:SetTextColor(unpack(C.text))
        end)
        row:SetScript("OnClick", function()
            local game = ns.Arcade.games[row.gameId]
            self:Close()
            if not game then return end
            window:OpenGame(game.id)
            if window.activeGame == game then game:ShowAchievements() end
        end)
        self.rows[i] = row
    end
end

function Bell:Open()
    if not self.panel then self:CreatePanel() end
    local list = Unlocked()
    local seen = ns.db.achievementsSeen or 0
    self.count:SetText(("%d / %d"):format(#list, #ns.Achievements.list))
    self.empty:SetShown(#list == 0)
    for i, row in ipairs(self.rows) do
        local entry = list[i]
        row:SetShown(entry ~= nil)
        if entry then
            local def = entry.def
            local game = ns.Arcade.games[def.game]
            row.gameId = def.game
            row.icon:SetTexture(def.icon)
            row.name:SetText(L[def.nameKey])
            row.sub:SetText((game and L[game.nameKey] or "") .. "  ·  " .. date(L.DATE_FORMAT, entry.at))
            row.dot:SetShown(entry.at > seen)
        end
    end
    self.panel:SetHeight(52 + math.max(1, math.min(ROWS, #list)) * ROW_H + 4)
    self.catcher:Show()
    self.panel:Show()
    -- Looked at: the bell turns plain again; the dots stay until the list closes.
    ns.db.achievementsSeen = time()
    self:Update()
end

function Bell:Close()
    if self.panel then
        self.panel:Hide()
        self.catcher:Hide()
    end
end

function ns.Window:UpdateBell()
    Bell:Update()
end
