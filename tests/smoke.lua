-- Loads the whole addon against a permissive WoW API mock and drives it through the UI:
-- every button gets clicked, rounds are played, a flight starts and lands.
-- Catches nil errors and typos in UI code; it does not verify rendering.

local frames, timers, now = {}, {}, 0
local cursorX, cursorY = 300, 300
local onTaxi = false
local chat = {}

local NUMBER_GETTERS = {
    GetLeft = 100, GetTop = 600, GetEffectiveScale = 1, GetScale = 1, GetFrameLevel = 1,
    GetWidth = 100, GetHeight = 100, GetAlpha = 1, GetStringWidth = 50,
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
Settings = {
    VarType = { Boolean = "boolean", Number = "number", String = "string" },
    RegisterVerticalLayoutCategory = function()
        return { GetID = function() return 1 end }, { AddInitializer = function() end }
    end,
    RegisterAddOnSetting = function(_, variable, key, tbl, _, _, default)
        if tbl[key] == nil then tbl[key] = default end
        return { variable = variable, key = key, tbl = tbl }
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

local Window, Arcade = ns.Window, ns.Arcade
assert(#Arcade.order == 6, "six games registered")
assert(Arcade.order[1] == "spellbounce", "most popular game first")
SlashCmdList.DARKMOONARCADE("")
assert(Window.frame._shown, "window should be shown")

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
    local state = game and game.game.state
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
    if step % 150 == 0 then
        local ids = { "murlocblast", "flappygriffin", "jewelsofuldum", "goblinslots", "spellbounce", "darkmoondeck" }
        SlashCmdList.DARKMOONARCADE(ids[(step / 150) % 6 + 1])
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
assert(ns.Stats.TotalTime() > 0 and ns.Stats.TotalRuns() > 0, "play time and runs counted")
assert(DarkmoonArcadeDB.stats.flights >= 1, "flight with the arcade counted")
for _, id in ipairs(Arcade.order) do
    if Arcade.games[id].StatLines then assert(#Arcade.games[id]:StatLines() > 0, id .. " stat lines") end
end
Window:OpenHub()

-- Settings callbacks and dropdown contents.
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
