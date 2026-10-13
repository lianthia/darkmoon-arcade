-- Loads the whole addon against a permissive WoW API mock and drives it through the UI:
-- every button gets clicked, rounds are played, a flight starts and lands.
-- Catches nil errors and typos in UI code; it does not verify rendering.

local frames, timers, now = {}, {}, 0
local cursorX, cursorY = 300, 300
local onTaxi = false
local chat = {}

local NUMBER_GETTERS = {
    GetLeft = 100, GetTop = 600, GetEffectiveScale = 1, GetScale = 1, GetFrameLevel = 1,
    GetWidth = 100, GetHeight = 100, GetAlpha = 1, GetStringWidth = 50, GetStringHeight = 12,
}

local methods = {
    GetParent = function(self) return rawget(self, "_parent") end,
    SetScript = function(self, name, fn) self._scripts[name] = fn end,
    GetScript = function(self, name) return self._scripts[name] end,
    IsShown = function(self) return self._shown end,
    Show = function(self)
        if not self._shown then
            self._shown = true
            if self._scripts.OnShow then self._scripts.OnShow(self) end
        end
    end,
    Hide = function(self)
        if self._shown then
            self._shown = false
            if self._scripts.OnHide then self._scripts.OnHide(self) end
        end
    end,
    SetShown = function(self, shown)
        if shown then self:Show() else self:Hide() end
    end,
    IsMouseOver = function() return true end,
    GetPoint = function() return "CENTER", nil, "CENTER", 0, 0 end,
    GetCenter = function() return 500, 500 end,
    SetText = function(self, text) self._text = text end,
    SetChecked = function(self, v) self._checked = v end,
    GetChecked = function(self) return self._checked end,
    SetFont = function() return true end,
    SetupMenu = function(self, fn) self._menu = fn end,
}

local function Wrap(o)
    o._scripts = o._scripts or {}
    if o._shown == nil then o._shown = true end
    return setmetatable(o, {
        __index = function(_, k)
            if methods[k] then return methods[k] end
            if NUMBER_GETTERS[k] then return function() return NUMBER_GETTERS[k] end end
            if k:match("^Create") then
                return function(self) return Wrap({ _parent = self }) end
            end
            return function() end
        end,
    })
end

UIParent = Wrap({})
Minimap = Wrap({})
GameTooltip = Wrap({})
function GameTooltip_Hide() end
function CreateFrame(_, name, parent)
    local f = Wrap({ _parent = parent })
    frames[#frames + 1] = f
    if name then _G[name] = f end
    return f
end
function CreateFont() return Wrap({}) end

UISpecialFrames = {}
tinsert = table.insert
SlashCmdList = {}
SOUNDKIT = setmetatable({}, { __index = function() return 1 end })
function GetMinimapShape() return "ROUND" end
MinimalSliderWithSteppersMixin = { Label = { Right = 1 } }
function CreateSettingsListSectionHeaderInitializer() return {} end
local settingCallbacks, dropdownOptions = {}, {}
-- Like the client's secure delegate: a refused setting (taken name) hands back the previous result.
local registeredSettings, lastSettingResult = {}, nil
Settings = {
    VarType = { Boolean = "boolean", Number = "number", String = "string" },
    RegisterVerticalLayoutCategory = function()
        lastSettingResult = { GetID = function() return 1 end }
        return lastSettingResult, { AddInitializer = function() end }
    end,
    RegisterAddOnSetting = function(_, variable, key, tbl, varType, _, default)
        if registeredSettings[variable] then return lastSettingResult end
        registeredSettings[variable] = true
        if tbl[key] == nil then tbl[key] = default end
        lastSettingResult = { variable = variable, key = key, tbl = tbl, GetVariableType = function() return varType end }
        return lastSettingResult
    end,
    CreateCheckbox = function() end,
    CreateDropdown = function(_, setting, options) dropdownOptions[setting.variable] = { setting = setting, options = options } end,
    CreateControlTextContainer = function()
        local data = {}
        return { Add = function(_, value, label) data[#data + 1] = { value = value, label = label } end, GetData = function() return data end }
    end,
    CreateSliderOptions = function() return { SetLabelFormatter = function(_, _, fn) fn(1.15) end } end,
    CreateSlider = function() end,
    SetOnValueChangedCallback = function(variable, fn) settingCallbacks[variable] = fn end,
    RegisterAddOnCategory = function() end,
    OpenToCategory = function() end,
}
LE_PARTY_CATEGORY_INSTANCE = 2
Enum = { UIMapType = { Continent = 2 } }
C_Timer = {
    After = function(delay, fn) timers[#timers + 1] = { at = now + delay, fn = fn } end,
    NewTicker = function(interval, fn)
        local ticker = { cancelled = false }
        local function Schedule()
            timers[#timers + 1] = { at = now + interval, fn = function()
                if ticker.cancelled then return end
                fn()
                Schedule()
            end }
        end
        Schedule()
        function ticker:Cancel() self.cancelled = true end
        return ticker
    end,
}
local playerX, playerY = 0.40, 0.70
C_Map = {
    GetBestMapForUnit = function() return 1429 end,
    GetPlayerMapPosition = function() return { GetXY = function() return playerX, playerY end } end,
    GetMapInfo = function(id) return { mapType = id == 13 and 2 or 3, parentMapID = 13 } end,
    GetWorldPosFromMapPos = function(_, v)
        return 0, { GetXY = function() return v.x * 20000, v.y * 30000 end }
    end,
}
function CreateVector2D(x, y) return { x = x, y = y } end
function GetLocale() return "deDE" end
function GetBuildInfo() return "1.60.1", "70205", "Oct 1 2026", 16001 end
local knownTemplates = { SimplePanelTemplate = true, WowStyle1DropdownTemplate = true, TabSystemTemplate = true }
TabSystemMixin = { OnLoad = function() end }
TabSystemOwnerMixin = {
    OnLoad = function() end,
    SetTabSystem = function() end,
    AddNamedTab = function(self) rawset(self, "_tabs", (rawget(self, "_tabs") or 0) + 1); return rawget(self, "_tabs") end,
    SetTab = function() end,
}
function Mixin(target, source) for k, v in pairs(source) do rawset(target, k, v) end return target end
C_XMLUtil = { GetTemplateInfo = function(name) if knownTemplates[name] then return { type = "Frame" } end end }
function GetTime() return now end
function time() return 1760000000 + math.floor(now) end
date = os.date
function GetCursorPosition() return cursorX, cursorY end
function InCombatLockdown() return false end
function UnitOnTaxi() return onTaxi end
function IsInGroup() return true end
function IsInRaid() return false end
function IsInGuild() return true end
local addonMessages = {}
C_ChatInfo = {
    RegisterAddonMessagePrefix = function() return true end,
    SendAddonMessage = function(prefix, text, channel) addonMessages[#addonMessages + 1] = text end,
}
function Ambiguate(name) return (name:gsub("%-.*", "")) end
function UnitName() return "Berthold" end
function strsplit(sep, text)
    local parts = {}
    for part in (text .. sep):gmatch("(.-)" .. sep) do parts[#parts + 1] = part end
    return unpack(parts)
end
function SendChatMessage(msg, channel, _, target)
    chat[#chat + 1] = channel .. ": " .. msg .. (target and (" > " .. target) or "")
end
StaticPopupDialogs = {}
local popupText
-- Shows the dialog like Blizzard's StaticPopup and accepts it with whatever name was typed.
function StaticPopup_Show(which, _, _, data)
    local dialog = StaticPopupDialogs[which]
    local box = Wrap({})
    box.SetText = function(self, text) popupText = text end
    box.GetText = function() return popupText ~= "" and popupText or "Guildie" end
    local popup = Wrap({ editBox = box, data = data })
    box._parent = popup
    dialog.OnShow(popup)
    dialog.EditBoxOnEnterPressed(box)
end
function UnitIsPlayer() return true end
function UnitIsUnit() return false end
function GetUnitName() return "Target-Realm" end
function PlaySound() end
function PlaySoundFile() end
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function hooksecurefunc(name, hook)
    local original = _G[name]
    _G[name] = function(...)
        original(...)
        hook(...)
    end
end
local printed = {}
print = function(msg) printed[#printed + 1] = msg end

-- Taxi API: node 1 is the current node, node 2 the destination via two hops.
function TakeTaxiNode() end
function NumTaxiNodes() return 2 end
function TaxiNodeGetType(i) return i == 1 and "CURRENT" or "REACHABLE" end
function TaxiNodeName(i) return i == 1 and "Goldhain" or "Sturmwind" end
function GetNumRoutes() return 2 end
function TaxiGetSrcX(_, hop) return 0.40 + hop * 0.01 end
function TaxiGetSrcY(_, hop) return 0.70 - hop * 0.02 end
function TaxiGetDestX(_, hop) return 0.41 + hop * 0.01 end
function TaxiGetDestY(_, hop) return 0.68 - hop * 0.02 end

local ns = {}
for _, file in ipairs(ADDON_FILES) do
    local fn = assert(loadstring(ADDON_SOURCES[file], "@" .. file))
    fn("DarkmoonArcade", ns)
end

local function Fire(event, ...)
    for _, f in ipairs(frames) do
        if f._scripts.OnEvent then f._scripts.OnEvent(f, event, ...) end
    end
end

local function Tick(seconds)
    local steps = math.floor(seconds * 60)
    for _ = 1, steps do
        now = now + 1 / 60
        for i = #timers, 1, -1 do
            if timers[i] and timers[i].at <= now then
                local t = table.remove(timers, i)
                t.fn()
            end
        end
        for _, f in ipairs(frames) do
            if f._scripts.OnUpdate and f._shown then f._scripts.OnUpdate(f, 1 / 60) end
        end
    end
end

local function IsVisible(f)
    while f do
        if not rawget(f, "_shown") then return false end
        f = rawget(f, "_parent")
    end
    return true
end

local function ClickVisibleButtons(rnd)
    local clicked = 0
    for _, f in ipairs(frames) do
        if f._scripts.OnClick and IsVisible(f) and rnd(3) == 0 then
            f._scripts.OnClick(f, "LeftButton")
            clicked = clicked + 1
        end
    end
    return clicked
end

DarkmoonArcadeDB = nil
Fire("ADDON_LOADED", "DarkmoonArcade")
Fire("PLAYER_LOGIN")
assert(DarkmoonArcadeDB.flightGame == "murlocblast", "defaults")
-- The release copy steps aside while the dev copy is enabled (both would share one save).
assert(not ns.standingDown and not ns.DevCopyActive(), "no dev copy: the release copy runs")
C_AddOns = {
    GetAddOnEnableState = function(name) return name == "DarkmoonArcade_Dev" and 2 or 0 end,
    IsAddOnLoadable = function() return true end,
}
assert(ns.DevCopyActive(), "release copy sees the enabled dev copy")
C_AddOns.IsAddOnLoadable = function() return false end
assert(not ns.DevCopyActive(), "a dev copy that cannot load does not count")
C_AddOns.GetAddOnEnableState = function() return 0 end
C_AddOns.IsAddOnLoadable = function() return true end
assert(not ns.DevCopyActive(), "disabled dev copy does not count")
C_AddOns = nil

local Window, Arcade = ns.Window, ns.Arcade
assert(#Arcade.order == 7, "seven games registered")
assert(Arcade.order[1] == "mercenaries", "newest game first")
assert(Arcade.order[2] == "spellbounce", "then the most popular game")

-- Every version of the news, in every language, has the texts of its rows; newest first.
local function NewsText(key, what)
    local text = ns.L[key]
    assert(type(text) == "string" and text ~= "" and not text:find("^NEWS_"), "news text " .. key .. " " .. what)
end
for _, language in ipairs({ "enUS", "deDE", "frFR", "esES", "ruRU", "zhCN" }) do
    ns.SetLanguage(language)
    for i, v in ipairs(ns.News.VERSIONS) do
        local newsKeys = {}
        for _, item in ipairs(v.items) do
            assert(item.key and not newsKeys[item.key], "news rows need distinct keys: " .. v.version)
            newsKeys[item.key] = true
            NewsText(ns.News.Key(v, item.key .. "_TITLE"), language)
            NewsText(ns.News.Key(v, item.key .. "_TEXT"), language)
        end
        if v.thanks then NewsText(ns.News.Key(v, "THANKS"), language) end
        if v.headline then NewsText(ns.News.Key(v, "HEADLINE"), language) end
    end
end
ns.SetLanguage(DarkmoonArcadeDB.language)
-- A player back from 1.3.1 missed 1.3.2 (and nothing older).
local missed = ns.News.Missed("v1.3.1")
assert(missed["1.3.2"] and not missed["1.3.1"] and not missed["1.3.0"], "missed versions")
assert(next(ns.News.Missed(nil)) == nil and next(ns.News.Missed("dev")) == nil, "nothing missed on a fresh install")
-- After login (a fresh install) the window opens on the news tab, once per version.
local News = ns.News
assert(not Window.frame._shown, "news wait for the loading screen")
Tick(4)
assert(Window.frame._shown and News.frame._shown and Window.tab == "news", "news tab after a fresh install")
assert(DarkmoonArcadeDB.newsSeen == ns.Version(), "the tab counts the news as seen")
Window.frame:Hide()
News:ShowIfNew()
assert(not Window.frame._shown, "news only once per version")

SlashCmdList.DARKMOONARCADE("")
assert(Window.frame._shown, "window should be shown")
-- The header: a tab each for home, news, statistics and options; the game tab only with a game open.
for _, id in ipairs({ "home", "news", "stats", "options" }) do
    assert(Window.tabButtons[id]._shown, id .. " tab")
end
assert(not Window.tabButtons.game._shown, "no game tab in the main menu")
Window.tabButtons.home._scripts.OnClick(Window.tabButtons.home)
assert(Window.hub._shown and Window.tab == "home", "home tab shows the main menu")
Window.frame:Hide()
DarkmoonArcadeDB.newsSeen = "1.0.0"
News:ShowIfNew()
assert(Window.frame._shown and News.frame._shown, "news after an update")
Window.tabButtons.home._scripts.OnClick(Window.tabButtons.home)
assert(Window.hub._shown and not News.frame._shown, "back to the main menu")
-- The main menu: the featured game on its stage with the player's progress, the others in a list.
assert(Window.featured.id == "mercenaries", "Mercenaries is featured")
assert(Window.heroStats[1].value._text ~= nil and Window.heroStats[4].label._text ~= nil, "progress on the stage")
assert(Window.heroPlay.label._text == ns.L.PLAY, "play, no bounty under way yet")
assert(#Window.tiles == #ns.Arcade.order - 1, "every other game in the list")
assert(Window.heroNews[1].title._text ~= nil, "the latest highlights on the stage")
-- The flight star: one game is starred; starring another moves it, starring it again turns it off.
assert(#Window.stars == #ns.Arcade.order, "a star for every game")
local star = Window.stars[1]
star._scripts.OnClick(star)
assert(DarkmoonArcadeDB.flightGame == star.game.id, "the star picks the flight game")
star._scripts.OnClick(star)
assert(DarkmoonArcadeDB.flightGame == "off", "a second click turns it off")
DarkmoonArcadeDB.flightGame = "murlocblast"
Window:RefreshHub()
-- See-through while moving, but not under the mouse and not while standing.
DarkmoonArcadeDB.fadeMoving, DarkmoonArcadeDB.fadeAlpha = true, 0.3
Window.moving = true
local away = setmetatable({ IsMouseOver = function() return false end }, { __index = Window.frame })
assert(math.abs(Window:FadeTarget(away) - 0.3) < 1e-6, "fades while moving")
assert(Window:FadeTarget(Window.frame) == 1, "stays visible under the mouse")
Window.moving = false
assert(Window:FadeTarget(away) == 1, "fully visible when standing")
DarkmoonArcadeDB.fadeMoving = false
-- The news tab: the versions on the left, a returning player sees what was missed.
DarkmoonArcadeDB.newsSeen = "v1.3.1"
Window.tabButtons.news._scripts.OnClick(Window.tabButtons.news)
assert(News.frame._shown and News.selected == 1, "newest version first")
assert(News.tabs[2].mark._shown and not News.tabs[3].mark._shown, "missed versions are marked")
News.tabs[#ns.News.VERSIONS]._scripts.OnClick(News.tabs[#ns.News.VERSIONS])
assert(News.selected == #ns.News.VERSIONS, "a version on the left opens it")
-- The option keeps the tab from opening by itself; the check box on the tab is the same switch.
News.neverCheck._checked = true
News.neverCheck._scripts.OnClick(News.neverCheck)
assert(DarkmoonArcadeDB.newsNever, "never again from the tab")
Window.frame:Hide()
DarkmoonArcadeDB.newsSeen = "1.0.0"
News:ShowIfNew()
assert(not Window.frame._shown, "never show the news automatically")
DarkmoonArcadeDB.newsNever = false
SlashCmdList.DARKMOONARCADE("")
Window:OpenHub()

local results = { murloc = 0, flappy = 0, jewels = 0, slots = 0, spell = 0, deck = 0, clicks = 0, best = 0 }
local seed = 42
local function rnd(n) seed = (seed * 16807) % 2147483647; return seed % n end

-- Flight start opens the configured game.
TakeTaxiNode(2)
onTaxi = true
Fire("PLAYER_CONTROL_LOST")
for _ = 1, 8 do
    playerX, playerY = playerX + 0.0015, playerY - 0.003
    Tick(0.5)
end
local _, remaining, _, isEstimate = ns.Flight:Status()
assert(isEstimate and remaining > 0, "live flight estimate")
assert(Window.activeGame and Window.activeGame.id == "murlocblast", "flight opens murloc blast")
assert(Window.flightText._text and Window.flightText._text:find("Sturmwind"), "flight text")
Window.activeGame:StartGame(1)

for step = 1, 900 do
    local game = Window.activeGame
    local state = game and game.game and game.game.state
    if game and game.id == "murlocblast" and state == "PLAYING" then
        cursorX, cursorY = 100 + rnd(432), 600 - rnd(380)
        Tick(0.05)
        game.field._scripts.OnMouseDown(game.field, "LeftButton")
        if rnd(5) == 0 then game.field._scripts.OnMouseDown(game.field, "RightButton") end
        Window.frame._scripts.OnKeyDown(Window.frame, "LEFT")
        Tick(0.1)
        Window.frame._scripts.OnKeyUp(Window.frame, "LEFT")
        Tick(0.5)
        results.murloc = results.murloc + 1
    elseif game and game.id == "goblinslots" and game.phase ~= "over" and state ~= "READY" and state ~= "OVER" then
        if game.phase == "idle" and state == "SPIN" then
            game.overlay:Hide()
            Window.frame._scripts.OnKeyDown(Window.frame, "SPACE")
        elseif game.phase == "offer" then
            game:Pick(game.game.offer[(step % 4) + 1])
        elseif game.phase == "rent" then
            game.overlay:Hide()
            game.phase = "idle"
            if step % 3 == 0 and #game.game.inventory > 0 then game.game:Remove(1) end
        end
        Tick(1.6)
        results.slots = results.slots + 1
    elseif game and game.id == "spellbounce" and state == "PLAYING" then
        cursorX, cursorY = 100 + rnd(432), 600 - rnd(400)
        Tick(0.05)
        if rnd(2) == 0 then
            game.field._scripts.OnMouseDown(game.field, "LeftButton")
        else
            Window.frame._scripts.OnKeyDown(Window.frame, "RIGHT")
            Tick(0.1)
            Window.frame._scripts.OnKeyUp(Window.frame, "RIGHT")
            Window.frame._scripts.OnKeyDown(Window.frame, "SPACE")
        end
        Tick(2.5)
        results.spell = results.spell + 1
    elseif game and game.id == "darkmoondeck" and state == "PLAYING" and game.busy <= 0 then
        local indexes = game.game:BestPlay()
        for _, i in ipairs(indexes) do game:ToggleCard(game.game.hand[i]) end
        if rnd(4) == 0 and game.game.discards > 0 then game:Discard() else Window.frame._scripts.OnKeyDown(Window.frame, "SPACE") end
        Tick(3)
        results.deck = results.deck + 1
    elseif game and game.id == "darkmoondeck" and state == "SHOP" and game.overlay.current == "shop" then
        game.game.gold = game.game.gold + 10
        game.shop.offers[1].buy._scripts.OnClick(game.shop.offers[1].buy)
        game:NextRound()
        Tick(0.5)
    elseif game and game.id == "jewelsofuldum" and state == "PLAYING" then
        local move = game.game:FindMove()
        if move then game:TrySwap(move[1], move[2], move[3], move[4]) end
        game.gemLayer._scripts.OnMouseDown(game.gemLayer, "LeftButton")
        Tick(1.2)
        results.jewels = results.jewels + 1
    elseif game and game.id == "flappygriffin" and (state == "PLAYING" or (state == "READY" and not game.overlay.current)) then
        if rnd(3) == 0 then game.container._scripts.OnMouseDown(game.container, "LeftButton") end
        if rnd(4) == 0 then Window.frame._scripts.OnKeyDown(Window.frame, "SPACE") end
        Tick(0.15)
        results.flappy = results.flappy + 1
        results.best = math.max(results.best, game.game.score)
    else
        Tick(1.2)
        results.clicks = results.clicks + ClickVisibleButtons(rnd)
        if not Window.frame._shown then SlashCmdList.DARKMOONARCADE("") end
    end
    -- Every game comes up at least once; random clicks (the header's tabs too) may leave it early.
    if step % 75 == 0 then
        local ids = { "murlocblast", "flappygriffin", "jewelsofuldum", "goblinslots", "spellbounce", "darkmoondeck", "mercenaries" }
        SlashCmdList.DARKMOONARCADE(ids[(step / 75) % 7 + 1])
        if Window.activeGame and Window.activeGame.id == "darkmoondeck" then Window.activeGame:NewRun() end
        if Window.activeGame and Window.activeGame.id == "flappygriffin" then Window.activeGame:NewRun() end
        if Window.activeGame and Window.activeGame.id == "murlocblast" then Window.activeGame:StartGame(1) end
        if Window.activeGame and Window.activeGame.id == "spellbounce" then Window.activeGame:StartGame(1) end
        if Window.activeGame and Window.activeGame.id == "goblinslots" then Window.activeGame:NewGame() end
        if Window.activeGame and Window.activeGame.id == "jewelsofuldum" then Window.activeGame:NewGame() end
    end
    if rnd(60) == 0 then Window.frame._scripts.OnKeyDown(Window.frame, "P") end
end
assert(results.murloc > 0 and results.flappy > 0 and results.jewels > 0 and results.slots > 0 and results.spell > 0 and results.deck > 0,
    ("all games were played: %d %d %d %d %d %d"):format(results.murloc, results.flappy, results.jewels, results.slots, results.spell, results.deck))

-- Darkmoon Deck: win an attraction, shop, then run out of plays.
SlashCmdList.DARKMOONARCADE("darkmoondeck")
local deck = Window.activeGame
deck:NewRun()
deck.game.goal = 1
deck:ToggleCard(deck.game.hand[1])
deck:Play()
Tick(4)
assert(deck.overlay.current == "shop", "shop after a won attraction")
deck.game.gold = 50
deck.shop.offers[1].buy._scripts.OnClick(deck.shop.offers[1].buy)
assert(#deck.game.trinkets == 1, "bought a Darkmoon card")
deck.shop.slots[1].sell._scripts.OnClick(deck.shop.slots[1].sell)
deck:NextRound()
deck.game.goal = 10 ^ 9
for _ = 1, 8 do
    if deck.game.state ~= "PLAYING" then break end
    deck:ToggleCard(deck.game.hand[1])
    deck:Play()
    Tick(4)
end
assert(deck.overlay.current == "over", "game over page: " .. tostring(deck.overlay.current))

-- Mercenaries: the camp, the collection, then a whole bounty fought through the board.
SlashCmdList.DARKMOONARCADE("mercenaries")
local mc = Window.activeGame
-- Which spell effects the battles play.
local fxPlayed = {}
local playFx = mc.PlayFx
mc.PlayFx = function(self, id, ...)
    fxPlayed[id] = true
    return playFx(self, id, ...)
end
local MC = ns.Mercenaries
local store = mc:Store()
if store.run then mc:AbandonRun(); mc.resultClose._scripts.OnClick(mc.resultClose) end
assert(mc.view == "camp", "mercenaries open in the camp: " .. tostring(mc.view))
mc:ShowView("collection")
local collection = mc.views.collection
collection.next._scripts.OnClick(collection.next)
collection.prev._scripts.OnClick(collection.prev)
collection.tabs.caster._scripts.OnClick(collection.tabs.caster)
store.mercs.jaina = store.mercs.jaina or MC.Bounty.NewEntry(false)
store.mercs.jaina.coins = 200
mc:CollectionClicked("jaina")
assert(mc.view == "merc", "mercenary page")
local mercView = mc.views.merc
mercView.recruit._scripts.OnClick(mercView.recruit)
assert(store.mercs.jaina.owned, "jaina recruited")
mercView.ups[1]._scripts.OnClick(mercView.ups[1])
mercView.gear[1]._scripts.OnClick(mercView.gear[1])
mc:GearTooltip(mercView.gear[3], "jaina", 3)
mc:ShowView("collection")
collection.slots[1]._scripts.OnClick(collection.slots[1])
mc:CollectionClicked("jaina")
assert(store.party[1] == "jaina", "jaina joined the party")
mc:ShowView("camp")
-- Roadmap: the medallion in the camp opens the milestones; every coin can be chosen.
mc.views.camp.roadmap._scripts.OnClick(mc.views.camp.roadmap)
assert(mc.view == "roadmap", "roadmap from the camp")
for i, coin in ipairs(mc.roadmapNodes) do
    coin._scripts.OnClick(coin)
    assert(mc.roadmapSelection == i, "milestone " .. i .. " chosen")
end
for _, language in ipairs({ "enUS", "deDE", "frFR", "esES", "ruRU", "zhCN" }) do
    ns.SetLanguage(language)
    local keys = {}
    for i, stone in ipairs(ns.Mercenaries.ROADMAP) do
        assert(not keys[stone.key], "milestone key twice: " .. stone.key)
        keys[stone.key] = true
        assert(ns.L["MC_RM_" .. stone.key .. "_TITLE"], language .. " milestone title " .. stone.key)
        assert(ns.L["MC_RM_" .. stone.key .. "_TEXT"]:find("•"), language .. " milestone " .. stone.key)
    end
end
ns.SetLanguage(DarkmoonArcadeDB.language)
-- Effect gallery (dev copy only): builds, plays every effect, keeps tuning and ratings.
for _, e in ipairs(ns.Mercenaries.FX_LIST) do
    assert(not e.impact or ns.Mercenaries.FX[e.impact], "effect " .. e.id .. " has an unknown impact")
end
mc:BuildFxGallery()
mc:OpenFxGallery()
assert(mc.view == "fxgallery", "effect gallery shown")
for _ = 1, #ns.Mercenaries.FX_LIST do
    mc:StepFx(1)
    for _ = 1, 40 do mc:OnUpdate(0.05) end
end
mc:TuneFx({ "scale", "Scale", 1.15, "mul", 2 }, 1)
mc:TuneFxCamera(5)
for _, key in ipairs({ "fovAxis", "mirror", "pitchSign", "down", "loop" }) do mc:ToggleFxSetting(key) end
mc:RateFx("good")
local fxId = ns.Mercenaries.FX_LIST[mc.fxIndex].id
local fxSaved = DarkmoonArcadeDB.fxGallery.v3[fxId]
assert(fxSaved.rating == "good" and fxSaved.scale > (ns.Mercenaries.FX[fxId].scale or 1), "effect tuning kept")
assert(DarkmoonArcadeDB.fxGallery.cam.ppy == 53 and DarkmoonArcadeDB.fxGallery.cam.mirror, "camera settings kept")
mc:ResetFx()
assert(fxSaved.scale == nil and fxSaved.rating == "good", "reset keeps the rating")
mc:Route()
mc:ShowView("camp")
mc.views.camp.travel._scripts.OnClick(mc.views.camp.travel)
assert(mc.view == "travel", "travel point")
local travel = mc.views.travel
travel.tabs.kal._scripts.OnClick(travel.tabs.kal)
travel.tabs.zephras._scripts.OnClick(travel.tabs.zephras)
for _, id in ipairs(store.party) do store.mercs[id].level = 14 end
travel.tabs.ek._scripts.OnClick(travel.tabs.ek)
travel.regions[1]._scripts.OnClick(travel.regions[1])
Tick(1)
travel.overview._scripts.OnClick(travel.overview)
Tick(1)
travel.regions[3]._scripts.OnClick(travel.regions[3])
Tick(1)
local elwynnPin
for _, pin in ipairs(travel.pins) do
    if pin.zone == "elwynn" then elwynnPin = pin end
end
elwynnPin._scripts.OnClick(elwynnPin)
Tick(1)
assert(mc.travelZone == "elwynn", "elwynn picked on the map")
travel.boss.heroic._scripts.OnClick(travel.boss.heroic)
travel.boss.normal._scripts.OnClick(travel.boss.normal)
travel.boss.choose._scripts.OnClick(travel.boss.choose)
assert(store.run and mc.view == "map", "bounty started on the map")
-- A guest from the recruit mystery rides along to the result page (not in the collection).
assert(MC.Bounty.AddGuest(store, store.run), "guest joined the party")
mc:RefreshMap()
local fights, autoTurns, autoBattle = 0, 0, nil
for _ = 1, 600 do
    local run = store.run
    if not run or mc.overlay.current == "result" then break end
    local current = mc.overlay.current
    if current == "treasure" then
        mc.treasureButtons[1]._scripts.OnClick(mc.treasureButtons[1])
    elseif current == "healer" then
        local b = mc.healerButtons[1]
        if b._shown then b._scripts.OnClick(b) else mc.healerSkip._scripts.OnClick(mc.healerSkip) end
    elseif current == "event" then
        mc.eventContinue._scripts.OnClick(mc.eventContinue)
    elseif current == "stranger" then
        mc.strangerButtons[1]._scripts.OnClick(mc.strangerButtons[1])
    elseif run.phase == "map" then
        local choice = MC.Bounty.Choices(run)[1]
        mc:SelectNode(choice.layer, choice.index, true)
        mc.travelButton._scripts.OnClick(mc.travelButton)
    elseif run.phase == "battle" then
        local b = run.battle
        if mc.autoBattle then
            -- "Play all turns" plays and sends in fresh mercenaries by itself.
            autoTurns = autoTurns + 1
        elseif b.phase == "deploy" or b.phase == "replace" then
            local token = mc.tokens[b.bench.ally[1]]
            token._scripts.OnClick(token, "LeftButton")
            token._scripts.OnEnter(token)
        elseif b.phase == "command" and not mc.playing then
            fights = fights + 1
            if fights == 1 then
                -- Double speed and the log from the header, both while the turn plays.
                mc.speedButton._scripts.OnClick(mc.speedButton)
                assert(ns.Arcade.Settings(mc).fast, "double speed on")
                mc.logButton._scripts.OnClick(mc.logButton)
                assert(mc.logPanel._shown, "battle log open")
            end
            if fights == 3 then
                -- "Play all turns" belongs to the dev copy only; as the dev copy, it plays the battle.
                assert(not MC.DEV and not mc.autoButton._shown, "play all turns hidden in the release copy")
                MC.DEV = true
                mc:RefreshBattle()
                assert(not mc.autoButton._shown, "play all turns needs the debug mode, too")
                DarkmoonArcadeDB.debugMode = true
                mc:RefreshBattle()
                assert(mc.autoButton._shown, "play all turns offered in the dev copy's debug mode")
                -- The sound switch in the header and the choice of battle sounds.
                mc.soundButton._scripts.OnClick(mc.soundButton)
                assert(DarkmoonArcadeDB.sound == false, "sounds muted from the battle")
                mc.soundButton._scripts.OnClick(mc.soundButton)
                assert(DarkmoonArcadeDB.sound == true, "sounds back on")
                assert(ns.Arcade.Settings(mc).sounds == "ingame" and MC.AbilitySound("cairne_1"), "in-game combat sounds by default")
                ns.Arcade.Settings(mc).sounds = "simple"
                assert(not MC.AbilitySound("cairne_1"), "simple sounds leave the ability sounds out")
                ns.Arcade.Settings(mc).sounds = "ingame"
                -- Colour-blind friendly roles: fighters turn gold, the board redraws at once.
                assert(not MC.RoleTex("role_", "fighter"):find("_cb"), "green fighters by default")
                ns.Arcade.Settings(mc).colorblind = true
                assert(MC.RoleTex("otoken_", "fighter"):find("_cb") and not MC.RoleTex("otoken_", "caster"):find("_cb"), "gold fighters")
                mc:RefreshShown()
                ns.Arcade.Settings(mc).colorblind = false
                mc:RefreshShown()
                mc.autoButton._scripts.OnClick(mc.autoButton)
                assert(mc.autoBattle, "automatic battle on")
                autoBattle = b
            elseif fights % 2 == 0 then
                -- Key R: orders for everyone and the turn starts.
                Window.frame._scripts.OnKeyDown(Window.frame, "R")
                assert(mc.playing, "play turn started the turn")
                if fights == 2 then
                    -- The tray turns into the turn's timeline; the first action lights up.
                    Tick(1.3)
                    assert(mc.timeline._shown and #mc.timelineList > 0, "timeline shown while the turn plays")
                    assert(mc.timelineCurrent >= 1, "timeline follows the actions")
                end
            else
                mc:PickAbility(1)
                local enemy = mc.tokens[b.board.enemy[1]]
                if enemy and mc.pending then
                    -- Aiming: the expected damage shows over the foe under the mouse.
                    enemy._scripts.OnEnter(enemy)
                    mc:UpdateAim()
                    assert(mc.preview._shown, "damage preview while aiming")
                    enemy._scripts.OnLeave(enemy)
                end
                if enemy then enemy._scripts.OnClick(enemy, "LeftButton") end
                Window.frame._scripts.OnKeyDown(Window.frame, "A")
                Window.frame._scripts.OnKeyDown(Window.frame, "SPACE")
            end
        end
        Tick(1.5)
    else
        Tick(0.5)
    end
end
assert(fights > 0, "mercenaries fought")
assert(autoTurns > 0, "a battle played by itself")
assert(next(fxPlayed), "battles play spell effects")
for school, set in pairs(MC.SCHOOL_FX) do
    for _, id in pairs(set) do
        assert(MC.FX[id] and not MC.FX[id].unused, school .. " uses a known, wanted effect: " .. id)
    end
end
for id in pairs(MC.Abilities) do assert(MC.AbilityFx(id), id .. " has its look") end
MC.DEV, DarkmoonArcadeDB.debugMode = false, false
assert(not mc.autoBattle or mc.autoBattleFor == autoBattle, "the next battle starts by hand")
assert(not mc.timeline._shown, "timeline gone after the turn")
for id in pairs(MC.Abilities) do
    assert(MC.ABILITY_SOUNDS[MC.AbilitySoundKey(id)], id .. " has a sound")
end
local logged = table.concat(mc.battleLogLines or {}, "\n")
assert(logged:find("|cff8cc8ff", 1, true) and logged:find("|cffff8c7a", 1, true), "battle log names both sides")
assert(logged:find("-%d"), "battle log lists damage")
mc.speedButton._scripts.OnClick(mc.speedButton)
mc.logButton._scripts.OnClick(mc.logButton)
assert(not ns.Arcade.Settings(mc).fast and not mc.logPanel._shown, "speed and log switched back")
if mc.overlay.current ~= "result" then
    local run = store.run
    local errs = DarkmoonArcadeDB.errors and table.concat((function() local t = {} for k, v in pairs(DarkmoonArcadeDB.errors) do t[#t + 1] = tostring(k) .. "=" .. tostring(type(v) == "table" and (v.message or v[1]) or v) end return t end)(), " | ") or "none"
    error(("bounty did not end: overlay %s, run %s, battle %s, playing %s, view %s, errors %s"):format(
        tostring(mc.overlay.current), tostring(run and run.phase), tostring(run and run.battle and run.battle.phase),
        tostring(mc.playing), tostring(mc.view), errs))
end
mc.resultClose._scripts.OnClick(mc.resultClose)
assert(not store.run and mc.view == "camp", "back in camp")
-- Elwynn is cleared: Hogger fell. Achievements also come afterwards, from the saved progress.
assert(ns.Achievements.IsDone("mc_hogger"), "hogger achievement")
DarkmoonArcadeDB.achievements.mc_hogger = nil
mc:Enter()
assert(ns.Achievements.IsDone("mc_hogger"), "achievements granted for earlier progress")
-- A run survives a reload of the view: start one and route back into it.
mc:StartBounty("dunmorogh", false)
mc:Route()
assert(mc.view == "map", "saved run resumes on the map")
mc.overlay:Show("confirm")
mc:AbandonRun()
mc.resultClose._scripts.OnClick(mc.resultClose)

-- Spellbounce: play a whole map to its fireworks and continue on the next one.
SlashCmdList.DARKMOONARCADE("spellbounce")
local sb = Window.activeGame
sb:StartGame(1)
for _, peg in ipairs(sb.game.pegs) do
    if peg.kind == "target" then peg.lit = true end
end
sb.game.targetsHit = sb.game.targetsTotal - 1
local lastTarget
for _, peg in ipairs(sb.game.pegs) do
    if peg.kind == "target" and not lastTarget then lastTarget = peg; peg.lit = false end
end
sb.game:SetAim(math.atan2(lastTarget.y - 34, lastTarget.x - 216))
sb.game.balls = {}
sb.game:Shoot()
sb.game.balls[1].x, sb.game.balls[1].y, sb.game.balls[1].vx, sb.game.balls[1].vy = lastTarget.x, lastTarget.y - 20, 0, 50
Tick(12)
assert(sb.game.state == "CLEAR", "spellbounce map cleared: " .. sb.game.state)
Tick(4)
assert(sb.overlay.current == "clear", "clear page shown")
sb:NextMap()
assert(sb.game.level == 2 and sb.game.state == "PLAYING", "next map")

-- Talents: earn points, learn along the tree, unlearn, and the run uses them.
DarkmoonArcadeDB.stats.counters.spellbounce = DarkmoonArcadeDB.stats.counters.spellbounce or {}
DarkmoonArcadeDB.stats.counters.spellbounce.class_mage = 30
ns.Arcade.Settings(sb).class = "mage"
wipe(sb:TalentAlloc("mage"))
sb:ShowTalents("menu")
assert(sb.overlay.current == "talents", "talent page")
local order = { "focus", "focus", "focus", "focus", "focus", "well", "well", "well", "well", "well",
    "power1", "power1", "power1", "secondwind", "secondwind", "runes", "power2", "power2", "pockets", "pockets", "gilded" }
local buttons = sb.talentPage.tree.buttons
for _, id in ipairs(order) do buttons[id]._scripts.OnClick(buttons[id], "LeftButton") end
assert(sb:TalentAlloc("mage").gilded == 1, "capstone learned")
buttons.focus._scripts.OnClick(buttons.focus, "RightButton")
assert(sb:TalentAlloc("mage").focus == 5, "cannot unlearn below a deeper talent")
buttons.gilded._scripts.OnClick(buttons.gilded, "RightButton")
assert(not sb:TalentAlloc("mage").gilded, "capstone unlearned")
buttons.focus._scripts.OnEnter(buttons.focus)
ns.Arcade.Settings(sb).class = "mage"
sb:StartGame(1)
assert(sb.game.orbs == 12, "deep pockets applied: " .. sb.game.orbs)

-- A moving map: pegs travel and the guide follows them.
sb:StartGame(12)
assert(sb.game.moving, "map 12 moves")
Tick(1)
sb.overlay:Show("menu")
local settings = ns.Arcade.Settings(sb)
settings.reached = 13
sb.overlay:Refresh()
assert(sb:StartMap() >= 1 and sb:StartMap() <= 13, "start map in range")

-- Shared scores carry the addon name; whispers go to the target.
ns.Widgets.Share("WHISPER", "test")
ns.Widgets.Share("SAY", "test")
assert(chat[#chat - 1] == "WHISPER: [Darkmoon Arcade] test > Target-Realm", "whisper: " .. tostring(chat[#chat - 1]))
assert(chat[#chat] == "SAY: [Darkmoon Arcade] test", "prefix")

-- Jewels of Uldum: a special combo and a few Zen moves.
SlashCmdList.DARKMOONARCADE("jewelsofuldum")
local ju = Window.activeGame
ns.Arcade.Settings(ju).mode = "zen"
ju:NewGame()
ju.game.board[4][4] = { color = 1, special = "star" }
ju.game.board[4][5] = { color = 2, special = "power" }
ju:RebuildBoard()
ju:TrySwap(4, 4, 4, 5)
Tick(4)
for _ = 1, 5 do
    local move = ju.game:FindMove()
    ju:TrySwap(move[1], move[2], move[3], move[4])
    Tick(3)
end
assert(ju.game.state == "PLAYING", "zen keeps going")
ns.Arcade.Settings(ju).mode = "classic"

-- Flappy Griffin as the Horde: desert scenery and the wind rider.
SlashCmdList.DARKMOONARCADE("flappygriffin")
ns.Arcade.Settings(Window.activeGame).faction = "horde"
Window.activeGame:ApplyTheme()
Window.activeGame:NewRun()
Window.activeGame.game:Flap()
Tick(1)
ns.Arcade.Settings(Window.activeGame).faction = "alliance"
Window.activeGame:ApplyTheme()

-- Landing pauses and records the flight.
SlashCmdList.DARKMOONARCADE("flappygriffin")
Window.activeGame:NewRun()
Window.activeGame.game:Flap()
onTaxi = false
Fire("PLAYER_CONTROL_GAINED")
Tick(1)
assert(Window.activeGame.game.state == "PAUSED", "landing should pause")
assert(DarkmoonArcadeDB.flights["Goldhain > Sturmwind"], "flight duration recorded")

-- Guild leaderboard: a guildmate's record arrives, our own bests were broadcast.
Tick(16)
Fire("CHAT_MSG_ADDON", "DMArcade", "S	flappygriffin	default	42", "GUILD", "Guildie-Realm")
Fire("CHAT_MSG_ADDON", "DMArcade", "R", "GUILD", "Guildie-Realm")
Tick(6)
assert(DarkmoonArcadeDB.guild.flappygriffin.default.Guildie.score == 42, "guild record stored")
assert(#addonMessages > 0, "bests broadcast")
assert(ns.Guild.Top("flappygriffin", "default", 5)[1].name == "Guildie", "guild top list")

-- Achievements unlock once and show a toast.
ns.Achievements.Unlock("fg_first")
ns.Achievements.Unlock("fg_first")
assert(ns.Achievements.IsDone("fg_first"), "achievement stored")
Tick(5)

-- In-window options: every check box toggles, every selector steps both ways.
Window:OpenOptions()
DarkmoonArcadeDB.scale = 1.1
for _, row in ipairs(ns.OptionsView.rows) do
    if row.check then
        row.check._checked = not row.check._checked
        row.check._scripts.OnClick(row.check)
    elseif row.cycler then
        ns.OptionsView:Step(row, 1)
        ns.OptionsView:Step(row, -1)
    end
end
assert(math.abs(DarkmoonArcadeDB.scale - 1.1) < 0.001, "scale stepped back")
for _, row in ipairs(ns.OptionsView.rows) do
    if row.dropdown then
        local radios = {}
        row.dropdown._menu(row.dropdown, { CreateRadio = function(_, text, isSelected, select)
            radios[#radios + 1] = { isSelected = isSelected, select = select }
        end })
        assert(#radios > 1, "dropdown has choices")
        for _, radio in ipairs(radios) do radio.select(); assert(radio.isSelected(), "radio selected") end
    end
end
DarkmoonArcadeDB.language = "auto"
Window:ApplyLanguage()
Window:OpenHub()

-- Statistics: play time, runs and flights were counted; every game has a block.
Window:OpenStats()
assert(ns.StatsView.view._shown, "statistics shown")
for i = 1, #ns.StatsView.entries do
    ns.StatsView.entries[i]._scripts.OnClick(ns.StatsView.entries[i])
    assert(ns.StatsView.selected == i and ns.StatsView.title._text, "statistics page " .. i)
end
assert(ns.OptionsView.version._text:find(ns.Version(), 1, true), "the version under the options")
assert(ns.Stats.TotalTime() > 0 and ns.Stats.TotalRuns() > 0, "play time and runs counted")
assert(DarkmoonArcadeDB.stats.flights >= 1, "flight with the arcade counted")
for _, id in ipairs(Arcade.order) do
    if Arcade.games[id].StatLines then assert(#Arcade.games[id]:StatLines() > 0, id .. " stat lines") end
end
Window:OpenHub()

-- Settings callbacks and dropdown contents.
for _, name in ipairs({ "DarkmoonArcade_language", "DarkmoonArcade_scale", "DarkmoonArcade_flightGame",
        "DarkmoonArcade_newsNever", "DarkmoonArcade_mercenaries_fast",
        "DarkmoonArcade_mercenaries_sounds", "DarkmoonArcade_mercenaries_colorblind",
        "DarkmoonArcade_flightTime" }) do
    assert(registeredSettings[name], name .. " registered")
end
assert(not registeredSettings.DarkmoonArcade_debugMode, "no debug mode in the release copy")
assert(ns.SafeCall("Settings again", ns.Settings.Register, ns.Settings), "taken setting names are skipped quietly")
for variable, entry in pairs(dropdownOptions) do
    local data = entry.options()
    assert(#data > 0, variable .. " options")
    for _, option in ipairs(data) do
        entry.setting.tbl[entry.setting.key] = option.value
        if settingCallbacks[variable] then settingCallbacks[variable](nil, nil, option.value) end
    end
end
for variable, fn in pairs(settingCallbacks) do fn(nil, nil, true) end
DarkmoonArcadeDB.language = "auto"
Window:ApplyLanguage()

Fire("PLAYER_REGEN_DISABLED")
assert(not Window.frame._shown, "combat should hide the window")
for _, cmd in ipairs({ "options", "minimap", "minimap", "fg anim 4", "fg facing 1.5", "fg nope", "reset", "help" }) do
    SlashCmdList.DARKMOONARCADE(cmd)
end
DarkmoonArcade_OnAddonCompartmentEnter(nil, Wrap({}))
DarkmoonArcade_OnAddonCompartmentClick(nil, "LeftButton")
_G.DarkmoonArcadeMinimapButton._scripts.OnEnter(_G.DarkmoonArcadeMinimapButton)
_G.DarkmoonArcadeMinimapButton._scripts.OnClick(_G.DarkmoonArcadeMinimapButton, "RightButton")
Tick(1)

for _, line in ipairs(printed) do
    if tostring(line):find("error") then error("captured: " .. tostring(line)) end
end
assert(not DarkmoonArcadeDB.errors, "errors recorded in SavedVariables")
assert(DarkmoonArcadeDB.debug.chrome == "SimplePanelTemplate", "chrome template diagnostics")

return results.murloc, results.flappy, results.clicks, results.best
