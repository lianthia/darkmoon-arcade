-- Option definitions shared by the in-window options view and Blizzard's settings panel.

local ADDON, ns = ...

local L = ns.L

local SettingsPage = {}
ns.Settings = SettingsPage

-- Setting variables are global to the client: the folder name keeps the release and a dev copy apart.
local PREFIX = ADDON .. "_"

-- kind: "section", "check", "choice" (choices() -> { {value, label}, ... }) or "range" (min, max, step).
function SettingsPage.Definitions()
    local db, Window = ns.db, ns.Window
    local defs = {
        { kind = "section", label = "OPT_GENERAL" },
        { kind = "choice", tbl = db, key = "language", label = "OPT_LANGUAGE", tip = "OPT_LANGUAGE_TIP", default = "auto",
            onChange = function() Window:ApplyLanguage() end,
            choices = function()
                local choices = {}
                for _, code in ipairs(ns.LANGUAGES) do
                    choices[#choices + 1] = { code, code == "auto" and L.LANG_AUTO or ns.LANGUAGE_NAMES[code] }
                end
                return choices
            end },
        { kind = "range", tbl = db, key = "scale", label = "OPT_SCALE", tip = "OPT_SCALE_TIP", default = 1.1,
            min = 0.8, max = 1.6, step = 0.1, onChange = function() Window:ApplyScale() end,
            format = function(value) return ("%d%%"):format(value * 100 + 0.5) end },
        { kind = "check", tbl = db, key = "minimap", label = "OPT_MINIMAP", tip = "OPT_MINIMAP_TIP", default = true,
            onChange = function() ns.Minimap:Update() end },

        { kind = "section", label = "OPT_SECTION_SOUND" },
        { kind = "check", tbl = db, key = "sound", label = "OPT_SOUND", tip = "OPT_SOUND_TIP", default = true },
        { kind = "check", tbl = db, key = "voices", label = "OPT_VOICES", tip = "OPT_VOICES_TIP", default = true },

        { kind = "section", label = "OPT_SECTION_FLIGHTS" },
        { kind = "choice", tbl = db, key = "flightGame", label = "OPT_FLIGHT_GAME", tip = "OPT_FLIGHT_GAME_TIP",
            default = "murlocblast", onChange = function() Window:RefreshHub() end,
            choices = function()
                local choices = { { "off", L.FLIGHT_OFF }, { "hub", L.FLIGHT_HUB } }
                for _, id in ipairs(ns.Arcade.order) do
                    choices[#choices + 1] = { id, L[ns.Arcade.games[id].nameKey] }
                end
                return choices
            end },
        { kind = "check", tbl = db, key = "flightTime", label = "OPT_FLIGHT_TIME", tip = "OPT_FLIGHT_TIME_TIP", default = true },
    }
    for _, id in ipairs(ns.Arcade.order) do
        local game = ns.Arcade.games[id]
        if game.Options then
            defs[#defs + 1] = { kind = "section", label = game.nameKey, tab = "games" }
            for _, def in ipairs(game:Options()) do
                def.scope = id
                defs[#defs + 1] = def
            end
        end
    end
    return defs
end

function SettingsPage:Register()
    if not (Settings and Settings.RegisterVerticalLayoutCategory) then return end
    local title = ADDON == "DarkmoonArcade" and L.TITLE or (L.TITLE .. " (Dev)")
    local category, layout = Settings.RegisterVerticalLayoutCategory(title)
    local types = { check = Settings.VarType.Boolean, choice = Settings.VarType.String, range = Settings.VarType.Number }

    for _, def in ipairs(SettingsPage.Definitions()) do
        if def.kind == "section" then
            layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L[def.label]))
        else
            local variable = PREFIX .. (def.scope and (def.scope .. "_") or "") .. def.key
            local setting = Settings.RegisterAddOnSetting(category, variable, def.key, def.tbl, types[def.kind], L[def.label], def.default)
            -- A refused setting (e.g. a name taken by another addon) hands back an older result instead.
            if not (setting and setting.GetVariableType) then
                ns.Debug("settingRefused", variable)
                break
            end
            if def.kind == "check" then
                Settings.CreateCheckbox(category, setting, L[def.tip])
            elseif def.kind == "choice" then
                Settings.CreateDropdown(category, setting, function()
                    local container = Settings.CreateControlTextContainer()
                    for _, choice in ipairs(def.choices()) do container:Add(choice[1], choice[2]) end
                    return container:GetData()
                end, L[def.tip])
            else
                local options = Settings.CreateSliderOptions(def.min, def.max, def.step)
                options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, def.format)
                Settings.CreateSlider(category, setting, options, L[def.tip])
            end
            if def.onChange then
                Settings.SetOnValueChangedCallback(variable, function(_, _, value) def.onChange(value) end)
            end
        end
    end

    Settings.RegisterAddOnCategory(category)
    self.category = category
end
