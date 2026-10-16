-- The task board (by the campfire): the open chains on the left (several per mercenary; finished ones
-- dimmed at the end, a page at a time), the chosen task on a quest page on the right - its story, objective with progress, reward and "Hand in".
-- Until the dungeons come, only the dev copy opens it; the board shows the achievements otherwise.

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
local TOP, ROW_H = 58, 50
local ROWS = 8

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
        return L.MC_QO_DUNGEON:format(L["MC_DUNGEON_" .. task.dungeon], name)
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
    view.rows = {}
    for i = 1, ROWS do
        local b = CreateFrame("Button", nil, list)
        b:SetSize(LIST_W - 16, ROW_H - 4)
        b:SetPoint("TOP", 0, -8 - (i - 1) * ROW_H)
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
        b:SetScript("OnClick", function()
            MC.Sound("select")
            self.questShown = b.chain
            self:RefreshQuests()
        end)
        view.rows[i] = b
    end

    view.prev = Kit.Arrow(list, -1, function()
        self.questPage = math.max(1, (self.questPage or 1) - 1)
        self:RefreshQuests()
    end)
    view.prev:SetPoint("BOTTOMLEFT", 6, 4)
    view.next = Kit.Arrow(list, 1, function()
        self.questPage = (self.questPage or 1) + 1
        self:RefreshQuests()
    end)
    view.next:SetPoint("BOTTOMRIGHT", -6, 4)

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

    view.refresh = function() self:RefreshQuests() end
end

function Module:RefreshQuests()
    local view, store = self.views.quests, self:Store()
    self:SetScene(nil)
    -- Running chains first, a mercenary's together; finished ones at the end.
    local open, done = {}, {}
    for _, chain in ipairs(MC.QUEST_CHAIN_ORDER) do
        if Quests.Open(store, chain) then
            table.insert(Quests.Done(store, chain) and done or open, chain)
        end
    end
    for _, chain in ipairs(done) do open[#open + 1] = chain end
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
    local pages = math.max(1, math.ceil(#open / ROWS))
    local page = math.min(self.questPage or 1, pages)
    self.questPage = page
    for i, b in ipairs(view.rows) do
        local chain = open[(page - 1) * ROWS + i]
        b:SetShown(chain ~= nil)
        b.chain = chain
        if chain then
            local merc = MC.QUEST_CHAINS[chain].merc
            local task, step = Quests.Current(store, chain)
            b.name:SetText(Describe.MercName(merc))
            b.mark:SetTexture(not task and ICON_DONE or Quests.IsReady(store, chain) and ICON_READY or ICON_AVAILABLE)
            b.sub:SetText(L["MC_Q_" .. chain .. "_" .. math.min(step, #MC.QUEST_CHAINS[chain].steps) .. "_TITLE"])
            b:SetAlpha(task and 1 or 0.55)
            b.shade:SetColorTexture(1, 0.85, 0.5, chain == shown and 0.2 or 0.06)
        end
    end
    view.prev:SetShown(pages > 1)
    view.next:SetShown(pages > 1)
    view.prev:SetEnabled(page > 1)
    view.next:SetEnabled(page < pages)
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

function Module:TurnInQuest()
    local store, merc = self:Store(), self.questShown
    local coins, unlock = Quests.TurnIn(store, merc)
    if not coins then return end
    PlaySound(SOUNDKIT.IG_QUEST_LIST_COMPLETE)
    self:RefreshQuests()
    if unlock then
        self.overlay:Show("event", {
            icon = "Interface\\Icons\\INV_Misc_Key_03", title = L.MC_QUEST_UNLOCKED,
            text = L["MC_QUEST_UNLOCK_" .. unlock],
        })
    end
end
