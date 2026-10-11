-- Mercenaries: the game module. It owns the views (camp, travel, collection, bounty map,
-- battle), the dialogs between stops and the run's bookkeeping; the views live in their own files.

local _, ns = ...
local MC = ns.Mercenaries
local Combat, Bounty, Describe = MC.Combat, MC.Bounty, MC.Describe
local Arcade, Widgets, Scores, Media, Achievements, L = ns.Arcade, ns.Widgets, ns.Scores, ns.Media, ns.Achievements, ns.L

local W, H = 840, 560
MC.W, MC.H = W, H

local Module = {
    id = "mercenaries",
    rank = 0,
    fieldWidth = W,
    fieldHeight = H,
    nameKey = "MC_NAME",
    descKey = "MC_DESC",
    helpKey = "MC_HELP",
    tile = "tiles/mercenaries",
    defaults = { fast = false, sounds = "ingame" },
}
MC.Module = Module

function MC.Tex(name) return Media.Tex("mercs/" .. name) end
function MC.Sound(name) Media.Play("mercs/" .. name) end

MC.ROLE_COLORS = {
    protector = { 0.86, 0.2, 0.16 },
    fighter = { 0.28, 0.74, 0.22 },
    caster = { 0.22, 0.48, 0.96 },
    neutral = { 0.62, 0.62, 0.62 },
}

-- Level colours like WoW's: grey far below, green below, yellow close, orange and red above.
function MC.ConColor(level, reference)
    local d = level - reference
    if d >= 5 then return 1, 0.12, 0.1 end
    if d >= 3 then return 1, 0.5, 0.2 end
    if d >= -2 then return 1, 0.85, 0 end
    if d >= -7 then return 0.25, 0.8, 0.25 end
    return 0.6, 0.6, 0.6
end

-- Foes ten or more levels above show as "??", like in WoW.
function MC.LevelText(level, reference)
    if reference and level - reference >= 10 then return "??" end
    return tostring(level)
end

Achievements.Register("mercenaries", {
    { id = "mc_first", nameKey = "MC_ACH_FIRST", descKey = "MC_ACH_FIRST_DESC", icon = "Interface\\Icons\\INV_Sword_04" },
    { id = "mc_bounty", nameKey = "MC_ACH_BOUNTY", descKey = "MC_ACH_BOUNTY_DESC", icon = "Interface\\Icons\\INV_Misc_Note_02" },
    { id = "mc_recruit", nameKey = "MC_ACH_RECRUIT", descKey = "MC_ACH_RECRUIT_DESC", icon = "Interface\\Icons\\INV_Misc_Coin_02" },
    { id = "mc_rank", nameKey = "MC_ACH_RANK", descKey = "MC_ACH_RANK_DESC", icon = "Interface\\Icons\\Spell_Holy_MindVision" },
    { id = "mc_starter", nameKey = "MC_ACH_STARTER", descKey = "MC_ACH_STARTER_DESC", icon = "Interface\\Icons\\INV_Misc_Map_01" },
    { id = "mc_heroic", nameKey = "MC_ACH_HEROIC", descKey = "MC_ACH_HEROIC_DESC", icon = "Interface\\Icons\\INV_Misc_Head_Dragon_01" },
    { id = "mc_flawless", nameKey = "MC_ACH_FLAWLESS", descKey = "MC_ACH_FLAWLESS_DESC", icon = "Interface\\Icons\\Spell_Holy_DivineIntervention" },
    { id = "mc_few", nameKey = "MC_ACH_FEW", descKey = "MC_ACH_FEW_DESC", icon = "Interface\\Icons\\Ability_Warrior_Challange" },
    { id = "mc_flight", nameKey = "MC_ACH_FLIGHT", descKey = "MC_ACH_FLIGHT_DESC", icon = "Interface\\TaxiFrame\\UI-Taxi-Icon-Green" },
    { id = "mc_level30", nameKey = "MC_ACH_LEVEL30", descKey = "MC_ACH_LEVEL30_DESC", icon = "Interface\\Icons\\INV_Misc_Book_09" },
    { id = "mc_gear", nameKey = "MC_ACH_GEAR", descKey = "MC_ACH_GEAR_DESC", icon = "Interface\\Icons\\INV_Chest_Plate06" },
    { id = "mc_stage1", nameKey = "MC_ACH_STAGE1", descKey = "MC_ACH_STAGE1_DESC", icon = "Interface\\Icons\\Ability_Hunter_Pathfinding" },
    { id = "mc_stage2", nameKey = "MC_ACH_STAGE2", descKey = "MC_ACH_STAGE2_DESC", icon = "Interface\\Icons\\Spell_Nature_EarthBind" },
    { id = "mc_stage3", nameKey = "MC_ACH_STAGE3", descKey = "MC_ACH_STAGE3_DESC", icon = "Interface\\Icons\\Spell_Fire_FelFlameRing" },
    { id = "mc_hogger", nameKey = "MC_ACH_HOGGER", descKey = "MC_ACH_HOGGER_DESC", icon = "Interface\\Icons\\INV_Misc_Head_Gnoll_01" },
    { id = "mc_legends", nameKey = "MC_ACH_LEGENDS", descKey = "MC_ACH_LEGENDS_DESC", icon = "Interface\\Icons\\INV_Misc_Head_Dragon_Black" },
    { id = "mc_hyjal_heroic", nameKey = "MC_ACH_HYJAL", descKey = "MC_ACH_HYJAL_DESC", icon = "Interface\\Icons\\Spell_Shadow_DemonicTactics" },
    { id = "mc_eastern", nameKey = "MC_ACH_EASTERN", descKey = "MC_ACH_EASTERN_DESC", icon = "Interface\\Icons\\Achievement_Zone_EasternKingdoms_01" },
    { id = "mc_kalimdor", nameKey = "MC_ACH_KALIMDOR", descKey = "MC_ACH_KALIMDOR_DESC", icon = "Interface\\Icons\\Achievement_Zone_Kalimdor_01" },
    { id = "mc_newshores", nameKey = "MC_ACH_NEWSHORES", descKey = "MC_ACH_NEWSHORES_DESC", icon = "Interface\\Icons\\Spell_Arcane_TeleportTheramore" },
    { id = "mc_fullgear", nameKey = "MC_ACH_FULLGEAR", descKey = "MC_ACH_FULLGEAR_DESC", icon = "Interface\\Icons\\INV_Helmet_03" },
    { id = "mc_master", nameKey = "MC_ACH_MASTER", descKey = "MC_ACH_MASTER_DESC", icon = "Interface\\Icons\\Spell_Holy_SealOfWisdom" },
    { id = "mc_underdog", nameKey = "MC_ACH_UNDERDOG", descKey = "MC_ACH_UNDERDOG_DESC", icon = "Interface\\Icons\\INV_Throwingknife_02" },
    { id = "mc_blitz", nameKey = "MC_ACH_BLITZ", descKey = "MC_ACH_BLITZ_DESC", icon = "Interface\\Icons\\Ability_Warrior_Charge" },
    { id = "mc_casters", nameKey = "MC_ACH_CASTERS", descKey = "MC_ACH_CASTERS_DESC", icon = "Interface\\Icons\\Spell_Holy_MagicalSentry" },
    { id = "mc_protectors", nameKey = "MC_ACH_PROTECTORS", descKey = "MC_ACH_PROTECTORS_DESC", icon = "Interface\\Icons\\INV_Shield_06" },
    { id = "mc_fighters", nameKey = "MC_ACH_FIGHTERS", descKey = "MC_ACH_FIGHTERS_DESC", icon = "Interface\\Icons\\Ability_DualWield" },
    { id = "mc_mysteries", nameKey = "MC_ACH_MYSTERIES", descKey = "MC_ACH_MYSTERIES_DESC", icon = "Interface\\Icons\\INV_Misc_Ticket_Tarot_Furies" },
    { id = "mc_cursed", nameKey = "MC_ACH_CURSED", descKey = "MC_ACH_CURSED_DESC", icon = "Interface\\Icons\\Spell_Shadow_CurseOfSargeras" },
    { id = "mc_guest", nameKey = "MC_ACH_GUEST", descKey = "MC_ACH_GUEST_DESC", icon = "Interface\\Icons\\INV_Misc_GroupNeedMore" },
    { id = "mc_veteran", nameKey = "MC_ACH_VETERAN", descKey = "MC_ACH_VETERAN_DESC", icon = "Interface\\Icons\\INV_BannerPVP_02" },
    { id = "mc_heroic_all", nameKey = "MC_ACH_HEROIC_ALL", descKey = "MC_ACH_HEROIC_ALL_DESC", icon = "Interface\\Icons\\INV_Crown_02" },
    { id = "mc_all60", nameKey = "MC_ACH_ALL60", descKey = "MC_ACH_ALL60_DESC", icon = "Interface\\Icons\\Achievement_Level_60" },
    { id = "mc_collection", nameKey = "MC_ACH_COLLECTION", descKey = "MC_ACH_COLLECTION_DESC", icon = "Interface\\Icons\\INV_Misc_Book_11" },
    { id = "mc_heroic10", nameKey = "MC_ACH_HEROIC10", descKey = "MC_ACH_HEROIC10_DESC", icon = "Interface\\Icons\\INV_Crown_01" },
    { id = "mc_level60", nameKey = "MC_ACH_LEVEL60", descKey = "MC_ACH_LEVEL60_DESC", icon = "Interface\\Icons\\INV_Misc_Book_07" },
    { id = "mc_heroic_flawless", nameKey = "MC_ACH_HEROIC_FLAWLESS", descKey = "MC_ACH_HEROIC_FLAWLESS_DESC", icon = "Interface\\Icons\\Spell_Holy_SealOfProtection" },
})
local STARTING_ZONES = { "elwynn", "dunmorogh", "tirisfal", "teldrassil", "durotar", "mulgore", "zephras" }

function Module:Store()
    local store = Arcade.Settings(self)
    if not store.mercs then Bounty.Init(store) end
    store.stats = store.stats or { fights = 0, bounties = 0, heroics = 0 }
    return store
end

function Module:BestScore()
    return Scores.Best(self.id, "default")
end

local function ShareMessage(entry)
    local zone = entry.zone and Describe.ZoneName(entry.zone) or ""
    return L.MC_SHARE:format(ns.FormatNumber(entry.score), zone .. (entry.heroic and (" (" .. L.MC_HEROIC .. ")") or ""))
end

-- Building -----------------------------------------------------------------------------------

function Module:Build(container)
    self.container = container
    self.effects = {}
    Bounty.Init(self:Store())

    -- Behind every view: a dark ground and the map art of the zone the view is about.
    local ground = container:CreateTexture(nil, "BACKGROUND")
    ground:SetAllPoints()
    ground:SetColorTexture(0.04, 0.03, 0.03, 1)
    self.scene = MC.CreateScene(container, W, H)
    self.scene:SetPoint("TOPLEFT")

    -- The overlay comes first: views add pages of their own to it.
    self.overlay = Widgets.NewOverlay(container)
    self.overlay.frame:SetFrameLevel(container:GetFrameLevel() + 70)
    self:CreatePages()

    self.views = {}
    self:BuildCamp()
    self:BuildTravel()
    self:BuildCollection()
    self:BuildRoadmap()
    self:BuildMap()
    self:BuildBattle()

    local fx = CreateFrame("Frame", nil, container)
    fx:SetAllPoints()
    fx:SetFrameLevel(container:GetFrameLevel() + 60)
    self.fxLayer = fx
    self.textPool = Media.Pool(function() return fx:CreateFontString(nil, "OVERLAY") end, function(fs) fs:Hide() end)

    self.overlay:Hide()
    self:Route()
end

-- Shows `key`'s map art dimmed to `dim` behind the views; nil leaves the dark ground.
function Module:SetScene(key, dim)
    self.scene:SetShown(key ~= nil)
    if key then self.scene:ShowZone(key, dim) end
end

function Module:AddView(name, frame)
    frame:SetAllPoints()
    frame:SetFrameLevel(self.container:GetFrameLevel() + 10)
    frame:Hide()
    self.views[name] = frame
    return frame
end

function Module:ShowView(name, data)
    for viewName, frame in pairs(self.views) do frame:SetShown(viewName == name) end
    self.view = name
    local frame = self.views[name]
    if frame.refresh then frame.refresh(data) end
    ns.Window:UpdateSidebar()
end

-- Shows whatever the saved run is waiting for; without a run, the camp.
function Module:Route()
    local store = self:Store()
    local run = store.run
    if not run then
        self.overlay:Hide()
        self:ShowView("camp")
        return
    end
    local phase = run.phase
    if phase == "battle" then
        self.overlay:Hide()
        self:ShowView("battle")
        return
    end
    self:ShowView("map")
    if phase == "treasure" then
        self.overlay:Show("treasure")
    elseif phase == "healer" then
        self.overlay:Show("healer")
    elseif phase == "stranger" then
        self.overlay:Show("stranger")
    elseif phase == "complete" or phase == "lost" then
        self.overlay:Show("result")
    else
        self.overlay:Hide()
    end
end

-- Runs ---------------------------------------------------------------------------------------------

function Module:StartBounty(zoneId, heroic)
    local store = self:Store()
    if store.run then return end
    local run = Bounty.NewRun(store, zoneId, heroic, time() * 7 + math.random(1, 100000))
    if not run then return end
    run.flight = ns.Flight.current ~= nil
    PlaySound(SOUNDKIT.IG_QUEST_LIST_OPEN)
    self:Route()
end

function Module:Travel(layer, index)
    local store = self:Store()
    local run = store.run
    if not run or not Bounty.Travel(store, run, layer, index) then return end
    local node = Bounty.Node(run)
    if node.type == "mystery" then self:CheckProgress() end
    -- What happened at the stop is shown in a window that waits for the player.
    local event
    if node.type == "boon" then
        event = { icon = MC.Tex("role_" .. node.role), title = L.MC_NODE_BOON,
            text = L.MC_EVENT_BOON:format(Describe.RoleName(node.role), Bounty.BoonTier(run) * 10) }
    elseif node.type == "mystery" and run.phase == "map" then
        local kind = node.mystery
        local text = L["MC_EVENT_" .. kind:upper()]
        if kind == "recruit" then
            if run.guestJoined then
                text = L.MC_EVENT_RECRUIT:format(Describe.MercName(run.guestJoined))
            else
                kind, text = "bonus", L.MC_EVENT_BONUS
            end
        end
        event = { icon = MC.MYSTERY_ICON[kind], title = L["MC_MYSTERY_" .. kind:upper()], text = text,
            merc = kind == "recruit" and run.guestJoined or nil }
    elseif node.type == "healer" and run.phase == "map" then
        event = { icon = "Interface\\Icons\\Spell_Holy_Resurrection", title = L.MC_NODE_HEALER, text = L.MC_EVENT_HEALER_IDLE }
    end
    self:Route()
    if event and self:Store().run.phase == "map" then self.overlay:Show("event", event) end
end

-- Called by the battle view once the last animation of a finished battle has played.
function Module:FinishBattle()
    local store = self:Store()
    local run = store.run
    if not run or not run.battle then return end
    local b = run.battle
    local won = b.phase == "won"
    local survivors = #b.board.ally + #b.bench.ally
    if won then
        if b.turn <= 2 then Achievements.Unlock("mc_blitz") end
        local node = Bounty.Node(run)
        if node and node.type == "boss" then
            for _, u in pairs(b.units) do
                if u.side == "enemy" and u.id == MC.Zones[run.zone].boss and u.killedBy then
                    local killer = b.units[u.killedBy]
                    local member = killer and killer.pidx and run.party[killer.pidx]
                    if member and member.guest then run.guestFinisher = true end
                end
            end
        end
    end
    Bounty.AfterBattle(store, run)
    if won then
        store.stats.fights = store.stats.fights + 1
        Achievements.Unlock("mc_first")
        if run.phase == "complete" then
            self:OnBountyComplete(run, survivors)
        end
        MC.Sound("victory")
    else
        MC.Sound("defeat")
    end
    self:CheckLevels()
    self:Route()
end

local ROLE_ONLY = { caster = "mc_casters", protector = "mc_protectors", fighter = "mc_fighters" }

function Module:OnBountyComplete(run, survivors)
    local store = self:Store()
    store.stats.bounties = store.stats.bounties + 1
    Achievements.Unlock("mc_bounty")
    local flawless = #Bounty.DeadMembers(run) == 0
    if flawless then Achievements.Unlock("mc_flawless") end
    if survivors <= 3 then Achievements.Unlock("mc_few") end
    if run.flight and ns.Flight.current then Achievements.Unlock("mc_flight") end
    if run.heroic then
        store.stats.heroics = store.stats.heroics + 1
        Achievements.Unlock("mc_heroic")
        if flawless then Achievements.Unlock("mc_heroic_flawless") end
    end
    -- How the bounty was won: one role only, a party well below the boss, a cursed treasure, a guest
    -- landing the last blow.
    local roles, count, levels, cursed = {}, 0, 0, false
    for _, member in ipairs(run.party) do
        for _, treasure in ipairs(member.treasures or {}) do
            if type(treasure) == "string" and treasure:find("^cursed") then cursed = true end
        end
        local merc = MC.Mercs[member.id]
        if not member.guest and merc then
            roles[merc.role] = true
            count = count + 1
            levels = levels + ((run.startLevels and run.startLevels[member.id]) or Bounty.Entry(store, member.id).level)
        end
    end
    local role = next(roles)
    if role and next(roles, role) == nil and count >= 3 and ROLE_ONLY[role] then Achievements.Unlock(ROLE_ONLY[role]) end
    if count > 0 and levels / count <= Bounty.BossLevel(MC.Zones[run.zone], run.heroic) - 3 then
        Achievements.Unlock("mc_underdog")
    end
    if cursed then Achievements.Unlock("mc_cursed") end
    if run.guestFinisher then Achievements.Unlock("mc_guest") end
    self:CheckProgress()
end

-- Achievements that follow from the saved progress alone. Checked after bounties and battles and
-- whenever the game opens, so progress made before an achievement existed counts as well.
function Module:CheckProgress()
    local store = self:Store()
    local function Cleared(zid, heroic)
        local state = Bounty.ZoneState(store, zid)
        return ((heroic and state.heroic or state.normal) or 0) > 0
    end
    local function All(list, heroic)
        for _, zid in ipairs(list) do
            if not Cleared(zid, heroic) then return false end
        end
        return true
    end
    local function Zones(test)
        local list = {}
        for _, zid in ipairs(MC.ZONE_ORDER) do
            if test(MC.Zones[zid]) then list[#list + 1] = zid end
        end
        return list
    end
    local function Unlock(id, done)
        if done then Achievements.Unlock(id) end
    end

    Unlock("mc_starter", All(STARTING_ZONES))
    -- Stages: every zone up to level 30, up to level 45, and all of them.
    Unlock("mc_stage1", All(Zones(function(z) return z.max <= 30 end)))
    Unlock("mc_stage2", All(Zones(function(z) return z.max <= 45 end)))
    Unlock("mc_stage3", All(MC.ZONE_ORDER))
    Unlock("mc_hogger", Cleared("elwynn"))
    Unlock("mc_legends", All({ "dustwallow", "azshara", "blastedlands", "silithus" }))
    Unlock("mc_hyjal_heroic", Cleared("hyjal", true))
    Unlock("mc_eastern", All(Zones(function(z) return z.continent == "ek" end)))
    Unlock("mc_kalimdor", All(Zones(function(z) return z.continent == "kal" end)))
    Unlock("mc_newshores", All({ "zephras", "shendralas", "riverglades" }))
    Unlock("mc_heroic_all", All(MC.ZONE_ORDER, true))
    local heroics = 0
    for _, zid in ipairs(MC.ZONE_ORDER) do
        if Cleared(zid, true) then heroics = heroics + 1 end
    end
    Unlock("mc_heroic10", heroics >= 10)
    Unlock("mc_veteran", (store.stats.bounties or 0) >= 100)

    local gears, all60 = 0, true
    for _, id in ipairs(MC.MERC_ORDER) do
        local entry = store.mercs[id]
        if entry then
            local full = true
            for i = 1, 3 do
                if entry.gears[i] then
                    if i > 1 then gears = gears + 1 end
                else
                    full = false
                end
            end
            Unlock("mc_fullgear", full and entry.owned)
            Unlock("mc_master", entry.owned and entry.ranks[1] >= 3 and entry.ranks[2] >= 3 and entry.ranks[3] >= 3)
        end
        if not (entry and entry.owned and entry.level >= MC.MAX_LEVEL) then all60 = false end
    end
    Unlock("mc_gear", gears >= 10)
    Unlock("mc_all60", all60)

    local seen = store.stats.mysteries or {}
    local everyMystery = true
    for _, m in ipairs(Bounty.MYSTERIES) do
        if not seen[m] then everyMystery = false end
    end
    Unlock("mc_mysteries", everyMystery)
end

function Module:CheckLevels()
    local store = self:Store()
    local owned = 0
    for id, entry in pairs(store.mercs) do
        if entry.owned and MC.Mercs[id] then owned = owned + 1 end
        if entry.level >= 30 then Achievements.Unlock("mc_level30") end
        if entry.level >= MC.MAX_LEVEL then Achievements.Unlock("mc_level60") end
        for _, rank in ipairs(entry.ranks) do
            if rank >= 3 then Achievements.Unlock("mc_rank") end
        end
    end
    if owned > #MC.STARTERS then Achievements.Unlock("mc_recruit") end
    if owned >= #MC.MERC_ORDER then Achievements.Unlock("mc_collection") end
    self:CheckProgress()
end

-- Leaves the finished run: records the score and returns to the camp.
function Module:CloseRun()
    local store = self:Store()
    local run = store.run
    if run and run.score > 0 and not run.recorded then
        run.recorded = true
        self.lastEntry = { score = run.score, zone = run.zone, heroic = run.heroic or nil }
        self.lastRank = Scores.Record(self.id, "default", self.lastEntry)
    end
    Bounty.EndRun(store)
    self:Route()
end

function Module:AbandonRun()
    local store = self:Store()
    if not store.run then return end
    Bounty.Abandon(store, store.run)
    self:Route()
end

-- Dialogs --------------------------------------------------------------------------------------------

local function OptionButton(parent, width, height)
    local Kit = MC.Kit
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width, height)
    b.glowTex = b:CreateTexture(nil, "BACKGROUND", nil, -8)
    b.glowTex:SetPoint("TOPLEFT", -10, 10)
    b.glowTex:SetPoint("BOTTOMRIGHT", 10, -10)
    b.glowTex:SetColorTexture(1, 0.8, 0.35, 0.35)
    b.glowTex:SetBlendMode("ADD")
    b.glowTex:SetAlpha(0)
    Kit.Parchment(b)
    Widgets.Rim(b, b)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(46, 46)
    b.icon:SetPoint("TOP", 0, -18)
    local mask = b:CreateMaskTexture()
    mask:SetTexture(MC.Tex("disc_mask"), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(b.icon)
    b.icon:AddMaskTexture(mask)
    local ring = b:CreateTexture(nil, "OVERLAY")
    ring:SetPoint("CENTER", b.icon)
    ring:SetSize(60, 60)
    Kit.Atlas(ring, "hud-PlayerFrame-portraitring-large", MC.Tex("node_ring"))
    b.ring = ring
    b.name = Kit.Ink(b, 14, { 0.45, 0.12, 0.04 })
    b.name:SetPoint("TOP", b.icon, "BOTTOM", 0, -12)
    b.name:SetWidth(width - 16)
    b.desc = Kit.Ink(b, 11, { 0.2, 0.12, 0.05 })
    b.desc:SetPoint("TOP", b.name, "BOTTOM", 0, -6)
    b.desc:SetWidth(width - 24)
    b.desc:SetJustifyH("CENTER")
    -- Rarity (treasures): a frame in the rarity's colour inside the rim, the ring tinted, the name in
    -- its ink, the rarity's name at the foot; epic and legendary cards glow.
    b.aura = b:CreateTexture(nil, "BACKGROUND", nil, -7)
    b.aura:SetPoint("TOPLEFT", -26, 26)
    b.aura:SetPoint("BOTTOMRIGHT", 26, -26)
    b.aura:SetTexture(MC.Tex("soft_spot"))
    b.aura:SetBlendMode("ADD")
    b.aura:Hide()
    b.frame = {}
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local t = b:CreateTexture(nil, "BORDER", nil, 2)
        if side == "TOP" or side == "BOTTOM" then
            local y = side == "TOP" and -1 or 1
            t:SetPoint(side .. "LEFT", 1, y)
            t:SetPoint(side .. "RIGHT", -1, y)
            t:SetHeight(4)
        else
            local x = side == "LEFT" and 1 or -1
            t:SetPoint("TOP" .. side, x, -1)
            t:SetPoint("BOTTOM" .. side, x, 1)
            t:SetWidth(4)
        end
        t:Hide()
        b.frame[#b.frame + 1] = t
    end
    b.rarity = Kit.Ink(b, 11, { 1, 1, 1 })
    b.rarity:SetPoint("BOTTOM", 0, 10)
    function b:SetRarity(rarity)
        local color, ink = rarity and MC.RARITY_COLORS[rarity], rarity and MC.RARITY_INKS[rarity]
        for _, t in ipairs(self.frame) do
            t:SetShown(color ~= nil)
            if color then t:SetColorTexture(color[1], color[2], color[3], rarity == "common" and 0.55 or 0.9) end
        end
        self.ring:SetDesaturated(color ~= nil)
        if color and rarity ~= "common" then
            self.ring:SetVertexColor(color[1], color[2], color[3])
        else
            self.ring:SetVertexColor(1, 1, 1)
        end
        self.name:SetTextColor(unpack(ink or { 0.45, 0.12, 0.04 }))
        self.rarity:SetText(rarity and L["MC_RARITY_" .. rarity:upper()] or "")
        if ink then self.rarity:SetTextColor(ink[1], ink[2], ink[3]) end
        local glow = rarity == "epic" or rarity == "legendary"
        self.aura:SetShown(glow)
        if glow then self.aura:SetVertexColor(color[1], color[2], color[3], rarity == "legendary" and 0.7 or 0.45) end
    end
    b:HookScript("OnClick", function() PlaySound(SOUNDKIT.IG_MAINMENU_OPTION) end)
    Kit.Hover(b, { grow = 1.04, lift = 6, sound = false })
    return b
end
MC.OptionButton = OptionButton

-- A treasure's name in its rarity's colour (for tooltips and lists on dark backgrounds).
function MC.TreasureName(id)
    local t = MC.Treasures[id]
    local c = t and MC.RARITY_COLORS[t.rarity] or { 1, 0.82, 0 }
    return ("|cff%02x%02x%02x%s|r"):format(c[1] * 255, c[2] * 255, c[3] * 255, L["MC_T_" .. id])
end

function Module:TreasureText(id, mercId)
    local t = MC.Treasures[id]
    return L["MC_T_" .. id], Describe.Mods(t.mods, MC.Mercs[mercId] and MC.Mercs[mercId].abilities)
end

function Module:CreatePages()
    local overlay = self.overlay

    local pause = overlay:AddPage("pause")
    local pauseTitle = Widgets.PageTitle(pause, "PAUSED", -150)
    local landed = Widgets.Text(pause, 14, "blue")
    landed:SetPoint("TOP", pauseTitle, "BOTTOM", 0, -8)
    local resume = Widgets.Button(pause, 200, 26, "RESUME", function() self:Route() end)
    resume:SetPoint("TOP", landed, "BOTTOM", 0, -30)
    pause.refresh = function(data) landed:SetText((data and data.landed) and L.LANDED or L.MC_SAVED) end

    -- Treasure: three choices for one mercenary; cursed offers may be declined.
    local treasure = overlay:AddPage("treasure")
    local tTitle = Widgets.PageTitle(treasure, nil, -26)
    local tSub = Widgets.Text(treasure, 14, "blue")
    tSub:SetPoint("TOP", tTitle, "BOTTOM", 0, -6)
    tSub:SetWidth(W - 120)
    local tToken = MC.CreateToken(treasure)
    tToken:SetPoint("TOP", treasure, "TOP", 0, -98)
    tToken:EnableMouse(false)
    local tButtons = {}
    for i = 1, 3 do
        local b = OptionButton(treasure, 200, 196)
        MC.Kit.Place(b, W / 2 + (i - 2) * 220, 352, treasure)
        b:SetScript("OnClick", function()
            local store = self:Store()
            if Bounty.ChooseTreasure(store, store.run, i) then
                PlaySound(SOUNDKIT.IG_QUEST_LIST_COMPLETE)
                self:Route()
            end
        end)
        tButtons[i] = b
    end
    local decline = Widgets.Button(treasure, 200, 26, "MC_DECLINE", function()
        local store = self:Store()
        if Bounty.ChooseTreasure(store, store.run, nil) then self:Route() end
    end)
    decline:SetPoint("TOP", treasure, "TOP", 0, -456)
    self.treasureButtons, self.declineButton = tButtons, decline
    treasure.refresh = function()
        local run = self:Store().run
        local offer = run and run.offer
        if not offer then return end
        local mercId = run.party[offer.member].id
        local cursed = offer.kind == "cursed"
        local unit = MC.PreviewUnit(self:Store(), mercId, run.party[offer.member].guest)
        unit.side = "ally"
        tToken:SetData(unit)
        tTitle:SetText(cursed and L.MC_CURSED_TITLE or L.MC_TREASURE_TITLE)
        tSub:SetText((cursed and L.MC_CURSED_SUB or L.MC_TREASURE_SUB):format(Describe.MercName(mercId), MC.CURSE_HEALTH * 100))
        for i, b in ipairs(tButtons) do
            local id = offer.options[i]
            b:SetShown(id ~= nil)
            if id then
                local name, desc = self:TreasureText(id, mercId)
                b.icon:SetTexture(MC.Treasures[id].icon)
                b.name:SetText(name)
                b.desc:SetText(desc)
                b:SetRarity(MC.Treasures[id].rarity)
            end
        end
        decline:SetShown(cursed)
    end

    -- An event on the way: what the stop brought, until the player moves on.
    local eventPage = overlay:AddPage("event")
    local card = OptionButton(eventPage, 320, 170)
    card:SetPoint("CENTER", 0, 20)
    card:EnableMouse(false)
    MC.Kit.NoHover(card)
    card.name:SetFont(Media.FontFile(), 18, "")
    card.desc:SetFont(Media.FontFile(), 13, "")
    local eventToken = MC.CreateToken(eventPage)
    eventToken:SetScale(0.7)
    eventToken:SetPoint("BOTTOM", card, "TOP", 0, -30 / 0.7)
    eventToken:EnableMouse(false)
    local eventGo = MC.Kit.Button(eventPage, 180, 30, "MC_CONTINUE", function() self.overlay:Hide() end, "blue")
    eventGo:SetPoint("TOP", card, "BOTTOM", 0, -16)
    self.eventContinue = eventGo
    eventPage.refresh = function(ev)
        if not ev then return end
        card.icon:SetTexture(ev.icon)
        card.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        card.name:SetText(ev.title)
        card.desc:SetText(ev.text)
        eventToken:SetShown(ev.merc ~= nil)
        if ev.merc then
            local run = self:Store().run
            local member = run and run.party[#run.party]
            local unit = MC.PreviewUnit(self:Store(), ev.merc, member and member.guest)
            unit.side = "ally"
            eventToken:SetData(unit)
        end
    end

    -- Spirit healer: bring one fallen mercenary back.
    local healer = overlay:AddPage("healer")
    Widgets.PageTitle(healer, "MC_HEALER_TITLE", -60)
    local hSub = Widgets.LocalizedText(healer, 14, "blue", "MC_HEALER_SUB")
    hSub:SetPoint("TOP", 0, -104)
    local hButtons = {}
    for i = 1, 6 do
        local b = OptionButton(healer, 120, 120)
        b:SetPoint("TOP", healer, "TOP", (i - 3.5) * 130, -170)
        b.desc:Hide()
        b:SetScript("OnClick", function()
            local store = self:Store()
            if Bounty.Revive(store.run, b.member) then
                MC.Sound("heal")
                self:Route()
            end
        end)
        hButtons[i] = b
    end
    local hSkip = Widgets.Button(healer, 200, 26, "MC_CONTINUE", function()
        local store = self:Store()
        Bounty.Revive(store.run, nil)
        self:Route()
    end)
    hSkip:SetPoint("TOP", 0, -330)
    self.healerButtons, self.healerSkip = hButtons, hSkip
    healer.refresh = function()
        local run = self:Store().run
        if not run then return end
        local dead = Bounty.DeadMembers(run)
        -- The healer only waits when someone has fallen; one of them must be brought back.
        hSkip:SetShown(#dead == 0)
        for i, b in ipairs(hButtons) do
            local idx = dead[i]
            b:SetShown(idx ~= nil)
            if idx then
                local id = run.party[idx].id
                b.member = idx
                if MC.Kit.HAS_PORTRAITS then
                    SetPortraitTextureFromCreatureDisplayID(b.icon, MC.Mercs[id].display)
                else
                    b.icon:SetTexture(MC.Tex("role_" .. MC.Mercs[id].role))
                end
                b.name:SetText(Describe.MercName(id))
            end
        end
        for i, b in ipairs(hButtons) do
            b:ClearAllPoints()
            b:SetPoint("TOP", healer, "TOP", (i - (#dead + 1) / 2) * 130, -170)
        end
    end

    -- Mysterious stranger: copy a treasure the party already carries.
    local stranger = overlay:AddPage("stranger")
    Widgets.PageTitle(stranger, "MC_STRANGER_TITLE", -40)
    local sSub = Widgets.LocalizedText(stranger, 14, "blue", "MC_STRANGER_SUB")
    sSub:SetPoint("TOP", 0, -84)
    local sButtons = {}
    for i = 1, 8 do
        local b = CreateFrame("Button", nil, stranger)
        b:SetSize(360, 40)
        local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
        b:SetPoint("TOPLEFT", stranger, "TOP", (col == 0 and -370 or 10), -120 - row * 48)
        local fill = b:CreateTexture(nil, "BACKGROUND")
        fill:SetAllPoints()
        fill:SetColorTexture(0.08, 0.06, 0.1, 0.92)
        Widgets.Rim(b, b)
        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 0.82, 0.4, 0.12)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetSize(32, 32)
        b.icon:SetPoint("LEFT", 4, 0)
        b.text = Widgets.Text(b, 12, "white")
        b.text:SetPoint("LEFT", b.icon, "RIGHT", 8, 0)
        b.text:SetWidth(310)
        b.text:SetJustifyH("LEFT")
        b:SetScript("OnClick", function()
            local store = self:Store()
            if Bounty.Stranger(store.run, b.option) then
                PlaySound(SOUNDKIT.IG_QUEST_LIST_COMPLETE)
                self:Route()
            end
        end)
        sButtons[i] = b
    end
    self.strangerButtons = sButtons
    stranger.refresh = function()
        local run = self:Store().run
        if not run then return end
        local options = Bounty.StrangerOptions(run)
        for i, b in ipairs(sButtons) do
            local o = options[i]
            b:SetShown(o ~= nil)
            if o then
                b.option = i
                local id = run.party[o.member].id
                b.icon:SetTexture(MC.Treasures[o.treasure].icon)
                b.text:SetText(("%s  ·  %s"):format(MC.TreasureName(o.treasure), Describe.MercName(id)))
            end
        end
    end

    self:CreateResultPage()

    local confirm = overlay:AddPage("confirm")
    Widgets.PageTitle(confirm, "MC_ABANDON_TITLE", -150)
    local cText = Widgets.LocalizedText(confirm, 14, "blue", "MC_ABANDON_TEXT")
    cText:SetPoint("TOP", 0, -196)
    cText:SetWidth(W - 160)
    local yes = Widgets.Button(confirm, 180, 26, "MC_ABANDON", function() self:AbandonRun() end)
    yes:SetPoint("TOP", -96, -260)
    local no = Widgets.Button(confirm, 180, 26, "BACK", function() self:Route() end)
    no:SetPoint("TOP", 96, -260)

    Widgets.ScoresPage(overlay, W, {
        gameId = self.id,
        detail = function(entry) return self:ScoreDetail(entry) end,
        shareMessage = ShareMessage,
        onBack = function() self:Route() end,
    })
    local function Back()
        if self.subPageBack and self.subPageBack ~= "menu" then
            overlay:Show(self.subPageBack, self.subPageBackData)
        else
            self:Route()
        end
    end
    Widgets.AchievementsPage(overlay, W, self.id, Back)
    self:BuildHelp(Back)
end

-- The result page lives in Result.lua.
function Module:ShareText(entry)
    return ShareMessage(entry)
end

-- A short notice on the map: what a boon, a mystery or an idle healer did.
function Module:MapEvent(text)
    self.mapEvent = text
    self.mapEventTime = 4
end

-- Floating text for battle and map effects.
function Module:Popup(x, y, text, size, r, g, b, duration, rise)
    local fs = self.textPool.Acquire()
    fs:SetFont(Media.FontFile(), size or 16, "OUTLINE")
    fs:SetTextColor(r or 1, g or 1, b or 1)
    fs:SetText(text)
    fs:ClearAllPoints()
    fs:SetPoint("CENTER", self.fxLayer, "TOPLEFT", x, -y)
    fs:SetAlpha(1)
    fs:Show()
    duration, rise = duration or 0.9, rise or 30
    self.effects[#self.effects + 1] = {
        t = 0,
        update = function(e)
            local p = e.t / duration
            if p >= 1 then return false end
            fs:SetPoint("CENTER", self.fxLayer, "TOPLEFT", x, -(y - rise * p))
            fs:SetAlpha(p < 0.7 and 1 or (1 - (p - 0.7) / 0.3))
            return true
        end,
        finish = function() self.textPool.Release(fs) end,
    }
end

function Module:ClearEffects()
    for _, e in ipairs(self.effects) do
        if e.finish then e.finish(e) end
    end
    self.effects = {}
end

-- Arcade interface ------------------------------------------------------------------------------------

function Module:Sidebar()
    local store = self:Store()
    local run = store.run
    local info
    if run then
        info = Describe.ZoneName(run.zone) .. (run.heroic and (" (" .. L.MC_HEROIC .. ")") or "")
            .. "\n" .. L.MC_STAGE:format(math.max(run.layer, 0), #run.map.layers)
    else
        info = L.MC_PARTY_LEVEL:format(math.floor(Bounty.PartyLevel(store)))
    end
    return { score = run and run.score or 0, bucket = "default", info = info }
end

function Module:ScoreDetail(entry)
    if not entry.zone then return "" end
    return Describe.ZoneName(entry.zone) .. (entry.heroic and " (H)" or "")
end

function Module:ShowAchievements()
    Widgets.ShowSubPage(self, "achievements")
end

function Module:ShowHelp()
    Widgets.ShowSubPage(self, "help")
end

function Module:Enter()
    -- Also grants achievements earned before they existed.
    self:CheckLevels()
    self:Route()
end

function Module:Leave()
    self:Pause({})
end

-- Battles are turn by turn and the run is saved after every step, so pausing only matters
-- to tell the player they landed.
function Module:Pause(info)
    if not self.overlay then return end
    if info.landed and not self.overlay.current and self:Store().run then
        self.overlay:Show("pause", info)
    end
end

function Module:RefreshTexts()
    self.overlay:Refresh()
    local frame = self.view and self.views[self.view]
    if frame and frame.refresh then frame.refresh() end
end

function Module:OnKey(key)
    if self.overlay.current then return false end
    if self.view == "battle" then return self:BattleKey(key) end
    return false
end

function Module:OnUpdate(dt)
    if self.view == "battle" then self:UpdateBattle(dt) end
    if self.view == "map" then self:UpdateMap(dt) end
    if self.view == "travel" then self:UpdateTravel(dt) end
    for i = #self.effects, 1, -1 do
        local e = self.effects[i]
        e.t = e.t + dt
        if not e.update(e, dt) then
            if e.finish then e.finish(e) end
            table.remove(self.effects, i)
        end
    end
end

function Module:DecorateTile(tile, art)
    local displays = { 4527, 2970, 4307 } -- Thrall, Jaina, Cairne
    for i, display in ipairs(displays) do
        local m = CreateFrame("PlayerModel", nil, tile)
        -- Right of the logo and below the best score.
        m:SetSize(96, 112)
        m:SetPoint("BOTTOMRIGHT", art, "BOTTOMRIGHT", 6 - (#displays - i) * 58, 2)
        local function Apply()
            pcall(m.SetDisplayInfo, m, display)
            pcall(m.SetFacing, m, 0.5 - (i - 1) * 0.35)
        end
        Apply()
        m:SetScript("OnShow", Apply)
    end
end

function Module:Options()
    return {
        { kind = "check", tbl = Arcade.Settings(self), key = "fast", label = "MC_OPT_FAST", tip = "MC_OPT_FAST_TIP", default = false },
        { kind = "choice", tbl = Arcade.Settings(self), key = "sounds", label = "MC_OPT_SOUNDS", tip = "MC_OPT_SOUNDS_TIP",
            default = "ingame", choices = function()
                return { { "ingame", L.MC_SOUNDS_INGAME }, { "simple", L.MC_SOUNDS_SIMPLE } }
            end },
    }
end

function Module:StatLines()
    local store = self:Store()
    local owned, best = 0, 0
    for id, entry in pairs(store.mercs) do
        if entry.owned and MC.Mercs[id] then owned = owned + 1 end
        best = math.max(best, entry.level)
    end
    local normal, heroic = 0, 0
    for _, state in pairs(store.zones) do
        if (state.normal or 0) > 0 then normal = normal + 1 end
        if (state.heroic or 0) > 0 then heroic = heroic + 1 end
    end
    return {
        { L.MC_STAT_ZONES, ("%d / %d"):format(normal, #MC.ZONE_ORDER) },
        { L.MC_STAT_HEROIC, ("%d / %d"):format(heroic, #MC.ZONE_ORDER) },
        { L.MC_STAT_MERCS, ("%d / %d"):format(owned, #MC.MERC_ORDER) },
        { L.MC_STAT_LEVEL, tostring(best) },
        { L.MC_STAT_FIGHTS, ns.FormatNumber(store.stats.fights) },
    }
end

function Module:ResetProgress()
    local store = Arcade.Settings(self)
    for k in pairs(store) do
        if k ~= "fast" then store[k] = nil end
    end
    Bounty.Init(store)
    if self.overlay then self:Route() end
end

Arcade.RegisterGame(Module)
