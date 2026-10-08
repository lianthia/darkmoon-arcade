-- The bounty map: the path from the camp at the bottom to the boss at the top, the party on the
-- left and the chosen stop's details on the right.

local _, ns = ...
local MC = ns.Mercenaries
local Bounty, Describe = MC.Bounty, MC.Describe
local Widgets, Media, L = ns.Widgets, ns.Media, ns.L
local Module = MC.Module
local W, H = MC.W, MC.H

local MAP_LEFT, MAP_RIGHT = 210, 630
local MAP_CX = (MAP_LEFT + MAP_RIGHT) / 2
local MAP_TOP, MAP_BOTTOM = 70, H - 60
local NODE, BOSS_NODE, NODE_GAP = 40, 58, 104
local MAX_NODES = 32

local NODE_ICON = {
    fight = "Interface\\Icons\\Ability_DualWield",
    elite = "Interface\\Icons\\INV_Misc_Head_Dragon_01",
    boss = "Interface\\Icons\\INV_Misc_Bone_HumanSkull_01",
    healer = "Interface\\Icons\\Spell_Holy_Resurrection",
    mystery = "Interface\\Icons\\INV_Misc_QuestionMark",
}

local function Place(region, x, y)
    region:ClearAllPoints()
    region:SetPoint("CENTER", region:GetParent(), "TOPLEFT", x, -y)
end

local function Panel(parent, x, y, w, h)
    local p = CreateFrame("Frame", nil, parent)
    p:SetSize(w, h)
    p:SetPoint("TOPLEFT", x, -y)
    local fill = p:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    fill:SetColorTexture(0.05, 0.03, 0.02, 0.78)
    Widgets.Rim(p, p)
    return p
end

function Module:BuildMap()
    local view = self:AddView("map", CreateFrame("Frame", nil, self.container))
    -- The zone's own map under the path.
    local art = MC.CreateMapCanvas(view, MAP_RIGHT - MAP_LEFT + 20, H)
    art:SetPoint("TOPLEFT", MAP_LEFT - 10, 0)
    view.art = art
    local edge = CreateFrame("Frame", nil, art)
    edge:SetAllPoints()
    edge:SetFrameLevel(art:GetFrameLevel() + 2)
    local vignette = edge:CreateTexture(nil, "ARTWORK")
    vignette:SetAllPoints()
    vignette:SetTexture(MC.Tex("vignette"))
    vignette:SetAlpha(0.7)

    -- Heading on a ribbon, above the map art.
    local top = CreateFrame("Frame", nil, view)
    top:SetAllPoints()
    top:SetFrameLevel(art:GetFrameLevel() + 12)
    local ribbon = MC.CreateRibbon(top, 360, nil, 16)
    ribbon:SetPoint("TOP", view, "TOPLEFT", MAP_CX, -2)
    view.title = ribbon.text
    view.event = Widgets.Text(top, 13, "white")
    view.event:SetPoint("TOP", ribbon, "BOTTOM", 0, -2)
    view.event:SetWidth(MAP_RIGHT - MAP_LEFT - 20)

    local lines = CreateFrame("Frame", nil, view)
    lines:SetAllPoints()
    lines:SetFrameLevel(art:GetFrameLevel() + 4)
    self.mapLines = {}
    self.lineLayer = lines

    self.mapNodes = {}
    for i = 1, MAX_NODES do
        local b = CreateFrame("Button", nil, view)
        b:SetFrameLevel(lines:GetFrameLevel() + 2)
        b.glow = b:CreateTexture(nil, "BACKGROUND")
        b.glow:SetTexture(MC.Tex("node_glow"))
        b.glow:SetPoint("CENTER")
        b.glow:SetBlendMode("ADD")
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetPoint("CENTER")
        local mask = b:CreateMaskTexture()
        mask:SetTexture(MC.Tex("circle_mask"), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(b.icon)
        b.icon:AddMaskTexture(mask)
        b.ring = b:CreateTexture(nil, "OVERLAY")
        b.ring:SetTexture(MC.Tex("node_ring"))
        b.ring:SetPoint("CENTER")
        b.check = b:CreateTexture(nil, "OVERLAY", nil, 1)
        b.check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
        b.check:SetSize(18, 18)
        b.check:SetPoint("BOTTOMRIGHT", 4, -4)
        b:SetScript("OnClick", function() self:SelectNode(b.layer, b.index, true) end)
        b:SetScript("OnDoubleClick", function() self:SelectNode(b.layer, b.index, true) self:TravelSelected() end)
        b:SetScript("OnEnter", function() self:ShowNodeInfo(b.layer, b.index) end)
        b:SetScript("OnLeave", function() self:ShowNodeInfo() end)
        b:Hide()
        self.mapNodes[i] = b
    end

    -- Party on the left.
    local party = Panel(view, 10, 10, MAP_LEFT - 30, H - 64)
    local partyTitle = Widgets.LocalizedText(party, 13, "gold", "MC_PARTY")
    partyTitle:SetPoint("TOP", 0, -10)
    self.partyRows = {}
    for i = 1, Bounty.PARTY_SIZE do
        local row = CreateFrame("Frame", nil, party)
        row:SetSize(MAP_LEFT - 46, 54)
        row:SetPoint("TOP", 0, -34 - (i - 1) * 60)
        row:EnableMouse(true)
        row.role = row:CreateTexture(nil, "ARTWORK")
        row.role:SetSize(24, 24)
        row.role:SetPoint("TOPLEFT", 2, -2)
        row.name = Widgets.Text(row, 12, "white")
        row.name:SetPoint("TOPLEFT", row.role, "TOPRIGHT", 6, -1)
        row.name:SetWidth(MAP_LEFT - 84)
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(false)
        row.level = Widgets.Text(row, 10, "gray")
        row.level:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -2)
        row.treasures = {}
        for k = 1, 8 do
            local icon = row:CreateTexture(nil, "ARTWORK")
            icon:SetSize(15, 15)
            icon:SetPoint("BOTTOMLEFT", 32 + (k - 1) * 17, 2)
            row.treasures[k] = icon
        end
        row:SetScript("OnEnter", function() self:PartyTooltip(row, i) end)
        row:SetScript("OnLeave", GameTooltip_Hide)
        self.partyRows[i] = row
    end
    view.effects = Widgets.Text(party, 11, "blue")
    view.effects:SetPoint("BOTTOM", 0, 10)
    view.effects:SetWidth(MAP_LEFT - 46)
    local abandon = Widgets.Button(view, MAP_LEFT - 30, 22, "MC_ABANDON", function() self.overlay:Show("confirm") end)
    abandon:SetPoint("BOTTOMLEFT", 10, 14)

    -- The chosen stop on the right.
    local info = Panel(view, MAP_RIGHT + 10, 10, W - MAP_RIGHT - 20, H - 64)
    view.infoTitle = Widgets.Text(info, 15, "gold")
    view.infoTitle:SetPoint("TOP", 0, -12)
    view.infoTitle:SetWidth(W - MAP_RIGHT - 36)
    view.infoLevel = Widgets.Text(info, 12, "white")
    view.infoLevel:SetPoint("TOP", view.infoTitle, "BOTTOM", 0, -4)
    view.infoModel = MC.Model(info, nil)
    view.infoModel:SetSize(W - MAP_RIGHT - 40, 150)
    view.infoModel:SetPoint("TOP", view.infoLevel, "BOTTOM", 0, -4)
    view.infoText = Widgets.Text(info, 11, "white")
    view.infoText:SetPoint("TOP", view.infoLevel, "BOTTOM", 0, -10)
    view.infoText:SetWidth(W - MAP_RIGHT - 40)
    view.infoText:SetJustifyH("LEFT")
    view.infoText:SetSpacing(3)
    self.travelButton = Widgets.Button(view, W - MAP_RIGHT - 20, 30, nil, function() self:TravelSelected() end)
    self.travelButton:SetPoint("BOTTOMRIGHT", -10, 14)

    view.refresh = function() self:RefreshMap() end
end

function Module:NodePoint(run, layer, index)
    local layers = run.map.layers
    local n = #layers
    local y = MAP_BOTTOM - (layer - 1) * (MAP_BOTTOM - MAP_TOP) / math.max(1, n - 1)
    local count = #layers[layer]
    local x = MAP_CX + (index - (count + 1) / 2) * NODE_GAP
    return x, y
end

function Module:IsReachable(run, layer, index)
    for _, c in ipairs(Bounty.Choices(run)) do
        if c.layer == layer and c.index == index then return true end
    end
    return false
end

function Module:Line(i)
    local line = self.mapLines[i]
    if not line then
        line = self.lineLayer:CreateLine(nil, "ARTWORK")
        self.mapLines[i] = line
    end
    return line
end

function Module:RefreshMap()
    local store = self:Store()
    local run = store.run
    local view = self.views.map
    if not run then return end
    self:SetScene(run.zone, 0.3)
    local u0, u1, v0, v1 = MC.ZoneView((MAP_RIGHT - MAP_LEFT + 20) / H)
    view.art:SetMap(run.zone, u0, u1, v0, v1)
    view.art:SetTint(0.92, 0.9, 0.85)
    view.title:SetText(Describe.ZoneName(run.zone) .. (run.heroic and ("  |cffa335ee(" .. L.MC_HEROIC .. ")|r") or ""))

    local visited = {}
    for _, key in ipairs(run.visited) do visited[key] = true end
    local layers = run.map.layers
    local used, lineCount = 0, 0
    for l, row in ipairs(layers) do
        for i, node in ipairs(row) do
            used = used + 1
            local b = self.mapNodes[used]
            local x, y = self:NodePoint(run, l, i)
            local size = node.type == "boss" and BOSS_NODE or NODE
            b:SetSize(size, size)
            b.icon:SetSize(size - 6, size - 6)
            b.ring:SetSize(size + 6, size + 6)
            b.glow:SetSize(size * 1.9, size * 1.9)
            Place(b, x, y)
            b.layer, b.index = l, i
            local key = l .. ":" .. i
            local icon = NODE_ICON[node.type]
            if node.type == "boon" then icon = MC.Tex("role_" .. node.role) end
            if node.type == "mystery" and visited[key] then
                icon = ({
                    stranger = "Interface\\Icons\\INV_Misc_Head_Human_01", sabotage = "Interface\\Icons\\INV_Misc_Bomb_04",
                    portal = "Interface\\Icons\\Spell_Arcane_PortalIronForge", cursed = "Interface\\Icons\\Spell_Shadow_CurseOfSargeras",
                    bonus = "Interface\\Icons\\INV_Misc_Coin_02",
                })[node.mystery] or icon
            end
            b.icon:SetTexture(icon)
            local reachable = self:IsReachable(run, l, i)
            local current = run.layer == l and run.index == i
            b.reachable = reachable
            b.icon:SetDesaturated(not reachable and not current and not visited[key])
            b.icon:SetAlpha((reachable or current or visited[key]) and 1 or 0.7)
            b.check:SetShown(visited[key] and not current)
            b.glow:SetShown(reachable or current)
            b.glow:SetVertexColor(current and 1 or 0.5, current and 0.85 or 1, current and 0.3 or 0.5)
            b.ring:SetVertexColor(node.type == "elite" and 0.8 or 1, node.type == "elite" and 0.55 or 1, node.type == "elite" and 1 or 1)
            b:Show()
            for _, j in ipairs(node.links) do
                lineCount = lineCount + 1
                local line = self:Line(lineCount)
                local x2, y2 = self:NodePoint(run, l + 1, j)
                line:SetStartPoint("TOPLEFT", self.lineLayer, x, -y)
                line:SetEndPoint("TOPLEFT", self.lineLayer, x2, -y2)
                line:SetThickness(current and self:IsReachable(run, l + 1, j) and 4 or 3)
                local walked = visited[key] and visited[(l + 1) .. ":" .. j]
                if walked then
                    line:SetColorTexture(0.85, 0.6, 0.15, 0.95)
                elseif current and self:IsReachable(run, l + 1, j) then
                    line:SetColorTexture(1, 0.95, 0.75, 0.9)
                else
                    line:SetColorTexture(0.35, 0.24, 0.14, 0.55)
                end
                line:Show()
            end
        end
    end
    for i = used + 1, MAX_NODES do self.mapNodes[i]:Hide() end
    for i = lineCount + 1, #self.mapLines do self.mapLines[i]:Hide() end

    -- Party, boons and curse.
    local reference = math.floor(Bounty.PartyLevel(store) + 0.5)
    for i, row in ipairs(self.partyRows) do
        local member = run.party[i]
        row:SetShown(member ~= nil)
        if member then
            local def = MC.Mercs[member.id]
            row.role:SetTexture(MC.Tex("role_" .. def.role))
            row.name:SetText(Describe.MercName(member.id))
            local entry = store.mercs[member.id]
            row.level:SetText(member.dead and ("|cffff4040" .. L.MC_FALLEN .. "|r") or L.LEVEL:format(entry.level))
            row:SetAlpha(member.dead and 0.5 or 1)
            for k, icon in ipairs(row.treasures) do
                local t = member.treasures[k]
                icon:SetShown(t ~= nil)
                if t then icon:SetTexture(MC.Treasures[t].icon) end
            end
        end
    end
    local effects = {}
    for _, role in ipairs(Bounty.ROLES) do
        local tier = run.boons[role] or 0
        if tier > 0 then effects[#effects + 1] = L.MC_BOON_LINE:format(Describe.RoleName(role), tier * 10) end
    end
    if run.curse > 0 then effects[#effects + 1] = "|cffc060ff" .. L.MC_CURSE_LINE:format(run.curse * MC.CURSE_HEALTH * 100) .. "|r" end
    if run.sabotage then effects[#effects + 1] = L.MC_SABOTAGE_LINE end
    if run.portal then effects[#effects + 1] = L.MC_PORTAL_LINE end
    view.effects:SetText(table.concat(effects, "\n"))

    -- Keep the selection on a reachable stop.
    if not self.mapSelection or not self:IsReachable(run, self.mapSelection.layer, self.mapSelection.index) then
        local first = Bounty.Choices(run)[1]
        self.mapSelection = first and { layer = first.layer, index = first.index } or nil
    end
    self.partyReference = reference
    self:ShowNodeInfo()
end

function Module:SelectNode(layer, index, clicked)
    local run = self:Store().run
    if not run then return end
    if clicked and self:IsReachable(run, layer, index) then
        self.mapSelection = { layer = layer, index = index }
        MC.Sound("select")
    end
    self:ShowNodeInfo(layer, index)
end

-- Fills the right panel with the hovered stop, or the selected one.
function Module:ShowNodeInfo(layer, index)
    local run = self:Store().run
    local view = self.views.map
    if not run then return end
    if not layer and self.mapSelection then layer, index = self.mapSelection.layer, self.mapSelection.index end
    local node = layer and Bounty.Node(run, layer, index)
    view.infoModel:Hide()
    if not node then
        view.infoTitle:SetText("")
        view.infoLevel:SetText("")
        view.infoText:SetText("")
        self.travelButton:Hide()
        return
    end
    local reference = self.partyReference or 1
    local kind = node.type
    view.infoTitle:SetText(L["MC_NODE_" .. kind:upper()])
    view.infoLevel:SetText("")
    local lines = {}
    if node.enemies then
        local r, g, b = MC.ConColor(node.level, reference)
        view.infoLevel:SetText(("|cff%02x%02x%02x%s|r"):format(r * 255, g * 255, b * 255,
            node.level - reference >= 10 and L.MC_LEVEL_SKULL or L.LEVEL:format(node.level)))
        if kind == "boss" then
            local boss = MC.Zones[run.zone].boss
            view.infoModel:SetShown(MC.Enemies[boss].display ~= 0)
            view.infoModel:SetDisplay(MC.Enemies[boss].display, 0.3)
        end
        for _, id in ipairs(node.enemies) do
            lines[#lines + 1] = ("|T%s:14:14|t %s"):format(MC.Tex("role_" .. MC.Enemies[id].role), L["MC_E_" .. id])
        end
        if kind == "elite" then lines[#lines + 1] = "\n" .. L.MC_ELITE_INFO end
    elseif kind == "boon" then
        lines[#lines + 1] = L.MC_BOON_INFO:format(Describe.RoleName(node.role), Bounty.BoonTier(run) * 10)
    elseif kind == "mystery" then
        lines[#lines + 1] = L.MC_MYSTERY_INFO
    elseif kind == "healer" then
        lines[#lines + 1] = L.MC_HEALER_INFO
    end
    view.infoText:SetText(table.concat(lines, "\n"))
    -- The boss stands between the heading and the list.
    view.infoText:ClearAllPoints()
    if view.infoModel:IsShown() then
        view.infoText:SetPoint("TOP", view.infoModel, "BOTTOM", 0, -6)
    else
        view.infoText:SetPoint("TOP", view.infoLevel, "BOTTOM", 0, -10)
    end
    local selected = self.mapSelection and self.mapSelection.layer == layer and self.mapSelection.index == index
    local reachable = self:IsReachable(run, layer, index)
    self.travelButton:SetShown(reachable and selected and run.phase == "map")
    self.travelButton:SetText(node.enemies and L.MC_FIGHT or L.MC_TRAVEL)
end

function Module:TravelSelected()
    local sel = self.mapSelection
    if not sel then return end
    self.mapSelection = nil
    self:Travel(sel.layer, sel.index)
end

function Module:PartyTooltip(owner, i)
    local store = self:Store()
    local run = store.run
    local member = run and run.party[i]
    if not member then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(Describe.MercName(member.id), 1, 0.82, 0)
    GameTooltip:AddLine(L.LEVEL:format(store.mercs[member.id].level) .. "  ·  " .. Describe.RoleName(MC.Mercs[member.id].role), 0.8, 0.8, 0.8)
    if #member.treasures == 0 then GameTooltip:AddLine(L.MC_NO_TREASURES, 0.6, 0.6, 0.6) end
    for _, t in ipairs(member.treasures) do
        local name, desc = self:TreasureText(t, member.id)
        GameTooltip:AddLine(name, 1, 0.82, 0)
        GameTooltip:AddLine(desc, 1, 1, 1, true)
    end
    GameTooltip:Show()
end

function Module:UpdateMap(dt)
    self.mapPulse = (self.mapPulse or 0) + dt
    local a = 0.55 + 0.35 * math.sin(self.mapPulse * 4)
    for _, b in ipairs(self.mapNodes) do
        if b:IsShown() and b.reachable then b.glow:SetAlpha(a) end
    end
    local view = self.views.map
    if self.mapEventTime and self.mapEventTime > 0 then
        self.mapEventTime = self.mapEventTime - dt
        view.event:SetText(self.mapEvent or "")
        view.event:SetAlpha(math.min(1, self.mapEventTime))
    else
        view.event:SetText("")
    end
end
