-- Building blocks of the Mercenaries views: the portrait token of a unit and the ability card.

local _, ns = ...
local MC = ns.Mercenaries
local Combat, Describe = MC.Combat, MC.Describe
local Widgets, Media, L = ns.Widgets, ns.Media, ns.L

-- The oval token texture is 192x224; on screen it is scaled to TOKEN_W x TOKEN_H.
MC.TOKEN_W, MC.TOKEN_H = 110, 128
local TW, TH = MC.TOKEN_W, MC.TOKEN_H
local SCALE = TW / 192
-- The portrait window inside the token texture (cx 96, cy 100, rx 74, ry 90).
local OVAL_X, OVAL_Y, OVAL_W, OVAL_H = 22 * SCALE, 10 * SCALE, 148 * SCALE, 180 * SCALE

local function Badge(parent, kind, size, fontSize)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(size, size)
    f.tex = f:CreateTexture(nil, "ARTWORK")
    f.tex:SetAllPoints()
    f.tex:SetTexture(MC.Tex("badge_" .. kind))
    f.text = f:CreateFontString(nil, "OVERLAY")
    f.text:SetFont(Media.FontFile(), fontSize, "OUTLINE")
    f.text:SetPoint("CENTER", 0, kind == "health" and -1 or 0)
    return f
end
MC.Badge = Badge

local function DisplayFor(kind, id)
    local def = kind == "merc" and MC.Mercs[id] or MC.Enemies[id]
    return def and def.display or 0
end
MC.DisplayFor = DisplayFor

-- A model that keeps its display across hides (the client resets models when they are hidden).
function MC.Model(parent, zoom)
    local m = CreateFrame("PlayerModel", nil, parent)
    m.zoom, m.display, m.facing = zoom, false, false
    function m:SetDisplay(display, facing)
        self.display, self.facing = display, facing
        self:SetShown(display ~= nil and display ~= 0)
        self:Apply()
    end
    function m:Apply()
        if not self.display or self.display == 0 then return end
        pcall(self.ClearModel, self)
        pcall(self.SetDisplayInfo, self, self.display)
        if self.zoom then pcall(self.SetPortraitZoom, self, self.zoom) end
        if self.facing then pcall(self.SetFacing, self, self.facing) end
    end
    m:SetScript("OnShow", function(self) self:Apply() end)
    return m
end

-- Map art ----------------------------------------------------------------------------------------

-- A window onto a map's client art (MapArt.lua). `SetMap` shows the part u0..u1, v0..v1 of the
-- map (0..1 across its visible 1002x668), stretched to the canvas; `Point` turns map coordinates
-- into canvas offsets for pins.
function MC.CreateMapCanvas(parent, w, h)
    local clip = CreateFrame("Frame", nil, parent)
    clip:SetSize(w, h)
    clip:SetClipsChildren(true)
    local inner = CreateFrame("Frame", nil, clip)
    inner:SetAllPoints()
    clip.tiles = {}
    for i = 1, 12 do
        clip.tiles[i] = inner:CreateTexture(nil, "BACKGROUND")
    end
    clip.fallback = inner:CreateTexture(nil, "BACKGROUND", nil, -1)
    clip.fallback:SetAllPoints()
    clip.fallback:SetTexture(MC.Tex("map"))
    clip.fallback:SetTexCoord(0, 840 / 1024, 0, 560 / 1024)
    clip.view = { 0, 1, 0, 1 }

    function clip:SetMap(key, u0, u1, v0, v1)
        local art = MC.MapArt[key]
        self.view = { u0 or 0, u1 or 1, v0 or 0, v1 or 1 }
        self.fallback:SetShown(art == nil)
        for i, tex in ipairs(self.tiles) do
            local file = art and art.files[i]
            tex:SetShown(file ~= nil)
            if file then
                local u0, u1, v0, v1 = unpack(self.view)
                local sx, sy = w / ((u1 - u0) * art.w), h / ((v1 - v0) * art.h)
                local row, col = math.floor((i - 1) / art.cols), (i - 1) % art.cols
                tex:SetTexture(file)
                tex:SetSize(art.tw * sx, art.th * sy)
                tex:ClearAllPoints()
                tex:SetPoint("TOPLEFT", inner, "TOPLEFT", (col * art.tw - u0 * art.w) * sx, -(row * art.th - v0 * art.h) * sy)
            end
        end
    end

    function clip:Point(u, v)
        local u0, u1, v0, v1 = unpack(self.view)
        return (u - u0) / (u1 - u0) * w, (v - v0) / (v1 - v0) * h
    end

    function clip:SetTint(r, g, b)
        for _, tex in ipairs(self.tiles) do tex:SetVertexColor(r, g, b) end
        self.fallback:SetVertexColor(r, g, b)
    end
    return clip
end

-- The part of a zone's own map that frames it best for a scene of the given aspect (w / h).
function MC.ZoneView(aspect)
    local mapAspect = 1002 / 668
    if aspect >= mapAspect then
        local v = mapAspect / aspect
        return 0, 1, 0.5 - v / 2, 0.5 + v / 2
    end
    local u = aspect / mapAspect
    return 0.5 - u / 2, 0.5 + u / 2, 0, 1
end

-- A scene background: the zone's map art, dimmed, with dark edges.
function MC.CreateScene(parent, w, h)
    local canvas = MC.CreateMapCanvas(parent, w, h)
    local shade = CreateFrame("Frame", nil, canvas)
    shade:SetAllPoints()
    shade:SetFrameLevel(canvas:GetFrameLevel() + 2)
    local vignette = shade:CreateTexture(nil, "ARTWORK")
    vignette:SetAllPoints()
    vignette:SetTexture(MC.Tex("vignette"))
    function canvas:ShowZone(key, dim)
        local u0, u1, v0, v1 = MC.ZoneView(w / h)
        self:SetMap(key, u0, u1, v0, v1)
        dim = dim or 0.55
        self:SetTint(dim, dim * 0.95, dim * 0.88)
    end
    return canvas
end

-- Gold-rimmed dark plate with a line of text, drawn above models.
function MC.CreatePlate(parent, w, h, size)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(w, h)
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    f.bg:SetTexture(MC.Tex("plate"))
    f.text = Widgets.Text(f, size or 12, "white")
    f.text:SetPoint("CENTER", 0, 1)
    f.text:SetWidth(w - 12)
    f.text:SetWordWrap(false)
    return f
end

-- Red title ribbon with a gold heading.
function MC.CreateRibbon(parent, w, key, size)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(w, w * 96 / 512)
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    f.bg:SetTexture(MC.Tex("ribbon"))
    f.text = key and Widgets.LocalizedText(f, size or 18, "gold", key) or Widgets.Text(f, size or 18, "gold")
    f.text:SetPoint("CENTER", 0, w * 6 / 512)
    return f
end

-- Token -------------------------------------------------------------------------------------------

-- Methods mixed into every token frame.
local Token = {}

function MC.CreateToken(parent)
    local f = CreateFrame("Button", nil, parent)
    f:SetSize(TW, TH)
    f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    for k, fn in pairs(Token) do f[k] = fn end
    -- Position and animation state, read before the first layout.
    f.x, f.y, f.tx, f.ty = false, false, false, false
    f.shake, f.nudge, f.fadeIn = 0, 0, false
    f.uid, f.unitKey, f.data = false, false, false

    f.glow = f:CreateTexture(nil, "BACKGROUND", nil, 0)
    f.glow:SetTexture(MC.Tex("otoken_glow"))
    f.glow:SetPoint("CENTER")
    f.glow:SetSize(TW * 1.25, TH * 1.25)
    f.glow:SetBlendMode("ADD")
    f.glow:Hide()
    f.taunt = f:CreateTexture(nil, "BACKGROUND", nil, 1)
    f.taunt:SetTexture(MC.Tex("taunt"))
    f.taunt:SetPoint("CENTER", 0, -2)
    f.taunt:SetSize(TW * 1.2, TH * 1.18)
    f.taunt:Hide()
    f.back = f:CreateTexture(nil, "BACKGROUND", nil, 2)
    f.back:SetTexture(MC.Tex("otoken_back"))
    f.back:SetAllPoints()

    f.model = MC.Model(f, 0.62)
    f.model:SetPoint("TOPLEFT", OVAL_X, -OVAL_Y)
    f.model:SetSize(OVAL_W, OVAL_H)
    f.missing = f:CreateTexture(nil, "BACKGROUND", nil, 3)
    f.missing:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    f.missing:SetSize(OVAL_W * 0.6, OVAL_W * 0.6)
    f.missing:SetPoint("CENTER", 0, TH / 2 - OVAL_Y - OVAL_H / 2)
    f.missing:Hide()

    -- Frame, badges and status icons sit on a layer above the model.
    local top = CreateFrame("Frame", nil, f)
    top:SetAllPoints()
    top:SetFrameLevel(f.model:GetFrameLevel() + 2)
    f.top = top
    f.frame = top:CreateTexture(nil, "ARTWORK", nil, 0)
    f.frame:SetAllPoints()
    f.divine = top:CreateTexture(nil, "ARTWORK", nil, 1)
    f.divine:SetTexture(MC.Tex("divine"))
    f.divine:SetAllPoints()
    f.divine:SetBlendMode("ADD")
    f.divine:Hide()
    f.select = top:CreateTexture(nil, "OVERLAY", nil, 0)
    f.select:SetTexture(MC.Tex("otoken_glow"))
    f.select:SetPoint("CENTER")
    f.select:SetSize(TW * 1.15, TH * 1.15)
    f.select:SetBlendMode("ADD")
    f.select:SetVertexColor(0.4, 1, 0.4)
    f.select:Hide()

    f.attack = Badge(top, "attack", 40, 18)
    f.attack:SetPoint("CENTER", top, "BOTTOMLEFT", 16, 22)
    f.health = Badge(top, "health", 40, 18)
    f.health:SetPoint("CENTER", top, "BOTTOMRIGHT", -16, 22)
    f.attack.text:SetPoint("CENTER", 0, 3)
    f.health.text:SetPoint("CENTER", 0, -3)
    f.level = Badge(top, "level", 24, 10)
    f.level:SetPoint("CENTER", top, "TOP", 0, -4)
    f.absorb = top:CreateFontString(nil, "OVERLAY")
    f.absorb:SetFont(Media.FontFile(), 11, "OUTLINE")
    f.absorb:SetTextColor(0.8, 0.9, 1)
    f.absorb:SetPoint("BOTTOM", f.health, "TOP", 0, -2)
    f.name = Widgets.Text(top, 11, "white")
    f.name:SetPoint("TOP", top, "BOTTOM", 0, -2)
    f.name:SetWidth(TW + 30)
    f.name:SetWordWrap(false)

    -- Status icons in a row over the frame's lower edge.
    f.icons = {}
    for i = 1, 4 do
        local icon = top:CreateTexture(nil, "OVERLAY", nil, 2)
        icon:SetSize(16, 16)
        icon:SetPoint("BOTTOM", top, "BOTTOM", (i - 2.5) * 17, 4)
        icon:Hide()
        f.icons[i] = icon
    end

    -- The chosen ability over the token: its icon and speed.
    local bubble = CreateFrame("Frame", nil, f)
    bubble:SetSize(34, 34)
    bubble:SetPoint("BOTTOM", top, "TOP", 0, 4)
    bubble:SetFrameLevel(top:GetFrameLevel() + 2)
    bubble.icon = bubble:CreateTexture(nil, "ARTWORK")
    bubble.icon:SetAllPoints()
    local mask = bubble:CreateMaskTexture()
    mask:SetTexture(MC.Tex("circle_mask"), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints()
    bubble.icon:AddMaskTexture(mask)
    bubble.ring = bubble:CreateTexture(nil, "OVERLAY")
    bubble.ring:SetTexture(MC.Tex("node_ring"))
    bubble.ring:SetPoint("CENTER")
    bubble.ring:SetSize(40, 40)
    bubble.speed = Badge(bubble, "speed", 22, 11)
    bubble.speed:SetPoint("CENTER", bubble, "BOTTOMRIGHT", -2, 4)
    bubble.speed.text:SetTextColor(0.1, 0.1, 0.15)
    bubble.speed.text:SetShadowOffset(0, 0)
    bubble.order = bubble:CreateFontString(nil, "OVERLAY")
    bubble.order:SetFont(Media.FontFile(), 12, "OUTLINE")
    bubble.order:SetPoint("CENTER", bubble, "TOPLEFT", 2, -2)
    bubble:Hide()
    f.bubble = bubble
    return f
end

-- data: { kind, id, role, level, atk, hp, maxHp, shield, absorb, taunt, stealth, stun, dots, buffs, dead }
function Token:SetData(data, reference)
    local first = self.unitKey ~= (data.kind .. data.id)
    self.unitKey = data.kind .. data.id
    self.data = data
    local boss = data.kind == "boss"
    local role = data.role or "neutral"
    self.frame:SetTexture(MC.Tex("otoken_" .. role))
    self.frame:SetVertexColor(boss and 1 or 1, boss and 0.86 or 1, boss and 0.45 or 1)
    self.attack.tex:SetTexture(MC.Tex("hs_attack_" .. role))
    self.health.tex:SetTexture(MC.Tex("hs_health_" .. role))
    if first then
        local display = DisplayFor(data.kind, data.id)
        self.missing:SetShown(display == 0)
        self.model:SetShown(display ~= 0)
        self.model:SetDisplay(display, data.side == "enemy" and -0.25 or 0.25)
        self.name:SetText(Describe.UnitName(data.kind, data.id))
    end
    self:SetStats(data, reference)
end

function Token:SetStats(data, reference)
    self.attack.text:SetText(data.atk or 0)
    local atkBuffed = data.atkBase and data.atk > data.atkBase
    self.attack.text:SetTextColor(atkBuffed and 0.4 or 1, 1, atkBuffed and 0.4 or 1)
    self.health.text:SetText(math.max(0, data.hp or 0))
    local hurt = data.maxHp and data.hp < data.maxHp
    self.health.text:SetTextColor(1, hurt and 0.35 or 1, hurt and 0.35 or 1)
    self.level.text:SetText(MC.LevelText(data.level, reference))
    if reference then
        self.level.text:SetTextColor(MC.ConColor(data.level, reference))
    else
        self.level.text:SetTextColor(1, 0.85, 0.4)
    end
    self.divine:SetShown(data.shield and true or false)
    self.taunt:SetShown(data.taunt and true or false)
    self.absorb:SetText((data.absorb or 0) > 0 and ("+" .. data.absorb) or "")
    self:SetAlpha(data.dead and 0.35 or (data.stealth and 0.55 or 1))
    self.model:SetAlpha(data.dead and 0.4 or 1)
    local icons = {}
    if data.stun then icons[#icons + 1] = "Interface\\Icons\\Spell_Frost_Stun" end
    if data.dot then icons[#icons + 1] = "Interface\\Icons\\Spell_Shadow_ShadowWordPain" end
    if data.hot then icons[#icons + 1] = "Interface\\Icons\\Spell_Nature_Rejuvenation" end
    if data.debuff then icons[#icons + 1] = "Interface\\Icons\\Spell_Shadow_CurseOfTounges" end
    if data.buff then icons[#icons + 1] = "Interface\\Icons\\Spell_Holy_WordFortitude" end
    for i, icon in ipairs(self.icons) do
        icon:SetShown(icons[i] ~= nil)
        if icons[i] then icon:SetTexture(icons[i]) end
    end
end

-- Mercenaries not yet recruited show greyed out.
function Token:SetLocked(locked)
    for _, tex in ipairs({ self.frame, self.back, self.attack.tex, self.health.tex, self.level.tex }) do
        tex:SetDesaturated(locked)
    end
    self.model:SetAlpha(locked and 0.35 or 1)
    self.frame:SetVertexColor(locked and 0.6 or 1, locked and 0.6 or 1, locked and 0.6 or 1)
end

function Token:SetBubble(abilityId, speed, order)
    if not abilityId then
        self.bubble:Hide()
        return
    end
    self.bubble.icon:SetTexture(MC.Abilities[abilityId].icon)
    self.bubble.speed.text:SetText(speed)
    self.bubble.order:SetText(order or "")
    self.bubble:Show()
end

-- Plain table of what a token shows, read from a combat unit.
function MC.UnitView(u)
    local hasDot, hasHot, debuff, buff = false, false, false, false
    for _, d in ipairs(u.dots) do
        if d.heal then hasHot = true else hasDot = true end
    end
    for _, b in ipairs(u.buffs) do
        if Combat.IsDebuff(b) then debuff = true elseif b.k ~= "ambush" then buff = true end
    end
    local atk = Combat.Attack(u)
    return {
        side = u.side, kind = u.kind == "elite" and "enemy" or u.kind, id = u.id, role = u.role, level = u.level,
        atk = atk, atkBase = math.floor(u.atk + 0.5), hp = u.hp, maxHp = u.maxHp,
        shield = u.st.shield, absorb = u.st.absorb, taunt = u.st.taunt, stealth = u.st.stealth, stun = u.st.stun,
        dot = hasDot, hot = hasHot, debuff = debuff, buff = buff, dead = u.dead, elite = u.kind == "elite",
    }
end

-- Tooltip for a unit: name, role, level and every ability with its current values.
function MC.UnitTooltip(owner, u, reference)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    local name = Describe.UnitName(u.kind == "elite" and "enemy" or (u.kind == "boss" and "enemy" or u.kind), u.id)
    GameTooltip:SetText(name, 1, 0.82, 0)
    local roleColor = MC.ROLE_COLORS[u.role] or MC.ROLE_COLORS.neutral
    local levelText = L.LEVEL:format(u.level)
    if reference and u.level - reference >= 10 then levelText = L.MC_LEVEL_SKULL end
    GameTooltip:AddLine(levelText .. "  ·  " .. Describe.RoleName(u.role), roleColor[1], roleColor[2], roleColor[3])
    if u.kind == "elite" then GameTooltip:AddLine(L.MC_ELITE, 0.75, 0.5, 1) end
    for i, slot in ipairs(u.abilities) do
        local def = MC.Abilities[slot.id]
        GameTooltip:AddLine(" ")
        local stats = Describe.AbilityStats(slot.id, u, i)
        GameTooltip:AddDoubleLine(Describe.AbilityName(slot.id), stats, 1, 1, 1, 0.7, 0.7, 0.7)
        GameTooltip:AddLine(Describe.Ability(slot.id, u, i), 0.9, 0.9, 0.9, true)
        if slot.cd and slot.cd > 0 and not def.passive then
            GameTooltip:AddLine(L.MC_READY_IN:format(slot.cd), 1, 0.4, 0.3)
        end
    end
    GameTooltip:Show()
end

-- Ability card ----------------------------------------------------------------------------------------

MC.CARD_W, MC.CARD_H = 104, 142

function MC.CreateAbilityCard(parent)
    local CW, CH = MC.CARD_W, MC.CARD_H
    local s = CW / 128
    local c = CreateFrame("Button", nil, parent)
    c:SetSize(CW, CH)
    c.glow = c:CreateTexture(nil, "BACKGROUND")
    c.glow:SetTexture(MC.Tex("card_glow"))
    c.glow:SetPoint("CENTER")
    c.glow:SetSize(CW + 12, CH + 12)
    c.glow:SetBlendMode("ADD")
    c.glow:SetVertexColor(0.4, 1, 0.4)
    c.glow:Hide()
    c.bg = c:CreateTexture(nil, "ARTWORK", nil, 0)
    c.bg:SetAllPoints()
    c.bg:SetTexture(MC.Tex("card"))
    c.icon = c:CreateTexture(nil, "ARTWORK", nil, 1)
    c.icon:SetPoint("TOPLEFT", 32 * s, -16 * s)
    c.icon:SetSize(64 * s, 64 * s)
    c.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    c.name = c:CreateFontString(nil, "OVERLAY")
    c.name:SetFont(Media.FontFile(), 10, "OUTLINE")
    c.name:SetTextColor(1, 0.82, 0)
    c.name:SetPoint("TOP", 0, -87 * s)
    c.name:SetWidth(CW - 10)
    c.name:SetWordWrap(false)
    c.desc = c:CreateFontString(nil, "OVERLAY")
    c.desc:SetFont(Media.FontFile(), 8, "")
    c.desc:SetTextColor(0.95, 0.92, 0.85)
    c.desc:SetPoint("TOP", c.name, "BOTTOM", 0, -4)
    c.desc:SetWidth(CW - 14)
    c.desc:SetHeight(CH - 87 * s - 22)
    c.desc:SetJustifyV("TOP")
    c.speed = Badge(c, "speed", 28, 13)
    c.speed:SetPoint("CENTER", c, "TOPLEFT", 12, -12)
    c.speed.text:SetTextColor(0.1, 0.1, 0.15)
    c.speed.text:SetShadowOffset(0, 0)
    c.rank = c:CreateFontString(nil, "OVERLAY")
    c.rank:SetFont(Media.FontFile(), 10, "OUTLINE")
    c.rank:SetTextColor(1, 0.82, 0)
    c.rank:SetPoint("TOPRIGHT", -8, -6)
    c.shade = c:CreateTexture(nil, "OVERLAY", nil, 2)
    c.shade:SetAllPoints()
    c.shade:SetColorTexture(0, 0, 0, 0.6)
    c.shade:Hide()
    c.cooldown = c:CreateFontString(nil, "OVERLAY", nil, 3)
    c.cooldown:SetFont(Media.FontFile(), 30, "THICKOUTLINE")
    c.cooldown:SetPoint("CENTER", c.icon, "CENTER")
    c.cdLabel = c:CreateFontString(nil, "OVERLAY")
    c.cdLabel:SetFont(Media.FontFile(), 9, "OUTLINE")
    c.cdLabel:SetTextColor(0.75, 0.75, 0.75)
    c.cdLabel:SetPoint("BOTTOM", 0, 6)

    local ROMAN = { "I", "II", "III" }
    -- unit: the owner (combat unit or a spec-like table); `ready` false greys the card out.
    function c:SetAbility(id, unit, slot, cdLeft)
        local def = MC.Abilities[id]
        self.abilityId, self.slot = id, slot
        self.icon:SetTexture(def.icon)
        self.name:SetText(Describe.AbilityName(id))
        self.desc:SetText(Describe.Ability(id, unit, slot))
        local _, speed, cd = Describe.AbilityStats(id, unit, slot)
        self.speed.text:SetText(speed)
        local rank = unit and unit.abilities and unit.abilities[slot] and unit.abilities[slot].rank or 1
        self.rank:SetText(ROMAN[rank] or "")
        self.cdLabel:SetText(cd > 0 and L.MC_COOLDOWN:format(cd) or "")
        local waiting = cdLeft and cdLeft > 0
        self.shade:SetShown(waiting)
        self.cooldown:SetText(waiting and cdLeft or "")
        self.icon:SetDesaturated(waiting)
    end
    return c
end
