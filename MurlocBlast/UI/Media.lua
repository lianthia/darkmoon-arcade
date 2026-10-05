local ADDON, ns = ...

local Media = {}
ns.Media = Media

local PATH = "Interface\\AddOns\\" .. ADDON .. "\\media\\"

Media.FONT = "Fonts\\FRIZQT__.TTF"

-- Tint per bubble color for glows and sparks; indices match Levels.LETTERS.
Media.COLORS = {
    { 1.00, 0.30, 0.28 },
    { 1.00, 0.86, 0.25 },
    { 0.35, 0.90, 0.40 },
    { 0.30, 0.60, 1.00 },
    { 0.78, 0.40, 1.00 },
    { 1.00, 0.60, 0.20 },
}

function Media.Tex(name)
    return PATH .. name .. ".tga"
end

function Media.Play(name)
    if ns.db and not ns.db.sound then return end
    PlaySoundFile(PATH .. name .. ".ogg", "SFX")
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
