-- Assembling a raid: the party always goes (locked), up to four reinforcements join it. On the left
-- every owned mercenary (a click adds or removes a reinforcement), on the right the roster: the party,
-- then the free places; "Set out" saves the reinforcements (store.raid) and starts the raid.

local _, ns = ...
local MC = ns.Mercenaries
local Kit, Describe, Bounty = MC.Kit, MC.Describe, MC.Bounty
local Widgets, L = ns.Widgets, ns.L
local Module = MC.Module
local W, H = MC.W, MC.H

local GRID_X, GRID_Y, COLS, CELL_W, CELL_H = 18, 100, 3, 210, 46
local ROSTER_X, ROW_H, HEAD_H = W - 244, 36, 20
local LOCK = "Interface\\Buttons\\LockButton-Locked-Up"

-- A follower plate: level, name and role, as in the party panel of the book; a lock for the party.
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
    b.level = MC.Badge(b, "level", 24, 10)
    b.level:SetPoint("LEFT", 6, 0)
    b.role = b:CreateTexture(nil, "ARTWORK")
    b.role:SetSize(16, 16)
    b.role:SetPoint("RIGHT", -8, 0)
    b.lock = b:CreateTexture(nil, "ARTWORK")
    b.lock:SetSize(20, 20)
    b.lock:SetPoint("RIGHT", b.role, "LEFT", -2, 0)
    b.lock:SetTexture(LOCK)
    b.name = Widgets.Text(b, 11, "white")
    b.name:SetPoint("LEFT", b.level, "RIGHT", 5, 0)
    b.name:SetPoint("RIGHT", b.lock, "LEFT", -2, 0)
    b.name:SetJustifyH("LEFT")
    b.name:SetWordWrap(false)
    return b
end

-- Fills a plate with a mercenary, or (roster) an empty place.
local function Show(b, store, id, locked)
    b.merc = id
    b.level:SetShown(id ~= nil)
    b.role:SetShown(id ~= nil)
    b.lock:SetShown(locked == true)
    if id then
        b.level.text:SetText(store.mercs[id].level)
        b.name:SetText(Describe.MercName(id))
        b.name:SetTextColor(1, 1, 1)
        b.role:SetTexture(MC.RoleTex("role_", MC.Mercs[id].role))
    else
        b.name:SetText(L.MC_RAID_FREE)
        b.name:SetTextColor(0.6, 0.55, 0.45)
    end
end

local function Heading(parent, key)
    local fs = Kit.Ink(parent, 12, { 1, 0.82, 0.4 }, "OUTLINE")
    fs:SetJustifyH("LEFT")
    Widgets.OnRefresh(function() fs:SetText(L[key]) end)
    return fs
end

function Module:BuildRaid()
    local view = self:AddView("raid", CreateFrame("Frame", nil, self.container))
    local wood = Kit.Wood(view, W, H, true)
    wood:SetPoint("TOPLEFT")
    local title = Kit.Plaque(view, 300, "MC_RAID_SETUP", 17)
    title:SetPoint("TOP", -122, -4)
    -- The hint on a layer of its own, above the wood.
    local top = CreateFrame("Frame", nil, view)
    top:SetAllPoints()
    top:SetFrameLevel(view:GetFrameLevel() + 5)
    view.hint = Kit.Ink(top, 11, { 1, 0.92, 0.75 }, "OUTLINE")
    view.hint:SetPoint("TOPLEFT", GRID_X, -78)
    view.hint:SetWidth(COLS * CELL_W - 6)
    view.hint:SetJustifyH("CENTER")

    -- Every owned mercenary.
    view.cells = {}
    for i = 1, #MC.MERC_ORDER do
        local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
        local b = Plate(view, CELL_W - 6, CELL_H - 6)
        b:SetPoint("TOPLEFT", GRID_X + col * CELL_W, -(GRID_Y + row * CELL_H))
        b:SetScript("OnClick", function() self:ToggleRaidMember(b.merc) end)
        view.cells[i] = b
    end

    -- The roster on the right: the party (locked), then the reinforcements.
    local panel = CreateFrame("Frame", nil, view)
    panel:SetPoint("TOPLEFT", ROSTER_X, -54)
    panel:SetPoint("BOTTOMRIGHT", -10, 44)
    local fill = panel:CreateTexture(nil, "BACKGROUND", nil, 2)
    fill:SetAllPoints()
    fill:SetColorTexture(0.08, 0.05, 0.03, 0.75)
    Widgets.Rim(panel, panel)
    view.rosterTitle = Kit.Plaque(panel, 210, nil, 14)
    view.rosterTitle:SetPoint("TOP", 0, 6)
    view.partyHead = Heading(panel, "MC_PARTY")
    view.extraHead = Heading(panel, "MC_RAID_EXTRA")
    view.rows = {}
    for i = 1, Bounty.RAID_SIZE do
        local b = Plate(panel, 216, ROW_H - 4)
        b:SetScript("OnClick", function() self:ToggleRaidMember(b.merc) end)
        view.rows[i] = b
    end

    local back = Kit.Button(view, 120, 28, "BACK", function() self:ShowView("travel") end, "red")
    Kit.Place(back, 76, H - 18)
    view.go = Kit.Button(view, 200, 28, "MC_RAID_GO", function()
        Bounty.SetRaidRoster(self:Store(), self.raidExtra)
        self:StartBounty(self.raidZone, self.raidHeroic or false)
    end, "green")
    Kit.Place(view.go, W - 118, H - 18)
    view.refresh = function(zoneId)
        if zoneId then
            local store = self:Store()
            self.raidZone = zoneId
            -- The reinforcements chosen last time (still owned, not in the party).
            self.raidExtra = {}
            for _, id in ipairs(Bounty.RaidRoster(store)) do
                if not Bounty.InParty(store, id) then self.raidExtra[#self.raidExtra + 1] = id end
            end
        end
        self:RefreshRaid()
    end
end

-- Adds a reinforcement (if there is room) or takes it out; the party stays.
function Module:ToggleRaidMember(id)
    local store = self:Store()
    if not id or Bounty.InParty(store, id) then return end
    local extra = self.raidExtra
    for i, other in ipairs(extra) do
        if other == id then
            table.remove(extra, i)
            MC.Sound("select")
            self:RefreshRaid()
            return
        end
    end
    if #store.party + #extra < Bounty.RAID_SIZE then
        extra[#extra + 1] = id
        MC.Sound("select")
        self:RefreshRaid()
    end
end

function Module:RefreshRaid()
    local view, store = self.views.raid, self:Store()
    self:SetScene(nil)
    local party, extra = store.party or {}, self.raidExtra or {}
    local chosen = {}
    for _, id in ipairs(extra) do chosen[id] = true end
    local room = Bounty.RAID_SIZE - #party
    local full = #extra >= room
    local owned = {}
    for _, id in ipairs(MC.MERC_ORDER) do
        if store.mercs[id] and store.mercs[id].owned then owned[#owned + 1] = id end
    end
    for i, b in ipairs(view.cells) do
        local id = owned[i]
        b:SetShown(id ~= nil)
        if id then
            local inParty = Bounty.InParty(store, id)
            Show(b, store, id, inParty)
            b.glowTex:SetAlpha(chosen[id] and 1 or 0)
            b:SetAlpha(inParty and 0.45 or (not chosen[id] and full) and 0.6 or 1)
        end
    end
    -- The roster: "Party", its six, "Reinforcements", the chosen ones and the free places.
    local y = 40
    view.partyHead:ClearAllPoints()
    view.partyHead:SetPoint("TOPLEFT", 14, -y)
    y = y + HEAD_H
    for i, b in ipairs(view.rows) do
        if i == #party + 1 then
            y = y + 4
            view.extraHead:ClearAllPoints()
            view.extraHead:SetPoint("TOPLEFT", 14, -y)
            y = y + HEAD_H
        end
        b:ClearAllPoints()
        b:SetPoint("TOP", 0, -y)
        y = y + ROW_H
        if i <= #party then
            Show(b, store, party[i], true)
            b.glowTex:SetAlpha(0)
        else
            Show(b, store, extra[i - #party])
            b.glowTex:SetAlpha(extra[i - #party] and 1 or 0)
        end
    end
    view.extraHead:SetShown(room > 0)
    view.rosterTitle.text:SetText(L.MC_RAID_ROSTER:format(#party + #extra, Bounty.RAID_SIZE))
    local zone = MC.Zones[self.raidZone or ""]
    view.hint:SetText(L.MC_RAID_HINT:format(room, zone and zone.board or MC.Combat.BOARD))
    view.go:SetEnabled(store.run == nil)
end
