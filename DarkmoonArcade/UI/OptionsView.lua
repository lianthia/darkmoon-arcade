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

-- Sorts the shared definitions into categories. Every arcade section is a category of its own; a big
-- game (one with key art for the spotlight, like Mercenaries) gets one, the other games share
-- "minigames" and keep their names as headings.
function OptionsView.Categories()
    local big = {}
    for _, game in pairs(ns.Arcade.games) do
        if game.spotlight then big[game.nameKey] = true end
    end
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
            elseif big[def.label] then
                current = Category(def.label, def.label)
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
        elseif def.kind == "button" then
            -- An action (a game's reset): label on the left, a quiet button where the choices sit.
            local label = Style.LocalizedText(content, 12, C.text, def.label)
            label:SetPoint("TOPLEFT", 8, y - 6)
            local button = CreateFrame("Button", nil, content)
            button:SetSize(210, 24)
            button:SetPoint("TOPLEFT", 360, y)
            button.plate = Style.Rounded(button, button, 4, C.secondary)
            button.label = Style.LocalizedText(button, 11, C.text, def.button)
            button.label:SetPoint("LEFT", 8, 0)
            button.label:SetPoint("RIGHT", -8, 0)
            button.label:SetJustifyH("CENTER")
            button.label:SetWordWrap(false)
            button:SetScript("OnEnter", function(b)
                b.plate:SetColor(C.secondaryHover)
                if def.tip then
                    GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
                    GameTooltip:SetText(L[def.label], 1, 1, 1)
                    GameTooltip:AddLine(L[def.tip], nil, nil, nil, true)
                    GameTooltip:Show()
                end
            end)
            button:SetScript("OnLeave", function(b)
                b.plate:SetColor(C.secondary)
                GameTooltip_Hide()
            end)
            button:SetScript("OnClick", function()
                PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
                def.onClick(function() self:Refresh() end)
            end)
            row.button = button
            y = y - CHOICE_ROW
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

-- "More addons from us": our other addons for WoW: Forever, each with its logo (shipped here, so it shows
-- without the other addon), what it is, and whether it is installed or where to get it. Only on this page.
OptionsView.MORE = {
    { folder = "ForeverQoLPanel", name = "Forever QoL Panel", logo = "launcher/more_foreverqolpanel", text = "MORE_FQP",
        url = "https://www.curseforge.com/wow/addons/forever-qol-panel" },
}

local function AddonLoaded(folder)
    local A = C_AddOns
    if A and A.IsAddOnLoaded then return A.IsAddOnLoaded(folder) or A.IsAddOnLoaded(folder .. "_Dev") end
    return IsAddOnLoaded and (IsAddOnLoaded(folder) or IsAddOnLoaded(folder .. "_Dev")) or false
end

-- Asks before an action that can't be undone; `onAccept` runs on Yes.
function ns.Confirm(text, onAccept)
    if not StaticPopupDialogs then return onAccept() end
    StaticPopupDialogs.DARKMOONARCADE_CONFIRM = StaticPopupDialogs.DARKMOONARCADE_CONFIRM or {
        text = "%s", button1 = YES, button2 = NO, timeout = 0, whileDead = true, hideOnEscape = true,
        showAlert = true, preferredIndex = 3,
        OnAccept = function(_, data) if data then data() end end,
    }
    StaticPopup_Show("DARKMOONARCADE_CONFIRM", text, nil, onAccept)
end

-- A box with the link, selected for Ctrl+C (an addon cannot open a browser).
function ns.CopyLink(title, url)
    if not StaticPopupDialogs then return end
    StaticPopupDialogs.DARKMOONARCADE_COPY_LINK = StaticPopupDialogs.DARKMOONARCADE_COPY_LINK or {
        text = "%s", button1 = CLOSE or OKAY, hasEditBox = true, editBoxWidth = 360, timeout = 0,
        whileDead = true, hideOnEscape = true, preferredIndex = 3,
        OnShow = function(popup, data)
            local box = (popup.GetEditBox and popup:GetEditBox()) or rawget(popup, "editBox") or rawget(popup, "EditBox")
            if not box then return end
            box:SetText(data or "")
            box:HighlightText()
            box:SetFocus()
            -- The text stays the link, whatever is typed.
            box:SetScript("OnTextChanged", function(b)
                if b:GetText() ~= data then
                    b:SetText(data or "")
                    b:HighlightText()
                end
            end)
        end,
        OnHide = function(popup)
            local box = (popup.GetEditBox and popup:GetEditBox()) or rawget(popup, "editBox") or rawget(popup, "EditBox")
            if box then box:SetScript("OnTextChanged", nil) end
        end,
        EditBoxOnEscapePressed = function(box) box:GetParent():Hide() end,
        EditBoxOnEnterPressed = function(box) box:GetParent():Hide() end,
    }
    StaticPopup_Show("DARKMOONARCADE_COPY_LINK", title, nil, url)
end

function OptionsView:CreateMoreTab(view)
    local panel = CreateFrame("Frame", nil, view)
    panel:SetPoint("TOPLEFT", Style.CONTENT_X, -PAD)
    panel:SetPoint("BOTTOMRIGHT", -PAD, PAD)
    local title = Style.LocalizedText(panel, 22, C.text, "MORE_ADDONS")
    title:SetPoint("TOPLEFT", 4, -4)
    local plate = Style.Panel(panel)
    plate:SetPoint("TOPLEFT", 0, -40)
    plate:SetPoint("BOTTOMRIGHT")
    local tip = Style.LocalizedText(plate, 12, C.muted, "MORE_TIP")
    tip:SetPoint("TOPLEFT", 22, -18)
    panel.tiles = {}
    for i, addon in ipairs(OptionsView.MORE) do
        local tile = CreateFrame("Frame", nil, plate)
        tile:SetPoint("TOPLEFT", 16, -44 - (i - 1) * 144)
        tile:SetPoint("RIGHT", -16, 0)
        tile:SetHeight(132)
        Style.Rounded(tile, tile, 6, C.item)
        local logo = tile:CreateTexture(nil, "ARTWORK")
        logo:SetSize(84, 84)
        logo:SetPoint("TOPLEFT", 12, -12)
        logo:SetTexture(ns.Media.Tex(addon.logo))
        local name = Style.Text(tile, 15, C.text)
        name:SetPoint("TOPLEFT", logo, "TOPRIGHT", 16, -4)
        name:SetText(addon.name)
        local text = Style.Text(tile, 11, C.body)
        text:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -6)
        text:SetPoint("RIGHT", tile, "RIGHT", -20, 0)
        text:SetJustifyH("LEFT")
        text:SetWordWrap(true)
        tile.status = Style.Text(tile, 11, C.gold)
        tile.status:SetPoint("BOTTOMLEFT", tile, "BOTTOMLEFT", 112, 16)
        -- Not installed: a quiet button with the CurseForge link to copy.
        local link = CreateFrame("Button", nil, tile)
        link:SetSize(150, 24)
        link:SetPoint("BOTTOMRIGHT", -16, 12)
        link.plate = Style.Rounded(link, link, 4, C.secondary)
        link.label = Style.Text(link, 11, C.text)
        link.label:SetPoint("CENTER")
        link:SetScript("OnEnter", function() link.plate:SetColor(C.secondaryHover) end)
        link:SetScript("OnLeave", function() link.plate:SetColor(C.secondary) end)
        link:SetScript("OnClick", function()
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
            ns.CopyLink(L.MORE_LINK_TITLE:format(addon.name), addon.url)
        end)
        tile.link = link
        tile.addon = addon
        Widgets.OnRefresh(function()
            text:SetText(L[addon.text])
            link.label:SetText(L.MORE_LINK)
        end)
        panel.tiles[i] = tile
    end
    panel.refresh = function()
        for _, tile in ipairs(panel.tiles) do
            local have = AddonLoaded(tile.addon.folder)
            tile.status:SetText(have and ("|cff20ff20" .. L.MORE_INSTALLED .. "|r") or L.MORE_GET:format(tile.addon.name))
            tile.link:SetShown(not have)
        end
    end
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
    -- Last in the list, a little apart: our other addons.
    local more = #self.categories + 1
    self.panels[more] = self:CreateMoreTab(view)
    local b = Style.ListItem(nav, function()
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
        self:SelectTab(more)
    end)
    b:SetPoint("TOPLEFT", 8, -nav.top - (more - 1) * 50 - 12)
    Widgets.OnRefresh(function() b.label:SetText(L.MORE_ADDONS) end)
    self.navButtons[more] = b
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
    local panel = self.panels[index]
    if panel and panel.refresh then panel.refresh() end
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
        if row.button then
            local on = not def.enabled or def.enabled()
            row.button:SetEnabled(on)
            row.button:SetAlpha(on and 1 or 0.45)
        elseif row.check then
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
