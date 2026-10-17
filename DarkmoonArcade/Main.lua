local ADDON, ns = ...

local L, Window, Flight, Media = ns.L, ns.Window, ns.Flight, ns.Media

local DEFAULTS = {
    sound = true,
    voices = true,
    flightGame = "murlocblast",
    flightTime = true,
    minimap = true,
    minimapAngle = 225,
    newsNever = false,
    debugMode = false,
    scale = 1.1,
    fadeMoving = false,
    fadeAlpha = 0.4,
    language = "auto",
}

function ns.Print(msg)
    print("|cffd78cffDarkmoon Arcade|r " .. msg)
end

local function InitDB()
    local db = DarkmoonArcadeDB or {}
    DarkmoonArcadeDB = db
    for k, v in pairs(DEFAULTS) do
        if db[k] == nil then db[k] = v end
    end
    db.scores = db.scores or {}
    db.games = db.games or {}
    db.flights = db.flights or {}
    db.flightRate = db.flightRate or {}
    db.achievements = db.achievements or {}
    db.guild = db.guild or {}
    -- Favorites came with the launcher (1.4.0); the game that used to open on flights starts as one.
    if not db.favorites then
        db.favorites = {}
        if ns.Arcade.games[db.flightGame] then db.favorites[db.flightGame] = true end
    end
    db.errors = nil
    db.debug = { build = select(4, GetBuildInfo()), locale = GetLocale() }
    ns.db = db
end

-- The release copy steps aside while the dev copy (DarkmoonArcade_Dev) is enabled for this
-- character. Both keep their progress in DarkmoonArcadeDB, and WoW saves only the table of the
-- copy that loaded last into both files: anything played in the other copy would be lost.
local DEV_COPY = "DarkmoonArcade_Dev"

-- Tools for testing (such as playing every turn of a battle by itself) appear only in the dev copy
-- with its debug mode on.
function ns.DebugMode()
    return ADDON ~= "DarkmoonArcade" and ns.db ~= nil and ns.db.debugMode == true
end

function ns.DevCopyActive()
    if ADDON ~= "DarkmoonArcade" then return false end
    local state
    if C_AddOns and C_AddOns.GetAddOnEnableState then
        local ok, value = pcall(C_AddOns.GetAddOnEnableState, DEV_COPY, UnitName("player"))
        if ok then state = value end
    end
    if state == nil and GetAddOnEnableState then
        local ok, value = pcall(GetAddOnEnableState, UnitName("player"), DEV_COPY)
        if ok then state = value end
    end
    if type(state) ~= "number" or state == 0 then return false end
    local isLoadable = C_AddOns and C_AddOns.IsAddOnLoadable or IsAddOnLoadable
    return not isLoadable or (isLoadable(DEV_COPY) and true or false)
end

local events = CreateFrame("Frame")
local onTaxi = false
local waitForDev = false

local function Init()
    InitDB()
    ns.SetLanguage(ns.db.language)
    Media.ApplyLanguageFonts()
    ns.SafeCall("Window", Window.Create, Window)
    ns.SafeCall("Settings", ns.Settings.Register, ns.Settings)
    ns.SafeCall("Flight", Flight.Init, Flight)
    ns.SafeCall("Toast", ns.Toast.Create, ns.Toast)
end

local function CheckTaxi()
    local nowOnTaxi = UnitOnTaxi("player")
    if nowOnTaxi and not onTaxi then
        onTaxi = true
        Flight:Start()
        if not InCombatLockdown() then Window:OpenForFlight() end
    elseif not nowOnTaxi and onTaxi then
        onTaxi = false
        Flight:Finish()
        Window:OnLanded()
    end
end

events:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        events:UnregisterEvent("ADDON_LOADED")
        -- The dev copy loads after this one, so whether it really runs is only known at login; its
        -- enable state is just a hint (it can say "on" for a copy switched off in the AddOn list).
        if ns.DevCopyActive() then
            waitForDev = true
            return
        end
        Init()
    elseif event == "PLAYER_LOGIN" then
        if waitForDev then
            waitForDev = false
            local isLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
            if isLoaded(DEV_COPY) then
                ns.standingDown = true
                events:UnregisterAllEvents()
                C_Timer.After(5, function() ns.Print(L.DEV_COPY_ACTIVE) end)
                return
            end
            Init()
        end
        -- The minimap has its final size only once the UI layout is applied.
        ns.SafeCall("Minimap", ns.Minimap.Create, ns.Minimap)
        ns.SafeCall("Guild", ns.Guild.Init)
        ns.Print(L.LOADED)
        CheckTaxi()
        -- After a first install or an update, once the loading screen is gone.
        C_Timer.After(3, function()
            if not InCombatLockdown() then ns.SafeCall("News", ns.News.ShowIfNew, ns.News) end
        end)
    elseif event == "PLAYER_ENTERING_WORLD" then
        ns.Minimap:Update()
    elseif event == "PLAYER_REGEN_DISABLED" then
        if Window.frame:IsShown() then
            Window.frame:Hide()
            ns.Print(L.COMBAT)
        end
    elseif event == "PLAYER_CONTROL_LOST" or event == "PLAYER_CONTROL_GAINED" then
        -- UnitOnTaxi flips slightly after the control events fire.
        C_Timer.After(0.5, CheckTaxi)
    end
end)
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_CONTROL_LOST")
events:RegisterEvent("PLAYER_CONTROL_GAINED")

SLASH_DARKMOONARCADE1 = "/arcade"
SLASH_DARKMOONARCADE2 = "/darkmoon"
SLASH_DARKMOONARCADE3 = "/mb"
SlashCmdList.DARKMOONARCADE = function(input)
    local cmd = strtrim(input or ""):lower()
    if cmd == "" then
        if InCombatLockdown() then
            ns.Print(L.COMBAT)
        else
            Window:Toggle()
        end
    elseif cmd == "options" or cmd == "config" then
        Window:OpenOptions()
    elseif cmd == "debug" and ADDON ~= "DarkmoonArcade" then
        ns.db.debugMode = not ns.db.debugMode
        ns.Print(ns.db.debugMode and L.DEBUG_ON or L.DEBUG_OFF)
    elseif cmd == "fx" and ADDON ~= "DarkmoonArcade" then
        -- Dev copy: the effect gallery of Mercenaries.
        Window.frame:Show()
        Window:OpenGame("mercenaries")
        ns.Mercenaries.Module:OpenFxGallery()
    elseif cmd == "minimap" then
        ns.db.minimap = not ns.db.minimap
        ns.Minimap:Update()
    elseif cmd == "reset" then
        ns.Scores.Reset()
        ns.Stats.Reset()
        for _, settings in pairs(ns.db.games) do
            if type(settings.progress) == "table" then wipe(settings.progress) end
        end
        for _, game in pairs(ns.Arcade.games) do
            if game.ResetProgress then game:ResetProgress() end
        end
        Window:OpenHub()
        ns.Print(L.RESET_DONE)
    elseif cmd:match("^fg ") then
        local key, value = cmd:match("^fg (%a+) (%-?[%d%.]+)$")
        if not ns.FlappyGriffin.Module:Debug(key, tonumber(value)) then ns.Print("/arcade fg <facing|anim|zoom|size> <number>") end
    elseif ns.Arcade.games[cmd] then
        Window.frame:Show()
        Window:OpenGame(cmd)
    else
        ns.Print(L.USAGE)
    end
end
