-- "What's new" window: shown once per version at login, after a first install or an update.
-- Every release rewrites News.ITEMS and the NEWS_* texts: one row per highlight (icon, title, a
-- sentence), an optional thank-you and one line about the earlier versions.

local _, ns = ...

local Media, Widgets, L = ns.Media, ns.Widgets, ns.L

local News = {}
ns.News = News

local WIDTH, TEXT_W, TEXT_H = 560, 480, 216
local ART_W, ART_H = 480, 130
local ICON, ROW_GAP = 38, 10

-- This release's highlights: icon and the number of their NEWS_<n>_TITLE / NEWS_<n>_TEXT.
News.ITEMS = {
    { icon = "INV_Misc_PocketWatch_01" },
    { icon = "INV_Misc_Drum_01" },
    { icon = "INV_Sword_62" },
    { icon = "INV_Misc_Head_Gnoll_01" },
    { icon = "Spell_Holy_MindVision" },
    { icon = "Spell_Holy_SealOfRighteousness" },
    { icon = "INV_Misc_Wrench_01" },
}
-- A thank-you band (NEWS_THANKS); nil when a release has none.
News.THANKS_ICON = "INV_ValentinesCard02"
local TOP, BOTTOM = 70, 112
-- The Darkmoon Faire painting of the Mercenaries camp; its picture spans v 0.255 to 0.815.
local CAMP_ART, CAMP_V0, CAMP_V1 = 2821800, 0.255, 0.815

local TEMPLATES = { "SimplePanelTemplate", "PortraitFrameTemplateNoCloseButton" }

local function Template()
    for _, name in ipairs(TEMPLATES) do
        if C_XMLUtil and C_XMLUtil.GetTemplateInfo and C_XMLUtil.GetTemplateInfo(name) then return name end
    end
    return TEMPLATES[#TEMPLATES]
end

function News:Create()
    local f = CreateFrame("Frame", "DarkmoonArcadeNews", UIParent, Template())
    f:SetSize(WIDTH, TOP + 34 + ART_H + 14 + TEXT_H + BOTTOM)
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
    local headline = Widgets.LocalizedText(art, 18, "gold", "NEWS_HEADLINE")
    headline:SetPoint("BOTTOM", 0, 12)
    headline:SetShadowOffset(1, -1)

    -- The highlights scroll once the window would grow taller than the screen.
    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", art, "BOTTOMLEFT", 0, -14)
    scroll:SetSize(TEXT_W, TEXT_H)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(TEXT_W, TEXT_H)
    scroll:SetScrollChild(content)
    self.scroll, self.content = scroll, content

    -- One row per highlight: icon in a thin rim, gold title, a short sentence, a faint rule.
    self.rows = {}
    for i, item in ipairs(News.ITEMS) do
        local row = CreateFrame("Frame", nil, content)
        row:SetWidth(TEXT_W)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(ICON, ICON)
        row.icon:SetPoint("TOPLEFT", 4, -4)
        row.icon:SetTexture("Interface\\Icons\\" .. item.icon)
        row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        Widgets.Rim(row, row.icon)
        row.title = Widgets.LocalizedText(row, 13, "gold", "NEWS_" .. i .. "_TITLE")
        row.title:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 14, 0)
        row.title:SetWidth(TEXT_W - ICON - 22)
        row.title:SetJustifyH("LEFT")
        row.text = Widgets.LocalizedText(row, 11, "white", "NEWS_" .. i .. "_TEXT")
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
    thanks.text = Widgets.LocalizedText(thanks, 11, "white", "NEWS_THANKS")
    thanks.text:SetPoint("LEFT", thanks.icon, "RIGHT", 10, 0)
    thanks.text:SetWidth(TEXT_W - 60)
    thanks.text:SetJustifyH("LEFT")
    thanks.text:SetTextColor(1, 0.86, 0.7)
    self.thanks = thanks

    -- The earlier versions of this line in one quiet sentence.
    self.earlier = Widgets.LocalizedText(content, 10, "gray", "NEWS_EARLIER")
    self.earlier:SetWidth(TEXT_W - 8)
    self.earlier:SetJustifyH("LEFT")
    self.earlier:SetSpacing(2)

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
end

-- Shows the window unless this version's news were already seen.
function News:ShowIfNew()
    local version = ns.Version()
    if ns.db.newsNever or ns.db.newsSeen == version or not self.frame then return end
    self:Show()
end

function News:Show()
    self.version:SetText(L.VERSION:format(ns.Version()))
    -- Rows stack by their texts' heights; the window grows with them up to the screen, then scrolls.
    local y = 0
    for _, row in ipairs(self.rows) do
        local h = math.max(ICON + 8, 4 + (row.title:GetStringHeight() or 13) + 4 + (row.text:GetStringHeight() or 11) + 8)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetHeight(h)
        y = y + h + ROW_GAP
    end
    local hasThanks = News.THANKS_ICON ~= nil and L.NEWS_THANKS ~= nil and L.NEWS_THANKS ~= ""
    self.thanks:SetShown(hasThanks)
    if hasThanks then
        self.thanks.icon:SetTexture("Interface\\Icons\\" .. News.THANKS_ICON)
        local h = math.max(40, (self.thanks.text:GetStringHeight() or 11) + 18)
        self.thanks:ClearAllPoints()
        self.thanks:SetPoint("TOPLEFT", 0, -(y + 2))
        self.thanks:SetHeight(h)
        y = y + h + 14
    end
    self.earlier:ClearAllPoints()
    self.earlier:SetPoint("TOPLEFT", 4, -y)
    y = y + (self.earlier:GetStringHeight() or 10) + 6

    local chrome = TOP + 34 + ART_H + 14 + BOTTOM
    local height = math.max(TEXT_H, math.ceil(y))
    local room = math.max(TEXT_H, math.floor((UIParent:GetHeight() or 768) * 0.9) - chrome)
    local shown = math.min(height, room)
    self.content:SetHeight(height)
    self.scroll:SetHeight(shown)
    self.scroll:SetVerticalScroll(0)
    local bar = self.scroll.ScrollBar
    if type(bar) == "table" then bar:SetShown(height > shown) end
    self.frame:SetHeight(chrome + shown)
    self.frame:Show()
    PlaySound(SOUNDKIT.IG_MAINMENU_OPEN)
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
