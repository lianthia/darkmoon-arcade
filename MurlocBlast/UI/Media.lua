local ADDON, ns = ...

local Media = {}
ns.Media = Media

local PATH = "Interface\\AddOns\\" .. ADDON .. "\\media\\"

Media.ICON = PATH .. "icon.tga"

-- Tint per bubble color for glows and sparks; indices match Levels.LETTERS.
Media.COLORS = {
    { 1.00, 0.30, 0.28 },
    { 1.00, 0.86, 0.25 },
    { 0.35, 0.90, 0.40 },
    { 0.30, 0.60, 1.00 },
    { 0.78, 0.40, 1.00 },
    { 1.00, 0.60, 0.20 },
    { 0.95, 0.95, 1.00 },
    { 1.00, 0.45, 0.75 },
    { 0.70, 0.66, 0.60 },
    { 1.00, 0.55, 0.20 },
}

-- Symbols are white; the pearl bubble needs a dark symbol to stay readable.
Media.SYMBOL_TINT = { [7] = { 0.25, 0.25, 0.35 } }

function Media.Tex(name)
    return PATH .. name .. ".tga"
end

function Media.Play(name)
    if ns.db and not ns.db.sound then return end
    PlaySoundFile(PATH .. name .. ".ogg", "SFX")
end

-- File data IDs of the client's own murloc sounds (sound/creature/murloc/*.ogg).
local VOICES = {
    aggro = { 555997, 555992, 556006, 556000 },
    attack = { 556003, 556004, 556005 },
    fidget = { 555993, 556002, 556001 },
    wound = { 555999, 555996, 555994 },
    death = { 555995 },
}
local lastVoice = 0

function Media.Voice(kind, force)
    if not ns.db or not ns.db.voices then return end
    local now = GetTime()
    if not force and now - lastVoice < 1.5 then return end
    local list = VOICES[kind]
    if not list then return end
    lastVoice = now
    PlaySoundFile(list[math.random(#list)], "SFX")
end

-- Fonts -------------------------------------------------------------------

local FONT_FILES = {
    ruRU = "Fonts\\FRIZQT___CYR.TTF",
    zhCN = "Fonts\\ARKai_T.ttf",
}
local DEFAULT_FONT = "Fonts\\FRIZQT__.TTF"

local FONT_COLORS = {
    gold = { 1, 0.82, 0.2 },
    white = { 1, 1, 1 },
    gray = { 0.65, 0.65, 0.65 },
    blue = { 0.75, 0.92, 1 },
}

local fonts = {}

function Media.FontFile(language)
    return FONT_FILES[language or ns.language] or DEFAULT_FONT
end

-- Shared font objects, so a language switch updates every string at once.
function Media.Font(size, color, flags)
    color = color or "white"
    flags = flags or "OUTLINE"
    local key = size .. color .. flags
    local font = fonts[key]
    if not font then
        font = CreateFont("MurlocBlastFont" .. key:gsub("%W", ""))
        local c = FONT_COLORS[color]
        font:SetTextColor(c[1], c[2], c[3])
        font.size, font.flags = size, flags
        font:SetFont(Media.FontFile(), size, flags)
        fonts[key] = font
    end
    return font
end

function Media.ApplyLanguageFonts()
    local file = Media.FontFile()
    for _, font in pairs(fonts) do
        font:SetFont(file, font.size, font.flags)
    end
end

function Media.Pool(create, reset)
    local free = {}
    return {
        Acquire = function()
            return table.remove(free) or create()
        end,
        Release = function(obj)
            if reset then reset(obj) end
            free[#free + 1] = obj
        end,
    }
end
