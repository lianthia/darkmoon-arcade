local ADDON, ns = ...

local L, Window = ns.L, ns.Window

local DEFAULTS = {
    highscore = 0,
    maxLevel = 1,
    sound = true,
    symbols = true,
    flight = true,
    scale = 1.15,
}

local function Print(msg)
    print("|cff33ccffMurloc Blast|r " .. msg)
end

local function InitDB()
    MurlocBlastDB = MurlocBlastDB or {}
    for k, v in pairs(DEFAULTS) do
        if MurlocBlastDB[k] == nil then MurlocBlastDB[k] = v end
    end
    ns.db = MurlocBlastDB
end

local events = CreateFrame("Frame")
local onTaxi = false

local function CheckTaxi()
    local nowOnTaxi = UnitOnTaxi("player")
    if nowOnTaxi and not onTaxi then
        onTaxi = true
        if ns.db.flight and not InCombatLockdown() then
            Window.frame:Show()
        end
    elseif not nowOnTaxi and onTaxi then
        onTaxi = false
        if Window.frame:IsShown() then Window:Pause(true) end
    end
end

events:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        InitDB()
        Window:Create()
        events:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        Print(L.LOADED)
        CheckTaxi()
    elseif event == "PLAYER_REGEN_DISABLED" then
        if Window.frame:IsShown() then
            Window:Pause()
            Window.frame:Hide()
            Print(L.COMBAT)
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

local function Toggle(field, label)
    ns.db[field] = not ns.db[field]
    Print(ns.db[field] and L[label .. "_ON"] or L[label .. "_OFF"])
end

SLASH_MURLOCBLAST1 = "/mb"
SLASH_MURLOCBLAST2 = "/murlocblast"
SlashCmdList.MURLOCBLAST = function(input)
    local cmd, arg = strtrim(input or ""):lower():match("^(%S*)%s*(.-)$")
    if cmd == "" then
        if InCombatLockdown() then
            Print(L.COMBAT)
        else
            Window:Toggle()
        end
    elseif cmd == "flight" then
        Toggle("flight", "FLIGHT")
    elseif cmd == "sound" then
        Toggle("sound", "SOUND")
    elseif cmd == "symbols" then
        Toggle("symbols", "SYMBOLS")
        ns.Board:SyncBoard()
    elseif cmd == "scale" and tonumber(arg) then
        ns.db.scale = math.max(0.6, math.min(2, tonumber(arg)))
        Window:ApplyScale()
        Print(L.SCALE_SET:format(ns.db.scale))
    elseif cmd == "reset" then
        ns.db.highscore, ns.db.maxLevel = 0, 1
        Window:UpdateHud()
        Print(L.RESET_DONE)
    else
        Print(L.USAGE)
    end
end
