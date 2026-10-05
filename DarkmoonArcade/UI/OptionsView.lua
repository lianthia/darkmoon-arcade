-- Options inside the arcade window, built from the shared definitions in Settings.lua.

local _, ns = ...

local Widgets, L = ns.Widgets, ns.L

local OptionsView = {}
ns.OptionsView = OptionsView

local CHECK_ROW, CHOICE_ROW, SECTION_ROW = 30, 32, 30

local function Tooltip(region, def)
    region:SetScript("OnEnter", function(owner)
        if not def.tip then return end
        GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
        GameTooltip:SetText(L[def.label], 1, 0.82, 0)
        GameTooltip:AddLine(L[def.tip], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    region:SetScript("OnLeave", GameTooltip_Hide)
end

local function RangeValues(def)
    local values, count = {}, math.floor((def.max - def.min) / def.step + 0.5)
    for i = 0, count do values[#values + 1] = math.floor((def.min + i * def.step) * 100 + 0.5) / 100 end
    return values
end

local function NearestIndex(values, value)
    local best, bestDiff = 1, math.huge
    for i, v in ipairs(values) do
        local diff = math.abs(v - (value or 0))
        if diff < bestDiff then best, bestDiff = i, diff end
    end
    return best
end

function OptionsView:Create(parent)
    local view = CreateFrame("Frame", nil, parent)
    view:SetAllPoints()
    view:SetFrameLevel(parent:GetFrameLevel() + 5)
    view:Hide()
    self.view = view

    local title = Widgets.LocalizedText(view, 20, "gold", "OPTIONS")
    title:SetPoint("TOP", 0, -10)

    local panel = CreateFrame("Frame", nil, view)
    panel:SetPoint("TOPLEFT", 70, -46)
    panel:SetPoint("BOTTOMRIGHT", -70, 6)
    local fill = panel:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    fill:SetColorTexture(0, 0, 0, 0.32)
    Widgets.Rim(panel, panel)

    self.rows = {}
    local y = -10
    for _, def in ipairs(ns.Settings.Definitions()) do
        local row = { def = def }
        if def.kind == "section" then
            local text = Widgets.LocalizedText(panel, 14, "gold", def.label)
            text:SetPoint("TOPLEFT", 18, y - 6)
            local line = panel:CreateTexture(nil, "ARTWORK")
            line:SetColorTexture(0.86, 0.66, 0.3, 0.25)
            line:SetPoint("TOPLEFT", 18, y - 24)
            line:SetPoint("TOPRIGHT", -18, y - 24)
            line:SetHeight(1)
            y = y - SECTION_ROW
        elseif def.kind == "check" then
            local check = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
            check:SetSize(26, 26)
            check:SetPoint("TOPLEFT", 14, y)
            local label = Widgets.LocalizedText(panel, 12, "white", def.label)
            label:SetPoint("LEFT", check, "RIGHT", 6, 0)
            check:SetScript("OnClick", function(button)
                def.tbl[def.key] = button:GetChecked() and true or false
                if def.onChange then def.onChange(def.tbl[def.key]) end
            end)
            Tooltip(check, def)
            row.check = check
            y = y - CHECK_ROW
        else
            local label = Widgets.LocalizedText(panel, 12, "white", def.label)
            label:SetPoint("TOPLEFT", 20, y - 6)
            local cycler = Widgets.Cycler(panel, 210, function(dir) self:Step(row, dir) end)
            cycler:SetPoint("TOPRIGHT", -16, y)
            cycler:EnableMouse(true)
            Tooltip(cycler, def)
            row.cycler = cycler
            y = y - CHOICE_ROW
        end
        self.rows[#self.rows + 1] = row
    end
    return view
end

function OptionsView:Step(row, dir)
    local def = row.def
    if def.kind == "choice" then
        local values = {}
        for _, choice in ipairs(def.choices()) do values[#values + 1] = choice[1] end
        def.tbl[def.key] = Widgets.Cycle(values, def.tbl[def.key], dir)
    else
        local values = RangeValues(def)
        local index = math.max(1, math.min(#values, NearestIndex(values, def.tbl[def.key]) + dir))
        def.tbl[def.key] = values[index]
    end
    if def.onChange then def.onChange(def.tbl[def.key]) end
    self:Refresh()
end

function OptionsView:Refresh()
    for _, row in ipairs(self.rows) do
        local def = row.def
        if row.check then
            row.check:SetChecked(def.tbl[def.key] and true or false)
        elseif row.cycler then
            local label = row.cycler.label
            if def.kind == "choice" then
                local value, text = def.tbl[def.key], tostring(def.tbl[def.key])
                for _, choice in ipairs(def.choices()) do
                    if choice[1] == value then text = choice[2] end
                end
                -- Language names need the font of their own script.
                if def.key == "language" then
                    label:SetFont(ns.Media.FontFile(value ~= "auto" and value or ns.language), 13, "OUTLINE")
                end
                label:SetText(text)
            else
                label:SetText(def.format(def.tbl[def.key]))
            end
        end
    end
end

function OptionsView:Show()
    self:Refresh()
    self.view:Show()
end

function OptionsView:Hide()
    self.view:Hide()
end
