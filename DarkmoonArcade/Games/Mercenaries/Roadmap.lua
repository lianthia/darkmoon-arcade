-- The roadmap: what is planned for Mercenaries, drawn like a bounty map. Each coin on the winding
-- path is a milestone, from today's release at the bottom to ideas at the top; the panel on the
-- right tells what a milestone brings. Its texts (MC_RM_*) are kept up to date with every release.

local _, ns = ...
local MC = ns.Mercenaries
local Kit = MC.Kit
local Widgets, L = ns.Widgets, ns.L
local Module = MC.Module
local W, H = MC.W, MC.H

local SHEET_LEFT, SHEET_RIGHT = 10, 566
local SHEET_CX = (SHEET_LEFT + SHEET_RIGHT) / 2
local PATH_TOP, PATH_BOTTOM = 110, H - 64
local NODE, BIG_NODE = 58, 70
local DASH_GAP = 13

-- status: done, next, planned or idea; the offset winds the path left and right.
local MILESTONES = {
    { status = "done", icon = "INV_Sword_04", offset = 0 },
    { status = "next", icon = "Trade_Engineering", offset = -130 },
    { status = "planned", icon = "INV_Scroll_03", offset = 120 },
    { status = "planned", icon = "INV_Misc_Head_Dragon_01", offset = -110 },
    { status = "planned", icon = "INV_Misc_GroupNeedMore", offset = 130 },
    { status = "idea", icon = "INV_Misc_QuestionMark", offset = 0 },
}
MC.ROADMAP = MILESTONES
local METAL = { done = "gold", next = "gold", planned = "silver", idea = "bronze" }
local STATUS_COLOR = {
    done = { 0.4, 1, 0.4 }, next = { 1, 0.82, 0.2 }, planned = { 0.85, 0.85, 0.85 }, idea = { 0.6, 0.8, 1 },
}
local STATUS_KEY = { done = "MC_RM_DONE", next = "MC_RM_NEXT", planned = "MC_RM_PLANNED", idea = "MC_RM_IDEA" }

local function Point(i)
    local y = PATH_BOTTOM - (i - 1) * (PATH_BOTTOM - PATH_TOP) / (#MILESTONES - 1)
    return SHEET_CX + MILESTONES[i].offset, y
end

local function DarkPanel(parent, x, y, w, h)
    local p = CreateFrame("Frame", nil, parent)
    p:SetSize(w, h)
    p:SetPoint("TOPLEFT", x, -y)
    local fill = p:CreateTexture(nil, "BACKGROUND", nil, 2)
    fill:SetAllPoints()
    fill:SetColorTexture(0.08, 0.05, 0.03, 0.78)
    Widgets.Rim(p, p)
    return p
end

function Module:BuildRoadmap()
    local view = self:AddView("roadmap", CreateFrame("Frame", nil, self.container))
    local wood = Kit.Wood(view, W, H, true)
    wood:SetPoint("TOPLEFT")

    local art = CreateFrame("Frame", nil, view)
    art:SetSize(SHEET_RIGHT - SHEET_LEFT, H - 20)
    art:SetPoint("TOPLEFT", SHEET_LEFT, -10)
    local paper = art:CreateTexture(nil, "BACKGROUND")
    paper:SetAllPoints()
    Kit.Atlas(paper, "spellbook-page-left-c60", MC.Tex("poster"))
    paper:SetTexCoord(0.08, 0.92, 0, 1)
    local vignette = art:CreateTexture(nil, "BORDER")
    vignette:SetAllPoints()
    vignette:SetTexture(MC.Tex("vignette"))
    vignette:SetAlpha(0.45)
    Widgets.Rim(view, art)

    -- The path: gold up to the next milestone, faded beyond it.
    local dashes = CreateFrame("Frame", nil, view)
    dashes:SetAllPoints()
    dashes:SetFrameLevel(art:GetFrameLevel() + 4)
    for i = 1, #MILESTONES - 1 do
        local x1, y1 = Point(i)
        local x2, y2 = Point(i + 1)
        local dx, dy = x2 - x1, y2 - y1
        local length = math.sqrt(dx * dx + dy * dy)
        local ahead = MILESTONES[i + 1].status ~= "next" and MILESTONES[i].status ~= "done"
        local d = BIG_NODE / 2 + 6
        while d < length - BIG_NODE / 2 - 4 do
            local t = dashes:CreateTexture(nil, "ARTWORK")
            t:SetTexture(MC.Tex("dash"))
            t:SetSize(14, 7)
            t:SetPoint("CENTER", dashes, "TOPLEFT", x1 + dx * d / length, -(y1 + dy * d / length))
            t:SetRotation(math.atan2(-dy, dx))
            if ahead then t:SetVertexColor(0.35, 0.27, 0.18, 0.55) else t:SetVertexColor(0.55, 0.36, 0.12, 0.95) end
            d = d + DASH_GAP
        end
    end

    local nodes = CreateFrame("Frame", nil, view)
    nodes:SetAllPoints()
    nodes:SetFrameLevel(dashes:GetFrameLevel() + 2)
    self.roadmapNodes = {}
    for i, stone in ipairs(MILESTONES) do
        local big = stone.status == "done" or stone.status == "next"
        local size = big and BIG_NODE or NODE
        local b = Kit.Coin(nodes, size)
        b:SetMetal(METAL[stone.status])
        b:SetIcon("Interface\\Icons\\" .. stone.icon)
        if stone.status == "idea" then b.icon:SetDesaturated(true) end
        b.check:SetShown(stone.status == "done")
        local x, y = Point(i)
        Kit.Place(b, x, y, nodes)
        -- The milestone's name on a plate beside the coin, on the side away from the path's middle.
        b.plate = Kit.Banner(nodes, 168, 30, 11)
        if stone.offset < 0 then
            b.plate:SetPoint("LEFT", nodes, "TOPLEFT", x + size / 2 + 2, -y)
        elseif stone.offset > 0 then
            b.plate:SetPoint("RIGHT", nodes, "TOPLEFT", x - size / 2 - 2, -y)
        else
            b.plate:SetPoint("LEFT", nodes, "TOPLEFT", x + size / 2 + 2, -y)
        end
        Widgets.OnRefresh(function() b.plate.text:SetText(L["MC_RM_" .. i .. "_TITLE"]) end)
        b:SetScript("OnClick", function() self:SelectMilestone(i) end)
        b:HookScript("OnEnter", function() self:ShowMilestone(i) end)
        b:HookScript("OnLeave", function() self:ShowMilestone(self.roadmapSelection) end)
        Kit.Hover(b, { grow = 1.12, sound = false })
        self.roadmapNodes[i] = b
    end
    -- "You are here": today's release.
    local here = nodes:CreateTexture(nil, "OVERLAY", nil, 4)
    here:SetSize(26, 26)
    here:SetTexture("Interface\\Minimap\\MiniMap-QuestArrow")
    here:SetRotation(math.pi)
    here:SetPoint("BOTTOM", self.roadmapNodes[1], "TOP", 0, -6)

    local top = CreateFrame("Frame", nil, view)
    top:SetAllPoints()
    top:SetFrameLevel(nodes:GetFrameLevel() + 10)
    local plaque = Kit.Plaque(top, 300, "MC_ROADMAP", 16)
    plaque:SetPoint("TOP", view, "TOPLEFT", SHEET_CX, -4)

    -- The chosen milestone on the right.
    local panelW = W - SHEET_RIGHT - 20
    local info = DarkPanel(view, SHEET_RIGHT + 10, 10, panelW, H - 20)
    local infoTitle = Kit.Plaque(info, 190, "MC_RM_MILESTONE", 14)
    infoTitle:SetPoint("TOP", 0, 6)
    view.infoIcon = Kit.Coin(info, 96)
    view.infoIcon:SetPoint("CENTER", info, "TOP", 0, -96)
    view.infoIcon:EnableMouse(false)
    view.infoName = Kit.Banner(info, panelW - 24, 36, 13)
    view.infoName:SetPoint("TOP", view.infoIcon, "BOTTOM", 0, 2)
    view.infoStatus = Kit.Ink(info, 12, { 1, 1, 1 }, "OUTLINE")
    view.infoStatus:SetPoint("TOP", view.infoName, "BOTTOM", 0, -2)
    view.infoText = Widgets.Text(info, 12, "white")
    view.infoText:SetPoint("TOPLEFT", info, "TOPLEFT", 14, -206)
    view.infoText:SetWidth(panelW - 28)
    view.infoText:SetJustifyH("LEFT")
    view.infoText:SetJustifyV("TOP")
    view.infoText:SetSpacing(4)
    local back = Kit.Button(info, 120, 28, "BACK", function() self:ShowView("camp") end, "red")
    Kit.Place(back, panelW / 2, H - 42, info)
    local hint = Widgets.Text(info, 10, "gray")
    hint:SetPoint("BOTTOM", info, "BOTTOM", 0, 62)
    hint:SetWidth(panelW - 28)
    Widgets.OnRefresh(function() hint:SetText(L.MC_RM_HINT) end)

    view.refresh = function() self:RefreshRoadmap() end
end

function Module:RefreshRoadmap()
    self:SetScene(nil)
    local first = 1
    for i, stone in ipairs(MILESTONES) do
        if stone.status == "next" then first = i end
    end
    self:SelectMilestone(self.roadmapSelection or first)
end

function Module:SelectMilestone(i)
    self.roadmapSelection = i
    for k, b in ipairs(self.roadmapNodes) do
        Kit.SetSelected(b, k == i, true)
        Kit.SetPulse(b, (k ~= i and MILESTONES[k].status == "next") and 0.5 or nil)
    end
    self:ShowMilestone(i)
end

function Module:ShowMilestone(i)
    local view, stone = self.views.roadmap, MILESTONES[i]
    if not stone then return end
    view.infoIcon:SetMetal(METAL[stone.status])
    view.infoIcon:SetIcon("Interface\\Icons\\" .. stone.icon)
    view.infoName.text:SetText(L["MC_RM_" .. i .. "_TITLE"])
    local color = STATUS_COLOR[stone.status]
    view.infoStatus:SetTextColor(color[1], color[2], color[3])
    view.infoStatus:SetText(L[STATUS_KEY[stone.status]])
    view.infoText:SetText(L["MC_RM_" .. i .. "_TEXT"])
end

