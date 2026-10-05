-- Options live in Blizzard's own settings panel (Esc > Options > AddOns).

local _, ns = ...

local L = ns.L

local SettingsPage = {}
ns.Settings = SettingsPage

local PREFIX = "DarkmoonArcade_"

local function Checkbox(category, tbl, key, label, tooltip, default, onChange)
    local setting = Settings.RegisterAddOnSetting(category, PREFIX .. key, key, tbl, Settings.VarType.Boolean, label, default)
    Settings.CreateCheckbox(category, setting, tooltip)
    if onChange then Settings.SetOnValueChangedCallback(PREFIX .. key, function(_, _, value) onChange(value) end) end
end

local function Dropdown(category, key, label, tooltip, default, options, onChange)
    local setting = Settings.RegisterAddOnSetting(category, PREFIX .. key, key, ns.db, Settings.VarType.String, label, default)
    Settings.CreateDropdown(category, setting, function()
        local container = Settings.CreateControlTextContainer()
        for _, option in ipairs(options()) do container:Add(option[1], option[2]) end
        return container:GetData()
    end, tooltip)
    if onChange then Settings.SetOnValueChangedCallback(PREFIX .. key, function(_, _, value) onChange(value) end) end
end

function SettingsPage:Register()
    if not (Settings and Settings.RegisterVerticalLayoutCategory) then return end
    local db, Window = ns.db, ns.Window
    local category, layout = Settings.RegisterVerticalLayoutCategory(L.TITLE)

    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L.OPT_GENERAL))
    Checkbox(category, db, "sound", L.OPT_SOUND, L.OPT_SOUND_TIP, true)
    Checkbox(category, db, "voices", L.OPT_VOICES, L.OPT_VOICES_TIP, true)
    Checkbox(category, db, "minimap", L.OPT_MINIMAP, L.OPT_MINIMAP_TIP, true, function() ns.Minimap:Update() end)

    Dropdown(category, "flightGame", L.OPT_FLIGHT_GAME, L.OPT_FLIGHT_GAME_TIP, "murlocblast", function()
        local options = { { "off", L.FLIGHT_OFF }, { "hub", L.FLIGHT_HUB } }
        for _, id in ipairs(ns.Arcade.order) do
            options[#options + 1] = { id, L[ns.Arcade.games[id].nameKey] }
        end
        return options
    end)
    Checkbox(category, db, "flightTime", L.OPT_FLIGHT_TIME, L.OPT_FLIGHT_TIME_TIP, true)

    Dropdown(category, "language", L.OPT_LANGUAGE, L.OPT_LANGUAGE_TIP, "auto", function()
        local options = {}
        for _, code in ipairs(ns.LANGUAGES) do
            options[#options + 1] = { code, code == "auto" and L.LANG_AUTO or ns.LANGUAGE_NAMES[code] }
        end
        return options
    end, function() Window:ApplyLanguage() end)

    local scale = Settings.RegisterAddOnSetting(category, PREFIX .. "scale", "scale", db, Settings.VarType.Number, L.OPT_SCALE, 1.15)
    local sliderOptions = Settings.CreateSliderOptions(0.8, 1.6, 0.05)
    sliderOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
        return ("%d%%"):format(value * 100 + 0.5)
    end)
    Settings.CreateSlider(category, scale, sliderOptions, L.OPT_SCALE_TIP)
    Settings.SetOnValueChangedCallback(PREFIX .. "scale", function() Window:ApplyScale() end)

    for _, id in ipairs(ns.Arcade.order) do
        local game = ns.Arcade.games[id]
        if game.RegisterSettings then
            game:RegisterSettings(category, layout, Checkbox)
        end
    end

    Settings.RegisterAddOnCategory(category)
    self.category = category
end

function SettingsPage:Open()
    if InCombatLockdown() then
        ns.Print(L.COMBAT)
        return
    end
    if self.category then
        Settings.OpenToCategory(self.category:GetID())
    end
end
