-- "What's new" window: shown once per version at login, after a first install or an update.
-- Its texts (NEWS_*) are rewritten for every release.

local _, ns = ...

local Media, Widgets, L = ns.Media, ns.Widgets, ns.L

local News = {}
ns.News = News

local WIDTH, TEXT_W, TEXT_H = 520, 440, 216
local ART_W, ART_H = 440, 170
local TOP, BOTTOM = 70, 62
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
    f:SetSize(WIDTH, TOP + 34 + ART_H + 16 + TEXT_H + BOTTOM)
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

    self.text = Widgets.LocalizedText(f, 12, "white", "NEWS_TEXT")
    self.text:SetPoint("TOP", art, "BOTTOM", 0, -16)
    self.text:SetSize(TEXT_W, TEXT_H)
    self.text:SetJustifyH("LEFT")
    self.text:SetJustifyV("TOP")
    self.text:SetSpacing(4)

    local show = Widgets.Button(f, 210, 28, "NEWS_SHOW", function() self:Close(true) end)
    show:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -6, 20)
    local ok = Widgets.Button(f, 210, 28, "NEWS_OK", function() self:Close(false) end)
    ok:SetPoint("BOTTOMLEFT", f, "BOTTOM", 6, 20)

    self.showButton, self.okButton = show, ok
    self.art = art
    self.frame = f
end

-- Shows the window unless this version's news were already seen.
function News:ShowIfNew()
    local version = ns.Version()
    if ns.db.newsSeen == version or not self.frame then return end
    self:Show()
end

function News:Show()
    self.version:SetText(L.VERSION:format(ns.Version()))
    self.frame:Show()
    PlaySound(SOUNDKIT.IG_MAINMENU_OPEN)
end

-- Both buttons retire the news of this version; one also opens the arcade.
function News:Close(openArcade)
    ns.db.newsSeen = ns.Version()
    self.frame:Hide()
    PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)
    if openArcade then
        local window = ns.Window
        window.frame:Show()
        if not window.activeGame then window:OpenHub() end
    end
end
