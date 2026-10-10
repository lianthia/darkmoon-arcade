-- Roadmap page inside the arcade window: what is planned next, one block per milestone.
-- Its texts (ROADMAP_*) are kept up to date with every release.

local _, ns = ...

local Widgets, L = ns.Widgets, ns.L

local RoadmapView = {}
ns.RoadmapView = RoadmapView

local MILESTONES = 5
local TAG_COLORS = { next = { 0.4, 1, 0.4 }, planned = { 1, 0.82, 0 }, ideas = { 0.6, 0.8, 1 } }
local TAGS = { "next", "planned", "planned", "planned", "ideas" }

function RoadmapView:Create(parent)
    local view = CreateFrame("Frame", nil, parent)
    view:SetAllPoints()
    view:SetFrameLevel(parent:GetFrameLevel() + 5)
    view:Hide()
    self.view = view

    local title = Widgets.LocalizedText(view, 20, "gold", "ROADMAP")
    title:SetPoint("TOP", 0, -10)

    local panel = CreateFrame("Frame", nil, view)
    panel:SetPoint("TOPLEFT", 70, -44)
    panel:SetPoint("BOTTOMRIGHT", -70, 30)
    local fill = panel:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    fill:SetColorTexture(0, 0, 0, 0.32)
    Widgets.Rim(panel, panel)

    local note = Widgets.LocalizedText(view, 11, "gray", "ROADMAP_NOTE")
    note:SetPoint("TOP", panel, "BOTTOM", 0, -9)

    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, -6)
    scroll:SetPoint("BOTTOMRIGHT", -26, 6)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(panel:GetWidth() > 0 and panel:GetWidth() - 26 or 474)
    scroll:SetScrollChild(content)
    scroll:SetScript("OnSizeChanged", function(_, width) content:SetWidth(width) end)
    self.content = content

    self.blocks = {}
    for i = 1, MILESTONES do
        local block = {
            title = Widgets.Text(content, 14, "gold"),
            tag = Widgets.Text(content, 11, "white"),
            rule = content:CreateTexture(nil, "ARTWORK"),
            text = Widgets.Text(content, 12, "white"),
        }
        block.title:SetJustifyH("LEFT")
        block.rule:SetColorTexture(0.86, 0.66, 0.3, 0.25)
        block.rule:SetHeight(1)
        block.text:SetJustifyH("LEFT")
        block.text:SetJustifyV("TOP")
        block.text:SetSpacing(3)
        local color = TAG_COLORS[TAGS[i]]
        block.tag:SetTextColor(color[1], color[2], color[3])
        self.blocks[i] = block
    end
    return view
end

-- Lays the milestones out top to bottom; wrapped texts decide each block's height.
function RoadmapView:Refresh()
    local width = math.max(200, self.content:GetWidth() - 44)
    local y = -8
    for i, block in ipairs(self.blocks) do
        block.title:ClearAllPoints()
        block.title:SetPoint("TOPLEFT", 18, y)
        block.title:SetText(L["ROADMAP_" .. i .. "_TITLE"])
        block.tag:ClearAllPoints()
        block.tag:SetPoint("TOPRIGHT", -14, y - 2)
        block.tag:SetText(L["ROADMAP_TAG_" .. TAGS[i]:upper()])
        block.rule:ClearAllPoints()
        block.rule:SetPoint("TOPLEFT", 18, y - 20)
        block.rule:SetPoint("TOPRIGHT", -8, y - 20)
        block.text:ClearAllPoints()
        block.text:SetPoint("TOPLEFT", 26, y - 28)
        block.text:SetWidth(width)
        block.text:SetText(L["ROADMAP_" .. i .. "_TEXT"])
        y = y - 28 - (block.text:GetStringHeight() or 0) - 18
    end
    self.content:SetHeight(-y)
end

function RoadmapView:Show()
    self.view:Show()
    self:Refresh()
end

function RoadmapView:Hide()
    if self.view then self.view:Hide() end
end
