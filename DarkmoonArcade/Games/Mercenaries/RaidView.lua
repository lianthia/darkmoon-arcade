-- Assembling a raid: the party is already in, up to ten go. On the left every owned mercenary (a
-- click adds or removes it), on the right the roster in order; "Set out" saves it (store.raid) and
-- starts the raid.

local _, ns = ...
local MC = ns.Mercenaries
local Kit, Describe, Bounty = MC.Kit, MC.Describe, MC.Bounty
local Widgets, L = ns.Widgets, ns.L
local Module = MC.Module
local W, H = MC.W, MC.H

local INK = { 0.24, 0.14, 0.06 }
local GRID_X, GRID_Y, COLS, CELL_W, CELL_H = 24, 74, 3, 204, 44
local ROSTER_X, ROW_H = W - 244, 42

-- A follower plate: level, name and role, as in the party panel of the book.
local function Plate(parent, w, h)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w, h)
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    Kit.Atlas(bg, "GarrMission_FollowerListButton", MC.Tex("plate"))
    b.glowTex = b:CreateTexture(nil, "OVERLAY")
    b.glowTex:SetAllPoints()
    Kit.Atlas(b.glowTex, "GarrMission_FollowerListButton-Select", MC.Tex("plate"))
    b.glowTex:SetAlpha(0)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    Kit.Atlas(hl, "GarrMission_FollowerListButton-Highlight")
    b.level = MC.Badge(b, "level", 26, 11)
    b.level:SetPoint("LEFT", 6, 0)
    b.role = b:CreateTexture(nil, "ARTWORK")
    b.role:SetSize(18, 18)
    b.role:SetPoint("RIGHT", -8, 0)
    b.name = Widgets.Text(b, 11, "white")
    b.name:SetPoint("LEFT", b.level, "RIGHT", 5, 0)
    b.name:SetPoint("RIGHT", b.role, "LEFT", -4, 0)
    b.name:SetJustifyH("LEFT")
    b.name:SetWordWrap(false)
    return b
end

local function Show(b, store, id)
    b:SetShown(id ~= nil)
    if not id then return end
    b.merc = id
    b.level.text:SetText(store.mercs[id].level)
    b.name:SetText(Describe.MercName(id))
    b.role:SetTexture(MC.RoleTex("role_", MC.Mercs[id].role))
end

function Module:BuildRaid()
    local view = self:AddView("raid", CreateFrame("Frame", nil, self.container))
    local wood = Kit.Wood(view, W, H, true)
    wood:SetPoint("TOPLEFT")
    local title = Kit.Plaque(view, 300, "MC_RAID_SETUP", 17)
    title:SetPoint("TOP", 0, -4)
    view.hint = Kit.Ink(view, 12, { 1, 0.92, 0.75 }, "OUTLINE")
    view.hint:SetPoint("TOPLEFT", GRID_X, -50)
    view.hint:SetWidth(ROSTER_X - GRID_X - 20)
    view.hint:SetJustifyH("LEFT")

    -- Every owned mercenary.
    view.cells = {}
    for i = 1, #MC.MERC_ORDER do
        local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
        local b = Plate(view, CELL_W - 6, CELL_H - 4)
        b:SetPoint("TOPLEFT", GRID_X + col * CELL_W, -(GRID_Y + row * CELL_H))
        b:SetScript("OnClick", function() self:ToggleRaidMember(b.merc) end)
        view.cells[i] = b
    end

    -- The roster on the right.
    local panel = CreateFrame("Frame", nil, view)
    panel:SetPoint("TOPLEFT", ROSTER_X, -54)
    panel:SetPoint("BOTTOMRIGHT", -10, 44)
    local fill = panel:CreateTexture(nil, "BACKGROUND", nil, 2)
    fill:SetAllPoints()
    fill:SetColorTexture(0.08, 0.05, 0.03, 0.75)
    Widgets.Rim(panel, panel)
    view.rosterTitle = Kit.Plaque(panel, 210, nil, 14)
    view.rosterTitle:SetPoint("TOP", 0, 6)
    view.rows = {}
    for i = 1, Bounty.RAID_SIZE do
        local b = Plate(panel, 216, ROW_H - 4)
        b:SetPoint("TOP", 0, -34 - (i - 1) * ROW_H)
        b:SetScript("OnClick", function() self:ToggleRaidMember(b.merc) end)
        view.rows[i] = b
    end

    local back = Kit.Button(view, 120, 28, "BACK", function() self:ShowView("travel") end, "red")
    Kit.Place(back, 76, H - 18)
    view.go = Kit.Button(view, 200, 28, "MC_RAID_GO", function()
        Bounty.SetRaidRoster(self:Store(), self.raidRoster)
        self:StartBounty(self.raidZone, false)
    end, "green")
    Kit.Place(view.go, W - 118, H - 18)
    view.refresh = function(zoneId)
        if zoneId then
            self.raidZone = zoneId
            self.raidRoster = Bounty.RaidRoster(self:Store())
        end
        self:RefreshRaid()
    end
end

-- Adds a mercenary to the roster (if there is room) or takes it out.
function Module:ToggleRaidMember(id)
    if not id then return end
    local roster = self.raidRoster
    for i, other in ipairs(roster) do
        if other == id then
            table.remove(roster, i)
            MC.Sound("select")
            self:RefreshRaid()
            return
        end
    end
    if #roster < Bounty.RAID_SIZE then
        roster[#roster + 1] = id
        MC.Sound("select")
        self:RefreshRaid()
    end
end

function Module:RefreshRaid()
    local view, store = self.views.raid, self:Store()
    self:SetScene(nil)
    local roster = self.raidRoster or {}
    local inRoster = {}
    for _, id in ipairs(roster) do inRoster[id] = true end
    local owned = {}
    for _, id in ipairs(MC.MERC_ORDER) do
        if store.mercs[id] and store.mercs[id].owned then owned[#owned + 1] = id end
    end
    for i, b in ipairs(view.cells) do
        Show(b, store, owned[i])
        b.glowTex:SetAlpha(owned[i] and inRoster[owned[i]] and 1 or 0)
        b:SetAlpha(owned[i] and not inRoster[owned[i]] and #roster >= Bounty.RAID_SIZE and 0.5 or 1)
    end
    for i, b in ipairs(view.rows) do Show(b, store, roster[i]) end
    view.rosterTitle.text:SetText(L.MC_RAID_ROSTER:format(#roster, Bounty.RAID_SIZE))
    local zone = MC.Zones[self.raidZone or ""]
    view.hint:SetText(L.MC_RAID_HINT:format(Bounty.RAID_SIZE, zone and zone.board or MC.Combat.BOARD))
    view.go:SetEnabled(#roster > 0 and store.run == nil)
end
