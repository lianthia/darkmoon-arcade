-- "What's new" window: shown once per version at login, after a first install or an update.
-- News.VERSIONS keeps every release, newest first: one row per highlight (icon, title, a sentence)
-- and an optional thank-you. A row of version tabs under the picture leafs back through them;
-- updates a player missed since the last visit are marked there and named under the title.
-- A release adds its entry at the top and its NEWS_<version>_* texts (e.g. NEWS_133_1_TITLE).

local _, ns = ...

local Media, Widgets, L = ns.Media, ns.Widgets, ns.L

local News = {}
ns.News = News

local WIDTH, TEXT_W, TEXT_H = 560, 480, 216
local ART_W, ART_H = 480, 130
local ICON, ROW_GAP = 38, 10
local TAB_W, TAB_H, TAB_GAP, MAX_TABS = 64, 22, 6, 6

-- Every release, newest first. items: icon and the number of their NEWS_<tag>_<key>_TITLE /
-- _TEXT (tag: the version without dots); thanks: icon of the band NEWS_<tag>_THANKS;
-- headline: the version has its own NEWS_<tag>_HEADLINE instead of "Patch x.y.z".
News.VERSIONS = {
    {
        version = "1.3.3",
        thanks = "INV_ValentinesCard02",
        items = {
            { icon = "INV_Misc_PocketWatch_01", key = 1 },
            { icon = "Ability_Hunter_SniperShot", key = 8 },
            { icon = "INV_Misc_Drum_01", key = 2 },
            { icon = "INV_Sword_62", key = 3 },
            { icon = "INV_Misc_Head_Gnoll_01", key = 4 },
            { icon = "Spell_Holy_MindVision", key = 5 },
            { icon = "Spell_Holy_SealOfRighteousness", key = 6 },
            { icon = "INV_Misc_Wrench_01", key = 7 },
        },
    },
    {
        version = "1.3.2",
        items = {
            { icon = "INV_Misc_Note_01", key = 1 },
            { icon = "INV_Misc_Gear_01", key = 2 },
        },
    },
    {
        version = "1.3.1",
        items = {
            { icon = "Spell_Nature_Invisibilty", key = 1 },
            { icon = "Ability_Rogue_Sprint", key = 2 },
            { icon = "INV_Misc_Book_11", key = 3 },
            { icon = "INV_Misc_Map_01", key = 4 },
        },
    },
    {
        version = "1.3.0",
        headline = true,
        items = {
            { icon = "INV_Sword_04", key = 1 },
            { icon = "INV_Misc_Head_Dragon_01", key = 2 },
            { icon = "INV_Misc_GroupNeedMore", key = 3 },
            { icon = "Ability_DualWield", key = 4 },
            { icon = "Spell_Holy_Resurrection", key = 5 },
            { icon = "INV_Misc_Book_09", key = 6 },
        },
    },
}

function News.Tag(v)
    return (v.version:gsub("%.", ""))
end

function News.Key(v, rest)
    return "NEWS_" .. News.Tag(v) .. "_" .. rest
end

-- "v1.3.2" or "1.3.2" -> { 1, 3, 2 }; nil for "dev" and the like.
local function Parts(version)
    if type(version) ~= "string" then return nil end
    local parts = {}
    for n in version:gmatch("%d+") do parts[#parts + 1] = tonumber(n) end
    return #parts > 0 and parts or nil
end

local function Newer(a, b)
    for i = 1, math.max(#a, #b) do
        local x, y = a[i] or 0, b[i] or 0
        if x ~= y then return x > y end
    end
    return false
end

-- Versions after `seen` that came before the newest one: what a returning player missed.
function News.Missed(seen)
    local last = Parts(seen)
    local missed = {}
    if not last then return missed end
    for i = 2, #News.VERSIONS do
        local v = News.VERSIONS[i]
        if Newer(Parts(v.version), last) then missed[v.version] = true end
    end
    return missed
end

local TOP, BOTTOM = 70, 112
-- The Darkmoon Faire painting of the Mercenaries camp; its picture spans v 0.255 to 0.815.
local CAMP_ART, CAMP_V0, CAMP_V1 = 2821800, 0.255, 0.815
local CHROME = TOP + 34 + ART_H + 8 + TAB_H + 10 + BOTTOM

local TEMPLATES = { "SimplePanelTemplate", "PortraitFrameTemplateNoCloseButton" }

local function Template()
    for _, name in ipairs(TEMPLATES) do
        if C_XMLUtil and C_XMLUtil.GetTemplateInfo and C_XMLUtil.GetTemplateInfo(name) then return name end
    end
    return TEMPLATES[#TEMPLATES]
end

-- A version tab: the number, a line under it (gold when chosen) and a green mark when missed.
local function VersionTab(parent, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(TAB_W, TAB_H)
    b.label = Widgets.Text(b, 12, "gray")
    b.label:SetPoint("CENTER", 0, 1)
    b.line = b:CreateTexture(nil, "ARTWORK")
    b.line:SetPoint("BOTTOMLEFT", 8, 0)
    b.line:SetPoint("BOTTOMRIGHT", -8, 0)
    b.line:SetHeight(2)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetPoint("TOPLEFT", 2, 0)
    hl:SetPoint("BOTTOMRIGHT", -2, 0)
    hl:SetColorTexture(1, 0.85, 0.4, 0.1)
    b.mark = b:CreateTexture(nil, "OVERLAY")
    b.mark:SetSize(6, 6)
    b.mark:SetColorTexture(0.35, 1, 0.45, 1)
    b.mark:SetRotation(math.pi / 4)
    b.mark:SetPoint("LEFT", b.label, "RIGHT", 4, 4)
    b.mark:Hide()
    b:SetScript("OnClick", onClick)
    return b
end

function News:Create()
    local f = CreateFrame("Frame", "DarkmoonArcadeNews", UIParent, Template())
    f:SetSize(WIDTH, CHROME + TEXT_H)
    f:SetPoint("CENTER", 0, 40)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:Hide()
    if Template():find("^Portrait") then
        if ButtonFrameTemplate_HidePortrait then pcall(ButtonFrameTemplate_HidePortrait, f) end
        if f.SetTitle then f:SetTitle("") end
    end
    for _, key in ipairs({ "Inset", "TopTileStreaks", "Bg" }) do
        local part = f[key]
        if type(part) == "table" and part.Hide then part:Hide() end
    end
    local surface = f:CreateTexture(nil, "BACKGROUND", nil, 2)
    surface:SetPoint("TOPLEFT", 2, -4)
    surface:SetPoint("BOTTOMRIGHT", -2, 3)
    surface:SetTexture(Media.Tex("hub_background"))

    -- The arcade's logo crowns the window, as on the main frame; its own frame lifts it above the border.
    local logoFrame = CreateFrame("Frame", nil, f)
    logoFrame:SetAllPoints()
    logoFrame:SetFrameLevel(f:GetFrameLevel() + 1000)
    local logo = logoFrame:CreateTexture(nil, "OVERLAY")
    logo:SetSize(150, 97)
    logo:SetPoint("BOTTOM", f, "TOP", 0, -48)
    logo:SetTexture(Media.Tex("logo"))
    logo:SetTexCoord(0, 1, 0, 330 / 512)

    local title = Widgets.LocalizedText(f, 18, "gold", "NEWS_TITLE")
    title:SetPoint("TOP", 0, -TOP + 12)
    self.version = Widgets.Text(f, 11, "gray")
    self.version:SetPoint("TOP", title, "BOTTOM", 0, -4)
    self.version:SetWidth(WIDTH - 40)

    -- The new game's camp with its logo, framed by a thin gold rim.
    local art = CreateFrame("Frame", nil, f)
    art:SetSize(ART_W, ART_H)
    art:SetPoint("TOP", 0, -TOP - 34)
    local picture = art:CreateTexture(nil, "ARTWORK")
    picture:SetAllPoints()
    picture:SetTexture(CAMP_ART)
    local dv = 1024 / (768 * ART_W / ART_H)
    local middle = (CAMP_V0 + CAMP_V1) / 2
    picture:SetTexCoord(0, 1, middle - dv / 2, middle + dv / 2)
    local dusk = art:CreateTexture(nil, "ARTWORK", nil, 1)
    dusk:SetAllPoints()
    dusk:SetTexture(Media.Tex("mercs/vignette"))
    dusk:SetAlpha(0.85)
    local LOGO_W = 230 * 1024 / 960
    for i, name in ipairs({ "logo_shadow", "logo" }) do
        local t = art:CreateTexture(nil, "OVERLAY", nil, i)
        t:SetSize(LOGO_W, LOGO_W * 347 / 1024)
        t:SetPoint("TOP", 0, -10 + 32 * LOGO_W / 1024)
        t:SetTexture(Media.Tex("mercs/" .. name))
        t:SetTexCoord(0, 1, 0, 347 / 512)
    end
    Widgets.Rim(art, picture)
    self.headline = Widgets.Text(art, 18, "gold")
    self.headline:SetPoint("BOTTOM", 0, 12)
    self.headline:SetShadowOffset(1, -1)

    -- Version tabs, newest on the left; arrows page through when there are more than fit.
    local tabs = CreateFrame("Frame", nil, f)
    tabs:SetSize(TEXT_W, TAB_H)
    tabs:SetPoint("TOP", art, "BOTTOM", 0, -8)
    tabs:EnableMouseWheel(true)
    tabs:SetScript("OnMouseWheel", function(_, delta) self:Select(self.selected - delta) end)
    self.tabRow = tabs
    self.tabs = {}
    for i = 1, MAX_TABS do
        self.tabs[i] = VersionTab(tabs, function(tab) self:Select(tab.index) end)
    end
    local function Arrow(text, dir)
        local b = CreateFrame("Button", nil, tabs)
        b:SetSize(22, TAB_H)
        b.label = Widgets.Text(b, 12, "gold")
        b.label:SetPoint("CENTER", 0, 1)
        b.label:SetText(text)
        b:SetScript("OnClick", function()
            self.first = math.max(1, math.min(#News.VERSIONS - MAX_TABS + 1, self.first + dir * MAX_TABS))
            self:UpdateTabs()
        end)
        return b
    end
    self.older = Arrow(">", 1)
    self.older:SetPoint("RIGHT", tabs, "RIGHT", 0, 0)
    self.newer = Arrow("<", -1)
    self.newer:SetPoint("LEFT", tabs, "LEFT", 0, 0)
    self.first = 1

    -- The highlights scroll once the window would grow taller than the screen.
    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOP", tabs, "BOTTOM", 0, -10)
    scroll:SetSize(TEXT_W, TEXT_H)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(TEXT_W, TEXT_H)
    scroll:SetScrollChild(content)
    self.scroll, self.content = scroll, content

    -- One row per highlight: icon in a thin rim, gold title, a short sentence, a faint rule.
    local rowCount = 0
    for _, v in ipairs(News.VERSIONS) do rowCount = math.max(rowCount, #v.items) end
    self.rows = {}
    for i = 1, rowCount do
        local row = CreateFrame("Frame", nil, content)
        row:SetWidth(TEXT_W)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(ICON, ICON)
        row.icon:SetPoint("TOPLEFT", 4, -4)
        row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        Widgets.Rim(row, row.icon)
        row.title = Widgets.Text(row, 13, "gold")
        row.title:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 14, 0)
        row.title:SetWidth(TEXT_W - ICON - 22)
        row.title:SetJustifyH("LEFT")
        row.text = Widgets.Text(row, 11, "white")
        row.text:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -4)
        row.text:SetWidth(TEXT_W - ICON - 22)
        row.text:SetJustifyH("LEFT")
        row.text:SetTextColor(0.85, 0.83, 0.8)
        row.text:SetSpacing(2)
        row.rule = row:CreateTexture(nil, "BACKGROUND")
        row.rule:SetColorTexture(0.86, 0.66, 0.3, 0.18)
        row.rule:SetHeight(1)
        row.rule:SetPoint("BOTTOMLEFT", ICON + 18, 0)
        row.rule:SetPoint("BOTTOMRIGHT", 0, 0)
        self.rows[i] = row
    end

    -- Thanks to players who helped, on a warm band of its own.
    local thanks = CreateFrame("Frame", nil, content)
    thanks:SetWidth(TEXT_W)
    local fill = thanks:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    fill:SetColorTexture(0.45, 0.16, 0.22, 0.35)
    Widgets.Rim(thanks, thanks)
    thanks.icon = thanks:CreateTexture(nil, "ARTWORK")
    thanks.icon:SetSize(26, 26)
    thanks.icon:SetPoint("LEFT", 10, 0)
    thanks.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    thanks.text = Widgets.Text(thanks, 11, "white")
    thanks.text:SetPoint("LEFT", thanks.icon, "RIGHT", 10, 0)
    thanks.text:SetWidth(TEXT_W - 60)
    thanks.text:SetJustifyH("LEFT")
    thanks.text:SetTextColor(1, 0.86, 0.7)
    self.thanks = thanks

    local show = Widgets.Button(f, 210, 28, "NEWS_SHOW", function() self:Close(true) end)
    show:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -6, 68)
    local ok = Widgets.Button(f, 210, 28, "NEWS_OK", function() self:Close(false) end)
    ok:SetPoint("BOTTOMLEFT", f, "BOTTOM", 6, 68)
    -- Never again: the same switch as the option, with a note where to turn it back on.
    local never = Widgets.Button(f, 300, 22, "NEWS_NEVER", function() self:Close(false, true) end)
    never:SetPoint("BOTTOM", 0, 34)
    never:SetNormalFontObject(Media.Font(11, "gray", ""))
    local hint = Widgets.LocalizedText(f, 10, "gray", "NEWS_NEVER_HINT")
    hint:SetPoint("BOTTOM", 0, 16)
    hint:SetWidth(WIDTH - 60)
    self.neverButton = never

    self.showButton, self.okButton = show, ok
    self.art = art
    self.frame = f
    self.selected, self.missed = 1, {}
    Widgets.OnRefresh(function()
        if self.frame and self.frame:IsShown() then self:Show(self.selected) end
    end)
end

-- Shows the window unless this version's news were already seen.
function News:ShowIfNew()
    local version = ns.Version()
    if ns.db.newsNever or ns.db.newsSeen == version or not self.frame then return end
    self:Show()
end

-- Fills the rows with one version's highlights and returns the height they take.
function News:Fill(index)
    local v = News.VERSIONS[index]
    local y = 0
    for i, row in ipairs(self.rows) do
        local item = v.items[i]
        row:SetShown(item ~= nil)
        if item then
            row.icon:SetTexture("Interface\\Icons\\" .. item.icon)
            row.title:SetText(L[News.Key(v, item.key .. "_TITLE")])
            row.text:SetText(L[News.Key(v, item.key .. "_TEXT")])
            local h = math.max(ICON + 8, 4 + (row.title:GetStringHeight() or 13) + 4 + (row.text:GetStringHeight() or 11) + 8)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, -y)
            row:SetHeight(h)
            y = y + h + ROW_GAP
        end
    end
    self.thanks:SetShown(v.thanks ~= nil)
    if v.thanks then
        self.thanks.icon:SetTexture("Interface\\Icons\\" .. v.thanks)
        self.thanks.text:SetText(L[News.Key(v, "THANKS")])
        local h = math.max(40, (self.thanks.text:GetStringHeight() or 11) + 18)
        self.thanks:ClearAllPoints()
        self.thanks:SetPoint("TOPLEFT", 0, -(y + 2))
        self.thanks:SetHeight(h)
        y = y + h + 14
    end
    return y
end

-- Opens the window on a version (default: the newest). The window takes the height of the longest
-- version, so it keeps its size while leafing through them.
function News:Show(index)
    self.missed = News.Missed(ns.db.newsSeen)
    local names = {}
    for _, v in ipairs(News.VERSIONS) do
        if self.missed[v.version] then names[#names + 1] = v.version end
    end
    local line = L.VERSION:format(ns.Version())
    if #names > 0 then
        line = line .. "  -  |cff59ff73" .. L.NEWS_MISSED:format(table.concat(names, ", ")) .. "|r"
    end
    self.version:SetText(line)

    local tallest = 0
    for i = 1, #News.VERSIONS do tallest = math.max(tallest, self:Fill(i)) end
    local height = math.max(TEXT_H, math.ceil(tallest))
    local room = math.max(TEXT_H, math.floor((UIParent:GetHeight() or 768) * 0.9) - CHROME)
    local shown = math.min(height, room)
    self.content:SetHeight(height)
    self.scroll:SetHeight(shown)
    local bar = self.scroll.ScrollBar
    if type(bar) == "table" then bar:SetShown(height > shown) end
    self.frame:SetHeight(CHROME + shown)

    local wasShown = self.frame:IsShown()
    self:Select(index or 1, true)
    self.frame:Show()
    if not wasShown then PlaySound(SOUNDKIT.IG_MAINMENU_OPEN) end
end

function News:Select(index, quiet)
    index = math.max(1, math.min(#News.VERSIONS, index or 1))
    local changed = index ~= self.selected
    self.selected = index
    local v = News.VERSIONS[index]
    self.headline:SetText(v.headline and L[News.Key(v, "HEADLINE")] or L.NEWS_PATCH:format(v.version))
    self:Fill(index)
    self.scroll:SetVerticalScroll(0)
    -- Keep the chosen tab in view.
    if index < self.first then self.first = index end
    if index > self.first + MAX_TABS - 1 then self.first = index - MAX_TABS + 1 end
    self:UpdateTabs()
    if changed and not quiet then PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB) end
end

function News:UpdateTabs()
    local count = math.min(MAX_TABS, #News.VERSIONS)
    local width = count * TAB_W + (count - 1) * TAB_GAP
    for i, tab in ipairs(self.tabs) do
        local index = self.first + i - 1
        local v = i <= count and News.VERSIONS[index]
        tab:SetShown(v and true or false)
        if v then
            tab.index = index
            tab:ClearAllPoints()
            tab:SetPoint("LEFT", self.tabRow, "CENTER", -width / 2 + (i - 1) * (TAB_W + TAB_GAP), 0)
            tab.label:SetText(v.version)
            local chosen = index == self.selected
            if chosen then
                tab.label:SetTextColor(1, 0.82, 0)
                tab.line:SetColorTexture(1, 0.78, 0.3, 0.95)
            else
                tab.label:SetTextColor(0.62, 0.6, 0.56)
                tab.line:SetColorTexture(0.86, 0.66, 0.3, 0.2)
            end
            tab.mark:SetShown(self.missed[v.version] == true)
        end
    end
    self.newer:SetShown(self.first > 1)
    self.older:SetShown(self.first + MAX_TABS - 1 < #News.VERSIONS)
end

-- Both buttons retire the news of this version; one also opens the arcade.
function News:Close(openArcade, never)
    ns.db.newsSeen = ns.Version()
    if never then
        ns.db.newsNever = true
        ns.Print(L.NEWS_NEVER_DONE)
    end
    self.frame:Hide()
    PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)
    if openArcade then
        local window = ns.Window
        window.frame:Show()
        if not window.activeGame then window:OpenHub() end
    end
end
