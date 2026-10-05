local ADDON, ns = ...

local Media = {}
ns.Media = Media

local PATH = "Interface\\AddOns\\" .. ADDON .. "\\media\\"

Media.ICON = PATH .. "icon.tga"

function Media.Tex(name)
    return PATH .. name:gsub("/", "\\") .. ".tga"
end

function Media.Play(name)
    if ns.db and not ns.db.sound then return end
    PlaySoundFile(PATH .. name:gsub("/", "\\") .. ".ogg", "SFX")
end

local lastVoice = 0

-- Plays a random client sound file from `ids`; throttled so voices never pile up.
function Media.Voice(ids, force)
    if not ns.db or not ns.db.voices or not ids then return end
    local now = GetTime()
    if not force and now - lastVoice < 1.5 then return end
    lastVoice = now
    PlaySoundFile(ids[math.random(#ids)], "SFX")
end

-- Fonts -------------------------------------------------------------------

local FONT_FILES = {
    ruRU = "Fonts\\FRIZQT___CYR.TTF",
    zhCN = "Fonts\\ARKai_T.ttf",
}
local DEFAULT_FONT = "Fonts\\FRIZQT__.TTF"

local FONT_COLORS = {
    gold = { 1, 0.82, 0 },
    white = { 1, 1, 1 },
    gray = { 0.62, 0.62, 0.62 },
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
        font = CreateFont("DarkmoonArcadeFont" .. key:gsub("%W", ""))
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
