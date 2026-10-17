-- Options inside the arcade window (a tab of its own), built from the shared definitions in Settings.lua.

local _, ns = ...

local Widgets, Style, L = ns.Widgets, ns.Style, ns.L
local C = Style.C

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
    dropdown:SetPoint("TOPLEFT", 360, y)
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

-- The options tab: categories on the left (general, window, sound, flights, Mercenaries, the
-- minigames), the chosen category's settings on the right.
local PAD = Style.PAGE_PAD

-- Sorts the shared definitions into categories. Every arcade section is a category of its own; the
-- featured game gets one, the other games share "minigames" and keep their names as headings.
function OptionsView.Categories()
    local featured = ns.Arcade.Featured()
    local list, byId, current = {}, {}, nil
    local function Category(id, label)
        if not byId[id] then
            byId[id] = { id = id, label = label, defs = {} }
            list[#list + 1] = byId[id]
        end
        return byId[id]
    end
    for _, def in ipairs(ns.Settings.Definitions()) do
        if def.kind == "section" then
            if def.tab ~= "games" then
                current = Category(def.label, def.label)
            elseif def.label == featured.nameKey then
                current = Category("featured", def.label)
            else
                current = Category("minigames", "STATS_MINIGAMES")
                current.defs[#current.defs + 1] = def
            end
        elseif current then
            current.defs[#current.defs + 1] = def
        end
    end
    return list
end

-- Builds one category's page: its title, then a scroll frame with the rows of `defs`.
function OptionsView:CreateTab(view, category)
    local panel = CreateFrame("Frame", nil, view)
    panel:SetPoint("TOPLEFT", Style.CONTENT_X, -PAD)
    panel:SetPoint("BOTTOMRIGHT", -PAD, PAD)
    local title = Style.LocalizedText(panel, 22, C.text, category.label)
    title:SetPoint("TOPLEFT", 4, -4)
    -- The settings on a plate below the title.
    local plate = Style.Panel(panel)
    plate:SetPoint("TOPLEFT", 0, -40)
    plate:SetPoint("BOTTOMRIGHT")

    local scroll = CreateFrame("ScrollFrame", nil, plate, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 16, -12)
    scroll:SetPoint("BOTTOMRIGHT", -30, 12)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(panel:GetWidth() > 0 and panel:GetWidth() - 26 or 760)
    scroll:SetScrollChild(content)
    scroll:SetScript("OnSizeChanged", function(_, width) content:SetWidth(width) end)
    panel.content = content

    local y = -4
    for _, def in ipairs(category.defs) do
        local row = { def = def }
        if def.kind == "section" then
            local text = Style.LocalizedText(content, 13, C.gold, def.label)
            text:SetPoint("TOPLEFT", 6, y - 10)
            local line = Style.Line(content, C.border, "ARTWORK")
            line:SetPoint("TOPLEFT", 6, y - 28)
            line:SetPoint("TOPRIGHT", -8, y - 28)
            line:SetHeight(1)
            y = y - SECTION_ROW - 6
        elseif def.kind == "check" then
            local check = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
            check:SetSize(26, 26)
            check:SetPoint("TOPLEFT", 2, y)
            local label = Style.LocalizedText(content, 12, C.text, def.label)
            label:SetPoint("LEFT", check, "RIGHT", 6, 0)
            check:SetScript("OnClick", function(button)
                def.tbl[def.key] = button:GetChecked() and true or false
                if def.onChange then def.onChange(def.tbl[def.key]) end
            end)
            Tooltip(check, def)
            row.check = check
            y = y - CHECK_ROW
        else
            local label = Style.LocalizedText(content, 12, C.text, def.label)
            label:SetPoint("TOPLEFT", 8, y - 6)
            if TemplateExists("WowStyle1DropdownTemplate") then
                row.dropdown = self:CreateDropdown(content, def, y)
            else
                local cycler = Widgets.Cycler(content, 210, function(dir) self:Step(row, dir) end)
                cycler:SetPoint("TOPLEFT", 360, y)
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

    local nav = Style.SideList(view, "OPTIONS")
    self.rows, self.panels, self.navButtons = {}, {}, {}
    self.categories = OptionsView.Categories()
    for i, category in ipairs(self.categories) do
        self.panels[i] = self:CreateTab(view, category)
        local b = Style.ListItem(nav, function()
            PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
            self:SelectTab(i)
        end)
        b:SetPoint("TOPLEFT", 8, -nav.top - (i - 1) * 50)
        Widgets.OnRefresh(function() b.label:SetText(L[category.label]) end)
        self.navButtons[i] = b
    end
    -- The installed version at the foot of the list.
    local version = Style.Text(nav, 10, C.dim)
    version:SetPoint("BOTTOMLEFT", 16, 14)
    Widgets.OnRefresh(function() version:SetText(L.VERSION:format(ns.VersionNumber())) end)
    self.version = version
    self:SelectTab(1)
    return view
end

function OptionsView:SelectTab(index)
    self.selected = index
    for i, panel in ipairs(self.panels) do
        panel:SetShown(i == index)
        self.navButtons[i]:SetActive(i == index)
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
