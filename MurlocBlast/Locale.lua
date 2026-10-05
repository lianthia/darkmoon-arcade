local _, ns = ...

local strings = {
    enUS = {
        TITLE = "Murloc Blast",
        TAGLINE = "Mrglglglgl!",
        NEW_GAME = "New Game",
        CONTINUE = "Continue (Level %d)",
        RESUME = "Resume",
        NEXT_LEVEL = "Next Level",
        AGAIN = "Play Again",
        MENU = "Menu",
        PAUSED = "Paused",
        LANDED = "You have landed!",
        LEVEL = "Level %d",
        SCORE = "Score",
        BEST = "Best %s",
        NEXT = "Next",
        LEVEL_CLEAR = "Level cleared!",
        BONUS = "Bonus +%s",
        GAME_OVER = "Game Over",
        NEW_RECORD = "New record!",
        FINAL_SCORE = "Score: %s",
        COMBO = "Combo x%d!",
        HELP = "Left-click: shoot  ·  Right-click: swap\nA/D or arrows: aim  ·  Space: shoot",
        LOADED = "loaded. /mb opens the game.",
        COMBAT = "Game paused – you entered combat.",
        FLIGHT_ON = "Opens automatically on flights.",
        FLIGHT_OFF = "No longer opens on flights.",
        SOUND_ON = "Sound on.",
        SOUND_OFF = "Sound off.",
        SYMBOLS_ON = "Colour symbols on.",
        SYMBOLS_OFF = "Colour symbols off.",
        SCALE_SET = "Scale set to %.2f.",
        RESET_DONE = "Progress and record reset.",
        USAGE = "/mb – toggle  ·  /mb flight  ·  /mb sound  ·  /mb symbols  ·  /mb scale <0.6-2>  ·  /mb reset",
    },
    deDE = {
        TITLE = "Murloc Blast",
        TAGLINE = "Mrglglglgl!",
        NEW_GAME = "Neues Spiel",
        CONTINUE = "Fortsetzen (Level %d)",
        RESUME = "Weiter",
        NEXT_LEVEL = "Nächstes Level",
        AGAIN = "Nochmal",
        MENU = "Menü",
        PAUSED = "Pause",
        LANDED = "Du bist gelandet!",
        LEVEL = "Level %d",
        SCORE = "Punkte",
        BEST = "Rekord %s",
        NEXT = "Nächste",
        LEVEL_CLEAR = "Level geschafft!",
        BONUS = "Bonus +%s",
        GAME_OVER = "Game Over",
        NEW_RECORD = "Neuer Rekord!",
        FINAL_SCORE = "Punkte: %s",
        COMBO = "Combo x%d!",
        HELP = "Linksklick: schießen  ·  Rechtsklick: tauschen\nA/D oder Pfeile: zielen  ·  Leertaste: schießen",
        LOADED = "geladen. /mb öffnet das Spiel.",
        COMBAT = "Spiel pausiert – du bist im Kampf.",
        FLIGHT_ON = "Öffnet sich automatisch bei Flügen.",
        FLIGHT_OFF = "Öffnet sich nicht mehr bei Flügen.",
        SOUND_ON = "Sound an.",
        SOUND_OFF = "Sound aus.",
        SYMBOLS_ON = "Farbsymbole an.",
        SYMBOLS_OFF = "Farbsymbole aus.",
        SCALE_SET = "Skalierung auf %.2f gesetzt.",
        RESET_DONE = "Fortschritt und Rekord zurückgesetzt.",
        USAGE = "/mb – öffnen/schließen  ·  /mb flight  ·  /mb sound  ·  /mb symbols  ·  /mb scale <0.6-2>  ·  /mb reset",
    },
}

local active = strings[GetLocale()] or strings.enUS
ns.L = setmetatable({}, {
    __index = function(_, k)
        return active[k] or strings.enUS[k] or k
    end,
})

function ns.FormatNumber(n)
    local s = tostring(math.floor(n))
    local sep = (GetLocale() == "deDE") and "." or ","
    local formatted = s:reverse():gsub("(%d%d%d)", "%1" .. sep):reverse()
    if formatted:sub(1, 1) == sep then formatted = formatted:sub(2) end
    return formatted
end
