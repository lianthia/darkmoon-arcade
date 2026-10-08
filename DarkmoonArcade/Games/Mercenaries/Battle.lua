-- The battle view: foes on top, the party below, the selected mercenary's abilities at the bottom.
-- A turn is resolved at once in Combat; this view then plays its events back one by one.

local _, ns = ...
local MC = ns.Mercenaries
local Combat, Describe, Kit = MC.Combat, MC.Describe, MC.Kit
local Widgets, Media, L = ns.Widgets, ns.Media, ns.L
local Module = MC.Module
local W, H = MC.W, MC.H

local ENEMY_Y, ALLY_Y, BENCH_Y, CARD_Y = 108, 292, 470, 474
local SPACING, BENCH_SPACING, BENCH_SCALE = 150, 92, 0.78
local CARD_GAP, CARD_SCALE = 118, 0.8
local KEY_SLOT = { ["1"] = 1, ["2"] = 2, ["3"] = 3 }

function Module:TintBoard(zoneId)
    self:SetScene(zoneId, 0.5)
end

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
    self.tokens = {}
    self.tokenPool = Media.Pool(function()
        local t = MC.CreateToken(view)
        t:SetScript("OnClick", function(token, button) self:TokenClicked(token, button) end)
        t:SetScript("OnEnter", function(token)
            local b = self:Battle()
            local u = b and token.uid and b.units[token.uid]
            if u then MC.UnitTooltip(token, u, u.side == "enemy" and self:PartyReference() or nil) end
        end)
        t:SetScript("OnLeave", GameTooltip_Hide)
        return t
    end, function(t)
        t:Hide()
        t.uid, t.unitKey = false, false
        t.x, t.y, t.tx, t.ty = false, false, false, false
        t.shake, t.nudge, t.fadeIn = 0, 0, false
        t:SetScale(1)
    end)

    view.zone = Widgets.Text(view, 14, "gold")
    view.zone:SetPoint("TOPLEFT", 16, -12)
    view.turn = Widgets.Text(view, 12, "white")
    view.turn:SetPoint("TOPRIGHT", -16, -12)
    view.reserve = Widgets.Text(view, 11, "gray")
    view.reserve:SetPoint("TOPRIGHT", -16, -30)
    view.bench = Widgets.Text(view, 11, "gray")
    view.bench:SetPoint("TOPLEFT", 16, -(ALLY_Y + 40))
    view.hint = Widgets.Text(view, 12, "blue")
    view.hint:SetPoint("CENTER", view, "TOPLEFT", W - 104, -(CARD_Y - 6))
    view.hint:SetWidth(200)

    self.cards = {}
    for i = 1, 3 do
        local card = Kit.AbilityCard(view)
        Kit.SetBaseScale(card, CARD_SCALE)
        Kit.Place(card, W / 2 + (i - 2) * CARD_GAP, CARD_Y)
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
        self.cards[i] = card
    end

    self.readyButton = Kit.BigButton(view, 92, "MC_READY", function() self:ResolveTurn() end)
    Kit.Place(self.readyButton, W - 70, (ENEMY_Y + ALLY_Y) / 2)
    self.autoButton = Kit.Button(view, 170, 28, "MC_AUTO", function() self:AutoChoose() end)
    Kit.Place(self.autoButton, W - 104, CARD_Y + 44)

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
        self.tokens[uid] = t
    end
    return t
end

local function Slots(n, spacing)
    local list = {}
    for i = 1, n do list[i] = W / 2 + (i - (n + 1) / 2) * spacing end
    return list
end

-- Puts every token where it belongs; tokens no longer needed go back to the pool.
function Module:LayoutBattle(b, boards)
    boards = boards or b.board
    local wanted = {}
    local function Row(list, y, spacing, scale)
        local xs = Slots(#list, spacing)
        for i, uid in ipairs(list) do
            local t = self:TokenFor(uid)
            wanted[uid] = true
            t.tx, t.ty = xs[i], y
            t:SetScale(scale or 1)
            if not t.x then
                t.x, t.y = t.tx, t.ty
                Place(t, t.x / (scale or 1), t.y / (scale or 1))
            end
            t:Show()
        end
    end
    Row(boards.enemy, ENEMY_Y, SPACING)
    Row(boards.ally, ALLY_Y, SPACING)
    if (b.phase == "deploy" or b.phase == "replace") and not self.playing then
        Row(b.bench.ally, BENCH_Y, BENCH_SPACING, BENCH_SCALE)
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
    self:TintBoard(run.zone)
    local zone = Describe.ZoneName(run.zone) .. (run.heroic and (" (" .. L.MC_HEROIC .. ")") or "")
    local node = MC.Bounty.Node(run)
    local kind = node and (node.type == "boss" and L.MC_NODE_BOSS or node.type == "elite" and L.MC_NODE_ELITE or L.MC_NODE_FIGHT) or ""
    view.zone:SetText(zone .. "  ·  " .. kind)
    view.turn:SetText(L.MC_TURN:format(b.turn))
    view.reserve:SetText(#b.bench.enemy > 0 and L.MC_RESERVE:format(#b.bench.enemy) or "")
    local benchCount = #b.bench.ally
    view.bench:SetText(benchCount > 0 and b.phase == "command" and L.MC_BENCH:format(benchCount) or "")

    if self.playing then return end
    self:LayoutBattle(b)
    local reference = self:PartyReference()
    local commanding = b.phase == "command"
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
        t.select:SetShown(commanding and uid == self.selected)
        t.glow:SetShown(validTargets[uid] or ((b.phase == "deploy" or b.phase == "replace") and self:IsBench(uid)) or false)
        t.glow:SetVertexColor(validTargets[uid] and 1 or 0.4, validTargets[uid] and 0.85 or 1, validTargets[uid] and 0.3 or 0.4)
        if u.side == "ally" and u.choice and commanding then
            t:SetBubble(u.abilities[u.choice.slot].id, Combat.Speed(b, u, u.choice.slot))
        else
            t:SetBubble(nil)
        end
    end

    local sel = commanding and self.selected and b.units[self.selected]
    for i, card in ipairs(self.cards) do
        local slot = sel and sel.abilities[i]
        card:SetShown(slot ~= nil)
        if slot then
            card:SetAbility(slot.id, sel, i, slot.cd)
            local chosen = sel.choice and sel.choice.slot == i
            local pending = self.pending and self.pending.slot == i
            Kit.SetSelected(card, chosen or pending, pending)
            card.glowTex:SetVertexColor(pending and 1 or 0.4, pending and 0.85 or 1, pending and 0.3 or 0.4)
        end
    end
    self.readyButton:SetShown(commanding)
    self.readyButton:SetEnabled(Combat.Ready(b))
    self.autoButton:SetShown(commanding)
    local hint
    if b.phase == "deploy" or b.phase == "replace" then
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
    end
    return false
end

-- Playback -------------------------------------------------------------------------------------------

function Module:ResolveTurn()
    local b = self:Battle()
    if not b or self.playing or not Combat.Ready(b) then return end
    self.disp = {}
    for uid, u in pairs(b.units) do self.disp[uid] = MC.UnitView(u) end
    self.boardBefore = { ally = {}, enemy = {} }
    for side, list in pairs(b.board) do
        for i, uid in ipairs(list) do self.boardBefore[side][i] = uid end
    end
    self.pending = nil
    for _, card in ipairs(self.cards) do card:Hide() end
    self.readyButton:Hide()
    self.autoButton:Hide()
    self.views.battle.hint:SetText("")
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
    return t.x or t.tx or W / 2, t.y or t.ty or H / 2
end

local SCHOOL_COLORS = {
    physical = { 1, 0.3, 0.25 }, fire = { 1, 0.5, 0.1 }, frost = { 0.5, 0.8, 1 }, nature = { 0.4, 1, 0.3 },
    shadow = { 0.75, 0.45, 1 }, holy = { 1, 0.9, 0.5 }, arcane = { 1, 0.5, 1 },
}

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
            token.nudge = 0.35
            local x, y = self:TokenPoint(e.src)
            self:Popup(x, y - 78, Describe.AbilityName(e.ability), 13, 1, 0.82, 0, 1.0, 14)
        end
        return 0.55
    elseif t == "damage" then
        local d = disp[e.dst]
        if d then
            d.hp = d.hp - e.amount
            self:ShowDisp(e.dst)
        end
        local token = self.tokens[e.dst]
        if token then token.shake = 0.25 end
        local x, y = self:TokenPoint(e.dst)
        local c = SCHOOL_COLORS[e.school] or SCHOOL_COLORS.physical
        local text = "-" .. e.amount .. (e.crit and "!" or "")
        self:Popup(x + math.random(-10, 10), y - 10, text, e.crit and 24 or (e.adv and 20 or 17), c[1], c[2], c[3], 0.9, 34)
        if e.adv then self:Popup(x, y + 26, L.MC_ADVANTAGE, 10, 1, 0.85, 0.3, 0.9, 10) end
        MC.Sound("hit")
        return 0.3
    elseif t == "miss" then
        local x, y = self:TokenPoint(e.dst)
        self:Popup(x, y - 10, L.MC_MISS, 14, 0.7, 0.7, 0.7, 0.8, 24)
        return 0.28
    elseif t == "heal" then
        local d = disp[e.dst]
        if d then
            d.hp = math.min(d.maxHp, d.hp + e.amount)
            self:ShowDisp(e.dst)
        end
        if e.amount > 0 then
            local x, y = self:TokenPoint(e.dst)
            self:Popup(x, y - 10, "+" .. e.amount, 17, 0.3, 1, 0.3, 0.9, 30)
            MC.Sound("heal")
        end
        return 0.24
    elseif t == "shield" or t == "shieldBreak" then
        local d = disp[e.dst]
        if d then
            d.shield = t == "shield"
            self:ShowDisp(e.dst)
        end
        if t == "shield" then MC.Sound("shield") end
        return 0.18
    elseif t == "absorb" or t == "absorbUp" then
        local d = disp[e.dst]
        if d then
            d.absorb = t == "absorbUp" and e.amount or math.max(0, (d.absorb or 0) - e.amount)
            self:ShowDisp(e.dst)
        end
        return 0.14
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
        return 0.14
    elseif t == "stunned" then
        local d = disp[e.src]
        if d then
            d.stun = nil
            self:ShowDisp(e.src)
        end
        local token = self.tokens[e.src]
        if token then token:SetBubble(nil) end
        local x, y = self:TokenPoint(e.src)
        self:Popup(x, y - 40, L.MC_STUNNED, 14, 1, 0.9, 0.3, 0.9, 16)
        return 0.4
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
        return 0.14
    elseif t == "death" then
        local d = disp[e.dst]
        if d then
            d.dead = true
            self:ShowDisp(e.dst)
        end
        local token = self.tokens[e.dst]
        if token then token:SetBubble(nil) end
        MC.Sound("death")
        return 0.45
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
        self:Popup(x, y - 40, L.MC_FIZZLE, 12, 0.7, 0.7, 0.7, 0.8, 16)
        return 0.2
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

function Module:UpdateBattle(dt)
    local speed = ns.Arcade.Settings(self).fast and 2.2 or 1
    -- Tokens glide to their places, shake when hit and lunge when acting.
    local k = math.min(1, dt * 10)
    for _, t in pairs(self.tokens) do
        if t.tx then
            local scale = t:GetScale()
            t.x = t.x + (t.tx - t.x) * k
            t.y = t.y + (t.ty - t.y) * k
            local ox, oy = 0, 0
            if t.shake > 0 then
                t.shake = t.shake - dt
                ox = (math.random() - 0.5) * 6
            end
            if t.nudge > 0 then
                t.nudge = t.nudge - dt * speed
                local lift = math.sin(math.max(0, t.nudge) / 0.35 * math.pi) * 16
                local b = self:Battle()
                local u = b and b.units[t.uid]
                oy = (u and u.side == "ally") and -lift or lift
            end
            Place(t, (t.x + ox) / scale, (t.y + oy) / scale)
        end
        if t.fadeIn then
            t.fadeIn = t.fadeIn - dt
            t:SetAlpha(math.min(1, 1 - math.max(0, t.fadeIn) / 0.3))
            if t.fadeIn <= 0 then t.fadeIn = false end
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
