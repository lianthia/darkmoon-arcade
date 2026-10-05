-- Minimap button in the style of LibDBIcon, plus the AddOns compartment entry.

local _, ns = ...

local Media, L = ns.Media, ns.L

local MinimapButton = {}
ns.Minimap = MinimapButton

local RADIUS_PADDING = 5
local CORNER_INSET = 10

local function Place(button, angle)
    local radians = math.rad(angle)
    local x, y = math.cos(radians), math.sin(radians)
    local halfWidth = Minimap:GetWidth() / 2 + RADIUS_PADDING
    local halfHeight = Minimap:GetHeight() / 2 + RADIUS_PADDING
    if GetMinimapShape and GetMinimapShape() == "SQUARE" then
        local reachX = math.sqrt(2 * halfWidth * halfWidth) - CORNER_INSET
        local reachY = math.sqrt(2 * halfHeight * halfHeight) - CORNER_INSET
        x = math.max(-halfWidth, math.min(x * reachX, halfWidth))
        y = math.max(-halfHeight, math.min(y * reachY, halfHeight))
    else
        x, y = x * halfWidth, y * halfHeight
    end
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function FollowCursor(button)
    local centerX, centerY = Minimap:GetCenter()
    if not centerX then return end
    local scale = Minimap:GetEffectiveScale()
    local cursorX, cursorY = GetCursorPosition()
    ns.db.minimapAngle = math.deg(math.atan2(cursorY / scale - centerY, cursorX / scale - centerX)) % 360
    Place(button, ns.db.minimapAngle)
end

local function OnClick(mouseButton)
    if mouseButton == "RightButton" then
        ns.Settings:Open()
    else
        ns.Window:Toggle()
    end
end

local function ShowTooltip(owner, canDrag)
    GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
    GameTooltip:SetText(L.TITLE, 1, 0.82, 0)
    GameTooltip:AddLine(L.MINIMAP_LEFT, 1, 1, 1)
    GameTooltip:AddLine(L.MINIMAP_RIGHT, 1, 1, 1)
    if canDrag then GameTooltip:AddLine(L.MINIMAP_DRAG, 0.62, 0.62, 0.62) end
    GameTooltip:Show()
end

function DarkmoonArcade_OnAddonCompartmentClick(_, mouseButton)
    OnClick(mouseButton)
end

function DarkmoonArcade_OnAddonCompartmentEnter(_, menuButton)
    ShowTooltip(menuButton, false)
end

function DarkmoonArcade_OnAddonCompartmentLeave()
    GameTooltip:Hide()
end

function MinimapButton:Create()
    local b = CreateFrame("Button", "DarkmoonArcadeMinimapButton", Minimap)
    b:SetSize(31, 31)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local background = b:CreateTexture(nil, "BACKGROUND")
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetSize(24, 24)
    background:SetPoint("CENTER")

    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(Media.ICON)
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")

    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(50, 50)
    border:SetPoint("TOPLEFT")

    b:SetScript("OnClick", function(_, mouseButton) OnClick(mouseButton) end)
    b:SetScript("OnEnter", function(button)
        if not button.dragging then ShowTooltip(button, true) end
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    b:SetScript("OnDragStart", function(button)
        button.dragging = true
        GameTooltip_Hide()
        button:SetScript("OnUpdate", FollowCursor)
    end)
    b:SetScript("OnDragStop", function(button)
        button:SetScript("OnUpdate", nil)
        button.dragging = false
    end)

    self.button = b
    self:Update()
end

function MinimapButton:Update()
    local b = self.button
    if not b then return end
    Place(b, ns.db.minimapAngle)
    b:SetShown(ns.db.minimap)
end
