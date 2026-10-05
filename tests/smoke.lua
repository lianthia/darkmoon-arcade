-- Loads the whole addon against a permissive WoW API mock and plays a few rounds through the UI.
-- Catches nil errors and typos in UI code; it does not verify rendering.

local frames, timers, now = {}, {}, 0
local cursorX, cursorY = 300, 300

local NUMBER_GETTERS = {
    GetLeft = 100, GetTop = 600, GetEffectiveScale = 1, GetScale = 1, GetFrameLevel = 1,
    GetWidth = 100, GetHeight = 100,
}

-- Methods with behaviour that the addon relies on.
local methods = {
    GetParent = function(self) return self._parent end,
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
    IsMouseOver = function() return true end,
    GetPoint = function() return "CENTER", nil, "CENTER", 0, 0 end,
    SetText = function(self, text) self._text = text end,
}

local function Wrap(o)
    setmetatable(o, {
        __index = function(t, k)
            if methods[k] then return methods[k] end
            if NUMBER_GETTERS[k] then return function() return NUMBER_GETTERS[k] end end
            if k:match("^Create") then
                return function(self) return Wrap({ _parent = self, _scripts = {}, _shown = true }) end
            end
            return function() end
        end,
    })
    return o
end

UIParent = Wrap({ _scripts = {}, _shown = true })
function CreateFrame(_, name, parent)
    local f = Wrap({ _parent = parent, _scripts = {}, _shown = true })
    frames[#frames + 1] = f
    if name then _G[name] = f end
    return f
end

UISpecialFrames = {}
tinsert = table.insert
SlashCmdList = {}
SOUNDKIT = { IG_MAINMENU_OPEN = 1, IG_MAINMENU_CLOSE = 2 }
C_Timer = { After = function(delay, fn) timers[#timers + 1] = { at = now + delay, fn = fn } end }
function GetLocale() return "deDE" end
function GetTime() return now end
function GetCursorPosition() return cursorX, cursorY end
function InCombatLockdown() return false end
function UnitOnTaxi() return false end
function PlaySound() end
function PlaySoundFile() end
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
local printed = {}
print = function(msg) printed[#printed + 1] = msg end

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
            if timers[i].at <= now then
                local t = table.remove(timers, i)
                t.fn()
            end
        end
        for _, f in ipairs(frames) do
            if f._scripts.OnUpdate and f._shown then f._scripts.OnUpdate(f, 1 / 60) end
        end
    end
end

Fire("ADDON_LOADED", "MurlocBlast")
Fire("PLAYER_LOGIN")

local Window = ns.Window
Window.frame:Hide()
SlashCmdList.MURLOCBLAST("")
assert(Window.frame._shown, "window should be shown")

local overlay = Window.overlay
local results = { clears = 0, overs = 0 }
local seed = 42
local function rnd(n) seed = (seed * 16807) % 2147483647; return seed % n end

overlay.primary._scripts.OnClick()
for round = 1, 400 do
    local game = Window.game
    if game.state == "PLAYING" then
        cursorX, cursorY = 100 + rnd(256), 600 - rnd(300)
        Tick(0.05)
        Window.field._scripts.OnMouseDown(Window.field, "LeftButton")
        if rnd(5) == 0 then Window.field._scripts.OnMouseDown(Window.field, "RightButton") end
        Window.frame._scripts.OnKeyDown(Window.frame, "LEFT")
        Tick(0.1)
        Window.frame._scripts.OnKeyUp(Window.frame, "LEFT")
        Tick(0.8)
    else
        Tick(1.5)
        if game.state == "CLEAR" then results.clears = results.clears + 1 end
        if game.state == "OVER" then results.overs = results.overs + 1 end
        overlay.primary._scripts.OnClick()
    end
end

-- Pause/resume, combat, slash commands.
Window.frame._scripts.OnKeyDown(Window.frame, "P")
assert(Window.game.state == "PAUSED" or Window.game.state ~= "PLAYING")
overlay.primary._scripts.OnClick()
Fire("PLAYER_REGEN_DISABLED")
assert(not Window.frame._shown, "combat should hide the window")
for _, cmd in ipairs({ "flight", "sound", "symbols", "scale 1.4", "reset", "help" }) do
    SlashCmdList.MURLOCBLAST(cmd)
end
SlashCmdList.MURLOCBLAST("")
overlay.secondary._scripts.OnClick()
Tick(1)

return results.clears, results.overs
