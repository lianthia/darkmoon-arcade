local _, ns = ...

local JU = ns.JewelsOfUldum
local Game = JU.Game
local Arcade, Widgets, Scores, Media, Achievements, L = ns.Arcade, ns.Widgets, ns.Scores, ns.Media, ns.Achievements, ns.L

local W, H = 432, 462
local CELL, SIZE = 50, Game.SIZE
local BOARD_X, BOARD_Y = 16, 14
local GEM_SIZE = 44
local HINT_DELAY = 8

-- interface/icons/inv_misc_gem_*: ruby, topaz, crystal, emerald, sapphire, amethyst, diamond.
-- One gem per hue (red, yellow, turquoise, green, blue, purple, white); orange read too close to yellow.
local GEM_ICONS = { 134129, 134136, 134088, 134105, 134132, 134075, 134095 }
local GEM_TINT = {
    { 1, 0.3, 0.3 }, { 1, 0.9, 0.3 }, { 0.3, 1, 0.95 }, { 0.3, 1, 0.4 },
    { 0.35, 0.6, 1 }, { 0.75, 0.4, 1 }, { 0.95, 0.95, 1 },
}
local PRISM_TINT = { 1, 1, 1 }

local Module = {
    id = "jewelsofuldum",
    rank = 4,
    nameKey = "JU_NAME",
    descKey = "JU_DESC",
    helpKey = "JU_HELP",
    tile = "tiles/jewelsofuldum",
    defaults = { mode = "classic", hints = true, gems = 0 },
}

Achievements.Register("jewelsofuldum", {
    { id = "ju_first", nameKey = "JU_ACH_FIRST", descKey = "JU_ACH_FIRST_DESC", icon = GEM_ICONS[4] },
    { id = "ju_cascade4", nameKey = "JU_ACH_CASCADE4", descKey = "JU_ACH_CASCADE4_DESC", icon = GEM_ICONS[2] },
    { id = "ju_power", nameKey = "JU_ACH_POWER", descKey = "JU_ACH_POWER_DESC", icon = GEM_ICONS[1] },
    { id = "ju_prism", nameKey = "JU_ACH_PRISM", descKey = "JU_ACH_PRISM_DESC", icon = Media.Tex("uldum/prism") },
    { id = "ju_level5", nameKey = "JU_ACH_LEVEL5", descKey = "JU_ACH_LEVEL5_DESC", icon = GEM_ICONS[5] },
    { id = "ju_blitz", nameKey = "JU_ACH_BLITZ", descKey = "JU_ACH_BLITZ_DESC", icon = GEM_ICONS[3] },
    { id = "ju_cascade6", nameKey = "JU_ACH_CASCADE6", descKey = "JU_ACH_CASCADE6_DESC", icon = GEM_ICONS[6] },
    { id = "ju_prism_use", nameKey = "JU_ACH_PRISM_USE", descKey = "JU_ACH_PRISM_USE_DESC", icon = Media.Tex("uldum/prism") },
    { id = "ju_double", nameKey = "JU_ACH_DOUBLE", descKey = "JU_ACH_DOUBLE_DESC", icon = Media.Tex("uldum/prism") },
    { id = "ju_level10", nameKey = "JU_ACH_LEVEL10", descKey = "JU_ACH_LEVEL10_DESC", icon = GEM_ICONS[7] },
    { id = "ju_classic", nameKey = "JU_ACH_CLASSIC", descKey = "JU_ACH_CLASSIC_DESC", icon = GEM_ICONS[1] },
    { id = "ju_blitz2", nameKey = "JU_ACH_BLITZ2", descKey = "JU_ACH_BLITZ2_DESC", icon = GEM_ICONS[2] },
    { id = "ju_gems", nameKey = "JU_ACH_GEMS", descKey = "JU_ACH_GEMS_DESC", icon = GEM_ICONS[5] },
    { id = "ju_star", nameKey = "JU_ACH_STAR", descKey = "JU_ACH_STAR_DESC", icon = GEM_ICONS[7] },
    { id = "ju_combo", nameKey = "JU_ACH_COMBO", descKey = "JU_ACH_COMBO_DESC", icon = GEM_ICONS[1] },
    { id = "ju_time", nameKey = "JU_ACH_TIME", descKey = "JU_ACH_TIME_DESC", icon = GEM_ICONS[3] },
    { id = "ju_zen", nameKey = "JU_ACH_ZEN", descKey = "JU_ACH_ZEN_DESC", icon = GEM_ICONS[4] },
    { id = "ju_flight", nameKey = "JU_ACH_FLIGHT", descKey = "JU_ACH_FLIGHT_DESC", icon = "Interface\\TaxiFrame\\UI-Taxi-Icon-Green" },
})
local GOALS = { gems = 10000, classic = 100000, blitz = 15000, blitz2 = 35000, prismUse = 10, time = 30, zen = 50000 }

local function Tex(name) return Media.Tex("uldum/" .. name) end
local function Sound(name) Media.Play(name) end

local function Settings() return Arcade.Settings(Module) end

local function ModeName(mode)
    if mode == "blitz" then return L.JU_BLITZ end
    if mode == "zen" then return L.JU_ZEN end
    return L.JU_CLASSIC
end

local function CellCenter(r, c)
    return (c - 0.5) * CELL, (r - 0.5) * CELL
end

local function Place(region, x, y)
    region:ClearAllPoints()
    region:SetPoint("CENTER", region:GetParent(), "TOPLEFT", x, -y)
end

local function ShareMessage(entry, mode)
    return L.JU_SHARE:format(ns.FormatNumber(entry.score), ModeName(mode))
end

function Module:BestScore()
    return Scores.Best(self.id, Settings().mode)
end

-- Gem visuals ----------------------------------------------------------------------

function Module:CreateVisual()
    local layer = self.gemLayer
    local v = {
        glow = layer:CreateTexture(nil, "ARTWORK", nil, 0),
        icon = layer:CreateTexture(nil, "ARTWORK", nil, 1),
    }
    v.glow:SetTexture(Media.Tex("glow"))
    v.glow:SetBlendMode("ADD")
    v.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    -- Star gems carry a turning four-pointed spark, time gems their bonus seconds.
    v.star = layer:CreateTexture(nil, "ARTWORK", nil, 2)
    v.star:SetTexture(Media.Tex("spark"))
    v.star:SetBlendMode("ADD")
    v.time = layer:CreateFontString(nil, "OVERLAY")
    v.time:SetFont(Media.FontFile(), 12, "OUTLINE")
    v.time:SetTextColor(0.6, 1, 1)
    return v
end

local function HideVisual(v)
    v.icon:Hide()
    v.glow:Hide()
    v.star:Hide()
    v.time:Hide()
    v.icon:SetRotation(0)
end

function Module:SetGem(v, gem)
    v.gem = gem
    if gem.color == Game.PRISM then
        v.icon:SetTexture(Tex("prism"))
        v.icon:SetTexCoord(0, 1, 0, 1)
    else
        v.icon:SetTexture(GEM_ICONS[gem.color])
        v.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    local tint = GEM_TINT[gem.color] or PRISM_TINT
    v.glow:SetVertexColor(tint[1], tint[2], tint[3])
    v.glow:SetShown(gem.special ~= nil)
    v.star:SetShown(gem.special == "star")
    v.time:SetShown(gem.time ~= nil)
    v.time:SetText(gem.time and ("+" .. gem.time) or "")
    v.icon:Show()
    v.dirty = true
end

function Module:DrawVisual(v)
    if not v.dirty and not (v.gem and (v.gem.special or v.gem.time)) then return end
    v.dirty = false
    local scale = v.scale or 1
    v.icon:SetSize(GEM_SIZE * scale, GEM_SIZE * scale)
    v.icon:SetAlpha(v.alpha or 1)
    Place(v.icon, v.x, v.y)
    if v.gem and v.gem.special then
        local pulse = 0.55 + 0.3 * math.sin(GetTime() * 5 + v.x * 0.1)
        v.glow:SetSize(70 * scale, 70 * scale)
        v.glow:SetAlpha(pulse * (v.alpha or 1))
        Place(v.glow, v.x, v.y)
        if v.gem.color == Game.PRISM then v.icon:SetRotation(GetTime() * 1.5) end
        if v.gem.special == "star" then
            v.star:SetSize(62 * scale, 62 * scale)
            v.star:SetAlpha(0.8 * (v.alpha or 1))
            v.star:SetRotation(GetTime() * 2)
            Place(v.star, v.x, v.y)
        end
    end
    if v.gem and v.gem.time then
        v.time:SetAlpha((0.6 + 0.4 * math.sin(GetTime() * 6)) * (v.alpha or 1))
        Place(v.time, v.x + 12, v.y + 14)
    end
end

function Module:NewVisual(gem, r, c)
    local v = self.visualPool.Acquire()
    v.x, v.y = CellCenter(r, c)
    v.scale, v.alpha = 1, 1
    self:SetGem(v, gem)
    self.visuals[#self.visuals + 1] = v
    return v
end

function Module:ReleaseVisual(v)
    for i, other in ipairs(self.visuals) do
        if other == v then
            table.remove(self.visuals, i)
            break
        end
    end
    self.visualPool.Release(v)
end

function Module:RebuildBoard()
    for i = #self.visuals, 1, -1 do self.visualPool.Release(self.visuals[i]) end
    wipe(self.visuals)
    self.grid = {}
    for r = 1, SIZE do
        self.grid[r] = {}
        for c = 1, SIZE do
            local gem = self.game:At(r, c)
            if gem then self.grid[r][c] = self:NewVisual(gem, r, c) end
        end
    end
end

-- Tweens and effects ----------------------------------------------------------------

function Module:Tween(v, toX, toY, duration, opts)
    opts = opts or {}
    self.tweens[#self.tweens + 1] = {
        v = v, x0 = v.x, y0 = v.y, x1 = toX, y1 = toY, t = -(opts.delay or 0), duration = duration,
        ease = opts.ease, scale1 = opts.scale, alpha1 = opts.alpha, scale0 = v.scale or 1, alpha0 = v.alpha or 1,
        release = opts.release,
    }
end

function Module:UpdateTweens(dt)
    for i = #self.tweens, 1, -1 do
        local tw = self.tweens[i]
        tw.t = tw.t + dt
        if tw.t >= 0 then
            local p = math.min(1, tw.t / tw.duration)
            local e = tw.ease == "in" and p * p or (tw.ease == "out" and 1 - (1 - p) ^ 2 or p)
            local v = tw.v
            v.dirty = true
            v.x = tw.x0 + (tw.x1 - tw.x0) * e
            v.y = tw.y0 + (tw.y1 - tw.y0) * e
            if tw.scale1 then v.scale = tw.scale0 + (tw.scale1 - tw.scale0) * p end
            if tw.alpha1 then v.alpha = tw.alpha0 + (tw.alpha1 - tw.alpha0) * p end
            if p >= 1 then
                table.remove(self.tweens, i)
                if tw.release then self:ReleaseVisual(v) end
            end
        end
    end
end

function Module:AddEffect(update)
    self.effects[#self.effects + 1] = { t = 0, update = update }
end

function Module:Burst(x, y, tint, count, texture, size)
    for _ = 1, count do
        local tex = self.fxPool.Acquire()
        tex:SetTexture(Media.Tex(texture or "spark"))
        tex:SetBlendMode("ADD")
        tex:SetVertexColor(tint[1], tint[2], tint[3])
        tex:Show()
        local angle = math.random() * math.pi * 2
        local speed = 60 + math.random() * 110
        local px, py = x, y
        local life = 0.35 + math.random() * 0.25
        self:AddEffect(function(e, dt)
            local p = e.t / life
            if p >= 1 then
                self.fxPool.Release(tex)
                return false
            end
            px, py = px + math.cos(angle) * speed * dt, py + math.sin(angle) * speed * dt
            Place(tex, px, py)
            local s = (size or 14) * (1 - p * 0.6)
            tex:SetSize(s, s)
            tex:SetAlpha(1 - p)
            return true
        end)
    end
end

function Module:Ring(x, y, tint, from, to, duration)
    local tex = self.fxPool.Acquire()
    tex:SetTexture(Media.Tex("ring"))
    tex:SetBlendMode("ADD")
    tex:SetVertexColor(tint[1], tint[2], tint[3])
    tex:Show()
    self:AddEffect(function(e)
        local p = e.t / duration
        if p >= 1 then
            self.fxPool.Release(tex)
            return false
        end
        local s = from + (to - from) * p
        tex:SetSize(s, s)
        tex:SetAlpha(1 - p)
        Place(tex, x, y)
        return true
    end)
end

-- A beam of light along a row or column, fading out.
function Module:Beam(r, c, horizontal, tint)
    local tex = self.fxPool.Acquire()
    tex:SetTexture(Media.Tex("glow"))
    tex:SetBlendMode("ADD")
    tex:SetVertexColor(tint[1], tint[2], tint[3])
    local x, y = CellCenter(r, c)
    local length = SIZE * CELL + 30
    tex:Show()
    self:AddEffect(function(e)
        local p = e.t / 0.45
        if p >= 1 then
            self.fxPool.Release(tex)
            return false
        end
        if horizontal then
            tex:SetSize(length, 46 * (1 - p * 0.6))
            Place(tex, SIZE * CELL / 2, y)
        else
            tex:SetSize(46 * (1 - p * 0.6), length)
            Place(tex, x, SIZE * CELL / 2)
        end
        tex:SetAlpha(1 - p)
        return true
    end)
end

function Module:Popup(x, y, text, size, r, g, b)
    local fs = self.textPool.Acquire()
    fs:SetFont(Media.FontFile(), size, "OUTLINE")
    fs:SetTextColor(r, g, b)
    fs:SetText(text)
    fs:Show()
    x = math.max(60, math.min(SIZE * CELL - 60, x))
    self:AddEffect(function(e)
        local p = e.t / 0.9
        if p >= 1 then
            self.textPool.Release(fs)
            return false
        end
        Place(fs, x, y - 30 * (1 - (1 - p) ^ 3))
        fs:SetAlpha(p < 0.6 and 1 or (1 - (p - 0.6) / 0.4))
        return true
    end)
end

-- Step playback ---------------------------------------------------------------------

function Module:Busy()
    return self.stepTimer > 0 or #self.queue > 0
end

function Module:Enqueue(steps)
    for _, step in ipairs(steps) do self.queue[#self.queue + 1] = step end
end

function Module:PlayStep(step)
    local handler = self["Step_" .. step.type]
    return handler and handler(self, step) or 0
end

function Module:Step_swap(step)
    local a, b = step.a, step.b
    local va, vb = self.grid[a[1]][a[2]], self.grid[b[1]][b[2]]
    self.grid[a[1]][a[2]], self.grid[b[1]][b[2]] = vb, va
    local ax, ay = CellCenter(a[1], a[2])
    local bx, by = CellCenter(b[1], b[2])
    self:Tween(va, bx, by, 0.16, { ease = "out" })
    self:Tween(vb, ax, ay, 0.16, { ease = "out" })
    Sound("uldum/swap")
    return 0.16
end

function Module:Step_invalid(step)
    local a, b = step.a, step.b
    local va, vb = self.grid[a[1]][a[2]], self.grid[b[1]][b[2]]
    local ax, ay = CellCenter(a[1], a[2])
    local bx, by = CellCenter(b[1], b[2])
    self:Tween(va, bx, by, 0.13)
    self:Tween(vb, ax, ay, 0.13)
    self:Tween(va, ax, ay, 0.13, { delay = 0.13 })
    self:Tween(vb, bx, by, 0.13, { delay = 0.13 })
    -- The delayed tweens must start from the swapped spot, not the current one.
    self.tweens[#self.tweens - 1].x0, self.tweens[#self.tweens - 1].y0 = bx, by
    self.tweens[#self.tweens].x0, self.tweens[#self.tweens].y0 = ax, ay
    Sound("uldum/invalid")
    return 0.28
end

function Module:Step_clear(step)
    local sx, sy = 0, 0
    for i, cell in ipairs(step.cells) do
        local v = self.grid[cell.r][cell.c]
        self.grid[cell.r][cell.c] = nil
        local x, y = CellCenter(cell.r, cell.c)
        sx, sy = sx + x, sy + y
        if v then
            self:Tween(v, x, y, 0.22, { delay = math.min(i, 12) * 0.012, scale = 1.5, alpha = 0, release = true })
        end
        if i <= 24 then self:Burst(x, y, GEM_TINT[cell.color] or PRISM_TINT, 3) end
    end
    for _, spec in ipairs(step.created) do
        local v = self.grid[spec.r][spec.c]
        if v then self:SetGem(v, { color = spec.color, special = spec.special }) end
        local x, y = CellCenter(spec.r, spec.c)
        self:Ring(x, y, GEM_TINT[spec.color] or PRISM_TINT, 30, 110, 0.45)
    end
    for _, spot in ipairs(step.explosions) do
        local x, y = CellCenter(spot[1], spot[2])
        if spot.kind == "star" then
            self:Beam(spot[1], spot[2], true, { 0.7, 0.85, 1 })
            self:Beam(spot[1], spot[2], false, { 0.7, 0.85, 1 })
            self:Burst(x, y, { 0.8, 0.9, 1 }, 10, "spark", 16)
        elseif spot.kind == "cross" then
            for d = -1, 1 do
                self:Beam(spot[1] + d, spot[2], true, { 1, 0.85, 0.5 })
                self:Beam(spot[1], spot[2] + d, false, { 1, 0.85, 0.5 })
            end
        elseif spot.kind == "combo" then
            self:Ring(x, y, { 1, 0.5, 0.15 }, 60, 320, 0.7)
            self:Burst(x, y, { 1, 0.6, 0.2 }, 30, "spark", 20)
        else
            self:Ring(x, y, { 1, 0.6, 0.2 }, 40, 190, 0.5)
            self:Burst(x, y, { 1, 0.6, 0.2 }, 14, "spark", 18)
        end
    end
    if step.kind == "supernova" or step.kind == "combo" then
        self:Popup(SIZE * CELL / 2, SIZE * CELL * 0.4, L.JU_COMBO, 26, 1, 0.7, 0.25)
    end
    if (step.time or 0) > 0 then
        self:Popup(SIZE * CELL / 2, SIZE * CELL * 0.6, L.JU_TIME_BONUS:format(step.time), 20, 0.6, 1, 1)
    end
    local n = math.max(1, #step.cells)
    self:Popup(sx / n, sy / n, "+" .. ns.FormatNumber(step.points), 16, 1, 0.9, 0.4)
    if step.cascade >= 2 then
        self:Popup(SIZE * CELL / 2, SIZE * CELL * 0.45, L.JU_CASCADE:format(step.cascade), 22, 1, 0.6, 0.2)
    end
    Sound("uldum/match" .. math.min(step.cascade, 6))
    if #step.created > 0 then Sound("uldum/special") end
    if #step.explosions > 0 or step.kind == "prism" then Sound("murlocblast/explode") end
    self:OnClearStep(step)
    return 0.26
end

function Module:Step_fall(step)
    local longest = 0
    for _, move in ipairs(step.moves) do
        local v = self.grid[move.from][move.c]
        self.grid[move.to][move.c] = v
        self.grid[move.from][move.c] = nil
        local x, y = CellCenter(move.to, move.c)
        local duration = 0.1 + 0.035 * (move.to - move.from)
        if v then self:Tween(v, x, y, duration, { ease = "in" }) end
        longest = math.max(longest, duration)
    end
    local perColumn = {}
    for _, spawn in ipairs(step.spawns) do perColumn[spawn.c] = (perColumn[spawn.c] or 0) + 1 end
    for _, spawn in ipairs(step.spawns) do
        local v = self:NewVisual({ color = spawn.color }, spawn.r - perColumn[spawn.c], spawn.c)
        self.grid[spawn.r][spawn.c] = v
        local x, y = CellCenter(spawn.r, spawn.c)
        local duration = 0.1 + 0.035 * perColumn[spawn.c]
        self:Tween(v, x, y, duration, { ease = "in" })
        longest = math.max(longest, duration)
    end
    return longest + 0.02
end

function Module:Step_levelup(step)
    self:Popup(SIZE * CELL / 2, SIZE * CELL * 0.5, L.JU_LEVEL_UP:format(step.level), 26, 1, 0.85, 0.3)
    Sound("murlocblast/clear")
    if step.level >= 5 then Achievements.Unlock("ju_level5") end
    if step.level >= 10 then Achievements.Unlock("ju_level10") end
    if step.level >= 3 and ns.Flight.current then Achievements.Unlock("ju_flight") end
    self:UpdateHud()
    return 0.3
end

function Module:Step_reshuffle()
    self:RebuildBoard()
    for _, v in ipairs(self.visuals) do
        v.alpha = 0
        self:Tween(v, v.x, v.y, 0.4, { alpha = 1 })
    end
    self:Popup(SIZE * CELL / 2, SIZE * CELL * 0.5, L.JU_RESHUFFLE, 22, 0.7, 0.9, 1)
    return 0.45
end

function Module:Step_over(step)
    self:Popup(SIZE * CELL / 2, SIZE * CELL * 0.5, L.JU_NO_MOVES, 24, 1, 0.5, 0.4)
    return 0.6
end

function Module:OnClearStep(step)
    Achievements.Unlock("ju_first")
    if step.cascade >= 4 then Achievements.Unlock("ju_cascade4") end
    if step.cascade >= 6 then Achievements.Unlock("ju_cascade6") end
    for _, spec in ipairs(step.created) do
        if spec.special == "star" then
            Achievements.Unlock("ju_star")
        else
            Achievements.Unlock(spec.special == "prism" and "ju_prism" or "ju_power")
        end
    end
    if step.kind == "combo" or step.kind == "supernova" then Achievements.Unlock("ju_combo") end
    if self.game.mode == "blitz" and (self.game.timeGained or 0) >= GOALS.time then Achievements.Unlock("ju_time") end
    if step.kind == "prism" and #step.cells >= GOALS.prismUse then Achievements.Unlock("ju_prism_use") end
    local settings = Settings()
    settings.gems = settings.gems + #step.cells
    if settings.gems >= GOALS.gems then Achievements.Unlock("ju_gems") end
    local score = self.game.score
    if self.game.mode == "classic" and score >= GOALS.classic then Achievements.Unlock("ju_classic") end
    if self.game.mode == "blitz" and score >= GOALS.blitz then Achievements.Unlock("ju_blitz") end
    if self.game.mode == "blitz" and score >= GOALS.blitz2 then Achievements.Unlock("ju_blitz2") end
    if self.game.mode == "zen" and score >= GOALS.zen then Achievements.Unlock("ju_zen") end
    self:UpdateHud()
end

-- Input ---------------------------------------------------------------------------

function Module:CellAtCursor()
    local layer = self.gemLayer
    local left, top = layer:GetLeft(), layer:GetTop()
    if not left then return end
    local scale = layer:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    local x, y = cx / scale - left, top - cy / scale
    local r, c = math.floor(y / CELL) + 1, math.floor(x / CELL) + 1
    if r >= 1 and r <= SIZE and c >= 1 and c <= SIZE then return r, c, x, y end
end

function Module:TrySwap(r1, c1, r2, c2)
    local a, b = self.game:At(r1, c1), self.game:At(r2, c2)
    local doublePrism = a and b and a.color == Game.PRISM and b.color == Game.PRISM
    local steps = self.game:Swap(r1, c1, r2, c2)
    self.selected = nil
    if not steps then return end
    if doublePrism and steps[1].type == "swap" then Achievements.Unlock("ju_double") end
    self.idle = 0
    self:Enqueue(steps)
end

function Module:OnBoardMouseDown()
    if self.game.state ~= "PLAYING" or self:Busy() then return end
    local r, c, x, y = self:CellAtCursor()
    if not r then return end
    local sel = self.selected
    if sel and math.abs(sel[1] - r) + math.abs(sel[2] - c) == 1 then
        self:TrySwap(sel[1], sel[2], r, c)
        return
    end
    self.selected = { r, c }
    self.drag = { r = r, c = c, x = x, y = y }
    Sound("murlocblast/swap")
end

function Module:UpdateDrag()
    local drag = self.drag
    if not drag then return end
    if not IsMouseButtonDown("LeftButton") then
        self.drag = nil
        return
    end
    local _, _, x, y = self:CellAtCursor()
    if not x then return end
    local dx, dy = x - drag.x, y - drag.y
    if math.max(math.abs(dx), math.abs(dy)) < CELL * 0.4 then return end
    local r, c = drag.r, drag.c
    if math.abs(dx) > math.abs(dy) then c = c + (dx > 0 and 1 or -1) else r = r + (dy > 0 and 1 or -1) end
    self.drag = nil
    if r >= 1 and r <= SIZE and c >= 1 and c <= SIZE then self:TrySwap(drag.r, drag.c, r, c) end
end

-- Build ------------------------------------------------------------------------------

function Module:Build(container)
    self.container = container
    self.visuals, self.tweens, self.effects, self.queue, self.grid = {}, {}, {}, {}, {}
    self.stepTimer, self.idle = 0, 0

    local bg = container:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(Tex("background"))
    bg:SetTexCoord(0, W / 512, 0, H / 512)

    local board = CreateFrame("Frame", nil, container)
    board:SetSize(SIZE * CELL, SIZE * CELL)
    board:SetPoint("TOPLEFT", BOARD_X, -BOARD_Y)
    local fill = board:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    fill:SetColorTexture(0.02, 0.01, 0.05, 0.62)
    Widgets.Rim(board, board)
    for r = 1, SIZE do
        for c = 1, SIZE do
            local cell = board:CreateTexture(nil, "BORDER")
            cell:SetTexture(Tex("cell"))
            cell:SetSize(CELL - 2, CELL - 2)
            local x, y = CellCenter(r, c)
            cell:SetPoint("CENTER", board, "TOPLEFT", x, -y)
            cell:SetVertexColor(1, 0.85, 0.6, (r + c) % 2 == 0 and 0.07 or 0.12)
        end
    end

    local gemLayer = CreateFrame("Frame", nil, board)
    gemLayer:SetAllPoints()
    gemLayer:SetClipsChildren(true)
    gemLayer:SetFrameLevel(board:GetFrameLevel() + 2)
    gemLayer:EnableMouse(true)
    gemLayer:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then self:OnBoardMouseDown() end
    end)
    self.gemLayer = gemLayer
    self.visualPool = Media.Pool(function() return self:CreateVisual() end, HideVisual)

    local fx = CreateFrame("Frame", nil, board)
    fx:SetAllPoints()
    fx:SetFrameLevel(board:GetFrameLevel() + 4)
    self.fxPool = Media.Pool(function() return fx:CreateTexture(nil, "OVERLAY") end, function(t) t:Hide() end)
    self.textPool = Media.Pool(function() return fx:CreateFontString(nil, "OVERLAY") end, function(fs) fs:Hide() end)

    self.selection = fx:CreateTexture(nil, "OVERLAY")
    self.selection:SetTexture(Media.Tex("ring"))
    self.selection:SetBlendMode("ADD")
    self.selection:SetVertexColor(1, 0.85, 0.4)
    self.selection:SetSize(CELL + 10, CELL + 10)
    self.hints = {}
    for i = 1, 2 do
        local hint = fx:CreateTexture(nil, "OVERLAY")
        hint:SetTexture(Media.Tex("glow"))
        hint:SetBlendMode("ADD")
        hint:SetVertexColor(1, 1, 0.8)
        hint:SetSize(CELL + 20, CELL + 20)
        hint:Hide()
        self.hints[i] = hint
    end

    local barY = BOARD_Y + SIZE * CELL + 12
    local track = container:CreateTexture(nil, "ARTWORK")
    track:SetColorTexture(0, 0, 0, 0.55)
    track:SetPoint("TOPLEFT", BOARD_X, -barY)
    track:SetSize(SIZE * CELL, 10)
    self.bar = container:CreateTexture(nil, "ARTWORK", nil, 1)
    self.bar:SetColorTexture(0.86, 0.66, 0.3, 0.95)
    self.bar:SetPoint("TOPLEFT", track, "TOPLEFT")
    self.bar:SetHeight(10)
    self.barLabel = Widgets.Text(container, 11, "white")
    self.barLabel:SetPoint("TOP", track, "BOTTOM", 0, -4)

    local game = Game.New()
    game.onEvent = function(name) if name == "timeup" then Sound("uldum/invalid") end end
    self.game = game

    self.overlay = Widgets.NewOverlay(container)
    self:CreatePages()
    Widgets.ScoresPage(self.overlay, W, {
        gameId = self.id,
        buckets = Game.MODES,
        bucketName = ModeName,
        detail = function(entry) return self:ScoreDetail(entry) end,
        shareMessage = ShareMessage,
        onBack = function() self.overlay:Show("menu") end,
    })
    Widgets.AchievementsPage(self.overlay, W, self.id, function() Widgets.BackFromSubPage(self) end)
    Widgets.HelpPage(self.overlay, W, "JU_RULES", "JU_HELP", function() Widgets.BackFromSubPage(self) end)

    game:Start(Settings().mode)
    game.state = "READY"
    self:RebuildBoard()
    self.overlay:Show("menu")
end

function Module:CreatePages()
    local menu = self.overlay:AddPage("menu")
    local title = Widgets.PageTitle(menu, "JU_NAME", -54)
    local tagline = Widgets.LocalizedText(menu, 14, "blue", "JU_TAGLINE")
    tagline:SetPoint("TOP", title, "BOTTOM", 0, -6)
    local modeLabel = Widgets.LocalizedText(menu, 11, "gray", "JU_MODE")
    modeLabel:SetPoint("TOP", 0, -140)
    local mode = Widgets.Cycler(menu, 200, function(dir)
        local settings = Settings()
        settings.mode = Widgets.Cycle(Game.MODES, settings.mode, dir)
        menu.refresh()
        self:UpdateHud()
    end)
    mode:SetPoint("TOP", modeLabel, "BOTTOM", 0, -2)
    local play = Widgets.Button(menu, 200, 26, "NEW_GAME", function() self:NewGame() end)
    local scores = Widgets.Button(menu, 200, 26, "HIGHSCORES", function()
        self.overlay:Show("scores", { bucket = Settings().mode })
    end)
    Widgets.Stack(menu, { play, scores }, -196)
    menu.refresh = function() mode.label:SetText(ModeName(Settings().mode)) end

    local pause = self.overlay:AddPage("pause")
    local pauseTitle = Widgets.PageTitle(pause, "PAUSED", -100)
    local landed = Widgets.Text(pause, 14, "blue")
    landed:SetPoint("TOP", pauseTitle, "BOTTOM", 0, -8)
    local resume = Widgets.Button(pause, 200, 26, "RESUME", function() self:Resume() end)
    local pauseMenu = Widgets.Button(pause, 200, 26, "MENU", function() self:AbandonRun() end)
    Widgets.Stack(pause, { resume, pauseMenu }, -190)
    pause.refresh = function(data) landed:SetText((data and data.landed) and L.LANDED or "") end

    local over = self.overlay:AddPage("over")
    local overTitle = Widgets.PageTitle(over, "GAME_OVER", -70)
    local reason = Widgets.Text(over, 14, "blue")
    reason:SetPoint("TOP", overTitle, "BOTTOM", 0, -6)
    local final = Widgets.Text(over, 18, "white")
    final:SetPoint("TOP", reason, "BOTTOM", 0, -12)
    local record = Widgets.Text(over, 14, "gold")
    record:SetPoint("TOP", final, "BOTTOM", 0, -8)
    local share = Widgets.ShareRow(over, function()
        return self.lastEntry and ShareMessage(self.lastEntry, self.lastEntry.mode)
    end)
    share:SetPoint("TOP", 0, -220)
    local again = Widgets.Button(over, 200, 26, "AGAIN", function() self:NewGame() end)
    local overMenu = Widgets.Button(over, 200, 26, "MENU", function() self:ShowMenu() end)
    Widgets.Stack(over, { again, overMenu }, -262)
    over.refresh = function(data)
        reason:SetText(data.reason == "time" and L.JU_TIME_UP or L.JU_NO_MOVES)
        final:SetText(L.FINAL_SCORE:format(ns.FormatNumber(data.score)))
        record:SetText(data.rank == 1 and L.NEW_RECORD or "")
    end
end

-- Game flow ----------------------------------------------------------------------------

function Module:ClearAnimations()
    wipe(self.queue)
    wipe(self.tweens)
    for i = #self.effects, 1, -1 do
        local e = self.effects[i]
        e.t = 999
        e.update(e, 0)
    end
    wipe(self.effects)
    self.stepTimer = 0
    self.selected, self.drag = nil, nil
end

function Module:NewGame()
    self:ClearAnimations()
    self.finished = false
    self.idle = 0
    self.game:Start(Settings().mode)
    self:RebuildBoard()
    self.overlay:Hide()
    self:UpdateHud()
end

function Module:ShowMenu()
    self:ClearAnimations()
    self.game.state = "READY"
    self.overlay:Show("menu")
    self:UpdateHud()
end

function Module:AbandonRun()
    if self.game.score > 0 and not self.finished then self:Record() end
    self:ShowMenu()
end

function Module:Record()
    local game = self.game
    self.finished = true
    self.lastEntry = { score = game.score, level = game.level, mode = game.mode }
    return Scores.Record(self.id, game.mode, { score = game.score, level = game.level })
end

function Module:Finish(reason)
    local rank = self:Record()
    self:UpdateHud()
    Sound("murlocblast/gameover")
    C_Timer.After(0.8, function()
        self.overlay:Show("over", { score = self.game.score, rank = rank, reason = reason })
    end)
end

function Module:Pause(info)
    local game = self.game
    if not game then return end
    if game.state == "PLAYING" then
        game:Pause()
        self.overlay:Show("pause", info)
    elseif info.landed and game.state == "PAUSED" then
        self.overlay:Show("pause", info)
    end
end

function Module:Resume()
    self.game:Resume()
    self.overlay:Hide()
end

-- Arcade hooks ---------------------------------------------------------------------

function Module:Sidebar()
    local game = self.game
    local info
    if game.mode == "blitz" then
        info = L.JU_BLITZ .. "  ·  " .. L.JU_TIME:format(ns.FormatTime(game.timeLeft or Game.BLITZ_TIME))
    elseif game.mode == "zen" then
        info = L.JU_ZEN
    else
        local progress = math.floor(100 * game.levelPoints / Game.LevelTarget(game.level))
        info = L.JU_CLASSIC .. "  ·  " .. L.LEVEL:format(game.level) .. ("  ·  %d%%"):format(progress)
    end
    return { score = game.score, bucket = Settings().mode, info = info }
end

function Module:ScoreDetail(entry)
    return entry.level and entry.level > 1 and L.LEVEL:format(entry.level) or date(L.DATE_FORMAT, entry.time)
end

function Module:UpdateHud()
    ns.Window:UpdateSidebar()
end

function Module:ShowAchievements()
    Widgets.ShowSubPage(self, "achievements")
end

function Module:ShowHelp()
    Widgets.ShowSubPage(self, "help")
end

function Module:Enter()
    self:UpdateHud()
    self.overlay:Refresh()
end

function Module:Leave()
    self:Pause({})
end

function Module:RefreshTexts()
    self.overlay:Refresh()
    self:UpdateHud()
end

function Module:OnKey(key)
    local game = self.game
    if key == "P" and (game.state == "PLAYING" or (game.state == "PAUSED" and self.overlay.current == "pause")) then
        if game.state == "PLAYING" then self:Pause({}) else self:Resume() end
        return true
    end
    return false
end

function Module:UpdateBar()
    local game = self.game
    local fraction, label
    if game.mode == "blitz" then
        fraction = math.min(1, (game.timeLeft or Game.BLITZ_TIME) / Game.BLITZ_TIME)
        label = L.JU_TIME:format(ns.FormatTime(game.timeLeft or Game.BLITZ_TIME))
    elseif game.mode == "zen" then
        fraction = (GetTime() % 8) / 8
        label = L.JU_ZEN
    else
        fraction = game.levelPoints / Game.LevelTarget(game.level)
        label = L.LEVEL:format(game.level)
    end
    self.bar:SetWidth(math.max(1, SIZE * CELL * math.min(1, fraction)))
    self.barLabel:SetText(label)
end

function Module:OnUpdate(dt)
    local game = self.game
    if game.state == "PLAYING" then
        game:Update(dt)
        self:UpdateDrag()
    end

    if self.stepTimer > 0 then self.stepTimer = self.stepTimer - dt end
    while self.stepTimer <= 0 and #self.queue > 0 do
        self.stepTimer = self:PlayStep(table.remove(self.queue, 1))
    end
    self:UpdateTweens(dt)
    for _, v in ipairs(self.visuals) do self:DrawVisual(v) end
    for i = #self.effects, 1, -1 do
        local e = self.effects[i]
        e.t = e.t + dt
        if not e.update(e, dt) then table.remove(self.effects, i) end
    end

    if game.state == "OVER" and not self.finished and not self:Busy() then
        self:Finish(game.mode == "blitz" and "time" or "moves")
    end

    local sel = self.selected
    if sel and game.state == "PLAYING" then
        local x, y = CellCenter(sel[1], sel[2])
        Place(self.selection, x, y)
        self.selection:SetAlpha(0.6 + 0.3 * math.sin(GetTime() * 8))
        self.selection:Show()
    else
        self.selection:Hide()
    end

    local showHint = false
    if game.state == "PLAYING" and not self:Busy() and Settings().hints then
        self.idle = self.idle + dt
        if self.idle > HINT_DELAY then
            self.hintMove = self.hintMove or game:FindMove()
            showHint = self.hintMove ~= nil
        end
    else
        self.hintMove = nil
    end
    for i, hint in ipairs(self.hints) do
        if showHint then
            local m = self.hintMove
            local x, y = CellCenter(m[i * 2 - 1], m[i * 2])
            Place(hint, x, y)
            hint:SetAlpha(0.35 + 0.35 * math.sin(GetTime() * 4))
        end
        hint:SetShown(showHint)
    end
    if self.idle == 0 then self.hintMove = nil end

    self.sidebarTimer = (self.sidebarTimer or 0) - dt
    if self.sidebarTimer <= 0 then
        self.sidebarTimer = 0.25
        self:UpdateBar()
        if game.mode == "blitz" and game.state == "PLAYING" then self:UpdateHud() end
    end
end

function Module:DecorateTile(tile, art)
    local pattern = { { 1, 4, 2, 5, 3 }, { 6, 1, 7, 2, 4 }, { 3, 5, 1, 6, 7 } }
    for r, row in ipairs(pattern) do
        for c, color in ipairs(row) do
            local icon = tile:CreateTexture(nil, "OVERLAY")
            icon:SetTexture(GEM_ICONS[color])
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            icon:SetSize(26, 26)
            icon:SetPoint("TOPLEFT", art, "TOPLEFT", 122 + (c - 1) * 31, -24 - (r - 1) * 31)
        end
    end
end

function Module:Options()
    return {
        { kind = "check", tbl = Settings(), key = "hints", label = "JU_OPT_HINTS", tip = "JU_OPT_HINTS_TIP", default = true },
    }
end

function Module:StatLines()
    return { { L.JU_STAT_GEMS, ns.FormatNumber(Settings().gems or 0) } }
end

JU.Module = Module
Arcade.RegisterGame(Module)
