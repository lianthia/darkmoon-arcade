local ADDON, ns = ...

local L, Window, Flight, Media = ns.L, ns.Window, ns.Flight, ns.Media

local DEFAULTS = {
    sound = true,
    voices = true,
    symbols = true,
    flight = true,
    flightTime = true,
    minimap = true,
    minimapAngle = 200,
    scale = 1.0,
    language = "auto",
    difficulty = "normal",
}

function ns.Print(msg)
    print("|cff33ccffMurloc Blast|r " .. msg)
end

local function InitDB()
    local db = MurlocBlastDB or {}
    MurlocBlastDB = db
    for k, v in pairs(DEFAULTS) do
        if db[k] == nil then db[k] = v end
    end
    db.scores = db.scores or {}
    db.progress = db.progress or {}
    for _, difficulty in ipairs(ns.Levels.DIFFICULTIES) do
        db.scores[difficulty] = db.scores[difficulty] or {}
        db.progress[difficulty] = db.progress[difficulty] or 1
    end
    db.flights = db.flights or {}
    db.flightRate = db.flightRate or {}
    -- Pre-0.2 saves had a single record and level.
    if db.highscore then
        if db.highscore > 0 then
            table.insert(db.scores.normal, { score = db.highscore, level = db.maxLevel or 1, time = time() })
        end
        db.progress.normal = math.max(db.progress.normal, db.maxLevel or 1)
        db.highscore, db.maxLevel = nil, nil
    end
    ns.db = db
end

local events = CreateFrame("Frame")
local onTaxi = false

local function CheckTaxi()
    local nowOnTaxi = UnitOnTaxi("player")
    if nowOnTaxi and not onTaxi then
        onTaxi = true
        Flight:Start()
        if ns.db.flight and not InCombatLockdown() then
            Window.frame:Show()
        end
        if Window.currentPage == "menu" then Window.pages.menu.refresh() end
    elseif not nowOnTaxi and onTaxi then
        onTaxi = false
        Flight:Finish()
        if Window.frame:IsShown() then Window:Pause(true) end
        if Window.currentPage == "menu" then Window.pages.menu.refresh() end
    end
end

events:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        InitDB()
        ns.SetLanguage(ns.db.language)
        Media.ApplyLanguageFonts()
        Window:Create()
        ns.Minimap:Create()
        Flight:Init()
        events:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        ns.Print(L.LOADED)
        CheckTaxi()
    elseif event == "PLAYER_REGEN_DISABLED" then
        if Window.frame:IsShown() then
            Window:Pause()
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
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_CONTROL_LOST")
events:RegisterEvent("PLAYER_CONTROL_GAINED")

SLASH_MURLOCBLAST1 = "/mb"
SLASH_MURLOCBLAST2 = "/murlocblast"
SlashCmdList.MURLOCBLAST = function(input)
    local cmd = strtrim(input or ""):lower()
    if InCombatLockdown() and (cmd == "" or cmd == "options") then
        ns.Print(L.COMBAT)
    elseif cmd == "" then
        Window:Toggle()
    elseif cmd == "options" or cmd == "config" then
        Window:OpenOptions()
    elseif cmd == "minimap" then
        ns.db.minimap = not ns.db.minimap
        ns.Minimap:Update()
    elseif cmd == "reset" then
        for _, difficulty in ipairs(ns.Levels.DIFFICULTIES) do
            ns.db.scores[difficulty] = {}
            ns.db.progress[difficulty] = 1
        end
        Window:UpdateHud()
        ns.Print(L.RESET_DONE)
    else
        ns.Print(L.USAGE)
    end
end
