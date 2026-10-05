local _, ns = ...

local Media, L = ns.Media, ns.L

local MinimapButton = {}
ns.Minimap = MinimapButton

local RADIUS = 80

local function UpdatePosition(button)
    local angle = math.rad(ns.db.minimapAngle)
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * RADIUS, math.sin(angle) * RADIUS)
end

local function OnDragUpdate(button)
    local mx, my = Minimap:GetCenter()
    local scale = Minimap:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    ns.db.minimapAngle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
    UpdatePosition(button)
end

function MinimapButton:Create()
    local b = CreateFrame("Button", "MurlocBlastMinimapButton", Minimap)
    b:SetSize(31, 31)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local background = b:CreateTexture(nil, "BACKGROUND")
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetSize(20, 20)
    background:SetPoint("TOPLEFT", 7, -5)

    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(Media.ICON)
    icon:SetSize(19, 19)
    icon:SetPoint("TOPLEFT", 6, -6)

    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")

    b:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            ns.Window:OpenOptions()
        else
            ns.Window:Toggle()
        end
    end)
    b:SetScript("OnDragStart", function(button)
        button:SetScript("OnUpdate", OnDragUpdate)
    end)
    b:SetScript("OnDragStop", function(button)
        button:SetScript("OnUpdate", nil)
    end)
    b:SetScript("OnEnter", function(button)
        GameTooltip:SetOwner(button, "ANCHOR_LEFT")
        GameTooltip:AddLine(L.TITLE, 1, 0.82, 0.2)
        local difficulty = ns.db.difficulty
        local best = ns.db.scores[difficulty][1]
        GameTooltip:AddLine(L.BEST:format(ns.FormatNumber(best and best.score or 0)) .. "  (" .. L[difficulty:upper()] .. ")", 1, 1, 1)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L.MINIMAP_LEFT, 0.75, 0.92, 1)
        GameTooltip:AddLine(L.MINIMAP_RIGHT, 0.75, 0.92, 1)
        GameTooltip:AddLine(L.MINIMAP_DRAG, 0.65, 0.65, 0.65)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)

    self.button = b
    self:Update()
end

function MinimapButton:Update()
    local b = self.button
    if not b then return end
    UpdatePosition(b)
    b:SetShown(ns.db.minimap)
end
