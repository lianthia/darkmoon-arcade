-- The look of Mercenaries: wood, parchment, plaques, buttons and cards in the style of the
-- original, built from the client's own art (atlases) where it has it and from our textures
-- otherwise. Everything that reacts to the mouse animates through one shared ticker.

local _, ns = ...
local MC = ns.Mercenaries
local Combat, Describe = MC.Combat, MC.Describe
local Media, Widgets, L = ns.Media, ns.Widgets, ns.L

local Kit = {}
MC.Kit = Kit

local INK = { 0.24, 0.14, 0.06 }

-- Atlases ------------------------------------------------------------------------------------------

local atlasCache = {}

function Kit.HasAtlas(name)
    if atlasCache[name] == nil then
        local ok, info = pcall(function() return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) end)
        atlasCache[name] = (ok and info) and true or false
        if not atlasCache[name] and ns.db then
            -- Lists what the client lacks, so a test run tells which fallbacks were used.
            ns.db.debug = ns.db.debug or {}
            ns.db.debug.mcMissingAtlas = ns.db.debug.mcMissingAtlas or {}
            ns.db.debug.mcMissingAtlas[name] = true
        end
    end
    return atlasCache[name]
end

-- Shows atlas `name`, or `fallback` (a file path or ID) when the client has no such atlas.
function Kit.Atlas(tex, name, fallback)
    if Kit.HasAtlas(name) then
        tex:SetAtlas(name)
        return true
    end
    if fallback then tex:SetTexture(fallback) end
    return false
end

function Kit.Ink(parent, size, color, flags)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(Media.FontFile(), size, flags or "")
    local c = color or INK
    fs:SetTextColor(c[1], c[2], c[3])
    fs:SetShadowOffset(0, 0)
    return fs
end

-- Animation ----------------------------------------------------------------------------------------
-- Animated frames keep a centre point; scale and lift are eased towards their targets.

local animated = {}
local ticker = CreateFrame("Frame")

local function Approach(cur, target, k)
    if math.abs(target - cur) < 0.002 then return target end
    return cur + (target - cur) * k
end

-- Animation state lives beside the frames, not in them.
local states = setmetatable({}, { __mode = "k" })

local function State(f)
    local st = states[f]
    if not st then
        st = { scale = 1, scaleTarget = 1, lift = 0, liftTarget = 0, glow = 0, glowTarget = 0, base = 1 }
        states[f] = st
    end
    return st
end

local function Glow(f)
    return rawget(f, "glowTex")
end

local function Apply(f)
    local a = states[f]
    f:SetScale(a.scale)
    f:ClearAllPoints()
    f:SetPoint("CENTER", a.parent, "TOPLEFT", a.x / a.scale, -(a.y - a.lift) / a.scale)
    local glow = Glow(f)
    if glow then glow:SetAlpha(a.glow) end
end

ticker:SetScript("OnUpdate", function(_, dt)
    local k = math.min(1, dt * 14)
    for f in pairs(animated) do
        local a = states[f]
        if f:IsVisible() then
            local pulse = a.pulse and (0.5 + 0.5 * math.sin(GetTime() * 4)) * a.pulse or 0
            a.scale = Approach(a.scale, a.scaleTarget, k)
            a.lift = Approach(a.lift, a.liftTarget, k)
            a.glow = Approach(a.glow, math.max(a.glowTarget, pulse), k)
            Apply(f)
        end
    end
end)

-- Places `f` with its centre at x, y (from the parent's top left) and lets it animate.
function Kit.Place(f, x, y, parent)
    local a = State(f)
    a.parent = parent or f:GetParent()
    a.x, a.y = x, y
    a.placed = true
    animated[f] = true
    Apply(f)
end

-- Hover grows and lifts the frame and lights its glow; pressing pushes it down a little.
function Kit.Hover(f, opts)
    opts = opts or {}
    local grow, lift = opts.grow or 1.06, opts.lift or 0
    local a = State(f)
    a.hover = true
    f:HookScript("OnEnter", function()
        if not a.hover then return end
        a.scaleTarget, a.liftTarget = a.base * grow, lift
        a.glowTarget = a.selected and 1 or (opts.glow or 0.6)
        if not a.placed and Glow(f) then Glow(f):SetAlpha(a.glowTarget) end
        if opts.sound ~= false then PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) end
    end)
    f:HookScript("OnLeave", function()
        a.scaleTarget, a.liftTarget = a.base, 0
        a.glowTarget = a.selected and 1 or 0
        if not a.placed and Glow(f) then Glow(f):SetAlpha(a.glowTarget) end
    end)
    f:HookScript("OnMouseDown", function()
        if a.hover then a.scaleTarget = a.base * 0.96 end
    end)
    f:HookScript("OnMouseUp", function()
        if a.hover then a.scaleTarget = a.base * (f:IsMouseOver() and grow or 1) end
    end)
end

-- Turns hover effects off (for a card that only shows).
function Kit.NoHover(f)
    State(f).hover = false
end

function Kit.SetBaseScale(f, scale)
    local a = State(f)
    a.base, a.scale, a.scaleTarget = scale, scale, scale
    if a.placed then Apply(f) end
end

-- Keeps the glow lit (and gently pulsing) while the frame is selected.
function Kit.SetSelected(f, selected, pulse)
    local a = State(f)
    a.selected = selected
    a.glowTarget = selected and 1 or 0
    a.pulse = (selected and pulse) and 1 or nil
    if not a.placed and Glow(f) then Glow(f):SetAlpha(a.glowTarget) end
end

function Kit.SetPulse(f, pulse)
    State(f).pulse = pulse
end

-- Surfaces -----------------------------------------------------------------------------------------

-- Wooden planks filling `parent`, with the garrison's carved wood frame around them.
function Kit.Wood(parent, w, h, frame)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(w, h)
    holder:SetClipsChildren(true)
    local tile = 256
    for x = 0, math.ceil(w / tile) - 1 do
        for y = 0, math.ceil(h / tile) - 1 do
            local t = holder:CreateTexture(nil, "BACKGROUND")
            t:SetSize(tile, tile)
            t:SetPoint("TOPLEFT", x * tile, -y * tile)
            Kit.Atlas(t, "UI-Frame-Neutral-BackgroundTile", MC.Tex("menu_card"))
        end
    end
    if frame then
        -- The frame sits on the holder itself, so whatever the view adds later stays above it.
        for _, side in ipairs({ "TOP", "BOTTOM" }) do
            local t = holder:CreateTexture(nil, "BORDER")
            t:SetHeight(20)
            t:SetPoint(side .. "LEFT", 0, 0)
            t:SetPoint(side .. "RIGHT", 0, 0)
            Kit.Atlas(t, side == "TOP" and "_Garr_WoodFrameTile-Top" or "_Garr_WoodFrameTile-Bottom")
            t:SetHorizTile(true)
        end
        local shade = holder:CreateTexture(nil, "BACKGROUND", nil, 5)
        shade:SetAllPoints()
        shade:SetTexture(MC.Tex("vignette"))
        shade:SetAlpha(0.6)
    end
    return holder
end

-- A parchment page stretched over `parent`.
function Kit.Parchment(parent, atlas)
    local t = parent:CreateTexture(nil, "BACKGROUND", nil, 1)
    t:SetAllPoints()
    Kit.Atlas(t, atlas or "questbg-parchment", MC.Tex("poster"))
    return t
end

-- Title on a parchment ribbon.
function Kit.Plaque(parent, w, key, size)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(w, w * 84 / 281)
    local bg = f:CreateTexture(nil, "ARTWORK")
    bg:SetAllPoints()
    Kit.Atlas(bg, "ui-frame-neutral-ribbon", MC.Tex("ribbon"))
    f.text = Kit.Ink(f, size or 16, INK)
    f.text:SetPoint("CENTER", 0, 2)
    f.text:SetWidth(w * 0.7)
    f.text:SetWordWrap(false)
    if key then Widgets.OnRefresh(function() f.text:SetText(L[key]) end) end
    return f
end

-- A plank-coloured plate for names (the garrison's reward banner).
function Kit.Banner(parent, w, h, size)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(w, h)
    local bg = f:CreateTexture(nil, "ARTWORK")
    bg:SetAllPoints()
    Kit.Atlas(bg, "GarrMission_RewardsBanner", MC.Tex("plate"))
    f.text = Kit.Ink(f, size or 11, INK)
    f.text:SetPoint("CENTER", 0, 1)
    f.text:SetWidth(w * 0.78)
    f.text:SetWordWrap(false)
    return f
end

-- Buttons ------------------------------------------------------------------------------------------

-- Parchment button with gold rim and metal caps; grows on hover, sinks on press.
function Kit.Button(parent, w, h, key, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w, h)
    b.bg = b:CreateTexture(nil, "ARTWORK")
    b.bg:SetAllPoints()
    b.bg:SetTexture(MC.Tex("button"))
    b.glowTex = b:CreateTexture(nil, "OVERLAY")
    b.glowTex:SetPoint("TOPLEFT", 8, -6)
    b.glowTex:SetPoint("BOTTOMRIGHT", -8, 6)
    b.glowTex:SetColorTexture(1, 0.9, 0.6, 0.25)
    b.glowTex:SetBlendMode("ADD")
    b.glowTex:SetAlpha(0)
    b.label = Kit.Ink(b, math.min(14, h * 0.42), INK)
    b.label:SetPoint("CENTER", 0, 1)
    function b:SetText(text) self.label:SetText(text) end
    if key then Widgets.OnRefresh(function() b.label:SetText(L[key]) end) end
    b:HookScript("OnEnable", function() b.bg:SetDesaturated(false); b.label:SetAlpha(1) end)
    b:HookScript("OnDisable", function() b.bg:SetDesaturated(true); b.label:SetAlpha(0.5) end)
    b:SetMotionScriptsWhileDisabled(true)
    b:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
        if onClick then onClick(b) end
    end)
    Kit.Hover(b, { grow = 1.05, sound = false })
    return b
end

-- The big round button ("Choose", "Play", "Fight!"): a turning blue swirl in a metal ring.
function Kit.BigButton(parent, size, key, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size, size)
    b.glowTex = b:CreateTexture(nil, "BACKGROUND")
    b.glowTex:SetPoint("CENTER")
    b.glowTex:SetSize(size * 1.3, size * 1.3)
    Kit.Atlas(b.glowTex, "charactercreate-ring-select", MC.Tex("node_glow"))
    b.glowTex:SetVertexColor(0.4, 0.75, 1)
    b.glowTex:SetBlendMode("ADD")
    b.swirl = b:CreateTexture(nil, "ARTWORK")
    b.swirl:SetPoint("CENTER")
    b.swirl:SetSize(size * 0.86, size * 0.86)
    b.swirl:SetTexture(MC.Tex("swirl"))
    b.ring = b:CreateTexture(nil, "OVERLAY")
    b.ring:SetAllPoints()
    Kit.Atlas(b.ring, "charactercreate-ring-metaldark", MC.Tex("node_ring"))
    b.label = Kit.Ink(b, math.floor(size * 0.2), { 1, 1, 1 }, "THICKOUTLINE")
    b.label:SetPoint("CENTER")
    if key then Widgets.OnRefresh(function() b.label:SetText(L[key]) end) end
    function b:SetText(text) self.label:SetText(text) end
    local turn = 0
    b:SetScript("OnUpdate", function(self, dt)
        turn = (turn + dt * (self:IsEnabled() and 0.8 or 0.15)) % (math.pi * 2)
        self.swirl:SetRotation(-turn)
    end)
    b:HookScript("OnEnable", function()
        b.swirl:SetDesaturated(false)
        b.label:SetAlpha(1)
        Kit.SetPulse(b, 0.6)
    end)
    b:HookScript("OnDisable", function()
        b.swirl:SetDesaturated(true)
        b.label:SetAlpha(0.45)
        Kit.SetPulse(b, nil)
    end)
    b:SetMotionScriptsWhileDisabled(true)
    b:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_QUEST_LIST_OPEN)
        if onClick then onClick(b) end
    end)
    Kit.Hover(b, { grow = 1.08, sound = false })
    return b
end

-- The golden page arrows.
function Kit.Arrow(parent, dir, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(44, 44)
    local t = b:CreateTexture(nil, "ARTWORK")
    t:SetAllPoints()
    Kit.Atlas(t, dir > 0 and "charactercreate-customize-nextbutton" or "charactercreate-customize-backbutton",
        "Interface\\Buttons\\UI-SpellbookIcon-" .. (dir > 0 and "Next" or "Prev") .. "Page-Up")
    b.glowTex = b:CreateTexture(nil, "OVERLAY")
    b.glowTex:SetAllPoints()
    Kit.Atlas(b.glowTex, dir > 0 and "charactercreate-customize-nextbutton" or "charactercreate-customize-backbutton")
    b.glowTex:SetBlendMode("ADD")
    b.glowTex:SetAlpha(0)
    b:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
        onClick(dir)
    end)
    Kit.Hover(b, { grow = 1.12, sound = false })
    return b
end

-- A round icon in a metal ring with a golden hover ring.
function Kit.Medallion(parent, size, dark)
    local f = CreateFrame("Button", nil, parent)
    f:SetSize(size, size)
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetPoint("CENTER")
    f.icon:SetSize(size * 0.74, size * 0.74)
    local mask = f:CreateMaskTexture()
    mask:SetTexture(MC.Tex("circle_mask"), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(f.icon)
    f.icon:AddMaskTexture(mask)
    f.ring = f:CreateTexture(nil, "OVERLAY")
    f.ring:SetAllPoints()
    Kit.Atlas(f.ring, dark and "charactercreate-ring-metaldark" or "charactercreate-ring-metallight", MC.Tex("node_ring"))
    f.glowTex = f:CreateTexture(nil, "OVERLAY", nil, 2)
    f.glowTex:SetPoint("CENTER")
    f.glowTex:SetSize(size * 1.12, size * 1.12)
    Kit.Atlas(f.glowTex, "charactercreate-ring-select", MC.Tex("node_glow"))
    f.glowTex:SetBlendMode("ADD")
    f.glowTex:SetAlpha(0)
    return f
end

-- Glows and portraits ------------------------------------------------------------------------------

-- A soft light that follows the outline of a card or token (generated with GLOW_PAD pixels of room
-- round a `texW` wide shape). Hidden until hover or selection lights it.
local GLOW_PAD = 32

function Kit.Halo(f, name, texW, w)
    local t = f:CreateTexture(nil, "BACKGROUND", nil, -8)
    local pad = GLOW_PAD * (w or f:GetWidth()) / texW
    t:SetPoint("TOPLEFT", -pad, pad)
    t:SetPoint("BOTTOMRIGHT", pad, -pad)
    t:SetTexture(MC.Tex(name))
    t:SetBlendMode("ADD")
    t:SetVertexColor(1, 0.8, 0.35)
    t:SetAlpha(0)
    return t
end

-- A creature's painted portrait (the client renders it from the display ID, like the
-- dungeon journal does) inside an oval of w x h. Clients without that function show the model.
local HAS_PORTRAITS = SetPortraitTextureFromCreatureDisplayID ~= nil
Kit.HAS_PORTRAITS = HAS_PORTRAITS

function Kit.Portrait(parent, w, h)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(w, h)
    local mask = f:CreateMaskTexture()
    mask:SetTexture(MC.Tex("disc_mask"), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints()
    f.back = f:CreateTexture(nil, "BACKGROUND", nil, 1)
    f.back:SetAllPoints()
    f.back:SetTexture(MC.Tex("otoken_back"))
    f.back:SetTexCoord(22 / 192, 170 / 192, 10 / 224, 190 / 224)
    f.back:AddMaskTexture(mask)
    f.tex = f:CreateTexture(nil, "ARTWORK")
    -- Portraits are square; the oval shows their middle.
    local side = math.max(w, h)
    f.tex:SetSize(side, side)
    f.tex:SetPoint("CENTER")
    f.tex:AddMaskTexture(mask)
    if not HAS_PORTRAITS then
        f.model = MC.Model(f, 0.62)
        f.model:SetAllPoints()
    end
    function f:SetDisplay(display)
        if rawget(self, "model") then
            self.model:SetDisplay(display, 0)
        elseif display and display ~= 0 then
            SetPortraitTextureFromCreatureDisplayID(self.tex, display)
        else
            self.tex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        end
    end
    function f:SetDimmed(dim, alpha)
        self.tex:SetDesaturated(dim)
        self.tex:SetAlpha(alpha or 1)
        if rawget(self, "model") then self.model:SetAlpha(alpha or 1) end
    end
    return f
end

-- The mark on finished stops and zones.
function Kit.Check(parent, size)
    local t = parent:CreateTexture(nil, "OVERLAY", nil, 6)
    t:SetSize(size, size)
    Kit.Atlas(t, "adventures-checkmark", "Interface\\RaidFrame\\ReadyCheck-Ready")
    return t
end

-- A bounty coin: a picture in a gold, silver or bronze ring.
local COIN_RINGS = {
    gold = { atlas = "hud-PlayerFrame-portraitring-large" },
    silver = { atlas = "hud-PlayerFrame-portraitring-large", desat = true },
    bronze = { atlas = "legacy-tree-frame-ring-big-c60" },
}

function Kit.Coin(parent, size)
    local f = CreateFrame("Button", nil, parent)
    f:SetSize(size, size)
    f.glowTex = f:CreateTexture(nil, "BACKGROUND")
    f.glowTex:SetPoint("CENTER")
    f.glowTex:SetSize(size * 1.5, size * 1.5)
    Kit.Atlas(f.glowTex, "charactercreate-ring-select", MC.Tex("node_glow"))
    f.glowTex:SetBlendMode("ADD")
    f.glowTex:SetAlpha(0)
    local mask = f:CreateMaskTexture()
    mask:SetTexture(MC.Tex("disc_mask"), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetPoint("CENTER")
    mask:SetSize(size * 0.82, size * 0.82)
    f.back = f:CreateTexture(nil, "BORDER")
    f.back:SetAllPoints(mask)
    f.back:SetColorTexture(0.1, 0.08, 0.06, 1)
    f.back:AddMaskTexture(mask)
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetAllPoints(mask)
    f.icon:AddMaskTexture(mask)
    f.rim = f:CreateTexture(nil, "OVERLAY")
    f.rim:SetAllPoints()
    f.check = Kit.Check(f, size * 0.5)
    f.check:SetPoint("CENTER", f, "BOTTOMRIGHT", -size * 0.16, size * 0.16)
    f.check:Hide()
    function f:SetMetal(kind)
        local ring = COIN_RINGS[kind] or COIN_RINGS.bronze
        Kit.Atlas(self.rim, ring.atlas, MC.Tex("node_ring"))
        self.rim:SetDesaturated(ring.desat or false)
        local light = ring.desat and 1.15 or 1
        self.rim:SetVertexColor(light, light, light)
    end
    -- A portrait of the creature instead of an icon (bosses).
    function f:SetCreature(display)
        if HAS_PORTRAITS and display and display ~= 0 then
            self.icon:SetTexCoord(0, 1, 0, 1)
            SetPortraitTextureFromCreatureDisplayID(self.icon, display)
            return true
        end
        return false
    end
    function f:SetIcon(icon)
        self.icon:SetTexture(icon)
        self.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    end
    f:SetMetal("gold")
    return f
end

-- The mercenary coin of the original (from the client's Hearthsteel coins).
function Kit.CoinIcon(parent, size)
    local t = parent:CreateTexture(nil, "OVERLAY")
    t:SetSize(size, size)
    Kit.Atlas(t, "hearthsteel-icon-single", "Interface\\Icons\\INV_Misc_Coin_02")
    return t
end

-- Cards --------------------------------------------------------------------------------------------

Kit.CARD_W, Kit.CARD_H = 140, 192
local CARD_SCALE = Kit.CARD_W / 256

-- A mercenary card of the collection: portrait in the oval, name banner, level, experience,
-- attack and health.
function Kit.MercCard(parent)
    local c = CreateFrame("Button", nil, parent)
    c:SetSize(Kit.CARD_W, Kit.CARD_H)
    c.glowTex = Kit.Halo(c, "glow_card", 256, Kit.CARD_W)
    local ox, oy, rx, ry = 128 * CARD_SCALE, 122 * CARD_SCALE, 82 * CARD_SCALE, 102 * CARD_SCALE
    c.portrait = Kit.Portrait(c, rx * 2 + 2, ry * 2 + 2)
    c.portrait:SetPoint("CENTER", c, "TOPLEFT", ox, -oy)
    local top = CreateFrame("Frame", nil, c)
    top:SetAllPoints()
    top:SetFrameLevel(c.portrait:GetFrameLevel() + 3)
    c.top = top
    c.frame = top:CreateTexture(nil, "ARTWORK")
    c.frame:SetAllPoints()
    c.banner = Kit.Banner(top, 136, 32, 11)
    c.banner:SetPoint("CENTER", top, "TOPLEFT", ox, -(oy + ry - 2))
    c.level = MC.Badge(top, "level", 26, 11)
    c.level:SetPoint("CENTER", top, "TOPLEFT", ox, -(oy + ry + 24))
    local bar = CreateFrame("StatusBar", nil, top)
    bar:SetSize(62, 6)
    bar:SetPoint("CENTER", top, "TOPLEFT", ox, -(oy + ry + 43))
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(0.25, 0.55, 1)
    local barBg = bar:CreateTexture(nil, "BACKGROUND")
    barBg:SetAllPoints()
    barBg:SetColorTexture(0, 0, 0, 0.7)
    c.bar = bar
    c.attack = CreateFrame("Frame", nil, top)
    c.attack:SetSize(46, 46)
    c.attack:SetPoint("CENTER", top, "BOTTOMLEFT", 22, 26)
    c.attack.tex = c.attack:CreateTexture(nil, "ARTWORK")
    c.attack.tex:SetAllPoints()
    c.attack.text = Kit.Ink(c.attack, 20, { 1, 1, 1 }, "THICKOUTLINE")
    c.attack.text:SetPoint("CENTER", 0, 3)
    c.health = CreateFrame("Frame", nil, top)
    c.health:SetSize(46, 46)
    c.health:SetPoint("CENTER", top, "BOTTOMRIGHT", -22, 26)
    c.health.tex = c.health:CreateTexture(nil, "ARTWORK")
    c.health.tex:SetAllPoints()
    c.health.text = Kit.Ink(c.health, 20, { 1, 1, 1 }, "THICKOUTLINE")
    c.health.text:SetPoint("CENTER", 0, -3)
    -- In the party: a check on the card's corner.
    c.member = Kit.Check(top, 30)
    c.member:SetPoint("CENTER", top, "TOPRIGHT", -16, -16)
    c.member:Hide()
    c.coin = Kit.CoinIcon(top, 20)
    c.coin:SetPoint("TOPRIGHT", top, "BOTTOM", -2, -1)
    c.coins = Kit.Ink(top, 13, { 0.35, 0.24, 0.12 })
    c.coins:SetPoint("LEFT", c.coin, "RIGHT", 3, 0)

    -- unit: kind, id, role, level, atk, hp; extra: xp share, coins, locked, member
    function c:SetMerc(u, extra)
        extra = extra or {}
        self.merc = u.id
        self.frame:SetTexture(MC.Tex("card_" .. u.role))
        self.attack.tex:SetTexture(MC.Tex("hs_attack_" .. u.role))
        self.health.tex:SetTexture(MC.Tex("hs_health_" .. u.role))
        self.attack.text:SetText(u.atk)
        self.health.text:SetText(u.hp)
        self.level.text:SetText(u.level)
        self.banner.text:SetText(Describe.UnitName(u.kind, u.id))
        self.portrait:SetDisplay(MC.DisplayFor(u.kind, u.id))
        self.bar:SetShown(extra.xp ~= nil)
        if extra.xp then
            self.bar:SetMinMaxValues(0, 1)
            self.bar:SetValue(extra.xp)
        end
        self.coin:SetShown(extra.coins ~= nil)
        self.coins:SetText(extra.coins or "")
        self.member:SetShown(extra.member or false)
        local locked = extra.locked
        for _, tex in ipairs({ self.frame, self.attack.tex, self.health.tex }) do tex:SetDesaturated(locked) end
        self.frame:SetVertexColor(locked and 0.75 or 1, locked and 0.75 or 1, locked and 0.75 or 1)
        self.portrait:SetDimmed(locked, locked and 0.65 or 1)
    end
    Kit.Hover(c, { grow = 1.04, lift = 8 })
    return c
end

-- An ability card: speed in the top left corner, the icon in a gold ring, the name on a banner
-- and the text on parchment.
Kit.ACARD_W, Kit.ACARD_H = 124, 170
local A_SCALE = Kit.ACARD_W / 256

function Kit.AbilityCard(parent)
    local c = CreateFrame("Button", nil, parent)
    c:SetSize(Kit.ACARD_W, Kit.ACARD_H)
    c.glowTex = Kit.Halo(c, "glow_acard", 256, Kit.ACARD_W)
    local cx, cy, r = 128 * A_SCALE, 104 * A_SCALE, 66 * A_SCALE
    c.icon = c:CreateTexture(nil, "BACKGROUND", nil, 2)
    c.icon:SetSize(r * 2 + 2, r * 2 + 2)
    c.icon:SetPoint("CENTER", c, "TOPLEFT", cx, -cy)
    c.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    c.frame = c:CreateTexture(nil, "ARTWORK")
    c.frame:SetAllPoints()
    c.speed = MC.Badge(c, "speed", 34, 15)
    c.speed:SetPoint("CENTER", c, "TOPLEFT", 17, -17)
    c.speed.text:SetTextColor(0.1, 0.1, 0.15)
    c.speed.text:SetShadowOffset(0, 0)
    c.banner = Kit.Banner(c, 124, 28, 10)
    c.banner:SetPoint("CENTER", c, "TOPLEFT", cx, -(cy + r + 10))
    c.desc = Kit.Ink(c, 9, INK)
    c.desc:SetPoint("TOP", c, "TOPLEFT", cx, -(cy + r + 26))
    c.desc:SetWidth(Kit.ACARD_W - 30)
    c.desc:SetHeight(318 * A_SCALE - (cy + r + 26))
    c.desc:SetJustifyV("TOP")
    c.footer = Kit.Ink(c, 9, { 1, 1, 1 }, "OUTLINE")
    c.footer:SetPoint("BOTTOM", 0, 6)
    c.rank = Kit.Ink(c, 12, { 1, 0.82, 0 }, "OUTLINE")
    c.rank:SetPoint("CENTER", c, "TOPRIGHT", -16, -16)
    c.shade = c:CreateTexture(nil, "OVERLAY", nil, 3)
    c.shade:SetPoint("TOPLEFT", 7, -7)
    c.shade:SetPoint("BOTTOMRIGHT", -7, 7)
    c.shade:SetColorTexture(0, 0, 0, 0.5)
    c.shade:Hide()
    c.cooldown = Kit.Ink(c, 30, { 1, 1, 1 }, "THICKOUTLINE")
    c.cooldown:SetPoint("CENTER", c, "TOPLEFT", cx, -cy)
    -- Not yet learned: a lock over the icon and the level below it.
    c.lock = c:CreateTexture(nil, "OVERLAY", nil, 5)
    c.lock:SetSize(34, 34)
    c.lock:SetPoint("CENTER", c, "TOPLEFT", cx, -cy)
    c.lock:SetTexture("Interface\\PetBattles\\PetBattle-LockIcon")
    c.lock:Hide()
    c.lockText = Kit.Ink(c, 11, { 1, 0.9, 0.6 }, "OUTLINE")
    c.lockText:SetPoint("TOP", c, "TOPLEFT", cx, -(cy + r + 34))
    c.lockText:SetWidth(Kit.ACARD_W - 24)

    local ROMAN = { "I", "II", "III" }
    function c:SetAbility(id, unit, slot, cdLeft, role)
        local def = MC.Abilities[id]
        self.abilityId, self.slot = id, slot
        self.frame:SetTexture(MC.Tex("acard_" .. (role or (unit and unit.role) or "neutral")))
        self.icon:SetTexture(def.icon)
        self.banner.text:SetText(Describe.AbilityName(id))
        self.desc:SetText(Describe.Ability(id, unit, slot))
        local _, speed, cd = Describe.AbilityStats(id, unit, slot)
        self.speed.text:SetText(speed)
        local rank = unit and unit.abilities and unit.abilities[slot] and unit.abilities[slot].rank or 1
        self.rank:SetText(ROMAN[rank] or "")
        self.footer:SetText(cd > 0 and L.MC_COOLDOWN:format(cd) or L["MC_SCHOOL_" .. (def.school or "physical")])
        self.waiting = cdLeft and cdLeft > 0
        self.cooldown:SetText(self.waiting and cdLeft or "")
        self:SetLocked(nil)
    end
    -- `level`: the level that teaches the ability, nil when it is known.
    function c:SetLocked(level)
        local locked = level ~= nil
        self.lock:SetShown(locked)
        self.lockText:SetText(locked and L.MC_UNLOCKS_AT:format(level) or "")
        self.desc:SetShown(not locked)
        self.icon:SetDesaturated(locked or self.waiting or false)
        self.frame:SetDesaturated(locked)
        self.shade:SetShown(locked or self.waiting or false)
    end
    Kit.Hover(c, { grow = 1.05, lift = 6 })
    return c
end
