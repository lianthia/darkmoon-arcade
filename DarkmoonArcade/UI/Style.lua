-- The launcher's look (from the Figma design): its colours, rounded panels, icons and plain text.

local _, ns = ...

local Media = ns.Media

local Style = {}
ns.Style = Style

local function Hex(hex, alpha)
    return { tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255,
        alpha or 1 }
end
Style.Hex = Hex

Style.C = {
    window = Hex("0b070f"),
    surface = Hex("140c1d"),
    border = Hex("25202b"),
    edge = Hex("040205"),
    item = Hex("1d1626"),
    itemActive = Hex("241b25"),
    text = Hex("f2f1ed"),
    muted = Hex("a3a4ad"),
    dim = Hex("747680"),
    body = Hex("b9b5c2"),
    gold = Hex("d7bc7c"),
    goldHover = Hex("fede7a"),
    ink = Hex("17150f"),
    secondary = Hex("271e32"),
    secondaryHover = Hex("33283f"),
    divider = Hex("2b2c33"),
    ready = Hex("8aae94"),
    chip = { 21 / 255, 19 / 255, 29 / 255, 0.81 },
}

-- Plain text without the game's outline, in one of the colours above.
function Style.Text(parent, size, color, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY")
    fs:SetFontObject(Media.Font(size, "white", ""))
    fs:SetTextColor(unpack(color or Style.C.text))
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    return fs
end

function Style.LocalizedText(parent, size, color, key)
    local fs = Style.Text(parent, size, color)
    ns.Widgets.OnRefresh(function() fs:SetText(ns.L[key]) end)
    return fs
end

-- Rounded shapes: nine slices of a white 64 px texture whose corners have a 24 px radius.
local CORNER = 24 / 64

local function Slice(tex, piece)
    local a, b = CORNER, 1 - CORNER
    local u = { { 0, a }, { a, b }, { b, 1 } }
    local col, row = (piece - 1) % 3 + 1, math.floor((piece - 1) / 3) + 1
    tex:SetTexCoord(u[col][1], u[col][2], u[row][1], u[row][2])
end

local POINTS = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }

local Rounded = {}
Rounded.__index = Rounded

function Rounded:SetColor(color)
    for _, t in ipairs(self.parts) do t:SetVertexColor(color[1], color[2], color[3], color[4] or 1) end
end

function Rounded:SetShown(shown)
    for _, t in ipairs(self.parts) do t:SetShown(shown) end
end

-- A rounded rectangle filling `region`: "round" (filled) or "ring" (a line along its edge, one unit
-- wide at a radius of 8).
function Style.Rounded(parent, region, radius, color, layer, sublevel, shape)
    local tex = Media.Tex("launcher/" .. (shape or "round"))
    local parts = {}
    for i = 1, 9 do
        local t = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sublevel or 0)
        t:SetTexture(tex)
        Slice(t, i)
        parts[i] = t
    end
    local r = radius
    for i, t in ipairs(parts) do
        local col, row = (i - 1) % 3 + 1, math.floor((i - 1) / 3) + 1
        if col == 1 then
            t:SetPoint("LEFT", region, "LEFT")
            t:SetWidth(r)
        elseif col == 3 then
            t:SetPoint("RIGHT", region, "RIGHT")
            t:SetWidth(r)
        end
        if row == 1 then
            t:SetPoint("TOP", region, "TOP")
            t:SetHeight(r)
        elseif row == 3 then
            t:SetPoint("BOTTOM", region, "BOTTOM")
            t:SetHeight(r)
        end
        if col == 2 then
            t:SetPoint("LEFT", region, "LEFT", r, 0)
            t:SetPoint("RIGHT", region, "RIGHT", -r, 0)
        end
        if row == 2 then
            t:SetPoint("TOP", region, "TOP", 0, -r)
            t:SetPoint("BOTTOM", region, "BOTTOM", 0, r)
        end
    end
    local shape = setmetatable({ parts = parts }, Rounded)
    shape:SetColor(color or { 1, 1, 1, 1 })
    return shape
end

-- Round corners for a picture: the area outside a rounded corner painted in the colour behind it.
-- `which`: any of "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" (default: all four).
function Style.CutCorners(parent, region, radius, color, which, layer)
    local tex = Media.Tex("launcher/round_inv")
    local shape = setmetatable({ parts = {} }, Rounded)
    for _, point in ipairs(which or { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }) do
        local t = parent:CreateTexture(nil, layer or "OVERLAY", nil, 7)
        t:SetTexture(tex)
        t:SetSize(radius, radius)
        t:SetPoint(point, region, point)
        for i, p in ipairs(POINTS) do
            if p == point then Slice(t, i) end
        end
        shape.parts[#shape.parts + 1] = t
    end
    shape:SetColor(color)
    return shape
end

-- Icons from media/launcher/icons.tga (UI/IconAtlas.lua), at their designed size.
function Style.SetIcon(tex, key, size)
    local place = ns.IconAtlas[key]
    if not place then return end
    tex:SetTexture(Media.Tex("launcher/icons"))
    tex:SetTexCoord(place[1], place[2], place[3], place[4])
    if size then
        tex:SetSize(size * place[5] / math.max(place[5], place[6]), size * place[6] / math.max(place[5], place[6]))
    else
        tex:SetSize(place[5], place[6])
    end
end

function Style.Icon(parent, key, size, layer)
    local tex = parent:CreateTexture(nil, layer or "ARTWORK")
    Style.SetIcon(tex, key, size)
    return tex
end

-- A thin line in `color`.
function Style.Line(parent, color, layer)
    local t = parent:CreateTexture(nil, layer or "BORDER")
    t:SetColorTexture(unpack(color))
    return t
end

-- A horizontal gradient from one colour to another where the client has gradients.
function Style.Gradient(tex, left, right)
    tex:SetColorTexture(1, 1, 1, 1)
    local ok = CreateColor and pcall(tex.SetGradient, tex, "HORIZONTAL", CreateColor(unpack(left)), CreateColor(unpack(right)))
    if not ok then tex:SetColorTexture(left[1], left[2], left[3], (left[4] + right[4]) / 2) end
end

-- The games' small pictures (media/launcher/thumbs.tga, see tools/import_art.py).
local THUMBS = { "mercenaries", "spellbounce", "darkmoondeck", "murlocblast", "jewelsofuldum", "flappygriffin",
    "goblinslots" }

function Style.SetThumb(tex, gameId)
    for i, id in ipairs(THUMBS) do
        if id == gameId then
            tex:SetTexture(Media.Tex("launcher/thumbs"))
            tex:SetTexCoord((i - 1) / 8, i / 8, 0, 1)
            return
        end
    end
    -- A game without a picture of its own: the middle of its card.
    local game = ns.Arcade.games[gameId]
    tex:SetTexture(Media.Tex(game.tile))
    tex:SetTexCoord(0.25, 0.75, 0, 1)
end
