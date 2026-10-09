-- The battle board: foes on top, the party in the middle and a tray at the bottom that holds the
-- selected mercenary's abilities (or the bench while choosing who fights). Nothing in the tray
-- ever covers a token. A turn is resolved at once in Combat; this view plays its events back.

local _, ns = ...
local MC = ns.Mercenaries
local Combat, Describe, Kit = MC.Combat, MC.Describe, MC.Kit
local Widgets, Media, L = ns.Widgets, ns.Media, ns.L
local Module = MC.Module
local W, H = MC.W, MC.H

local ENEMY_Y, ALLY_Y, MID_Y = 122, 318, 222
local TRAY_TOP, TRAY_Y = 418, 490
local SPACING = 150
local BENCH_SPACING, BENCH_SCALE, BENCH_X = 100, 0.72, 360
local CARD_GAP, CARD_SCALE, CARD_X = 112, 0.78, 380
local KEY_SLOT = { ["1"] = 1, ["2"] = 2, ["3"] = 3 }
local MAX_DASHES = 40

local SCHOOL_COLORS = {
    physical = { 1, 0.3, 0.25 }, fire = { 1, 0.5, 0.1 }, frost = { 0.5, 0.8, 1 }, nature = { 0.4, 1, 0.3 },
    shadow = { 0.75, 0.45, 1 }, holy = { 1, 0.9, 0.5 }, arcane = { 1, 0.5, 1 },
}

function Module:Battle()
    local run = self:Store().run
    return run and run.battle, run
end

local function Place(region, x, y)
    region:ClearAllPoints()
    region:SetPoint("CENTER", region:GetParent(), "TOPLEFT", x, -y)
end

function Module:BuildBattle()
    local view = self:AddView("battle", CreateFrame("Frame", nil, self.container))

    -- The board: Forever's dark bronze ground, a lighter field for each side and the tray.
    local board = view:CreateTexture(nil, "BACKGROUND", nil, 0)
    board:SetAllPoints()
    Kit.Atlas(board, "heavybronze-frame-background-c60", nil)
    if not Kit.HasAtlas("heavybronze-frame-background-c60") then board:SetColorTexture(0.12, 0.09, 0.07, 1) end
    local function Field(y0, y1, r, g, b, a)
        local t = view:CreateTexture(nil, "BACKGROUND", nil, 1)
        t:SetPoint("TOPLEFT", 10, -y0)
        t:SetPoint("BOTTOMRIGHT", view, "TOPRIGHT", -10, -y1)
        t:SetColorTexture(r, g, b, a)
        return t
    end
    view.enemyField = Field(44, 212, 0.45, 0.12, 0.08, 0.18)
    view.allyField = Field(232, 404, 0.12, 0.25, 0.42, 0.18)
    local tray = Field(TRAY_TOP, H, 0, 0, 0, 0.45)
    tray:SetPoint("BOTTOMRIGHT", 0, 0)
    tray:SetPoint("TOPLEFT", 0, -TRAY_TOP)
    local trayEdge = view:CreateTexture(nil, "BORDER")
    trayEdge:SetPoint("TOPLEFT", 0, -TRAY_TOP)
    trayEdge:SetPoint("TOPRIGHT", 0, -TRAY_TOP)
    trayEdge:SetHeight(2)
    trayEdge:SetColorTexture(0.85, 0.65, 0.3, 0.8)
    local vignette = view:CreateTexture(nil, "BACKGROUND", nil, 3)
    vignette:SetAllPoints()
    vignette:SetTexture(MC.Tex("vignette"))
    vignette:SetAlpha(0.7)

    self.tokens = {}
    self.tokenPool = Media.Pool(function()
        local t = MC.CreateToken(view)
        t:SetScript("OnClick", function(token, button) self:TokenClicked(token, button) end)
        t:SetScript("OnEnter", function(token)
            token.hovered = true
            local b = self:Battle()
            local u = b and token.uid and b.units[token.uid]
            if u then MC.UnitTooltip(token, u, u.side == "enemy" and self:PartyReference() or nil) end
        end)
        t:SetScript("OnLeave", function(token)
            token.hovered = false
            GameTooltip:Hide()
        end)
        return t
    end, function(t)
        t:Hide()
        t.uid, t.unitKey = false, false
        t.x, t.y, t.tx, t.ty = false, false, false, false
        t.shake, t.fadeIn, t.flashT, t.lunge = 0, false, 0, false
        t.hovered, t.clickable, t.pulse = false, false, false
        t.base, t.cur = 1, 1
        t:SetScale(1)
    end)

    view.zone = Widgets.Text(view, 14, "gold")
    view.zone:SetPoint("TOPLEFT", 18, -14)
    view.turn = Widgets.Text(view, 13, "white")
    view.turn:SetPoint("TOPRIGHT", -18, -14)
    view.reserve = Widgets.Text(view, 11, "gray")
    view.reserve:SetPoint("TOPRIGHT", -18, -32)
    view.hint = Kit.Ink(view, 14, { 1, 0.92, 0.7 }, "OUTLINE")
    view.hint:SetPoint("CENTER", view, "TOPLEFT", W / 2, -MID_Y)
    view.hint:SetWidth(420)
    view.trayTitle = Kit.Ink(view, 13, { 1, 0.82, 0 }, "OUTLINE")
    view.trayTitle:SetPoint("LEFT", view, "TOPLEFT", 22, -(TRAY_TOP + 22))
    view.trayTitle:SetJustifyH("LEFT")
    view.trayTitle:SetWidth(200)
    view.trayText = Kit.Ink(view, 11, { 0.85, 0.85, 0.85 }, "OUTLINE")
    view.trayText:SetPoint("TOPLEFT", view.trayTitle, "BOTTOMLEFT", 0, -4)
    view.trayText:SetJustifyH("LEFT")
    view.trayText:SetWidth(200)

    -- The ability being used, shown big between the rows during playback.
    local banner = CreateFrame("Frame", nil, view)
    banner:SetSize(300, 50)
    banner:SetPoint("CENTER", view, "TOPLEFT", W / 2, -MID_Y)
    banner:SetFrameLevel(view:GetFrameLevel() + 40)
    banner.bg = banner:CreateTexture(nil, "ARTWORK")
    banner.bg:SetAllPoints()
    Kit.Atlas(banner.bg, "ui-frame-neutral-ribbon", MC.Tex("ribbon"))
    banner.icon = banner:CreateTexture(nil, "OVERLAY")
    banner.icon:SetSize(38, 38)
    banner.icon:SetPoint("CENTER", banner, "LEFT", 46, 2)
    banner.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local mask = banner:CreateMaskTexture()
    mask:SetTexture(MC.Tex("disc_mask"), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(banner.icon)
    banner.icon:AddMaskTexture(mask)
    banner.ring = banner:CreateTexture(nil, "OVERLAY", nil, 2)
    banner.ring:SetPoint("CENTER", banner.icon)
    banner.ring:SetSize(50, 50)
    Kit.Atlas(banner.ring, "hud-PlayerFrame-portraitring-large", MC.Tex("node_ring"))
    banner.text = Kit.Ink(banner, 15)
    banner.text:SetPoint("LEFT", banner.icon, "RIGHT", 10, 0)
    banner.text:SetPoint("RIGHT", -40, 3)
    banner:Hide()
    view.banner = banner

    self.cards = {}
    for i = 1, 3 do
        local card = Kit.AbilityCard(view)
        Kit.SetBaseScale(card, CARD_SCALE)
        Kit.Place(card, CARD_X + (i - 2) * CARD_GAP, TRAY_Y)
        card:SetScript("OnClick", function() self:PickAbility(i) end)
        card:HookScript("OnEnter", function(c)
            local b = self:Battle()
            local u = b and self.selected and b.units[self.selected]
            if not u or not c.abilityId then return end
            GameTooltip:SetOwner(c, "ANCHOR_TOP")
            GameTooltip:SetText(Describe.AbilityName(c.abilityId), 1, 0.82, 0)
            GameTooltip:AddLine(Describe.AbilityStats(c.abilityId, u, i), 0.7, 0.7, 0.7)
            GameTooltip:AddLine(Describe.Ability(c.abilityId, u, i), 1, 1, 1, true)
            GameTooltip:Show()
        end)
        card:HookScript("OnLeave", GameTooltip_Hide)
        card:Hide()
        self.cards[i] = card
    end

    self.readyButton = Kit.BigButton(view, 92, "MC_READY", function() self:ResolveTurn() end)
    Kit.Place(self.readyButton, W - 66, TRAY_Y + 4)
    self.autoButton = Kit.Button(view, 132, 28, "MC_AUTO", function() self:AutoChoose() end, "blue")
    Kit.Place(self.autoButton, W - 198, TRAY_Y + 30)

    -- The aiming line from a mercenary to the target under the mouse.
    local fx = CreateFrame("Frame", nil, view)
    fx:SetAllPoints()
    fx:SetFrameLevel(view:GetFrameLevel() + 30)
    self.battleFx = fx
    self.aimDashes = {}
    for i = 1, MAX_DASHES do
        local d = fx:CreateTexture(nil, "OVERLAY")
        d:SetTexture(MC.Tex("dash"))
        d:SetSize(16, 8)
        d:Hide()
        self.aimDashes[i] = d
    end
    self.projectiles = {}

    view.refresh = function() self:RefreshBattle() end
end

-- Average level of the party in this battle; foes' levels are coloured against it.
function Module:PartyReference()
    local b = self:Battle()
    if not b then return 1 end
    local sum, n = 0, 0
    for _, u in pairs(b.units) do
        if u.side == "ally" then sum, n = sum + u.level, n + 1 end
    end
    return n > 0 and math.floor(sum / n + 0.5) or 1
end

function Module:TokenFor(uid)
    local t = self.tokens[uid]
    if not t then
        t = self.tokenPool.Acquire()
        t.uid = uid
        t.base, t.cur = 1, 1
        t.shake, t.flashT = 0, 0
        self.tokens[uid] = t
    end
    return t
end

local function Slots(n, spacing, center)
    local list = {}
    for i = 1, n do list[i] = (center or W / 2) + (i - (n + 1) / 2) * spacing end
    return list
end

-- Puts every token where it belongs; tokens no longer needed go back to the pool.
function Module:LayoutBattle(b, boards)
    boards = boards or b.board
    local wanted = {}
    local function Row(list, y, spacing, scale, center)
        local xs = Slots(#list, spacing, center)
        for i, uid in ipairs(list) do
            local t = self:TokenFor(uid)
            wanted[uid] = true
            t.tx, t.ty = xs[i], y
            t.base = scale
            t.name:SetWidth(math.min(MC.TOKEN_W + 30, spacing / scale - 6))
            if not t.x then
                t.x, t.y, t.cur = t.tx, t.ty, scale
                t:SetScale(scale)
                Place(t, t.x / scale, t.y / scale)
            end
            t:Show()
        end
    end
    Row(boards.enemy, ENEMY_Y, SPACING, 1)
    Row(boards.ally, ALLY_Y, SPACING, 1)
    if (b.phase == "deploy" or b.phase == "replace") and not self.playing then
        Row(b.bench.ally, TRAY_Y, BENCH_SPACING, BENCH_SCALE, BENCH_X)
    end
    for uid, t in pairs(self.tokens) do
        if not wanted[uid] then
            self.tokens[uid] = nil
            self.tokenPool.Release(t)
        end
    end
end

function Module:IsBench(uid)
    local b = self:Battle()
    for _, id in ipairs(b.bench.ally) do
        if id == uid then return true end
    end
    return false
end

function Module:RefreshBattle()
    local b, run = self:Battle()
    local view = self.views.battle
    if not b then return end
    self:SetScene(nil)
    local zone = Describe.ZoneName(run.zone) .. (run.heroic and (" (" .. L.MC_HEROIC .. ")") or "")
    local node = MC.Bounty.Node(run)
    local kind = node and (node.type == "boss" and L.MC_NODE_BOSS or node.type == "elite" and L.MC_NODE_ELITE or L.MC_NODE_FIGHT) or ""
    view.zone:SetText(zone .. "  ·  " .. kind)
    view.turn:SetText(L.MC_TURN:format(b.turn))
    view.reserve:SetText(#b.bench.enemy > 0 and L.MC_RESERVE:format(#b.bench.enemy) or "")

    if self.playing then return end
    self:LayoutBattle(b)
    local reference = self:PartyReference()
    local commanding = b.phase == "command"
    local deploying = b.phase == "deploy" or b.phase == "replace"
    if commanding then
        local sel = self.selected and b.units[self.selected]
        if not sel or sel.dead or sel.side ~= "ally" or self:IsBench(sel.uid) then self:SelectNext(true) end
    else
        self.selected, self.pending = nil, nil
    end
    local validTargets = {}
    if self.pending then
        local u = b.units[self.pending.uid]
        for _, t in ipairs(Combat.ValidTargets(b, u, self.pending.slot)) do validTargets[t.uid] = true end
    end
    for uid, t in pairs(self.tokens) do
        local u = b.units[uid]
        t:SetData(MC.UnitView(u), u.side == "enemy" and reference or nil)
        local bench = deploying and self:IsBench(uid)
        local target = validTargets[uid] or false
        t.select:SetShown(commanding and uid == self.selected)
        t.glow:SetShown(target or bench)
        if target then
            if u.side == "enemy" then t.glow:SetVertexColor(1, 0.25, 0.15) else t.glow:SetVertexColor(0.3, 1, 0.35) end
        else
            t.glow:SetVertexColor(1, 0.8, 0.35)
        end
        t.clickable = bench or target or (commanding and not self.pending and u.side == "ally" and not u.dead)
        if u.side == "ally" and u.choice and commanding then
            t:SetBubble(u.abilities[u.choice.slot].id, Combat.Speed(b, u, u.choice.slot))
        else
            t:SetBubble(nil)
        end
    end

    local sel = commanding and self.selected and b.units[self.selected]
    for i, card in ipairs(self.cards) do
        local slot = sel and sel.abilities[i] or nil
        card:SetShown(slot ~= nil)
        if slot then
            card:SetAbility(slot.id, sel, i, slot.cd)
            local chosen = sel.choice and sel.choice.slot == i
            local pending = self.pending and self.pending.slot == i
            Kit.SetSelected(card, chosen or pending, pending)
        end
    end
    if sel then
        view.trayTitle:SetText(Describe.UnitName(sel.kind, sel.id))
        view.trayText:SetText(L.MC_TRAY_KEYS)
    elseif deploying then
        view.trayTitle:SetText(L.MC_BENCH_TITLE)
        view.trayText:SetText("")
    else
        view.trayTitle:SetText("")
        view.trayText:SetText("")
    end
    self.readyButton:SetShown(commanding)
    self.readyButton:SetEnabled(Combat.Ready(b))
    self.autoButton:SetShown(commanding)
    local hint
    if deploying then
        hint = L.MC_HINT_DEPLOY:format(Combat.DeploySlots(b))
    elseif self.pending then
        hint = L.MC_HINT_TARGET
    elseif not Combat.Ready(b) then
        hint = L.MC_HINT_CHOOSE
    else
        hint = L.MC_HINT_READY
    end
    view.hint:SetText(hint)
end

-- Selects the next mercenary on the board that still needs an order.
function Module:SelectNext(fromStart)
    local b = self:Battle()
    local row = b.board.ally
    local start = 0
    if not fromStart then
        for i, uid in ipairs(row) do
            if uid == self.selected then start = i end
        end
    end
    for k = 1, #row do
        local uid = row[(start + k - 1) % #row + 1]
        local u = b.units[uid]
        if not u.dead and not u.choice then
            self.selected = uid
            return
        end
    end
    if fromStart or not self.selected then self.selected = row[1] end
end

function Module:TokenClicked(token, button)
    local b = self:Battle()
    if not b or self.playing then return end
    local u = b.units[token.uid]
    if not u then return end
    if b.phase == "deploy" or b.phase == "replace" then
        if self:IsBench(u.uid) and Combat.Deploy(b, u.uid) then
            MC.Sound("select")
            self:RefreshBattle()
        end
        return
    end
    if b.phase ~= "command" then return end
    if button == "RightButton" then
        if u.side == "ally" then
            Combat.ClearChoice(b, u.uid)
            self.selected, self.pending = u.uid, nil
            self:RefreshBattle()
        end
        return
    end
    if self.pending then
        if Combat.SetChoice(b, self.pending.uid, self.pending.slot, u.uid) then
            MC.Sound("select")
            self.pending = nil
            self:SelectNext()
            self:RefreshBattle()
            return
        end
    end
    if u.side == "ally" and not u.dead then
        self.selected, self.pending = u.uid, nil
        MC.Sound("select")
        self:RefreshBattle()
    end
end

function Module:PickAbility(slot)
    local b = self:Battle()
    if not b or self.playing or b.phase ~= "command" then return end
    local u = self.selected and b.units[self.selected]
    if not u or not Combat.Available(u, slot) then return end
    local def = MC.Abilities[u.abilities[slot].id]
    if def.target == "enemy" or def.target == "ally" then
        local targets = Combat.ValidTargets(b, u, slot)
        if #targets == 1 then
            Combat.SetChoice(b, u.uid, slot, targets[1].uid)
            self.pending = nil
            self:SelectNext()
        else
            self.pending = { uid = u.uid, slot = slot }
        end
    else
        Combat.SetChoice(b, u.uid, slot)
        self.pending = nil
        self:SelectNext()
    end
    MC.Sound("select")
    self:RefreshBattle()
end

function Module:AutoChoose()
    local b = self:Battle()
    if not b or self.playing or b.phase ~= "command" then return end
    Combat.AutoChoose(b)
    self.pending = nil
    self:RefreshBattle()
end

function Module:BattleKey(key)
    local b = self:Battle()
    if not b or self.playing then return false end
    if KEY_SLOT[key] and b.phase == "command" then
        self:PickAbility(KEY_SLOT[key])
        return true
    elseif key == "TAB" and b.phase == "command" then
        self.pending = nil
        self:SelectNext()
        self:RefreshBattle()
        return true
    elseif (key == "SPACE" or key == "ENTER") and Combat.Ready(b) then
        self:ResolveTurn()
        return true
    elseif key == "A" then
        self:AutoChoose()
        return true
    elseif key == "ESCAPE" and self.pending then
        self.pending = nil
        self:RefreshBattle()
        return true
    end
    return false
end

-- Playback -------------------------------------------------------------------------------------------

function Module:ResolveTurn()
    local b = self:Battle()
    if not b or self.playing or not Combat.Ready(b) then return end
    self.disp = {}
    for uid, u in pairs(b.units) do self.disp[uid] = MC.UnitView(u) end
    self.pending = nil
    for _, card in ipairs(self.cards) do card:Hide() end
    self.readyButton:Hide()
    self.autoButton:Hide()
    local view = self.views.battle
    view.hint:SetText("")
    view.trayTitle:SetText("")
    view.trayText:SetText("")
    for _, t in pairs(self.tokens) do
        t.select:Hide()
        t.glow:Hide()
        t.clickable = false
    end
    local events = Combat.Resolve(b)
    self.queue, self.queueIndex, self.queueWait = events, 0, 0.15
    self.playing = true
    MC.Sound("ready")
end

function Module:ShowDisp(uid)
    local t, d = self.tokens[uid], self.disp[uid]
    if t and d then t:SetStats(d, d.side == "enemy" and self:PartyReference() or nil) end
end

function Module:TokenPoint(uid)
    local t = self.tokens[uid]
    if not t then return W / 2, H / 2 end
    return t.tx or t.x or W / 2, t.ty or t.y or H / 2
end

function Module:ShowBanner(abilityId)
    local banner = self.views.battle.banner
    banner.icon:SetTexture(MC.Abilities[abilityId].icon)
    banner.text:SetText(Describe.AbilityName(abilityId))
    banner:SetAlpha(1)
    banner:Show()
    self.bannerTime = 1.1
end

-- A glowing orb flying from one token to another (spells).
function Module:Projectile(src, dst, school)
    local x1, y1 = self:TokenPoint(src)
    local x2, y2 = self:TokenPoint(dst)
    local orb = self.battleFx:CreateTexture(nil, "OVERLAY")
    orb:SetTexture(MC.Tex("node_glow"))
    orb:SetBlendMode("ADD")
    orb:SetSize(34, 34)
    local c = SCHOOL_COLORS[school] or SCHOOL_COLORS.arcane
    orb:SetVertexColor(c[1], c[2], c[3])
    self.effects[#self.effects + 1] = {
        t = 0,
        update = function(e)
            local p = e.t / 0.28
            if p >= 1 then return false end
            local x, y = x1 + (x2 - x1) * p, y1 + (y2 - y1) * p - math.sin(p * math.pi) * 30
            orb:ClearAllPoints()
            orb:SetPoint("CENTER", self.battleFx, "TOPLEFT", x, -y)
            return true
        end,
        finish = function() orb:Hide() end,
    }
end

-- Plays one event and returns how long to wait before the next.
function Module:PlayEvent(e)
    local t = e.t
    local disp = self.disp
    if t == "order" then
        for i, item in ipairs(e.list) do
            local token = self.tokens[item.uid]
            if token then token:SetBubble(item.ability, item.speed, i) end
        end
        return 1.0
    elseif t == "act" then
        local token = self.tokens[e.src]
        if token then
            token:SetBubble(nil)
            local x, y = self:TokenPoint(e.src)
            local tx, ty
            if e.dst and e.dst ~= e.src and self.tokens[e.dst] then
                tx, ty = self:TokenPoint(e.dst)
            else
                tx, ty = x, y + (token.uid and self.disp[e.src] and self.disp[e.src].side == "ally" and -60 or 60)
            end
            local dx, dy = tx - x, ty - y
            local len = math.max(1, math.sqrt(dx * dx + dy * dy))
            local reach = math.min(70, len * 0.45)
            token.lunge = { t = 0, dx = dx / len * reach, dy = dy / len * reach }
            self:ShowBanner(e.ability)
            local school = MC.Abilities[e.ability].school
            if e.dst and e.dst ~= e.src and school and school ~= "physical" then
                self:Projectile(e.src, e.dst, school)
            end
        end
        return 0.65
    elseif t == "damage" then
        local d = disp[e.dst]
        if d then
            d.hp = d.hp - e.amount
            self:ShowDisp(e.dst)
        end
        local token = self.tokens[e.dst]
        if token then
            token.shake = 0.3
            token.flashT = 0.35
            token.flash:SetVertexColor(1, 1, 1)
        end
        local x, y = self:TokenPoint(e.dst)
        local c = SCHOOL_COLORS[e.school] or SCHOOL_COLORS.physical
        local text = "-" .. e.amount .. (e.crit and "!" or "")
        self:Popup(x, y - 6, text, e.crit and 34 or (e.adv and 30 or 26), c[1], c[2], c[3], 1.0, 40)
        if e.adv then self:Popup(x, y + 34, L.MC_ADVANTAGE, 12, 1, 0.85, 0.3, 1.0, 12) end
        MC.Sound("hit")
        return 0.35
    elseif t == "miss" then
        local x, y = self:TokenPoint(e.dst)
        self:Popup(x, y - 6, L.MC_MISS, 18, 0.8, 0.8, 0.8, 0.9, 28)
        return 0.3
    elseif t == "heal" then
        local d = disp[e.dst]
        if d then
            d.hp = math.min(d.maxHp, d.hp + e.amount)
            self:ShowDisp(e.dst)
        end
        if e.amount > 0 then
            local token = self.tokens[e.dst]
            if token then
                token.flashT = 0.35
                token.flash:SetVertexColor(0.3, 1, 0.3)
            end
            local x, y = self:TokenPoint(e.dst)
            self:Popup(x, y - 6, "+" .. e.amount, 26, 0.35, 1, 0.35, 1.0, 36)
            MC.Sound("heal")
        end
        return 0.3
    elseif t == "shield" or t == "shieldBreak" then
        local d = disp[e.dst]
        if d then
            d.shield = t == "shield"
            self:ShowDisp(e.dst)
        end
        if t == "shield" then MC.Sound("shield") end
        return 0.2
    elseif t == "absorb" or t == "absorbUp" then
        local d = disp[e.dst]
        if d then
            d.absorb = t == "absorbUp" and e.amount or math.max(0, (d.absorb or 0) - e.amount)
            self:ShowDisp(e.dst)
        end
        return 0.15
    elseif t == "taunt" or t == "stealth" or t == "unstealth" or t == "stun" or t == "dot" or t == "hot" or t == "cleanse" then
        local d = disp[e.dst]
        if d then
            if t == "taunt" then d.taunt = true end
            if t == "stealth" then d.stealth = true end
            if t == "unstealth" then d.stealth = nil end
            if t == "stun" then d.stun = true end
            if t == "dot" then d.dot = true end
            if t == "hot" then d.hot = true end
            if t == "cleanse" then d.dot, d.debuff, d.stun = false, false, nil end
            self:ShowDisp(e.dst)
        end
        return 0.15
    elseif t == "stunned" then
        local d = disp[e.src]
        if d then
            d.stun = nil
            self:ShowDisp(e.src)
        end
        local token = self.tokens[e.src]
        if token then token:SetBubble(nil) end
        local x, y = self:TokenPoint(e.src)
        self:Popup(x, y - 40, L.MC_STUNNED, 16, 1, 0.9, 0.3, 1.0, 16)
        return 0.45
    elseif t == "buff" then
        local d = disp[e.dst]
        if d then
            if e.k == "atk" then
                d.atk = d.atk + math.floor(e.v + 0.5)
            elseif e.k == "atkPct" then
                d.atk = math.floor(d.atk * (1 + e.v) + 0.5)
            elseif Combat.IsDebuff(e) then
                d.debuff = true
            elseif e.k ~= "ambush" then
                d.buff = true
            end
            self:ShowDisp(e.dst)
        end
        return 0.12
    elseif t == "maxhp" then
        local d = disp[e.dst]
        if d then
            d.maxHp, d.hp = d.maxHp + e.amount, d.hp + e.amount
            self:ShowDisp(e.dst)
        end
        return 0.15
    elseif t == "death" then
        local d = disp[e.dst]
        if d then
            d.dead = true
            self:ShowDisp(e.dst)
        end
        local token = self.tokens[e.dst]
        if token then token:SetBubble(nil) end
        MC.Sound("death")
        return 0.5
    elseif t == "enter" then
        local b = self:Battle()
        self:LayoutBattle(b)
        local token = self.tokens[e.dst]
        if token then
            disp[e.dst] = MC.UnitView(b.units[e.dst])
            token:SetData(disp[e.dst], self:PartyReference())
            token:SetAlpha(0)
            token.fadeIn = 0.3
        end
        return 0.35
    elseif t == "fizzle" then
        local x, y = self:TokenPoint(e.src)
        self:Popup(x, y - 40, L.MC_FIZZLE, 14, 0.75, 0.75, 0.75, 0.9, 16)
        return 0.25
    end
    return 0.05
end

function Module:EndPlayback()
    self.playing = false
    self.queue, self.disp = nil, nil
    local b = self:Battle()
    for _, t in pairs(self.tokens) do t:SetBubble(nil) end
    if b and (b.phase == "won" or b.phase == "lost") then
        self.finishTimer = 1.1
        self:RefreshBattle()
        return
    end
    self.selected = nil
    self:RefreshBattle()
end

-- Dashed line from the mercenary choosing a target to the token under the mouse.
function Module:UpdateAim()
    local count = 0
    local target
    if self.pending and not self.playing then
        for _, t in pairs(self.tokens) do
            if t.hovered and t.glow:IsShown() then target = t end
        end
    end
    if target then
        local x1, y1 = self:TokenPoint(self.pending.uid)
        local x2, y2 = target.x, target.y
        local dx, dy = x2 - x1, y2 - y1
        local length = math.sqrt(dx * dx + dy * dy)
        local angle = math.atan2(-dy, dx)
        local enemy = target.data and target.data.side == "enemy"
        local d = 50
        while d < length - 40 and count < MAX_DASHES do
            count = count + 1
            local dash = self.aimDashes[count]
            dash:ClearAllPoints()
            dash:SetPoint("CENTER", self.battleFx, "TOPLEFT", x1 + dx * d / length, -(y1 + dy * d / length))
            dash:SetRotation(angle)
            if enemy then dash:SetVertexColor(1, 0.35, 0.25) else dash:SetVertexColor(0.4, 1, 0.45) end
            dash:Show()
            d = d + 14
        end
    end
    for i = count + 1, MAX_DASHES do self.aimDashes[i]:Hide() end
end

function Module:UpdateBattle(dt)
    local speed = ns.Arcade.Settings(self).fast and 2.2 or 1
    local k = math.min(1, dt * 10)
    local pulse = 0.5 + 0.5 * math.sin(GetTime() * 5)
    for _, t in pairs(self.tokens) do
        if t.tx then
            -- Glide to the slot; grow a little under the mouse when clickable.
            t.x = t.x + (t.tx - t.x) * k
            t.y = t.y + (t.ty - t.y) * k
            local want = t.base * ((t.hovered and t.clickable) and 1.07 or 1)
            t.cur = t.cur + (want - t.cur) * math.min(1, dt * 14)
            t:SetScale(t.cur)
            local ox, oy = 0, 0
            if t.shake > 0 then
                t.shake = t.shake - dt
                ox = (math.random() - 0.5) * 8
            end
            if t.lunge then
                local l = t.lunge
                l.t = l.t + dt * speed
                local p = math.min(1, l.t / 0.4)
                local s = math.sin(p * math.pi)
                ox, oy = ox + l.dx * s, oy + l.dy * s
                if p >= 1 then t.lunge = false end
            end
            Place(t, (t.x + ox) / t.cur, (t.y + oy) / t.cur)
        end
        if t.glow:IsShown() then
            t.glow:SetAlpha(0.45 + 0.35 * pulse + ((t.hovered and t.clickable) and 0.2 or 0))
        end
        if t.select:IsShown() then t.select:SetAlpha(0.7 + 0.3 * pulse) end
        if t.flashT > 0 then
            t.flashT = t.flashT - dt
            t.flash:SetAlpha(math.max(0, t.flashT / 0.35) * 0.8)
        end
        if t.fadeIn then
            t.fadeIn = t.fadeIn - dt
            t:SetAlpha(math.min(1, 1 - math.max(0, t.fadeIn) / 0.3))
            if t.fadeIn <= 0 then t.fadeIn = false end
        end
    end
    self:UpdateAim()
    local banner = self.views.battle.banner
    if self.bannerTime then
        self.bannerTime = self.bannerTime - dt * speed
        banner:SetAlpha(math.min(1, math.max(0, self.bannerTime / 0.3)))
        if self.bannerTime <= 0 then
            self.bannerTime = nil
            banner:Hide()
        end
    end
    if self.playing then
        self.queueWait = self.queueWait - dt * speed
        while self.playing and self.queueWait <= 0 do
            self.queueIndex = self.queueIndex + 1
            local e = self.queue[self.queueIndex]
            if not e then
                self:EndPlayback()
                break
            end
            self.queueWait = self.queueWait + self:PlayEvent(e)
        end
    end
    if self.finishTimer then
        self.finishTimer = self.finishTimer - dt * speed
        if self.finishTimer <= 0 then
            self.finishTimer = nil
            for uid, t in pairs(self.tokens) do
                self.tokens[uid] = nil
                self.tokenPool.Release(t)
            end
            self:FinishBattle()
        end
    end
end
