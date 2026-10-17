-- The task board (by the campfire): the open chains on the left (several per mercenary; finished ones
-- dimmed at the end, scrolling), the chosen task on a quest page on the right - its story, objective with progress, reward and "Hand in".

local _, ns = ...
local MC = ns.Mercenaries
local Kit, Describe, Bounty = MC.Kit, MC.Describe, MC.Bounty
local Quests = MC.Quests
local Widgets, L = ns.Widgets, ns.L
local Module = MC.Module
local W, H = MC.W, MC.H

local INK = { 0.2, 0.12, 0.05 }
local LIST_X, LIST_W = 14, 250
local PAGE_X = LIST_X + LIST_W + 12
local PAGE_W = W - PAGE_X - 14
local TOP, ROW_H, HEAD_H = 58, 50, 26
local LIST_H = H - TOP - 60
-- The list scrolls inside its panel (mouse wheel); a thin bar on the right shows where.
local WHEEL_STEP, BAR_W = 50, 4

local ICON_AVAILABLE = "Interface\\GossipFrame\\AvailableQuestIcon"
local ICON_READY = "Interface\\GossipFrame\\ActiveQuestIcon"
local ICON_DONE = "Interface\\RaidFrame\\ReadyCheck-Ready"

-- What the current task of a chain asks, in words.
function Quests.Objective(store, chain)
    local task = Quests.Current(store, chain)
    if not task then return "" end
    local merc = MC.QUEST_CHAINS[chain].merc
    local name = Describe.MercName(merc)
    if task.kind == "clear" then
        local zone = Describe.ZoneName(task.zone)
        return task.with and L.MC_QO_CLEAR_WITH:format(zone, name) or L.MC_QO_CLEAR:format(zone)
    elseif task.kind == "kill" then
        local what = L["MC_QK_" .. task.what]
        if task.zone then return L.MC_QO_KILL_IN:format(task.count, what, Describe.ZoneName(task.zone), name) end
        return L.MC_QO_KILL:format(task.count, what, name)
    elseif task.kind == "ability" then
        return L.MC_QO_ABILITY:format(name, Describe.AbilityName(MC.Mercs[merc].abilities[task.slot]), task.count)
    elseif task.kind == "boss" then
        local zone = MC.Zones[task.zone]
        return L.MC_QO_BOSS:format(L["MC_E_" .. zone.boss], Describe.ZoneName(task.zone), name)
    elseif task.kind == "level" then
        return L.MC_QO_LEVEL:format(name, task.level)
    elseif task.kind == "dungeon" then
        return L.MC_QO_DUNGEON:format(Describe.ZoneName(task.dungeon), name)
    end
    return ""
end

local function Header(parent, key)
    local fs = Kit.Ink(parent, 14, { 0.45, 0.12, 0.04 })
    fs:SetJustifyH("LEFT")
    Widgets.OnRefresh(function() fs:SetText(L[key]) end)
    return fs
end

function Module:BuildQuests()
    local view = self:AddView("quests", CreateFrame("Frame", nil, self.container))
    local wood = Kit.Wood(view, W, H, true)
    wood:SetPoint("TOPLEFT")
    local title = Kit.Plaque(view, 300, "MC_QUESTS", 16)
    title:SetPoint("TOP", view, "TOP", 0, -4)

    -- The chains.
    local list = CreateFrame("Frame", nil, view)
    list:SetSize(LIST_W, H - TOP - 60)
    list:SetPoint("TOPLEFT", LIST_X, -TOP)
    local fill = list:CreateTexture(nil, "BACKGROUND", nil, 2)
    fill:SetAllPoints()
    fill:SetColorTexture(0.08, 0.05, 0.03, 0.78)
    Widgets.Rim(list, list)
    local clip = CreateFrame("Frame", nil, list)
    clip:SetSize(LIST_W, LIST_H - 8)
    clip:SetPoint("TOPLEFT", 0, -4)
    clip:SetClipsChildren(true)
    clip:EnableMouseWheel(true)
    clip:SetScript("OnMouseWheel", function(_, delta) self:ScrollQuests(-delta * WHEEL_STEP) end)
    local content = CreateFrame("Frame", nil, clip)
    content:SetSize(LIST_W, LIST_H)
    content:SetPoint("TOPLEFT")
    view.clip, view.content = clip, content
    view.bar = list:CreateTexture(nil, "OVERLAY")
    view.bar:SetWidth(BAR_W)
    view.bar:SetColorTexture(1, 0.82, 0.4, 0.5)
    view.rows = {}
    self.questScroll = 0
    function view.Row(i)
        if view.rows[i] then return view.rows[i] end
        local b = CreateFrame("Button", nil, content)
        b:SetSize(LIST_W - 20, ROW_H - 4)
        b.shade = b:CreateTexture(nil, "BACKGROUND")
        b.shade:SetAllPoints()
        b.shade:SetColorTexture(1, 0.85, 0.5, 0.06)
        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 0.85, 0.4, 0.12)
        b.mark = b:CreateTexture(nil, "ARTWORK")
        b.mark:SetSize(22, 22)
        b.mark:SetPoint("LEFT", 6, 0)
        b.name = Kit.Ink(b, 13, { 1, 0.82, 0 })
        b.name:SetPoint("TOPLEFT", 36, -6)
        b.name:SetWidth(LIST_W - 60)
        b.name:SetJustifyH("LEFT")
        b.name:SetWordWrap(false)
        b.sub = Widgets.Text(b, 10, "gray")
        b.sub:SetPoint("TOPLEFT", b.name, "BOTTOMLEFT", 0, -3)
        b.sub:SetWidth(LIST_W - 60)
        b.sub:SetJustifyH("LEFT")
        -- A section's heading uses the same row.
        b.head = Kit.Ink(b, 12, { 1, 0.82, 0.4 }, "OUTLINE")
        b.head:SetPoint("BOTTOMLEFT", 6, 4)
        b.head:SetJustifyH("LEFT")
        b.rule = b:CreateTexture(nil, "ARTWORK")
        b.rule:SetHeight(1)
        b.rule:SetPoint("BOTTOMLEFT", 6, 1)
        b.rule:SetPoint("BOTTOMRIGHT", -6, 1)
        b.rule:SetColorTexture(1, 0.82, 0.4, 0.35)
        b:SetScript("OnClick", function()
            if not b.chain then return end
            MC.Sound("select")
            self.questShown = b.chain
            self:RefreshQuests()
        end)
        b:EnableMouseWheel(true)
        b:SetScript("OnMouseWheel", function(_, delta) self:ScrollQuests(-delta * WHEEL_STEP) end)
        view.rows[i] = b
        return b
    end

    -- The quest page.
    local page = CreateFrame("Frame", nil, view)
    page:SetSize(PAGE_W, H - TOP - 60)
    page:SetPoint("TOPLEFT", PAGE_X, -TOP)
    Kit.Parchment(page)
    Widgets.Rim(page, page)
    local tw = PAGE_W - 48
    view.qStep = Kit.Ink(page, 11, { 0.35, 0.28, 0.2 })
    view.qStep:SetPoint("TOPLEFT", 24, -18)
    view.qStep:SetWidth(tw)
    view.qStep:SetJustifyH("LEFT")
    view.qTitle = Kit.Ink(page, 20, { 0.45, 0.12, 0.04 })
    view.qTitle:SetPoint("TOPLEFT", view.qStep, "BOTTOMLEFT", 0, -6)
    view.qTitle:SetWidth(tw)
    view.qTitle:SetJustifyH("LEFT")
    view.qText = Kit.Ink(page, 13, INK)
    view.qText:SetPoint("TOPLEFT", view.qTitle, "BOTTOMLEFT", 0, -12)
    view.qText:SetWidth(tw)
    view.qText:SetJustifyH("LEFT")
    view.qText:SetSpacing(4)
    view.goalHead = Header(page, "MC_QUEST_OBJECTIVE")
    view.goalHead:SetPoint("TOPLEFT", view.qText, "BOTTOMLEFT", 0, -20)
    view.qGoal = Kit.Ink(page, 13, INK)
    view.qGoal:SetPoint("TOPLEFT", view.goalHead, "BOTTOMLEFT", 0, -6)
    view.qGoal:SetWidth(tw)
    view.qGoal:SetJustifyH("LEFT")
    view.qProgress = Kit.Ink(page, 13, { 0.05, 0.42, 0 })
    view.qProgress:SetPoint("TOPLEFT", view.qGoal, "BOTTOMLEFT", 0, -6)
    view.qProgress:SetWidth(tw)
    view.qProgress:SetJustifyH("LEFT")
    view.rewardHead = Header(page, "MC_QUEST_REWARD")
    view.rewardHead:SetPoint("TOPLEFT", view.qProgress, "BOTTOMLEFT", 0, -20)
    view.qCoin = Kit.CoinIcon(page, 18)
    view.qCoin:SetPoint("TOPLEFT", view.rewardHead, "BOTTOMLEFT", 0, -6)
    view.qReward = Kit.Ink(page, 13, INK)
    view.qReward:SetPoint("LEFT", view.qCoin, "RIGHT", 6, 0)
    view.qReward:SetWidth(tw - 30)
    view.qReward:SetJustifyH("LEFT")
    view.qUnlock = Kit.Ink(page, 13, { 0.05, 0.28, 0.62 })
    view.qUnlock:SetPoint("TOPLEFT", view.qCoin, "BOTTOMLEFT", 0, -6)
    view.qUnlock:SetWidth(tw)
    view.qUnlock:SetJustifyH("LEFT")
    view.turnIn = Kit.Button(page, 160, 30, "MC_QUEST_TURN_IN", function() self:TurnInQuest() end, "green")
    view.turnIn:SetPoint("BOTTOM", 0, 16)

    local back = Kit.Button(view, 140, 30, "BACK", function() self:ShowView("camp") end, "red")
    Kit.Place(back, W / 2, H - 30, view)
    local achievements = Kit.Button(view, 140, 30, "ACHIEVEMENTS", function() self:ShowAchievements() end)
    Kit.Place(achievements, 90, H - 30, view)

    title:SetFrameLevel(page:GetFrameLevel() + 10)
    view.refresh = function() self:RefreshQuests() end
end

function Module:RefreshQuests()
    local view, store = self.views.quests, self:Store()
    self:SetScene(nil)
    -- Sections: chains of the party's mercenaries, those on the bench, finished ones. Inside a section the
    -- chains with a task to hand in come first.
    local party = {}
    for _, merc in ipairs(store.party or {}) do party[merc] = true end
    local sections = { { key = "MC_QUESTS_PARTY", list = {} }, { key = "MC_QUESTS_BENCH", list = {} },
        { key = "MC_QUESTS_DONE", list = {} } }
    local open = {}
    for _, chain in ipairs(MC.QUEST_CHAIN_ORDER) do
        if Quests.Open(store, chain) then
            local merc = MC.QUEST_CHAINS[chain].merc
            local section = Quests.Done(store, chain) and 3 or party[merc] and 1 or 2
            table.insert(sections[section].list, chain)
        end
    end
    for k = 1, 2 do
        local list, ready, rest = sections[k].list, {}, {}
        for _, chain in ipairs(list) do table.insert(Quests.IsReady(store, chain) and ready or rest, chain) end
        for _, chain in ipairs(rest) do ready[#ready + 1] = chain end
        sections[k].list = ready
    end
    -- The rows in order: each section's heading, then its chains.
    local entries = {}
    for _, section in ipairs(sections) do
        if #section.list > 0 then
            entries[#entries + 1] = { head = section.key }
            for _, chain in ipairs(section.list) do
                open[#open + 1] = chain
                entries[#entries + 1] = { chain = chain }
            end
        end
    end
    -- The chosen chain: the one shown before, else the first with a task to hand in, else the first.
    local shown = self.questShown
    if not (shown and Quests.Open(store, shown)) then
        shown = open[1]
        for _, chain in ipairs(open) do
            if Quests.IsReady(store, chain) then
                shown = chain
                break
            end
        end
    end
    self.questShown = shown
    for i = 1, #entries do view.Row(i) end
    local y = 4
    for i, b in ipairs(view.rows) do
        local entry = entries[i]
        b:SetShown(entry ~= nil)
        b.chain = entry and entry.chain
        if entry then
            local isHead = entry.head ~= nil and entry.chain == nil
            local h = isHead and HEAD_H or ROW_H
            b:SetHeight(h - 4)
            b:ClearAllPoints()
            b:SetPoint("TOP", 0, -y)
            y = y + h
            b.head:SetShown(isHead)
            b.rule:SetShown(isHead)
            b.mark:SetShown(not isHead)
            b.name:SetShown(not isHead)
            b.sub:SetShown(not isHead)
            b:EnableMouse(not isHead)
            if isHead then
                b.head:SetText(L[entry.head])
                b:SetAlpha(1)
                b.shade:SetColorTexture(0, 0, 0, 0)
            else
                local chain = entry.chain
                local merc = MC.QUEST_CHAINS[chain].merc
                local task, step = Quests.Current(store, chain)
                b.name:SetText(Describe.MercName(merc))
                b.mark:SetTexture(not task and ICON_DONE or Quests.IsReady(store, chain) and ICON_READY or ICON_AVAILABLE)
                b.sub:SetText(L["MC_Q_" .. chain .. "_" .. math.min(step, #MC.QUEST_CHAINS[chain].steps) .. "_TITLE"])
                b:SetAlpha(task and 1 or 0.55)
                b.shade:SetColorTexture(1, 0.85, 0.5, chain == shown and 0.2 or 0.06)
            end
        end
    end
    self.questListHeight = y + 4
    view.content:SetHeight(math.max(LIST_H, y + 4))
    self:ScrollQuests(0)
    if not shown then return end

    local def = MC.QUEST_CHAINS[shown]
    local task, step = Quests.Current(store, shown)
    local name = Describe.MercName(def.merc)
    if not task then
        view.qStep:SetText(name .. "  ·  " .. L.MC_QUEST_CHAIN_DONE)
        view.qTitle:SetText(L["MC_Q_" .. shown .. "_" .. #def.steps .. "_TITLE"])
        view.qText:SetText(L.MC_QUEST_CHAIN_DONE_TEXT:format(name))
        for _, part in ipairs({ view.goalHead, view.qGoal, view.qProgress, view.rewardHead, view.qCoin,
            view.qReward, view.qUnlock, view.turnIn }) do part:Hide() end
        return
    end
    for _, part in ipairs({ view.goalHead, view.qGoal, view.qProgress, view.rewardHead, view.qCoin,
        view.qReward, view.turnIn }) do part:Show() end
    local key = "MC_Q_" .. shown .. "_" .. step
    view.qStep:SetText(name .. "  ·  " .. L.MC_QUEST_STEP:format(step, #def.steps))
    view.qTitle:SetText(L[key .. "_TITLE"])
    view.qText:SetText(L[key .. "_TEXT"])
    view.qGoal:SetText(Quests.Objective(store, shown))
    local doneCount, need = Quests.Progress(store, shown)
    local ready = Quests.IsReady(store, shown)
    view.qProgress:SetText(ready and L.MC_QUEST_READY or ("%d / %d"):format(doneCount, need))
    view.qReward:SetText(L.MC_QUEST_COINS:format(Quests.COINS[step] or 0, name))
    view.qUnlock:SetShown(task.unlock ~= nil)
    if task.unlock then view.qUnlock:SetText(L["MC_QUEST_UNLOCK_" .. task.unlock]) end
    view.turnIn:SetEnabled(ready)
end

-- Scrolls the list by `delta` (kept inside its ends) and moves the bar.
function Module:ScrollQuests(delta)
    local view = self.views.quests
    local room = LIST_H - 8
    local max = math.max(0, (self.questListHeight or 0) - room)
    self.questScroll = math.max(0, math.min(max, (self.questScroll or 0) + delta))
    view.content:ClearAllPoints()
    view.content:SetPoint("TOPLEFT", view.clip, "TOPLEFT", 0, self.questScroll)
    view.bar:SetShown(max > 0)
    if max > 0 then
        local barH = math.max(24, room * room / (room + max))
        view.bar:SetHeight(barH)
        view.bar:ClearAllPoints()
        view.bar:SetPoint("TOPRIGHT", view.clip, "TOPRIGHT", -3, -(room - barH) * self.questScroll / max)
    end
end

function Module:TurnInQuest()
    local store, merc = self:Store(), self.questShown
    local coins, unlock = Quests.TurnIn(store, merc)
    if not coins then return end
    -- As in WoW: the quest complete sound and the coins.
    PlaySound(SOUNDKIT.IG_QUEST_LIST_COMPLETE)
    if SOUNDKIT.LOOT_WINDOW_COIN_SOUND then PlaySound(SOUNDKIT.LOOT_WINDOW_COIN_SOUND) end
    self:RefreshQuests()
    if unlock then
        self.overlay:Show("event", {
            icon = "Interface\\Icons\\INV_Misc_Key_03", title = L.MC_QUEST_UNLOCKED,
            text = L["MC_QUEST_UNLOCK_" .. unlock],
        })
    end
end
