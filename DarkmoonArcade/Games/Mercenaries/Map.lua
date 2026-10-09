-- The bounty map: coins on a parchment from the start at the bottom to the boss at the top, joined
-- by dashed paths. The party waits on the left, the chosen encounter on the right.

local _, ns = ...
local MC = ns.Mercenaries
local Bounty, Describe, Kit = MC.Bounty, MC.Describe, MC.Kit
local Widgets, L = ns.Widgets, ns.L
local Module = MC.Module
local W, H = MC.W, MC.H

local MAP_LEFT, MAP_RIGHT = 206, 634
local MAP_CX = (MAP_LEFT + MAP_RIGHT) / 2
local MAP_TOP, MAP_BOTTOM = 124, H - 48
local NODE, ELITE_NODE, BOSS_NODE, NODE_GAP = 48, 56, 76, 108
local MAX_NODES = 32
local DASH_GAP = 13

local NODE_ICON = {
    fight = "Interface\\Icons\\Ability_DualWield",
    elite = "Interface\\Icons\\INV_Misc_Head_Dragon_01",
    healer = "Interface\\Icons\\Spell_Holy_Resurrection",
    mystery = "Interface\\Icons\\INV_Misc_QuestionMark",
}
local MYSTERY_ICON = {
    stranger = "Interface\\Icons\\INV_Misc_Head_Human_01", sabotage = "Interface\\Icons\\INV_Misc_Bomb_04",
    portal = "Interface\\Icons\\Spell_Arcane_PortalIronForge", cursed = "Interface\\Icons\\Spell_Shadow_CurseOfSargeras",
    bonus = "Interface\\Icons\\INV_Misc_Coin_02",
}
local NODE_METAL = { boss = "gold", elite = "gold", fight = "bronze", healer = "silver", boon = "silver", mystery = "silver" }

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

function Module:BuildMap()
    local view = self:AddView("map", CreateFrame("Frame", nil, self.container))
    local wood = Kit.Wood(view, W, H, true)
    wood:SetPoint("TOPLEFT")

    -- A sheet of parchment under the path, in a gold rim.
    local art = CreateFrame("Frame", nil, view)
    art:SetSize(MAP_RIGHT - MAP_LEFT, H - 20)
    art:SetPoint("TOPLEFT", MAP_LEFT, -10)
    local paper = art:CreateTexture(nil, "BACKGROUND")
    paper:SetAllPoints()
    Kit.Atlas(paper, "spellbook-page-left-c60", MC.Tex("poster"))
    paper:SetTexCoord(0.17, 0.83, 0, 1)
    local vignette = art:CreateTexture(nil, "BORDER")
    vignette:SetAllPoints()
    vignette:SetTexture(MC.Tex("vignette"))
    vignette:SetAlpha(0.45)
    Widgets.Rim(view, art)
    view.art = art

    local dashes = CreateFrame("Frame", nil, view)
    dashes:SetAllPoints()
    dashes:SetFrameLevel(art:GetFrameLevel() + 4)
    self.dashLayer, self.dashes = dashes, {}

    local nodes = CreateFrame("Frame", nil, view)
    nodes:SetAllPoints()
    nodes:SetFrameLevel(dashes:GetFrameLevel() + 2)
    self.nodeLayer = nodes
    self.mapNodes = {}
    for i = 1, MAX_NODES do
        local b = Kit.Coin(nodes, NODE)
        b.here = b:CreateTexture(nil, "OVERLAY", nil, 4)
        b.here:SetSize(26, 26)
        b.here:SetPoint("BOTTOM", b, "TOP", 0, -6)
        b.here:SetTexture("Interface\\Minimap\\MiniMap-QuestArrow")
        b.here:SetRotation(math.pi)
        b:SetScript("OnClick", function() self:SelectNode(b.layer, b.index, true) end)
        b:SetScript("OnDoubleClick", function()
            self:SelectNode(b.layer, b.index, true)
            self:TravelSelected()
        end)
        b:HookScript("OnEnter", function() if b.open then self:ShowNodeInfo(b.layer, b.index) end end)
        b:HookScript("OnLeave", function() self:ShowNodeInfo() end)
        Kit.Hover(b, { grow = 1.14, sound = false })
        b:Hide()
        self.mapNodes[i] = b
    end

    local top = CreateFrame("Frame", nil, view)
    top:SetAllPoints()
    top:SetFrameLevel(nodes:GetFrameLevel() + 10)
    local plaque = Kit.Plaque(top, 300, nil, 16)
    plaque:SetPoint("TOP", view, "TOPLEFT", MAP_CX, -4)
    view.title = plaque.text
    view.event = Kit.Ink(top, 13, { 1, 0.95, 0.8 }, "OUTLINE")
    view.event:SetPoint("TOP", plaque, "BOTTOM", 0, 2)
    view.event:SetWidth(MAP_RIGHT - MAP_LEFT - 30)

    -- Party on the left.
    local party = DarkPanel(view, 10, 10, MAP_LEFT - 22, H - 62)
    local partyTitle = Kit.Plaque(party, 176, "MC_PARTY", 14)
    partyTitle:SetPoint("TOP", 0, 6)
    self.partyRows = {}
    for i = 1, Bounty.PARTY_SIZE do
        local row = CreateFrame("Frame", nil, party)
        row:SetSize(MAP_LEFT - 34, 60)
        row:SetPoint("TOP", 0, -48 - (i - 1) * 64)
        row:EnableMouse(true)
        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetPoint("TOPLEFT", 0, -2)
        bg:SetPoint("BOTTOMRIGHT", 0, 16)
        Kit.Atlas(bg, "GarrMission_FollowerListButton", MC.Tex("plate"))
        row.level = MC.Badge(row, "level", 28, 11)
        row.level:SetPoint("LEFT", 4, 8)
        row.name = Widgets.Text(row, 11, "white")
        row.name:SetPoint("LEFT", row.level, "RIGHT", 4, 0)
        row.name:SetWidth(MAP_LEFT - 92)
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(false)
        row.role = row:CreateTexture(nil, "ARTWORK")
        row.role:SetSize(18, 18)
        row.role:SetPoint("RIGHT", -6, 8)
        row.treasures = {}
        for k = 1, 8 do
            local icon = row:CreateTexture(nil, "ARTWORK")
            icon:SetSize(14, 14)
            icon:SetPoint("BOTTOMLEFT", 6 + (k - 1) * 16, 0)
            row.treasures[k] = icon
        end
        row:SetScript("OnEnter", function() self:PartyTooltip(row, i) end)
        row:SetScript("OnLeave", GameTooltip_Hide)
        self.partyRows[i] = row
    end
    view.effects = Kit.Ink(party, 10, { 0.75, 0.9, 1 }, "OUTLINE")
    view.effects:SetPoint("BOTTOM", 0, 8)
    view.effects:SetWidth(MAP_LEFT - 40)
    local abandon = Kit.Button(view, MAP_LEFT - 30, 26, "MC_ABANDON", function() self.overlay:Show("confirm") end)
    Kit.Place(abandon, (MAP_LEFT - 30) / 2 + 14, H - 22)

    -- The encounter on the right.
    local info = DarkPanel(view, MAP_RIGHT + 10, 10, W - MAP_RIGHT - 20, H - 20)
    local infoTitle = Kit.Plaque(info, 190, "MC_ENCOUNTER", 14)
    infoTitle:SetPoint("TOP", 0, 6)
    view.infoToken = MC.CreateToken(info)
    view.infoToken:SetPoint("CENTER", info, "TOP", 0, -120)
    view.infoToken:EnableMouse(false)
    view.infoName = Kit.Banner(info, 182, 36, 12)
    view.infoName:SetPoint("TOP", view.infoToken, "BOTTOM", 0, 10)
    view.infoIcon = Kit.Medallion(info, 96)
    view.infoIcon:SetPoint("CENTER", info, "TOP", 0, -120)
    view.infoIcon:EnableMouse(false)
    view.infoLevel = Widgets.Text(info, 12, "white")
    view.infoLevel:SetPoint("TOP", view.infoName, "BOTTOM", 0, 0)
    view.infoText = Widgets.Text(info, 11, "white")
    view.infoText:SetPoint("TOP", view.infoLevel, "BOTTOM", 0, -8)
    view.infoText:SetWidth(W - MAP_RIGHT - 44)
    view.infoText:SetJustifyH("LEFT")
    view.infoText:SetSpacing(3)
    self.travelButton = Kit.BigButton(info, 86, nil, function() self:TravelSelected() end)
    Kit.Place(self.travelButton, (W - MAP_RIGHT - 20) / 2, H - 78, info)

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

-- Dashed path between two points, skipping the part under the coins.
function Module:DrawPath(count, x1, y1, x2, y2, r1, r2, color)
    local dx, dy = x2 - x1, y2 - y1
    local length = math.sqrt(dx * dx + dy * dy)
    local angle = math.atan2(-dy, dx)
    local d = r1 + 6
    while d < length - r2 - 4 do
        count = count + 1
        local t = self.dashes[count]
        if not t then
            t = self.dashLayer:CreateTexture(nil, "ARTWORK")
            t:SetTexture(MC.Tex("dash"))
            t:SetSize(14, 7)
            self.dashes[count] = t
        end
        t:ClearAllPoints()
        t:SetPoint("CENTER", self.dashLayer, "TOPLEFT", x1 + dx * d / length, -(y1 + dy * d / length))
        t:SetRotation(angle)
        t:SetVertexColor(color[1], color[2], color[3], color[4])
        t:Show()
        d = d + DASH_GAP
    end
    return count
end

local function NodeSize(node)
    return node.type == "boss" and BOSS_NODE or (node.type == "elite" and ELITE_NODE or NODE)
end

function Module:NodeIcon(run, node, visited)
    if node.type == "boss" then
        local boss = MC.Zones[run.zone].boss
        return "Interface\\Icons\\" .. (MC.BOSS_ICON[boss] or "INV_Misc_Bone_HumanSkull_01"), MC.Enemies[boss].display
    end
    if node.type == "boon" then return MC.Tex("role_" .. node.role) end
    if node.type == "mystery" and visited then return MYSTERY_ICON[node.mystery] or NODE_ICON.mystery end
    return NODE_ICON[node.type]
end

function Module:RefreshMap()
    local store = self:Store()
    local run = store.run
    local view = self.views.map
    if not run then return end
    self:SetScene(nil)
    -- Keep the selection on a reachable stop.
    if not self.mapSelection or not self:IsReachable(run, self.mapSelection.layer, self.mapSelection.index) then
        local first = Bounty.Choices(run)[1]
        self.mapSelection = first and { layer = first.layer, index = first.index } or nil
    end
    view.title:SetText(Describe.ZoneName(run.zone) .. (run.heroic and (" (" .. L.MC_HEROIC .. ")") or ""))

    local visited = {}
    for _, key in ipairs(run.visited) do visited[key] = true end
    local layers = run.map.layers
    -- Stops that can still be reached: the next choices and everything their paths lead to.
    local ahead = {}
    for _, c in ipairs(Bounty.Choices(run)) do ahead[c.layer .. ":" .. c.index] = true end
    for l, row in ipairs(layers) do
        for i, node in ipairs(row) do
            if ahead[l .. ":" .. i] then
                for _, j in ipairs(node.links) do ahead[(l + 1) .. ":" .. j] = true end
            end
        end
    end
    local used, dashCount = 0, 0
    for l, row in ipairs(layers) do
        for i, node in ipairs(row) do
            used = used + 1
            local b = self.mapNodes[used]
            local x, y = self:NodePoint(run, l, i)
            local size = NodeSize(node)
            local key = l .. ":" .. i
            Kit.Place(b, x, y, self.nodeLayer)
            b.layer, b.index = l, i
            local icon, display = self:NodeIcon(run, node, visited[key])
            if not (display and b:SetCreature(display)) then b:SetIcon(icon) end
            b:SetMetal(NODE_METAL[node.type])
            local reachable = self:IsReachable(run, l, i)
            local current = run.layer == l and run.index == i
            local done = visited[key] and not current
            local open = ahead[key] or false
            b.reachable, b.open = reachable, open
            -- Finished stops get a check, stops left behind fade; neither reacts to the mouse.
            b.icon:SetDesaturated(done or not (open or current))
            b:SetAlpha((open or current or done) and 1 or 0.45)
            b.check:SetShown(done)
            b.here:SetShown(current)
            b:EnableMouse(open)
            Kit.SetHoverEnabled(b, open)
            local selected = self.mapSelection and self.mapSelection.layer == l and self.mapSelection.index == i
            Kit.SetSelected(b, reachable and selected or false, true)
            Kit.SetPulse(b, (reachable and not selected) and 0.5 or nil)
            Kit.SetBaseScale(b, size / NODE * (selected and 1.12 or 1))
            b:Show()
            for _, j in ipairs(node.links) do
                local x2, y2 = self:NodePoint(run, l + 1, j)
                local walked = visited[key] and visited[(l + 1) .. ":" .. j]
                local open = (current or (run.layer == 0 and false)) and self:IsReachable(run, l + 1, j)
                local color = walked and { 0.35, 0.85, 0.35, 1 } or (open and { 1, 0.92, 0.6, 1 } or { 0.25, 0.16, 0.08, 0.75 })
                dashCount = self:DrawPath(dashCount, x, y, x2, y2, size / 2, NodeSize(layers[l + 1][j]) / 2, color)
            end
        end
    end
    for i = used + 1, MAX_NODES do self.mapNodes[i]:Hide() end
    for i = dashCount + 1, #self.dashes do self.dashes[i]:Hide() end

    -- Party, boons and curse.
    local reference = math.floor(Bounty.PartyLevel(store) + 0.5)
    for i, row in ipairs(self.partyRows) do
        local member = run.party[i]
        row:SetShown(member ~= nil)
        if member then
            local def = MC.Mercs[member.id]
            row.role:SetTexture(MC.Tex("role_" .. def.role))
            row.name:SetText(member.dead and ("|cffff5050" .. Describe.MercName(member.id) .. "|r") or Describe.MercName(member.id))
            row.level.text:SetText(store.mercs[member.id].level)
            row:SetAlpha(member.dead and 0.55 or 1)
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

    self.partyReference = reference
    self:ShowNodeInfo()
end

function Module:SelectNode(layer, index, clicked)
    local run = self:Store().run
    if not run then return end
    if clicked and self:IsReachable(run, layer, index) then
        self.mapSelection = { layer = layer, index = index }
        MC.Sound("select")
        self:RefreshMap()
        return
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
    if not node then
        view.infoToken:Hide()
        view.infoIcon:Hide()
        view.infoName:Hide()
        view.infoLevel:SetText("")
        view.infoText:SetText("")
        self.travelButton:Hide()
        return
    end
    local reference = self.partyReference or 1
    local kind = node.type
    view.infoName:Show()
    local lines = {}
    if node.enemies then
        -- The strongest foe stands for the encounter: the boss, or the first of the group.
        local lead = kind == "boss" and MC.Zones[run.zone].boss or node.enemies[1]
        local def = MC.Enemies[lead]
        view.infoToken:Show()
        view.infoIcon:Hide()
        view.infoToken:SetData({ kind = def.boss and "boss" or "enemy", id = lead, side = "enemy", role = def.role,
            level = node.level, atk = def.atk, hp = def.hp }, reference)
        view.infoToken.attack:Hide()
        view.infoToken.health:Hide()
        view.infoToken.name:SetText("")
        view.infoName.text:SetText(kind == "boss" and L["MC_E_" .. lead] or L["MC_NODE_" .. kind:upper()])
        local r, g, b = MC.ConColor(node.level, reference)
        view.infoLevel:SetText(("|cff%02x%02x%02x%s|r"):format(r * 255, g * 255, b * 255,
            node.level - reference >= 10 and L.MC_LEVEL_SKULL or L.LEVEL:format(node.level)))
        for _, id in ipairs(node.enemies) do
            lines[#lines + 1] = ("|T%s:14:14|t %s"):format(MC.Tex("role_" .. MC.Enemies[id].role), L["MC_E_" .. id])
        end
        if kind == "elite" then lines[#lines + 1] = "\n" .. L.MC_ELITE_INFO end
    else
        view.infoToken:Hide()
        view.infoIcon:Show()
        local key = layer .. ":" .. index
        local seen = false
        for _, v in ipairs(run.visited) do
            if v == key then seen = true end
        end
        view.infoIcon.icon:SetTexture((self:NodeIcon(run, node, seen)))
        view.infoName.text:SetText(L["MC_NODE_" .. kind:upper()])
        view.infoLevel:SetText("")
        if kind == "boon" then
            lines[#lines + 1] = L.MC_BOON_INFO:format(Describe.RoleName(node.role), Bounty.BoonTier(run) * 10)
        elseif kind == "mystery" then
            lines[#lines + 1] = L.MC_MYSTERY_INFO
        elseif kind == "healer" then
            lines[#lines + 1] = L.MC_HEALER_INFO
        end
    end
    view.infoText:SetText(table.concat(lines, "\n"))
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
    if member.dead then GameTooltip:AddLine(L.MC_FALLEN, 1, 0.3, 0.3) end
    if #member.treasures == 0 then GameTooltip:AddLine(L.MC_NO_TREASURES, 0.6, 0.6, 0.6) end
    for _, t in ipairs(member.treasures) do
        local name, desc = self:TreasureText(t, member.id)
        GameTooltip:AddLine(name, 1, 0.82, 0)
        GameTooltip:AddLine(desc, 1, 1, 1, true)
    end
    GameTooltip:Show()
end

function Module:UpdateMap(dt)
    local view = self.views.map
    if self.mapEventTime and self.mapEventTime > 0 then
        self.mapEventTime = self.mapEventTime - dt
        view.event:SetText(self.mapEvent or "")
        view.event:SetAlpha(math.min(1, self.mapEventTime))
    else
        view.event:SetText("")
    end
end
