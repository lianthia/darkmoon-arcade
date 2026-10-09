-- The end of a bounty: a banner, the run in three numbers, and the party - mercenaries that gained
-- levels jump, light up and count their level up one after the other. Then coins and unlocks.

local _, ns = ...
local MC = ns.Mercenaries
local Bounty, Describe, Kit = MC.Bounty, MC.Describe, MC.Kit
local Widgets, L = ns.Widgets, ns.L
local Module = MC.Module
local W, H = MC.W, MC.H

local PARTY_Y, GAP, SCALE = 300, 124, 0.82
local STEP = 0.45   -- seconds between two mercenaries' level-up animations

local function StatTile(parent, icon)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(170, 64)
    Kit.Parchment(f)
    Widgets.Rim(f, f)
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetSize(38, 38)
    f.icon:SetPoint("LEFT", 12, 0)
    f.icon:SetTexture(icon)
    f.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    f.label = Kit.Ink(f, 11, { 0.35, 0.2, 0.08 })
    f.label:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 10, -1)
    f.value = Kit.Ink(f, 20, { 0.45, 0.12, 0.04 })
    f.value:SetPoint("BOTTOMLEFT", f.icon, "BOTTOMRIGHT", 10, -1)
    return f
end

function Module:CreateResultPage()
    local page = self.overlay:AddPage("result")
    local wood = Kit.Wood(page, W, H, true)
    wood:SetPoint("TOPLEFT")
    -- Texts and small pictures sit on their own layer above the wood.
    local top = CreateFrame("Frame", nil, page)
    top:SetAllPoints()
    top:SetFrameLevel(page:GetFrameLevel() + 20)
    local banner = Kit.Plaque(page, 380, nil, 22)
    banner:SetPoint("TOP", 0, 6)
    page.banner = banner
    page.zone = Kit.Ink(top, 14, { 1, 0.9, 0.7 }, "OUTLINE")
    page.zone:SetPoint("TOP", banner, "BOTTOM", 0, 10)
    page.zone:SetWidth(W - 100)

    page.tiles = {
        StatTile(page, "Interface\\Icons\\Ability_DualWield"),
        StatTile(page, "Interface\\Icons\\INV_Misc_Book_09"),
        StatTile(page, "Interface\\Icons\\INV_Misc_Ribbon_01"),
    }
    for i, tile in ipairs(page.tiles) do
        tile:SetPoint("TOP", page, "TOP", (i - 2) * 186, -140)
    end

    -- The party: portrait, a "Level up!" ribbon, rising sparks and the coins it earned.
    page.members = {}
    for i = 1, Bounty.PARTY_SIZE do
        local m = {}
        m.token = MC.CreateToken(page)
        m.token:EnableMouse(false)
        m.token.name:SetWidth(GAP / SCALE)
        m.token.glow:SetVertexColor(1, 0.82, 0.3)
        m.ribbon = Kit.Banner(page, 112, 26, 11)
        m.ribbon:SetFrameLevel(m.token:GetFrameLevel() + 10)
        m.ribbon.text:SetText(L.MC_LEVEL_UP)
        m.ribbon.text:SetTextColor(0.45, 0.2, 0)
        m.sparks = {}
        for k = 1, 6 do
            local s = top:CreateTexture(nil, "OVERLAY", nil, 6)
            s:SetTexture(MC.Tex("soft_spot"))
            s:SetBlendMode("ADD")
            s:SetVertexColor(1, 0.85, 0.35)
            s:SetSize(14, 14)
            s:Hide()
            m.sparks[k] = s
        end
        m.coin = Kit.CoinIcon(top, 18)
        m.coins = Kit.Ink(top, 13, { 1, 0.9, 0.6 }, "OUTLINE")
        m.coins:SetPoint("LEFT", m.coin, "RIGHT", 3, 0)
        page.members[i] = m
    end

    page.lines = Kit.Ink(top, 12, { 1, 0.95, 0.85 }, "OUTLINE")
    page.lines:SetPoint("TOP", page, "TOP", 0, -408)
    page.lines:SetWidth(W - 120)
    page.lines:SetSpacing(4)

    local share = Widgets.ShareRow(page, function() return self.lastEntry and self:ShareText(self.lastEntry) end)
    share:SetPoint("BOTTOM", 0, 50)
    page.share = share
    local close = Kit.Button(page, 220, 30, "MC_TO_CAMP", function() self:CloseRun() end, "blue")
    Kit.Place(close, W / 2, H - 22, page)
    self.resultClose = close

    page:SetScript("OnUpdate", function(_, dt) self:AnimateResult(dt) end)
    page.refresh = function() self:RefreshResult() end
end

function Module:RefreshResult()
    local page = self.overlay.pages.result
    local store = self:Store()
    local run = store.run
    if not run then return end
    local won = run.phase == "complete"
    Kit.FitText(page.banner.text, won and L.MC_COMPLETE or L.MC_DEFEAT, 380 * 0.7, 22, 15)
    page.banner.text:SetTextColor(won and 0.24 or 0.5, won and 0.14 or 0.05, won and 0.06 or 0.03)
    page.zone:SetText(Describe.ZoneName(run.zone) .. (run.heroic and (" (" .. L.MC_HEROIC .. ")") or ""))

    local values = { run.fights, ns.FormatNumber(run.xp), ns.FormatNumber(run.score) }
    local labels = { L.MC_STAT_FIGHTS, L.MC_STAT_XP, L.MC_STAT_SCORE }
    for i, tile in ipairs(page.tiles) do
        tile.label:SetText(labels[i])
        tile.value:SetText(values[i])
    end

    -- Who gained levels: against the levels at the start of the run (older saves: the last fight).
    local gained = {}
    if run.startLevels then
        for _, member in ipairs(run.party) do
            local before = run.startLevels[member.id]
            local now = store.mercs[member.id].level
            if before and now > before then gained[member.id] = before end
        end
    else
        for _, id in ipairs(run.levelUps or {}) do gained[id] = store.mercs[id].level - 1 end
    end

    local coins = won and run.rewards and run.rewards.coins or {}
    local members = {}
    for _, member in ipairs(run.party) do
        if not member.guest then members[#members + 1] = member end
    end
    local n = #members
    local order = 0
    self.resultAnims = {}
    for i, m in ipairs(page.members) do
        local member = members[i]
        local shown = member ~= nil
        m.token:SetShown(shown)
        m.ribbon:Hide()
        m.coin:SetShown(shown and coins[member and member.id] ~= nil)
        m.coins:SetText("")
        for _, s in ipairs(m.sparks) do s:Hide() end
        if shown then
            local x = W / 2 + (i - (n + 1) / 2) * GAP
            m.x = x
            m.token:SetScale(SCALE)
            m.token:ClearAllPoints()
            m.token:SetPoint("CENTER", page, "TOPLEFT", x / SCALE, -PARTY_Y / SCALE)
            local unit = MC.PreviewUnit(store, member.id)
            unit.side = "ally"
            m.token:SetData(unit)
            m.token.glow:Hide()
            m.token:SetAlpha(member.dead and 0.55 or 1)
            m.ribbon:ClearAllPoints()
            m.ribbon:SetPoint("BOTTOM", page, "TOPLEFT", x, -(PARTY_Y - MC.TOKEN_H * SCALE / 2 - 4))
            m.coin:ClearAllPoints()
            m.coin:SetPoint("TOPRIGHT", page, "TOPLEFT", x - 2, -(PARTY_Y + MC.TOKEN_H * SCALE / 2 + 22))
            if coins[member.id] then m.coins:SetText("+" .. coins[member.id]) end
            local before = gained[member.id]
            if before then
                -- Starts at the old level and waits for its turn.
                m.token.level.text:SetText(before)
                order = order + 1
                self.resultAnims[#self.resultAnims + 1] = { m = m, from = before, to = unit.level, t = -order * STEP }
            end
        end
    end

    local out = {}
    if won then
        local r = run.rewards
        if r.first then out[#out + 1] = "|cffffd100" .. L.MC_FIRST_CLEAR .. "|r" end
        -- Coins for mercenaries outside the party (the zone's loot) are listed by name.
        local extra = {}
        local inParty = {}
        for _, member in ipairs(run.party) do inParty[member.id] = true end
        for _, id in ipairs(MC.MERC_ORDER) do
            if r.coins[id] and not inParty[id] then extra[#extra + 1] = ("%s +%d"):format(Describe.MercName(id), r.coins[id]) end
        end
        if #extra > 0 then out[#out + 1] = L.MC_COINS_EARNED:format(table.concat(extra, ", ")) end
        if r.gear then
            out[#out + 1] = "|cff40ff40" .. L.MC_GEAR_UNLOCKED:format(L["MC_G_" .. r.gear.merc .. "_" .. r.gear.slot], Describe.MercName(r.gear.merc)) .. "|r"
        end
        if not run.heroic and r.first then out[#out + 1] = "|cffa335ee" .. L.MC_HEROIC_UNLOCKED .. "|r" end
    end
    page.lines:SetText(table.concat(out, "\n"))
    if run.score > 0 then
        self.lastEntry = { score = run.score, zone = run.zone, heroic = run.heroic or nil }
    end
    page.share:SetShown(run.score > 0)
end

-- Each level-up: a jump with a golden glow, the level counting up, sparks rising, then the ribbon.
function Module:AnimateResult(dt)
    for _, a in ipairs(self.resultAnims or {}) do
        a.t = a.t + dt
        local m, t = a.m, a.t
        if t >= 0 and not a.done then
            if not a.started then
                a.started = true
                m.token.glow:Show()
                PlaySound(SOUNDKIT.IG_QUEST_LIST_COMPLETE)
            end
            local p = math.min(1, t / 0.9)
            -- A quick jump that settles back.
            local jump = math.sin(math.min(1, t / 0.45) * math.pi) * 18
            local grow = 1 + math.sin(math.min(1, t / 0.45) * math.pi) * 0.12
            m.token:SetScale(SCALE * grow)
            m.token:ClearAllPoints()
            m.token:SetPoint("CENTER", m.token:GetParent(), "TOPLEFT", m.x / (SCALE * grow), -(PARTY_Y - jump) / (SCALE * grow))
            m.token.level.text:SetText(math.floor(a.from + (a.to - a.from) * p + 0.5))
            for k, s in ipairs(m.sparks) do
                local sp = (t * 0.9 + k / #m.sparks) % 1
                s:SetShown(t < 2.2)
                s:ClearAllPoints()
                s:SetPoint("CENTER", m.token:GetParent(), "TOPLEFT", m.x + math.sin(k * 2.1) * 34, -(PARTY_Y + 40 - sp * 110))
                s:SetAlpha(1 - sp)
            end
            if t > 0.45 then m.ribbon:Show() end
            if t >= 2.2 then
                a.done = true
                m.token:SetScale(SCALE)
                m.token:ClearAllPoints()
                m.token:SetPoint("CENTER", m.token:GetParent(), "TOPLEFT", m.x / SCALE, -PARTY_Y / SCALE)
                m.token.level.text:SetText(a.to)
            end
        end
        if a.done then
            m.token.glow:SetAlpha(0.6 + 0.3 * math.sin(GetTime() * 4))
        end
    end
end
