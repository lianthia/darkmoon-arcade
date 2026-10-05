local ADDON, ns = ...

local L, Window, Flight, Media = ns.L, ns.Window, ns.Flight, ns.Media

local DEFAULTS = {
    sound = true,
    voices = true,
    flightGame = "murlocblast",
    flightTime = true,
    minimap = true,
    minimapAngle = 225,
    scale = 1.15,
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
    db.errors = nil
    db.debug = { build = select(4, GetBuildInfo()), locale = GetLocale() }
    ns.db = db
end

local events = CreateFrame("Frame")
local onTaxi = false

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
        InitDB()
        ns.SetLanguage(ns.db.language)
        Media.ApplyLanguageFonts()
        ns.SafeCall("Window", Window.Create, Window)
        ns.SafeCall("Settings", ns.Settings.Register, ns.Settings)
        ns.SafeCall("Flight", Flight.Init, Flight)
        ns.SafeCall("Toast", ns.Toast.Create, ns.Toast)
        events:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        -- The minimap has its final size only once the UI layout is applied.
        ns.SafeCall("Minimap", ns.Minimap.Create, ns.Minimap)
        ns.SafeCall("Guild", ns.Guild.Init)
        ns.Print(L.LOADED)
        CheckTaxi()
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
        ns.Settings:Open()
    elseif cmd == "minimap" then
        ns.db.minimap = not ns.db.minimap
        ns.Minimap:Update()
    elseif cmd == "reset" then
        ns.Scores.Reset()
        for _, settings in pairs(ns.db.games) do
            if settings.progress then wipe(settings.progress) end
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
