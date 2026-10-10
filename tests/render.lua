-- Drives Mercenaries through its views and snapshots each one for tests/render.py.
-- Runs after smoke.lua's API globals and render_mock.lua.

local ns = {}
for _, file in ipairs(ADDON_FILES) do
    local fn = assert(loadstring(ADDON_SOURCES[file], "@" .. file))
    fn("DarkmoonArcade", ns)
end

local clock = 0
function GetTime() return clock end

local function Fire(event, ...)
    for _, f in ipairs(RenderFrames) do
        if f._scripts.OnEvent then f._scripts.OnEvent(f, event, ...) end
    end
end

local function Tick(seconds)
    for _ = 1, math.max(1, math.floor(seconds * 30)) do
        clock = clock + 1 / 30
        for _, f in ipairs(RenderFrames) do
            local fn = f._scripts.OnUpdate
            if fn and f:IsVisible() then fn(f, 1 / 30) end
        end
    end
end

local function Click(f, button)
    f._Fire(f, "OnMouseDown", button or "LeftButton")
    f._Fire(f, "OnClick", button or "LeftButton")
    f._Fire(f, "OnMouseUp", button or "LeftButton")
end

local function Enter(f)
    f._mouseOver = true
    f._Fire(f, "OnEnter")
end

local function Leave(f)
    f._mouseOver = false
    f._Fire(f, "OnLeave")
end

Shots = {}
local mc
local function Snap(name)
    Tick(0.6)
    local items, w, h = RenderDump(mc.container)
    Shots[#Shots + 1] = { name = name, items = items, w = w, h = h }
end

DarkmoonArcadeDB = nil
Fire("ADDON_LOADED", "DarkmoonArcade")
Fire("PLAYER_LOGIN")
if RENDER_LANG then
    ns.SetLanguage(RENDER_LANG)
    ns.Media.ApplyLanguageFonts()
    ns.Widgets.RefreshAll()
end
SlashCmdList.DARKMOONARCADE("mercenaries")
local Window = ns.Window
mc = Window.activeGame
local MC = ns.Mercenaries
local store = mc:Store()
Tick(0.5)

local only = RENDER_ONLY
local function Want(name)
    if not only then return true end
    for part in only:gmatch("[^|]+") do
        if name:find(part, 1, true) then return true end
    end
    return false
end

if Want("news") then
    ns.News:Show()
    Tick(0.6)
    local items, w, h = RenderDump(ns.News.frame)
    Shots[#Shots + 1] = { name = "news", items = items, w = w, h = h }
    ns.News.frame:Hide()
end
if Want("roadmap") then
    ns.Window:OpenRoadmap()
    Tick(0.6)
    local items, w, h = RenderDump(ns.RoadmapView.view)
    Shots[#Shots + 1] = { name = "roadmap", items = items, w = w, h = h }
    -- The renderer skips scroll children; the content on its own shows the text layout.
    ns.RoadmapView.content:SetPoint("TOPLEFT", ns.RoadmapView.view, "TOPLEFT", 70, -50)
    items, w, h = RenderDump(ns.RoadmapView.content)
    Shots[#Shots + 1] = { name = "roadmap_content", items = items, w = w, h = h }
    SlashCmdList.DARKMOONARCADE("mercenaries")
end
if Want("camp") then Snap("camp") end
mc:ShowView("collection")
if Want("collection") then
    Snap("collection")
    local card = mc.views.collection.cards[2]
    Enter(card)
    Snap("collection_hover")
    Leave(card)
end
store.mercs.jaina = store.mercs.jaina or MC.Bounty.NewEntry(false)
store.mercs.jaina.coins = 200
mc:CollectionClicked("cairne")
if Want("merc") then Snap("merc") end
mc:CollectionClicked("jaina")
if Want("merc") then Snap("merc_locked") end
mc:ShowView("camp")
Click(mc.views.camp.travel)
local travel = mc.views.travel
if Want("travel") then Snap("travel") end
Click(travel.regions[1])
Tick(1)
if Want("travel") then Snap("travel_lordaeron") end
Click(travel.overview)
Tick(1)
Click(travel.tabs.kal)
Tick(1)
if Want("travel") then Snap("travel_kalimdor") end
Click(travel.regions[2])
Tick(1)
if Want("travel") then Snap("travel_central") end
Click(travel.tabs.ek)
Tick(1)
Click(travel.regions[3])
Tick(1)
if Want("travel") then Snap("travel_region") end
for _, pin in ipairs(travel.pins) do
    if pin:IsShown() and pin.zone == "elwynn" then
        Click(pin)
        Enter(pin)
    end
end
if Want("travel") then Snap("travel_zone") end
for _, pin in ipairs(travel.pins) do
    if pin:IsShown() and pin.zone == "duskwood" then Click(pin) end
end
if Want("travel") then Snap("travel_warn") end
for _, pin in ipairs(travel.pins) do
    if pin:IsShown() and pin.zone == "elwynn" then Click(pin) end
end
Click(travel.boss.choose)
Tick(0.5)
if Want("map") then Snap("map") end

-- Walk the bounty: first stop, then the battle board in each phase.
local run = store.run
local choice = MC.Bounty.Choices(run)[1]
mc:SelectNode(choice.layer, choice.index, true)
if Want("map") then Snap("map_selected") end
mc.travelButton._scripts.OnClick(mc.travelButton)
Tick(0.5)
local battleShots = 0
for _ = 1, 200 do
    run = store.run
    if not run or run.phase ~= "battle" then break end
    local b = run.battle
    if b.phase == "deploy" and battleShots == 0 then
        if Want("battle") then Snap("battle_deploy") end
        battleShots = 1
    end
    if b.phase == "deploy" or b.phase == "replace" then
        local token = mc.tokens[b.bench.ally[1]]
        if token then Click(token) else MC.Combat.Deploy(b, b.bench.ally[1]); mc:RefreshBattle() end
    elseif b.phase == "command" and not mc.playing then
        if battleShots == 1 then
            if Want("battle") then Snap("battle_command") end
            mc:PickAbility(1)
            if Want("battle") then Snap("battle_target") end
            battleShots = 2
        end
        mc:AutoChoose()
        if battleShots == 2 then
            if Want("battle") then Snap("battle_ready") end
            battleShots = 3
        end
        mc:ResolveTurn()
        if battleShots == 3 then
            for i = 1, 4 do
                Tick(0.45)
                if Want("battle") then Snap("battle_play" .. i) end
            end
            battleShots = 4
        end
    end
    Tick(1)
end

-- Dialogs: the treasure after the first fight, then the handbook.
for _ = 1, 60 do
    run = store.run
    if not run or run.phase ~= "battle" then break end
    if run.battle.phase == "command" and not mc.playing then mc:AutoChoose(); mc:ResolveTurn() end
    if run.battle.phase == "deploy" or run.battle.phase == "replace" then
        MC.Combat.Deploy(run.battle, run.battle.bench.ally[1])
        mc:RefreshBattle()
    end
    Tick(2)
end
if store.run and store.run.phase == "treasure" then
    mc:Route()
    if Want("treasure") then Snap("treasure") end
end
mc.overlay:Show("help")
if Want("help") then Snap("help") end
mc:ShowHelpChapter(4)
if Want("help") then Snap("help_battle") end

-- The result after a won bounty: two mercenaries gained levels on the way.
run = store.run
if run then
    run.phase = "complete"
    run.fights, run.xp, run.score = 4, 1416, 210
    run.rewards = { first = true, coins = {}, gear = { merc = store.party[1], slot = 2 } }
    for _, member in ipairs(run.party) do run.rewards.coins[member.id] = 5 end
    run.rewards.coins.jaina = 24
    run.startLevels = run.startLevels or {}
    for _, member in ipairs(run.party) do run.startLevels[member.id] = store.mercs[member.id].level end
    store.mercs[store.party[2]].level = store.mercs[store.party[2]].level + 2
    store.mercs[store.party[5]].level = store.mercs[store.party[5]].level + 1
    mc:Route()
    if Want("result") then Snap("result_anim") end
    Tick(4)
    if Want("result") then Snap("result") end
end

-- An event window, as a mystery shows it.
if Want("event") then
    mc.overlay:Show("event", { icon = MC.MYSTERY_ICON.sabotage, title = ns.L.MC_MYSTERY_SABOTAGE, text = ns.L.MC_EVENT_SABOTAGE })
    Snap("event")
end
