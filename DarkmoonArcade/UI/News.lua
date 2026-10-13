-- "What's new": a tab of the arcade window, opened by itself once per version at login (after a
-- first install or an update). News.VERSIONS keeps every release, newest first: one row per
-- highlight (icon, title, a sentence) and an optional thank-you. The versions are listed on the
-- left; updates a player missed since the last visit are marked there.
-- A release adds its entry at the top and its NEWS_<version>_* texts (e.g. NEWS_133_1_TITLE).

local _, ns = ...

local Media, Widgets, L = ns.Media, ns.Widgets, ns.L

local News = {}
ns.News = News

local LIST_W, LIST_ROW, PAD = 250, 54, 18
local ART_H = 150
local ICON, ROW_GAP, COLUMN_GAP = 38, 12, 22
local GOLD = { 1, 0.82, 0.3 }
-- The Darkmoon Faire painting of the Mercenaries camp; its picture spans v 0.255 to 0.815.
local CAMP_ART, CAMP_V0, CAMP_V1 = 2821800, 0.255, 0.815

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


-- The tab ---------------------------------------------------------------------------------------

local function Hairline(parent, alpha)
    local t = parent:CreateTexture(nil, "BORDER")
    t:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], alpha)
    return t
end

-- One version in the list: number, headline, a mark when it was missed.
local function VersionButton(parent, onClick)
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
    b.version = Widgets.Text(b, 16, "gold")
    b.version:SetPoint("TOPLEFT", 18, -9)
    b.headline = Widgets.Text(b, 11, "gray")
    b.headline:SetPoint("TOPLEFT", b.version, "BOTTOMLEFT", 0, -3)
    b.headline:SetWidth(LIST_W - 40)
    b.headline:SetJustifyH("LEFT")
    b.headline:SetWordWrap(false)
    b.mark = b:CreateTexture(nil, "OVERLAY")
    b.mark:SetSize(7, 7)
    b.mark:SetColorTexture(0.35, 1, 0.45, 1)
    b.mark:SetRotation(math.pi / 4)
    b.mark:SetPoint("LEFT", b.version, "RIGHT", 8, 0)
    b:SetScript("OnClick", onClick)
    return b
end

function News:Headline(v)
    return v.headline and L[News.Key(v, "HEADLINE")] or L.NEWS_PATCH:format(v.version)
end

function News:Create(parent)
    local view = CreateFrame("Frame", nil, parent)
    view:SetAllPoints()
    view:SetFrameLevel(parent:GetFrameLevel() + 5)
    view:Hide()
    self.frame = view

    -- Left: every version, newest first.
    local list = CreateFrame("Frame", nil, view)
    list:SetPoint("TOPLEFT", PAD, -PAD)
    list:SetPoint("BOTTOMLEFT", PAD, PAD)
    list:SetWidth(LIST_W)
    local heading = Widgets.LocalizedText(list, 14, "gold", "NEWS_VERSIONS")
    heading:SetPoint("TOPLEFT", 4, 0)
    local rule = Hairline(list, 0.3)
    rule:SetHeight(1)
    rule:SetPoint("TOPLEFT", 0, -22)
    rule:SetPoint("TOPRIGHT", 0, -22)
    self.tabs = {}
    for i in ipairs(News.VERSIONS) do
        local b = VersionButton(list, function() self:Select(i) end)
        b:SetPoint("TOPLEFT", 0, -30 - (i - 1) * (LIST_ROW + 4))
        b.index = i
        self.tabs[i] = b
    end
    self.missedLine = Widgets.Text(list, 11, "white")
    self.missedLine:SetTextColor(0.45, 1, 0.55)
    self.missedLine:SetPoint("TOPLEFT", 4, -30 - #News.VERSIONS * (LIST_ROW + 4) - 8)
    self.missedLine:SetWidth(LIST_W - 8)
    self.missedLine:SetJustifyH("LEFT")
    -- Never open by itself: the same switch as the option.
    local never = CreateFrame("CheckButton", nil, list, "UICheckButtonTemplate")
    never:SetSize(24, 24)
    never:SetPoint("BOTTOMLEFT", 0, 0)
    never:SetScript("OnClick", function(button) ns.db.newsNever = button:GetChecked() and true or false end)
    local neverLabel = Widgets.LocalizedText(list, 11, "gray", "NEWS_NEVER_AUTO")
    neverLabel:SetPoint("LEFT", never, "RIGHT", 4, 0)
    neverLabel:SetWidth(LIST_W - 32)
    neverLabel:SetJustifyH("LEFT")
    self.neverCheck = never

    local divider = Hairline(view, 0.18)
    divider:SetWidth(1)
    divider:SetPoint("TOPLEFT", PAD + LIST_W + PAD, -PAD)
    divider:SetPoint("BOTTOMLEFT", PAD + LIST_W + PAD, PAD)

    -- Right: the camp painting with the version's headline, then its highlights in two columns.
    local left = PAD + LIST_W + PAD * 2
    local art = CreateFrame("Frame", nil, view)
    art:SetPoint("TOPLEFT", left, -PAD)
    art:SetPoint("TOPRIGHT", -PAD, -PAD)
    art:SetHeight(ART_H)
    art:SetClipsChildren(true)
    local picture = art:CreateTexture(nil, "ARTWORK")
    picture:SetAllPoints()
    picture:SetTexture(CAMP_ART)
    self.picture = picture
    local dusk = art:CreateTexture(nil, "ARTWORK", nil, 1)
    dusk:SetAllPoints()
    dusk:SetTexture(Media.Tex("mercs/vignette"))
    dusk:SetAlpha(0.85)
    for i, name in ipairs({ "logo_shadow", "logo" }) do
        local t = art:CreateTexture(nil, "OVERLAY", nil, i)
        t:SetSize(240, 240 * 347 / 1024)
        t:SetPoint("LEFT", 24, 6)
        t:SetTexture(Media.Tex("mercs/" .. name))
        t:SetTexCoord(0, 1, 0, 347 / 512)
    end
    self.headline = Widgets.Text(art, 22, "gold")
    self.headline:SetPoint("BOTTOMRIGHT", -24, 18)
    self.headline:SetShadowOffset(1, -1)
    self.art = art

    local scroll = CreateFrame("ScrollFrame", nil, view, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", art, "BOTTOMLEFT", 0, -16)
    scroll:SetPoint("BOTTOMRIGHT", -PAD - 22, PAD)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(10, 10)
    scroll:SetScrollChild(content)
    self.scroll, self.content = scroll, content

    local rowCount = 0
    for _, v in ipairs(News.VERSIONS) do rowCount = math.max(rowCount, #v.items) end
    self.rows = {}
    for i = 1, rowCount do
        local row = CreateFrame("Frame", nil, content)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(ICON, ICON)
        row.icon:SetPoint("TOPLEFT", 2, -2)
        row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        Widgets.Rim(row, row.icon)
        row.title = Widgets.Text(row, 13, "gold")
        row.title:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 12, 0)
        row.title:SetJustifyH("LEFT")
        row.text = Widgets.Text(row, 11, "white")
        row.text:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -4)
        row.text:SetJustifyH("LEFT")
        row.text:SetTextColor(0.85, 0.83, 0.8)
        row.text:SetSpacing(2)
        self.rows[i] = row
    end
    local thanks = CreateFrame("Frame", nil, content)
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
    thanks.text:SetJustifyH("LEFT")
    thanks.text:SetTextColor(1, 0.86, 0.7)
    self.thanks = thanks

    self.selected, self.missed = 1, {}
    Widgets.OnRefresh(function()
        if self.frame:IsShown() then self:Select(self.selected, true) end
    end)
    return view
end

-- Opens the tab by itself after an update, unless this version's news were already seen.
function News:ShowIfNew()
    local version = ns.Version()
    if ns.db.newsNever or ns.db.newsSeen == version or not self.frame then return end
    self:Show()
end

-- Opens the arcade window on this tab (default: the newest version).
function News:Show(index)
    ns.Window:OpenNews(index)
end

-- Called by the window when the tab opens: marks what was missed, then counts the news as seen.
function News:Refresh(index)
    self.missed = News.Missed(ns.db.newsSeen)
    local names = {}
    for _, v in ipairs(News.VERSIONS) do
        if self.missed[v.version] then names[#names + 1] = v.version end
    end
    self.missedLine:SetText(#names > 0 and L.NEWS_MISSED:format(table.concat(names, ", ")) or "")
    self.neverCheck:SetChecked(ns.db.newsNever and true or false)
    ns.db.newsSeen = ns.Version()
    self:Select(index or 1, true)
end

-- Lays out one version's highlights in two columns and returns the height they take.
function News:Fill(index)
    local v = News.VERSIONS[index]
    local width = math.max(200, (self.scroll:GetWidth() or 780))
    local colW = math.floor((width - COLUMN_GAP) / 2)
    self.content:SetWidth(width)
    local y = 0
    for i = 1, #self.rows, 2 do
        local rowH = 0
        for j = 0, 1 do
            local row, item = self.rows[i + j], v.items[i + j]
            if row then
                row:SetShown(item ~= nil)
                if item then
                    row:SetWidth(colW)
                    row.title:SetWidth(colW - ICON - 16)
                    row.text:SetWidth(colW - ICON - 16)
                    row.icon:SetTexture("Interface\\Icons\\" .. item.icon)
                    row.title:SetText(L[News.Key(v, item.key .. "_TITLE")])
                    row.text:SetText(L[News.Key(v, item.key .. "_TEXT")])
                    local h = math.max(ICON + 4, 2 + (row.title:GetStringHeight() or 13) + 4 + (row.text:GetStringHeight() or 11) + 6)
                    row:ClearAllPoints()
                    row:SetPoint("TOPLEFT", j * (colW + COLUMN_GAP), -y)
                    row:SetHeight(h)
                    rowH = math.max(rowH, h)
                end
            end
        end
        if rowH > 0 then y = y + rowH + ROW_GAP end
    end
    self.thanks:SetShown(v.thanks ~= nil)
    if v.thanks then
        self.thanks.icon:SetTexture("Interface\\Icons\\" .. v.thanks)
        self.thanks.text:SetWidth(width - 60)
        self.thanks.text:SetText(L[News.Key(v, "THANKS")])
        local h = math.max(40, (self.thanks.text:GetStringHeight() or 11) + 18)
        self.thanks:ClearAllPoints()
        self.thanks:SetPoint("TOPLEFT", 0, -(y + 4))
        self.thanks:SetSize(width, h)
        y = y + h + 8
    end
    self.content:SetHeight(math.max(10, y))
    return y
end

function News:Select(index, quiet)
    index = math.max(1, math.min(#News.VERSIONS, index or 1))
    local changed = index ~= self.selected
    self.selected = index
    local v = News.VERSIONS[index]
    self.headline:SetText(self:Headline(v))
    -- The painting at the banner's shape, a little further along for older versions.
    local w = self.art:GetWidth() or 780
    local span = math.min(CAMP_V1 - CAMP_V0, (ART_H / math.max(1, w)) * 1024 / 768)
    local top = CAMP_V0 + (CAMP_V1 - CAMP_V0 - span) * ((index - 1) % 3) / 2
    self.picture:SetTexCoord(0, 1, top, top + span)
    for i, b in ipairs(self.tabs) do
        local vi = News.VERSIONS[i]
        local chosen = i == index
        b.version:SetText(vi.version)
        b.headline:SetText(self:Headline(vi))
        b.fill:SetShown(chosen)
        b.edge:SetShown(chosen)
        b.version:SetTextColor(chosen and 1 or 0.75, chosen and 0.82 or 0.7, chosen and 0.3 or 0.6)
        b.mark:SetShown(self.missed[vi.version] == true)
    end
    self:Fill(index)
    self.scroll:SetVerticalScroll(0)
    local bar = self.scroll.ScrollBar
    if type(bar) == "table" then bar:SetShown((self.content:GetHeight() or 0) > (self.scroll:GetHeight() or 0)) end
    if changed and not quiet then PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB) end
end

function News:Hide()
    if self.frame then self.frame:Hide() end
end
