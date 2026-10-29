-- "What's new": a tab of the arcade window, opened by itself once per version at login (after a
-- first install or an update). News.VERSIONS keeps every release, newest first: one row per
-- highlight (icon, title, a sentence) and an optional thank-you. The versions are listed on the
-- left; updates a player missed since the last visit are marked there.
-- A release adds its entry at the top and its NEWS_<version>_* texts (e.g. NEWS_133_1_TITLE).

local _, ns = ...

local Media, Widgets, Style, L = ns.Media, ns.Widgets, ns.Style, ns.L
local C = Style.C

local News = {}
ns.News = News

local PAD = Style.PAGE_PAD
local ART_H = 150
local ICON, ROW_GAP, COLUMN_GAP, CARD_PAD = 36, 8, 8, 16
-- The Darkmoon Faire painting of the Mercenaries camp; its picture spans v 0.255 to 0.815.
local CAMP_ART, CAMP_V0, CAMP_V1 = 2821800, 0.255, 0.815

-- Every release, newest first. items: icon and the number of their NEWS_<tag>_<key>_TITLE /
-- _TEXT (tag: the version without dots); thanks: icon of the band NEWS_<tag>_THANKS;
-- headline: the version has its own NEWS_<tag>_HEADLINE instead of "Patch x.y.z"; alpha: marked as a
-- preview in the list (drop it for the stable release); art: a banner picture of its own instead of the
-- camp painting. An item with `planned` is announced for the release but not in this build yet: its row
-- is dimmed and says so.
News.VERSIONS = {
    {
        version = "1.4.2",
        items = {
            { icon = "Spell_Holy_Resurrection", key = 1 },
        },
        thanks = "INV_ValentinesCard02",
    },
    {
        version = "1.4.1",
        items = {
            { icon = "INV_Enchant_EssenceEternalLarge", key = 1 },
            { icon = "INV_Misc_Note_01", key = 2 },
        },
    },
    {
        version = "1.4.0",
        headline = true,
        -- The Mercenaries key art (910x512 of a 1024x512 texture), round the heroes' faces.
        art = { tex = "launcher/mercenaries", width = 910, height = 512, texWidth = 1024, texHeight = 512, v = 0.4 },
        items = {
            { icon = "INV_Misc_Spyglass_02", key = 1 },
            { icon = "INV_Jewelry_Talisman_04", key = 2 },
            { icon = "Spell_Fire_SealOfFire", key = 3 },
            { icon = "Spell_Fire_FlameBolt", key = 4 },
            { icon = "Ability_Warrior_BattleShout", key = 5 },
            { icon = "Spell_Holy_SurgeOfLight", key = 6 },
            { icon = "Achievement_General", key = 7 },
            { icon = "INV_Misc_Book_09", key = 8 },
            { icon = "INV_Misc_Note_01", key = 9 },
            { icon = "INV_Misc_Bone_HumanSkull_01", key = 10 },
            { icon = "INV_Sword_24", key = 11 },
            { icon = "INV_Enchant_DustStrange", key = 12 },
            { icon = "Spell_Holy_SealOfWisdom", key = 13 },
            { icon = "INV_Misc_Head_Dragon_01", key = 14 },
        },
    },
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

function News:Headline(v)
    return v.headline and L[News.Key(v, "HEADLINE")] or L.NEWS_PATCH:format(v.version)
end

function News:Create(parent)
    local view = CreateFrame("Frame", nil, parent)
    view:SetAllPoints()
    view:SetFrameLevel(parent:GetFrameLevel() + 5)
    view:Hide()
    self.frame = view

    -- Left: every version, newest first; a green dot marks the ones a player missed.
    local list = Style.SideList(view, "NEWS_VERSIONS")
    self.tabs = {}
    for i in ipairs(News.VERSIONS) do
        local b = Style.ListItem(list, function() self:Select(i) end, true)
        b:SetPoint("TOPLEFT", 8, -list.top - (i - 1) * 50)
        b.mark = b:CreateTexture(nil, "OVERLAY")
        b.mark:SetSize(6, 6)
        b.mark:SetTexture(Media.Tex("dot"))
        b.mark:SetVertexColor(unpack(C.ready))
        b.mark:SetPoint("RIGHT", -14, 0)
        b.index = i
        self.tabs[i] = b
    end
    self.missedLine = Style.Text(list, 10, C.ready)
    self.missedLine:SetPoint("TOPLEFT", 16, -list.top - #News.VERSIONS * 50 - 6)
    self.missedLine:SetWidth(Style.LIST_W - 32)
    self.missedLine:SetWordWrap(true)
    -- Never open by itself: the same switch as the option.
    local never = CreateFrame("CheckButton", nil, list, "UICheckButtonTemplate")
    never:SetSize(24, 24)
    never:SetPoint("BOTTOMLEFT", 10, 10)
    never:SetScript("OnClick", function(button) ns.db.newsNever = button:GetChecked() and true or false end)
    local neverLabel = Style.LocalizedText(list, 10, C.muted, "NEWS_NEVER_AUTO")
    neverLabel:SetPoint("LEFT", never, "RIGHT", 4, 0)
    neverLabel:SetWidth(Style.LIST_W - 52)
    neverLabel:SetWordWrap(true)
    self.neverCheck = never

    -- Right: the camp painting with the version's headline, then its highlights on plates in two
    -- columns.
    local art = CreateFrame("Frame", nil, view)
    art:SetPoint("TOPLEFT", Style.CONTENT_X, -PAD)
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
    local top = CreateFrame("Frame", nil, art)
    top:SetAllPoints()
    top:SetFrameLevel(art:GetFrameLevel() + 5)
    Style.CutCorners(top, art, 8, C.window)
    self.tag = Style.Caption(top, "NEWS_TITLE")
    self.tag:SetTextColor(unpack(C.gold))
    self.tag:SetPoint("BOTTOMRIGHT", -24, 50)
    self.headline = Style.Text(top, 22, C.text)
    self.headline:SetPoint("TOPRIGHT", self.tag, "BOTTOMRIGHT", 0, -6)
    self.headline:SetShadowOffset(1, -1)
    self.art = art

    local scroll = CreateFrame("ScrollFrame", nil, view, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", art, "BOTTOMLEFT", 0, -8)
    scroll:SetPoint("BOTTOMRIGHT", -PAD - 22, PAD)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(10, 10)
    scroll:SetScrollChild(content)
    self.scroll, self.content = scroll, content

    local rowCount = 0
    for _, v in ipairs(News.VERSIONS) do rowCount = math.max(rowCount, #v.items) end
    self.rows = {}
    for i = 1, rowCount do
        local row = Style.Panel(content)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(ICON, ICON)
        row.icon:SetPoint("TOPLEFT", CARD_PAD, -CARD_PAD)
        row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        Style.CutCorners(row, row.icon, 6, C.surface)
        row.title = Style.Text(row, 12, C.text)
        row.title:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 12, -1)
        row.title:SetWordWrap(true)
        -- "Not in this build yet" under the title of a planned item.
        row.planned = Style.LocalizedText(row, 9, C.gold, "NEWS_PLANNED")
        row.planned:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -4)
        row.text = Style.Text(row, 11, C.muted)
        row.text:SetWordWrap(true)
        row.text:SetSpacing(3)
        self.rows[i] = row
    end
    local thanks = CreateFrame("Frame", nil, content)
    Style.Rounded(thanks, thanks, 8, C.itemActive)
    Style.Rounded(thanks, thanks, 8, { C.gold[1], C.gold[2], C.gold[3], 0.5 }, "BORDER", 0, "ring")
    thanks.icon = thanks:CreateTexture(nil, "ARTWORK")
    thanks.icon:SetSize(26, 26)
    thanks.icon:SetPoint("LEFT", 14, 0)
    thanks.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    Style.CutCorners(thanks, thanks.icon, 5, C.itemActive)
    thanks.text = Style.Text(thanks, 11, C.gold)
    thanks.text:SetPoint("LEFT", thanks.icon, "RIGHT", 12, 0)
    thanks.text:SetWordWrap(true)
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

-- Lays out one version's highlights on plates in two columns and returns the height they take.
function News:Fill(index)
    local v = News.VERSIONS[index]
    local width = math.max(200, (self.scroll:GetWidth() or 700))
    local colW = math.floor((width - COLUMN_GAP) / 2)
    local textW = colW - ICON - 12 - 2 * CARD_PAD
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
                    row.title:SetWidth(textW)
                    row.text:SetWidth(textW)
                    row.icon:SetTexture("Interface\\Icons\\" .. item.icon)
                    row.title:SetText(L[News.Key(v, item.key .. "_TITLE")])
                    row.text:SetText(L[News.Key(v, item.key .. "_TEXT")])
                    local planned = item.planned == true
                    row.planned:SetShown(planned)
                    row.icon:SetDesaturated(planned)
                    row.icon:SetAlpha(planned and 0.6 or 1)
                    row.title:SetTextColor(unpack(planned and C.muted or C.text))
                    row.text:SetTextColor(unpack(planned and C.dim or C.muted))
                    row.text:ClearAllPoints()
                    row.text:SetPoint("TOPLEFT", planned and row.planned or row.title, "BOTTOMLEFT", 0, -5)
                    local tag = planned and ((row.planned:GetStringHeight() or 9) + 4) or 0
                    local h = math.max(ICON, 1 + (row.title:GetStringHeight() or 13) + tag + 5 + (row.text:GetStringHeight() or 11))
                    row:ClearAllPoints()
                    row:SetPoint("TOPLEFT", j * (colW + COLUMN_GAP), -y)
                    rowH = math.max(rowH, h + 2 * CARD_PAD)
                end
            end
        end
        -- Both plates of a row are as tall as the taller one.
        for j = 0, 1 do
            local row = self.rows[i + j]
            if row and v.items[i + j] then row:SetHeight(rowH) end
        end
        if rowH > 0 then y = y + rowH + ROW_GAP end
    end
    self.thanks:SetShown(v.thanks ~= nil)
    if v.thanks then
        self.thanks.icon:SetTexture("Interface\\Icons\\" .. v.thanks)
        self.thanks.text:SetWidth(width - 70)
        self.thanks.text:SetText(L[News.Key(v, "THANKS")])
        local h = math.max(44, (self.thanks.text:GetStringHeight() or 11) + 22)
        self.thanks:ClearAllPoints()
        self.thanks:SetPoint("TOPLEFT", 0, -y)
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
    local w = self.art:GetWidth() or 780
    if v.art then
        -- A picture of its own: its full width, the band round its centre `v` at the banner's shape.
        local pw, ph = v.art.width, v.art.height
        local span = math.min(1, (pw * ART_H / math.max(1, w)) / ph) * ph / v.art.texHeight
        local top = math.max(0, math.min(ph / v.art.texHeight - span, v.art.v - span / 2))
        self.picture:SetTexture(Media.Tex(v.art.tex))
        self.picture:SetTexCoord(0, pw / v.art.texWidth, top, top + span)
    else
        -- The camp painting at the banner's shape, a little further along for older versions.
        local span = math.min(CAMP_V1 - CAMP_V0, (ART_H / math.max(1, w)) * 1024 / 768)
        local top = CAMP_V0 + (CAMP_V1 - CAMP_V0 - span) * ((index - 1) % 3) / 2
        self.picture:SetTexture(CAMP_ART)
        self.picture:SetTexCoord(0, 1, top, top + span)
    end
    for i, b in ipairs(self.tabs) do
        local vi = News.VERSIONS[i]
        local chosen = i == index
        b.label:SetText(vi.version .. (vi.alpha and " Alpha" or ""))
        b.sub:SetText(self:Headline(vi))
        b:SetActive(chosen)
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
