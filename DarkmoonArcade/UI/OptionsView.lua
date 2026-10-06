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

local function TemplateExists(name)
    return C_XMLUtil and C_XMLUtil.GetTemplateInfo and C_XMLUtil.GetTemplateInfo(name) ~= nil
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

-- { value, label } pairs for a choice or range definition.
local function Choices(def)
    if def.kind == "choice" then return def.choices() end
    local choices = {}
    for _, value in ipairs(RangeValues(def)) do choices[#choices + 1] = { value, def.format(value) } end
    return choices
end

local function IsCurrent(def, value)
    local current = def.tbl[def.key]
    if type(value) == "number" then return math.abs((current or 0) - value) < 0.001 end
    return current == value
end

function OptionsView:Set(def, value)
    def.tbl[def.key] = value
    if def.onChange then def.onChange(value) end
    self:Refresh()
end

function OptionsView:CreateDropdown(panel, def, y)
    local dropdown = CreateFrame("DropdownButton", nil, panel, "WowStyle1DropdownTemplate")
    dropdown:SetWidth(210)
    dropdown:SetPoint("TOPRIGHT", -16, y)
    dropdown:SetupMenu(function(_, root)
        for _, choice in ipairs(Choices(def)) do
            root:CreateRadio(choice[2], function() return IsCurrent(def, choice[1]) end, function()
                self:Set(def, choice[1])
            end)
        end
    end)
    Tooltip(dropdown, def)
    return dropdown
end

-- Builds one tab: a framed panel with a scroll frame, filled with the rows of `defs`.
function OptionsView:CreateTab(view, defs)
    local panel = CreateFrame("Frame", nil, view)
    panel:SetPoint("TOPLEFT", 70, -78)
    panel:SetPoint("BOTTOMRIGHT", -70, 6)
    local fill = panel:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    fill:SetColorTexture(0, 0, 0, 0.32)
    Widgets.Rim(panel, panel)

    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, -6)
    scroll:SetPoint("BOTTOMRIGHT", -26, 6)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(panel:GetWidth() > 0 and panel:GetWidth() - 26 or 474)
    scroll:SetScrollChild(content)
    scroll:SetScript("OnSizeChanged", function(_, width) content:SetWidth(width) end)

    local y = -4
    for _, def in ipairs(defs) do
        local row = { def = def }
        if def.kind == "section" then
            local text = Widgets.LocalizedText(content, 14, "gold", def.label)
            text:SetPoint("TOPLEFT", 18, y - 6)
            local line = content:CreateTexture(nil, "ARTWORK")
            line:SetColorTexture(0.86, 0.66, 0.3, 0.25)
            line:SetPoint("TOPLEFT", 18, y - 24)
            line:SetPoint("TOPRIGHT", -8, y - 24)
            line:SetHeight(1)
            y = y - SECTION_ROW
        elseif def.kind == "check" then
            local check = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
            check:SetSize(26, 26)
            check:SetPoint("TOPLEFT", 14, y)
            local label = Widgets.LocalizedText(content, 12, "white", def.label)
            label:SetPoint("LEFT", check, "RIGHT", 6, 0)
            check:SetScript("OnClick", function(button)
                def.tbl[def.key] = button:GetChecked() and true or false
                if def.onChange then def.onChange(def.tbl[def.key]) end
            end)
            Tooltip(check, def)
            row.check = check
            y = y - CHECK_ROW
        else
            local label = Widgets.LocalizedText(content, 12, "white", def.label)
            label:SetPoint("TOPLEFT", 20, y - 6)
            if TemplateExists("WowStyle1DropdownTemplate") then
                row.dropdown = self:CreateDropdown(content, def, y)
            else
                local cycler = Widgets.Cycler(content, 210, function(dir) self:Step(row, dir) end)
                cycler:SetPoint("TOPRIGHT", -8, y)
                cycler:EnableMouse(true)
                Tooltip(cycler, def)
                row.cycler = cycler
            end
            y = y - CHOICE_ROW
        end
        self.rows[#self.rows + 1] = row
    end
    content:SetHeight(-y + 8)
    return panel
end

function OptionsView:Create(parent)
    local view = CreateFrame("Frame", nil, parent)
    view:SetAllPoints()
    view:SetFrameLevel(parent:GetFrameLevel() + 5)
    view:Hide()
    self.view = view

    local title = Widgets.LocalizedText(view, 20, "gold", "OPTIONS")
    title:SetPoint("TOP", 0, -10)

    -- Two tabs: everything about the arcade, and one long scrolling list for all games.
    local groups = { general = {}, games = {} }
    local current = "general"
    for _, def in ipairs(ns.Settings.Definitions()) do
        if def.tab then current = def.tab end
        table.insert(groups[current], def)
    end

    self.rows = {}
    self.panels = {
        self:CreateTab(view, groups.general),
        self:CreateTab(view, groups.games),
    }
    self:CreateTabButtons(view)
    self:SelectTab(1)
    return view
end

function OptionsView:CreateTabButtons(view)
    local keys = { "OPT_TAB_GENERAL", "OPT_TAB_GAMES" }
    if TemplateExists("TabSystemTemplate") and TabSystemMixin and TabSystemOwnerMixin then
        local tabs = CreateFrame("Frame", nil, view, "TabSystemTemplate")
        tabs.tabTemplate = "TabSystemTopButtonTemplate"
        TabSystemMixin.OnLoad(tabs)
        tabs:SetPoint("BOTTOMLEFT", self.panels[1], "TOPLEFT", 12, 2)
        Mixin(view, TabSystemOwnerMixin)
        TabSystemOwnerMixin.OnLoad(view)
        view:SetTabSystem(tabs)
        self.tabIDs = {}
        for i, key in ipairs(keys) do
            self.tabIDs[i] = view:AddNamedTab(L[key], self.panels[i])
        end
        self.tabSystem = view
        -- The template sizes a tab once from its text's current width, which truncates longer or
        -- translated labels. Give each label its full width, then let the tab measure itself again.
        local function FitTabs()
            for i, id in ipairs(self.tabIDs) do
                local button = tabs:GetTabButton(id)
                local label = button and (button.Text or (button.GetFontString and button:GetFontString()))
                if label then
                    local text = L[keys[i]]
                    button.tabText = text
                    label:SetText(text)
                    local width = label.GetUnboundedStringWidth and label:GetUnboundedStringWidth() or label:GetStringWidth()
                    label:SetWidth(math.ceil(width) + 4)
                    if button.UpdateTabWidth then
                        button:UpdateTabWidth()
                    else
                        button:SetWidth(math.max(110, width + 48))
                    end
                end
            end
            if tabs.MarkDirty then tabs:MarkDirty() end
        end
        Widgets.OnRefresh(FitTabs)
        FitTabs()
        return
    end
    -- Fallback: plain buttons that switch the panels.
    local last
    for i, key in ipairs(keys) do
        local b = Widgets.Button(view, 130, 24, key, function() self:SelectTab(i) end)
        if last then b:SetPoint("LEFT", last, "RIGHT", 6, 0) else b:SetPoint("BOTTOMLEFT", self.panels[1], "TOPLEFT", 4, 6) end
        last = b
    end
end

function OptionsView:SelectTab(index)
    if self.tabSystem then
        self.tabSystem:SetTab(self.tabIDs[index])
    else
        for i, panel in ipairs(self.panels) do panel:SetShown(i == index) end
    end
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
        if def.kind == "range" then
            local values = RangeValues(def)
            local snapped = values[NearestIndex(values, def.tbl[def.key])]
            if math.abs(snapped - (def.tbl[def.key] or 0)) > 0.001 then
                def.tbl[def.key] = snapped
                if def.onChange then def.onChange(snapped) end
            end
        end
        if row.check then
            row.check:SetChecked(def.tbl[def.key] and true or false)
        elseif row.dropdown then
            row.dropdown:GenerateMenu()
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
