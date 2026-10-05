-- Achievement toast near the top of the screen; several unlocks queue up.

local _, ns = ...

local Media, Widgets, L = ns.Media, ns.Widgets, ns.L

local Toast = { queue = {} }
ns.Toast = Toast

local FADE_IN, HOLD, FADE_OUT = 0.25, 3.5, 0.6

function Toast:Create()
    local f = CreateFrame("Frame", "DarkmoonArcadeToast", UIParent)
    f:SetSize(340, 85)
    f:SetPoint("TOP", 0, -150)
    f:SetFrameStrata("DIALOG")
    f:Hide()

    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(Media.Tex("toast"))

    local icon = f:CreateTexture(nil, "ARTWORK")
    icon:SetSize(46, 46)
    icon:SetPoint("LEFT", 20, 0)
    self.icon = icon

    local header = Widgets.LocalizedText(f, 11, "gold", "ACHIEVEMENT_EARNED")
    header:SetPoint("TOPLEFT", icon, "TOPRIGHT", 12, -2)
    self.name = Widgets.Text(f, 15, "white")
    self.name:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
    self.desc = Widgets.Text(f, 10, "gray")
    self.desc:SetPoint("TOPLEFT", self.name, "BOTTOMLEFT", 0, -3)
    self.desc:SetWidth(240)
    self.desc:SetJustifyH("LEFT")

    f:SetScript("OnUpdate", function(_, elapsed) self:Update(elapsed) end)
    self.frame = f
end

function Toast:Show(def)
    self.queue[#self.queue + 1] = def
    if not self.current then self:Next() end
end

function Toast:Next()
    local def = table.remove(self.queue, 1)
    self.current = def
    if not def then
        self.frame:Hide()
        return
    end
    self.icon:SetTexture(def.icon)
    self.name:SetText(L[def.nameKey])
    self.desc:SetText(L[def.descKey])
    self.t = 0
    self.frame:SetAlpha(0)
    self.frame:Show()
    Media.Play("flappy/medal")
end

function Toast:Update(elapsed)
    if not self.current then return end
    self.t = self.t + elapsed
    local t = self.t
    if t < FADE_IN then
        self.frame:SetAlpha(t / FADE_IN)
    elseif t < FADE_IN + HOLD then
        self.frame:SetAlpha(1)
    elseif t < FADE_IN + HOLD + FADE_OUT then
        self.frame:SetAlpha(1 - (t - FADE_IN - HOLD) / FADE_OUT)
    else
        self:Next()
    end
end
