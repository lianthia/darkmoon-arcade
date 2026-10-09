-- The help of Mercenaries: a small handbook with chapters on the left and the chapter's text on a
-- parchment page on the right.

local _, ns = ...
local MC = ns.Mercenaries
local Kit = MC.Kit
local L = ns.L
local Module = MC.Module
local W, H = MC.W, MC.H

local CHAPTERS = {
    { key = "OVERVIEW", icon = "Interface\\Icons\\INV_Misc_Book_09" },
    { key = "ZONES", icon = "Interface\\Icons\\INV_Misc_Map_01" },
    { key = "PATH", icon = "Interface\\Icons\\Ability_Rogue_Sprint" },
    { key = "BATTLE", icon = "Interface\\Icons\\Ability_DualWield" },
    { key = "ROLES", icon = "Interface\\Icons\\INV_Shield_06" },
    { key = "EFFECTS", icon = "Interface\\Icons\\Spell_Holy_DivineIntervention" },
    { key = "MERCS", icon = "Interface\\Icons\\INV_Misc_Coin_02" },
    { key = "TREASURES", icon = "Interface\\Icons\\INV_Misc_Bag_10" },
    { key = "CONTROLS", icon = "Interface\\Icons\\INV_Misc_Note_01" },
}

function Module:BuildHelp(onBack)
    local page = self.overlay:AddPage("help")
    local wood = Kit.Wood(page, W, H, true)
    wood:SetPoint("TOPLEFT")
    local title = Kit.Plaque(page, 260, "HELP", 18)
    title:SetPoint("TOP", 0, -2)

    -- Chapter list.
    page.buttons = {}
    for i, chapter in ipairs(CHAPTERS) do
        local b = CreateFrame("Button", nil, page)
        b:SetSize(196, 40)
        local bg = b:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        Kit.Atlas(bg, "GarrMission_FollowerListButton", MC.Tex("plate"))
        b.glowTex = b:CreateTexture(nil, "OVERLAY")
        b.glowTex:SetAllPoints()
        Kit.Atlas(b.glowTex, "GarrMission_FollowerListButton-Select", MC.Tex("plate"))
        b.glowTex:SetAlpha(0)
        local icon = b:CreateTexture(nil, "ARTWORK")
        icon:SetSize(28, 28)
        icon:SetPoint("LEFT", 8, 0)
        icon:SetTexture(chapter.icon)
        icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        b.text = Kit.Ink(b, 12, { 1, 0.9, 0.7 }, "OUTLINE")
        b.text:SetPoint("LEFT", icon, "RIGHT", 8, 0)
        b.text:SetPoint("RIGHT", -6, 0)
        b.text:SetJustifyH("LEFT")
        b:SetScript("OnClick", function()
            PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
            self:ShowHelpChapter(i)
        end)
        Kit.Hover(b, { grow = 1.03, sound = false })
        Kit.Place(b, 118, 78 + (i - 1) * 46, page)
        page.buttons[i] = b
    end

    -- The chapter on parchment.
    local sheet = CreateFrame("Frame", nil, page)
    sheet:SetPoint("TOPLEFT", 232, -56)
    sheet:SetPoint("BOTTOMRIGHT", -14, 48)
    Kit.Parchment(sheet)
    page.heading = Kit.Ink(sheet, 18, { 0.35, 0.16, 0.04 })
    page.heading:SetPoint("TOPLEFT", 34, -24)
    page.heading:SetPoint("RIGHT", -34, 0)
    page.heading:SetJustifyH("LEFT")
    page.text = Kit.Ink(sheet, 12, { 0.18, 0.11, 0.05 })
    page.text:SetPoint("TOPLEFT", page.heading, "BOTTOMLEFT", 0, -12)
    page.text:SetPoint("RIGHT", -34, 0)
    page.text:SetJustifyH("LEFT")
    page.text:SetJustifyV("TOP")
    page.text:SetSpacing(4)

    local back = Kit.Button(page, 140, 30, "BACK", onBack, "red")
    Kit.Place(back, W - 86, H - 22, page)
    page.refresh = function() self:ShowHelpChapter(self.helpChapter or 1) end
end

function Module:ShowHelpChapter(i)
    local page = self.overlay.pages.help
    self.helpChapter = i
    for k, b in ipairs(page.buttons) do
        b.text:SetText(L["MC_HELP_" .. CHAPTERS[k].key .. "_TITLE"])
        Kit.SetSelected(b, k == i)
    end
    local key = CHAPTERS[i].key
    page.heading:SetText(L["MC_HELP_" .. key .. "_TITLE"])
    if key == "CONTROLS" then
        page.text:SetText((L.MC_HELP:gsub("%s+·%s+", "\n")))
    else
        page.text:SetText(L["MC_HELP_" .. key])
    end
end
