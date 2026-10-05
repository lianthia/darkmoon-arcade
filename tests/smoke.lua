-- Loads the whole addon against a permissive WoW API mock and drives it through the UI:
-- every button gets clicked, rounds are played, a flight starts and lands.
-- Catches nil errors and typos in UI code; it does not verify rendering.

local frames, timers, now = {}, {}, 0
local cursorX, cursorY = 300, 300
local onTaxi = false
local chat = {}

local NUMBER_GETTERS = {
    GetLeft = 100, GetTop = 600, GetEffectiveScale = 1, GetScale = 1, GetFrameLevel = 1,
    GetWidth = 100, GetHeight = 100,
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
SOUNDKIT = { IG_MAINMENU_OPEN = 1, IG_MAINMENU_CLOSE = 2, U_CHAT_SCROLL_BUTTON = 3 }
LE_PARTY_CATEGORY_INSTANCE = 2
Enum = { UIMapType = { Continent = 2 } }
C_Timer = { After = function(delay, fn) timers[#timers + 1] = { at = now + delay, fn = fn } end }
C_Map = {
    GetBestMapForUnit = function() return 1429 end,
    GetMapInfo = function(id) return { mapType = id == 13 and 2 or 3, parentMapID = 13 } end,
    GetWorldPosFromMapPos = function(_, v)
        return 0, { GetXY = function() return v.x * 20000, v.y * 30000 end }
    end,
}
function CreateVector2D(x, y) return { x = x, y = y } end
function GetLocale() return "deDE" end
function GetTime() return now end
function time() return 1760000000 + math.floor(now) end
date = os.date
function GetCursorPosition() return cursorX, cursorY end
function InCombatLockdown() return false end
function UnitOnTaxi() return onTaxi end
function IsInGroup() return true end
function IsInRaid() return false end
function IsInGuild() return false end
function SendChatMessage(msg, channel) chat[#chat + 1] = channel .. ": " .. msg end
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
    fn("MurlocBlast", ns)
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

MurlocBlastDB = { highscore = 1234, maxLevel = 3 } -- pre-0.2 save
Fire("ADDON_LOADED", "MurlocBlast")
Fire("PLAYER_LOGIN")
assert(#MurlocBlastDB.scores.normal == 1 and MurlocBlastDB.progress.normal == 3, "migration")

local Window = ns.Window
SlashCmdList.MURLOCBLAST("")
assert(Window.frame._shown, "window should be shown")

local results = { clears = 0, overs = 0, clicks = 0 }
local seed = 42
local function rnd(n) seed = (seed * 16807) % 2147483647; return seed % n end

-- Flight starts while the menu is open.
TakeTaxiNode(2)
onTaxi = true
Fire("PLAYER_CONTROL_LOST")
Tick(1)
assert(ns.Flight.current and ns.Flight.current.estimate, "flight estimate")
assert(Window.flightText._text and Window.flightText._text:find("Sturmwind"), "flight text")

for _ = 1, 500 do
    local game = Window.game
    if game.state == "PLAYING" then
        cursorX, cursorY = 100 + rnd(432), 600 - rnd(380)
        Tick(0.05)
        Window.field._scripts.OnMouseDown(Window.field, "LeftButton")
        if rnd(5) == 0 then Window.field._scripts.OnMouseDown(Window.field, "RightButton") end
        Window.frame._scripts.OnKeyDown(Window.frame, "LEFT")
        Tick(0.1)
        Window.frame._scripts.OnKeyUp(Window.frame, "LEFT")
        Tick(0.6)
        if rnd(40) == 0 then Window.frame._scripts.OnKeyDown(Window.frame, "P") end
    else
        Tick(1.5)
        if game.state == "CLEAR" then results.clears = results.clears + 1 end
        if game.state == "OVER" then results.overs = results.overs + 1 end
        results.clicks = results.clicks + ClickVisibleButtons(rnd)
        if not Window.frame._shown then SlashCmdList.MURLOCBLAST("") end
    end
end

-- Landing pauses the game and records the flight.
Window:StartGame(1)
onTaxi = false
Fire("PLAYER_CONTROL_GAINED")
Tick(1)
assert(Window.game.state == "PAUSED", "landing should pause")
assert(MurlocBlastDB.flights["Goldhain > Sturmwind"], "flight duration recorded")

Fire("PLAYER_REGEN_DISABLED")
assert(not Window.frame._shown, "combat should hide the window")
for _, cmd in ipairs({ "options", "minimap", "minimap", "reset", "help" }) do
    SlashCmdList.MURLOCBLAST(cmd)
end
for _, language in ipairs(ns.LANGUAGES) do
    MurlocBlastDB.language = language
    Window:ApplyLanguage()
end
_G.MurlocBlastMinimapButton._scripts.OnEnter(_G.MurlocBlastMinimapButton)
_G.MurlocBlastMinimapButton._scripts.OnClick(_G.MurlocBlastMinimapButton, "RightButton")
Tick(1)

return results.clears, results.overs, results.clicks, #chat
