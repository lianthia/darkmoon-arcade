local _, ns = ...

local Game, Media, L = ns.Game, ns.Media, ns.L

local Board = {}
ns.Board = Board

local W, H, R = Game.WIDTH, Game.HEIGHT, Game.RADIUS
local D = R * 2
local BG_USED = H / 512
local SYMBOL_ALPHA = 0.45
local MURLOC_NPC_ID = 46 -- Murloc Forager, Elwynn Forest

local random = math.random

local function Place(region, x, y)
    region:ClearAllPoints()
    region:SetPoint("CENTER", region:GetParent(), "TOPLEFT", x, -y)
end

local function CreateBall(parent, sublevel)
    return {
        tex = parent:CreateTexture(nil, "ARTWORK", nil, sublevel),
        sym = parent:CreateTexture(nil, "ARTWORK", nil, sublevel + 1),
    }
end

local function ShowBall(ball, color, x, y, size, alpha, dead)
    alpha = alpha or 1
    ball.tex:SetTexture(Media.Tex("bubble" .. color))
    ball.tex:SetDesaturated(dead and true or false)
    ball.tex:SetSize(size, size)
    ball.tex:SetAlpha(alpha)
    Place(ball.tex, x, y)
    ball.tex:Show()
    if ns.db.symbols then
        ball.sym:SetTexture(Media.Tex("symbol" .. color))
        ball.sym:SetSize(size, size)
        ball.sym:SetAlpha(alpha * SYMBOL_ALPHA)
        Place(ball.sym, x, y)
        ball.sym:Show()
    else
        ball.sym:Hide()
    end
end

local function HideBall(ball)
    ball.tex:Hide()
    ball.sym:Hide()
end

function Board:Create(parent)
    local field = CreateFrame("Frame", nil, parent)
    field:SetSize(W, H)
    field:SetClipsChildren(true)
    self.field = field

    local bg = field:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(Media.Tex("background"))
    bg:SetTexCoord(0, 1, 0, BG_USED)

    local ceiling = field:CreateTexture(nil, "BORDER")
    ceiling:SetTexture(Media.Tex("ceiling"))
    ceiling:SetPoint("TOPLEFT")
    ceiling:SetPoint("TOPRIGHT")
    ceiling:Hide()
    self.ceiling = ceiling

    local death = field:CreateTexture(nil, "BORDER", nil, 2)
    death:SetColorTexture(1, 0.3, 0.25, 0.35)
    death:SetHeight(2)
    death:SetPoint("LEFT", field, "TOPLEFT", 0, -(R * 2 + (Game.VISIBLE_ROWS - 1) * (D * math.sqrt(3) / 2)))
    death:SetPoint("RIGHT", field, "TOPRIGHT", 0, 0)
    self.death = death

    local level = field:GetFrameLevel()

    local boardLayer = CreateFrame("Frame", nil, field)
    boardLayer:SetSize(W, H)
    boardLayer:SetPoint("TOPLEFT")
    boardLayer:SetFrameLevel(level + 1)
    self.boardLayer = boardLayer

    local launcherLayer = CreateFrame("Frame", nil, field)
    launcherLayer:SetAllPoints()
    launcherLayer:SetFrameLevel(level + 3)
    self.launcherLayer = launcherLayer

    local fxLayer = CreateFrame("Frame", nil, field)
    fxLayer:SetAllPoints()
    fxLayer:SetFrameLevel(level + 5)
    self.fxLayer = fxLayer

    self.boardPool = Media.Pool(function() return CreateBall(boardLayer, 1) end, HideBall)
    self.fxBallPool = Media.Pool(function() return CreateBall(fxLayer, 1) end, HideBall)
    self.fxTexPool = Media.Pool(function()
        return fxLayer:CreateTexture(nil, "OVERLAY")
    end, function(tex)
        tex:Hide()
        tex:SetBlendMode("BLEND")
        tex:SetVertexColor(1, 1, 1)
        tex:SetAlpha(1)
        tex:SetRotation(0)
    end)
    self.textPool = Media.Pool(function()
        local fs = fxLayer:CreateFontString(nil, "OVERLAY")
        fs:SetFont(Media.FONT, 16, "OUTLINE")
        return fs
    end, function(fs) fs:Hide() end)

    self.boardBalls = {}
    self.effects = {}
    self.displayCeil = 0
    self.shakeTime = 0
    self.shakeAmp = 0

    self:CreateLauncher()
    self:CreateAimDots()
    self:CreatePips()
    return field
end

function Board:CreateLauncher()
    local layer = self.launcherLayer
    local x, y = W / 2, Game.LAUNCH_Y

    local base = layer:CreateTexture(nil, "ARTWORK", nil, 0)
    base:SetTexture(Media.Tex("launcher"))
    base:SetSize(76, 76)
    Place(base, x, y)

    local arrow = layer:CreateTexture(nil, "ARTWORK", nil, 2)
    arrow:SetTexture(Media.Tex("arrow"))
    arrow:SetSize(120, 120)
    Place(arrow, x, y)
    self.arrow = arrow

    self.currentBall = CreateBall(layer, 4)

    local nextX, nextY = x - 72, y + 6
    local nextRing = layer:CreateTexture(nil, "ARTWORK", nil, 0)
    nextRing:SetTexture(Media.Tex("launcher"))
    nextRing:SetSize(44, 44)
    Place(nextRing, nextX, nextY)
    self.nextBall = CreateBall(layer, 4)
    self.nextPos = { nextX, nextY }

    local label = layer:CreateFontString(nil, "OVERLAY")
    label:SetFont(Media.FONT, 10, "OUTLINE")
    label:SetTextColor(0.85, 0.95, 1)
    label:SetText(L.NEXT)
    label:SetPoint("BOTTOM", layer, "TOPLEFT", nextX, -(nextY - 24))

    -- Purely decorative; pcall because model APIs differ between client flavors.
    local model = CreateFrame("PlayerModel", nil, layer)
    model:SetSize(96, 96)
    model:SetPoint("CENTER", layer, "TOPLEFT", x + 82, -(y - 14))
    model:SetFrameLevel(layer:GetFrameLevel() + 1)
    pcall(model.SetCreature, model, MURLOC_NPC_ID)
    pcall(model.SetFacing, model, -0.6)
    self.model = model
end

function Board:PlayModelAnimation(id)
    local model = self.model
    if model and model.SetAnimation then
        pcall(model.SetAnimation, model, id)
        C_Timer.After(2.5, function() pcall(model.SetAnimation, model, 0) end)
    end
end

function Board:CreateAimDots()
    self.dots = {}
    for i = 1, 40 do
        local dot = self.launcherLayer:CreateTexture(nil, "ARTWORK", nil, -2)
        dot:SetTexture(Media.Tex("dot"))
        dot:SetSize(7, 7)
        dot:SetBlendMode("ADD")
        dot:Hide()
        self.dots[i] = dot
    end
end

function Board:CreatePips()
    self.pips = {}
    for i = 1, 9 do
        local pip = self.launcherLayer:CreateTexture(nil, "ARTWORK", nil, 1)
        pip:SetTexture(Media.Tex("dot"))
        pip:SetSize(9, 9)
        Place(pip, W - 12 - (i - 1) * 11, H - 10)
        pip:Hide()
        self.pips[i] = pip
    end
end

function Board:Attach(game)
    self.game = game
end

function Board:SyncBoard()
    local game = self.game
    for i = #self.boardBalls, 1, -1 do
        self.boardPool.Release(self.boardBalls[i])
        self.boardBalls[i] = nil
    end
    local dead = game.state == "OVER"
    game.grid:Each(function(r, c, color)
        local ball = self.boardPool.Acquire()
        local x, y = game.grid:CellCenter(r, c)
        ShowBall(ball, color, x, y, D, 1, dead)
        self.boardBalls[#self.boardBalls + 1] = ball
    end)
    self:SyncLauncher()
    self:SyncPips()
end

function Board:SyncLauncher()
    local game = self.game
    if game.current and game.state ~= "READY" then
        ShowBall(self.currentBall, game.current, W / 2, Game.LAUNCH_Y, D)
        ShowBall(self.nextBall, game.next, self.nextPos[1], self.nextPos[2], 24)
    else
        HideBall(self.currentBall)
        HideBall(self.nextBall)
    end
end

function Board:SyncPips()
    local game = self.game
    local left = game.shotsUntilDrop or 0
    local warn = left <= 2
    for i, pip in ipairs(self.pips) do
        if game.state ~= "READY" and i <= left then
            if warn then pip:SetVertexColor(1, 0.35, 0.3) else pip:SetVertexColor(0.6, 0.9, 1) end
            pip:Show()
        else
            pip:Hide()
        end
    end
end

function Board:Reset()
    for i = #self.effects, 1, -1 do
        local e = self.effects[i]
        if e.finish then e.finish(e) end
        self.effects[i] = nil
    end
    if self.shotBall then
        self.fxBallPool.Release(self.shotBall)
        self.shotBall = nil
    end
    self.displayCeil = self.game and self.game:CeilingY() or 0
    self:ApplyCeiling()
end

function Board:AddEffect(e)
    e.t = 0
    self.effects[#self.effects + 1] = e
end

function Board:Shake(amount, duration)
    self.shakeAmp = math.max(self.shakeAmp, amount)
    self.shakeTime = math.max(self.shakeTime, duration)
end

function Board:SpawnGlow(x, y, color, size, duration, texture)
    local tex = self.fxTexPool.Acquire()
    tex:SetTexture(Media.Tex(texture or "glow"))
    tex:SetBlendMode("ADD")
    local c = Media.COLORS[color] or { 1, 1, 1 }
    tex:SetVertexColor(c[1], c[2], c[3])
    Place(tex, x, y)
    tex:Show()
    self:AddEffect({
        update = function(e)
            local p = e.t / duration
            if p >= 1 then return false end
            local s = size[1] + (size[2] - size[1]) * p
            tex:SetSize(s, s)
            tex:SetAlpha((1 - p) * 0.9)
            return true
        end,
        finish = function() self.fxTexPool.Release(tex) end,
    })
end

function Board:SpawnSparks(x, y, color, count)
    local c = Media.COLORS[color] or { 1, 1, 1 }
    for _ = 1, count do
        local tex = self.fxTexPool.Acquire()
        tex:SetTexture(Media.Tex("spark"))
        tex:SetBlendMode("ADD")
        tex:SetVertexColor(0.6 + c[1] * 0.4, 0.6 + c[2] * 0.4, 0.6 + c[3] * 0.4)
        tex:Show()
        local angle = random() * math.pi * 2
        local speed = 70 + random() * 110
        local px, py = x, y
        local vx, vy = math.cos(angle) * speed, math.sin(angle) * speed
        local life = 0.35 + random() * 0.2
        local spin = (random() - 0.5) * 8
        self:AddEffect({
            update = function(e, dt)
                local p = e.t / life
                if p >= 1 then return false end
                vy = vy + 260 * dt
                px, py = px + vx * dt, py + vy * dt
                Place(tex, px, py)
                local s = 14 * (1 - p * 0.6)
                tex:SetSize(s, s)
                tex:SetAlpha(1 - p)
                tex:SetRotation(e.t * spin)
                return true
            end,
            finish = function() self.fxTexPool.Release(tex) end,
        })
    end
end

function Board:SpawnText(x, y, text, size, r, g, b, rise, duration)
    local fs = self.textPool.Acquire()
    fs:SetFont(Media.FONT, size, "OUTLINE")
    fs:SetTextColor(r, g, b)
    fs:SetText(text)
    fs:Show()
    x = math.max(40, math.min(W - 40, x))
    self:AddEffect({
        update = function(e)
            local p = e.t / duration
            if p >= 1 then return false end
            local ease = 1 - (1 - p) ^ 3
            fs:ClearAllPoints()
            fs:SetPoint("CENTER", self.fxLayer, "TOPLEFT", x, -(y - rise * ease))
            fs:SetAlpha(p < 0.6 and 1 or (1 - (p - 0.6) / 0.4))
            local pop = p < 0.12 and (1 + (0.12 - p) * 3) or 1
            fs:SetScale(pop)
            return true
        end,
        finish = function()
            fs:SetScale(1)
            self.textPool.Release(fs)
        end,
    })
end

function Board:SpawnPop(cell, delay, index)
    local ball = self.fxBallPool.Acquire()
    local x, y = cell.x, cell.y - self.game:CeilingY() + self.displayCeil
    ShowBall(ball, cell.color, x, y, D)
    local popped = false
    self:AddEffect({
        update = function(e)
            if e.t < delay then return true end
            local p = (e.t - delay) / 0.18
            if not popped then
                popped = true
                self:SpawnGlow(x, y, cell.color, { 30, 72 }, 0.3)
                self:SpawnSparks(x, y, cell.color, 4)
                if index <= 6 then Media.Play("pop" .. math.min(index, 5)) end
            end
            if p >= 1 then return false end
            ShowBall(ball, cell.color, x, y, D * (1 + 0.55 * p), 1 - p)
            return true
        end,
        finish = function() self.fxBallPool.Release(ball) end,
    })
end

function Board:SpawnFall(cell, delay)
    local ball = self.fxBallPool.Acquire()
    local x = cell.x
    local y = cell.y - self.game:CeilingY() + self.displayCeil
    local vx = (random() - 0.5) * 140
    local vy = -60 - random() * 140
    ShowBall(ball, cell.color, x, y, D)
    self:AddEffect({
        update = function(e, dt)
            if e.t < delay then return true end
            vy = vy + 1300 * dt
            x, y = x + vx * dt, y + vy * dt
            if y > H + D then return false end
            ShowBall(ball, cell.color, x, y, D, 1)
            return true
        end,
        finish = function() self.fxBallPool.Release(ball) end,
    })
end

local function Centroid(cells, game, displayCeil)
    local sx, sy = 0, 0
    for i = 1, #cells do
        sx, sy = sx + cells[i].x, sy + cells[i].y
    end
    return sx / #cells, sy / #cells - game:CeilingY() + displayCeil
end

function Board:OnGameEvent(name, data)
    local game = self.game
    if name == "board" or name == "level" or name == "swap" then
        if name == "level" then self:Reset() end
        self:SyncBoard()
        if name == "swap" then Media.Play("swap") end
    elseif name == "shoot" then
        Media.Play("shoot")
        self.shotBall = self.shotBall or self.fxBallPool.Acquire()
        self:SyncLauncher()
    elseif name == "bounce" then
        Media.Play("bounce")
    elseif name == "land" then
        if self.shotBall then
            self.fxBallPool.Release(self.shotBall)
            self.shotBall = nil
        end
        Media.Play("land")
        self:SyncBoard()
        self:SpawnGlow(data.x, data.y - game:CeilingY() + self.displayCeil, data.color, { 34, 50 }, 0.18, "ring")
    elseif name == "pop" then
        self:SyncBoard()
        for i, cell in ipairs(data.cells) do
            self:SpawnPop(cell, (i - 1) * 0.035, i)
        end
        local cx, cy = Centroid(data.cells, game, self.displayCeil)
        self:SpawnGlow(cx, cy, data.cells[1].color, { 30, 40 + #data.cells * 18 }, 0.4, "ring")
        self:SpawnText(cx, cy, "+" .. ns.FormatNumber(data.points), 15, 1, 0.9, 0.4, 34, 0.9)
        if data.combo >= 2 then
            self:SpawnText(W / 2, H * 0.55, L.COMBO:format(data.combo), 22, 1, 0.55, 0.15, 30, 1.1)
        end
        if #data.cells >= 6 then self:Shake(3, 0.2) end
    elseif name == "drop" then
        self:SyncBoard()
        for i, cell in ipairs(data.cells) do
            self:SpawnFall(cell, 0.12 + (i - 1) * 0.02)
        end
        local cx, cy = Centroid(data.cells, game, self.displayCeil)
        C_Timer.After(0.15, function() Media.Play("drop") end)
        self:SpawnText(cx, cy + 20, "+" .. ns.FormatNumber(data.points), 18, 0.5, 1, 0.6, 44, 1.1)
        if #data.cells >= 5 then self:Shake(4, 0.3) end
    elseif name == "ceiling" then
        Media.Play("ceiling")
        self:Shake(5, 0.4)
        self:SyncPips()
    elseif name == "warn" then
        Media.Play("warn")
        self:SyncPips()
    elseif name == "clear" then
        Media.Play("clear")
        self:PlayModelAnimation(68)
        for _ = 1, 10 do
            self:SpawnSparks(random(30, W - 30), random(40, 260), random(1, 6), 3)
        end
        self:SyncLauncher()
        self:SyncPips()
    elseif name == "over" then
        Media.Play("gameover")
        self:SyncBoard()
        self:Shake(6, 0.5)
    end
end

function Board:ApplyCeiling()
    local h = self.displayCeil
    if h >= 1 then
        self.ceiling:SetHeight(h)
        self.ceiling:SetTexCoord(0, 1, 1 - h / 512, 1)
        self.ceiling:Show()
    else
        self.ceiling:Hide()
    end
end

function Board:UpdateAim()
    local game = self.game
    local showDots = game.state == "PLAYING" and not game.shot
    local rotation = game.angle - math.pi / 2
    self.arrow:SetRotation(rotation)
    if not showDots then
        for _, dot in ipairs(self.dots) do dot:Hide() end
        return
    end
    if self.lastTraceAngle ~= game.angle or self.lastTraceCeil ~= game.drops or self.traceDirty then
        self.lastTraceAngle, self.lastTraceCeil, self.traceDirty = game.angle, game.drops, false
        self.trace = game:Trace(900)
    end
    local points = self.trace
    local spacing, offset = 15, 34 - (GetTime() * 30) % 15
    local index, travelled = 1, 0
    local c = Media.COLORS[game.current] or { 1, 1, 1 }
    for seg = 1, #points - 1 do
        local x1, y1 = points[seg][1], points[seg][2]
        local x2, y2 = points[seg + 1][1], points[seg + 1][2]
        local len = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
        while offset <= travelled + len and index <= #self.dots do
            local t = (offset - travelled) / len
            local dot = self.dots[index]
            Place(dot, x1 + (x2 - x1) * t, y1 + (y2 - y1) * t + self.displayCeil - game:CeilingY())
            dot:SetVertexColor(c[1], c[2], c[3])
            dot:SetAlpha(0.9 * (1 - index / #self.dots))
            dot:Show()
            index = index + 1
            offset = offset + spacing
        end
        travelled = travelled + len
    end
    for i = index, #self.dots do self.dots[i]:Hide() end
end

function Board:Update(dt)
    local game = self.game
    if not game then return end

    local target = game:CeilingY()
    if math.abs(self.displayCeil - target) > 0.1 then
        self.displayCeil = self.displayCeil + (target - self.displayCeil) * math.min(1, dt * 10)
        self:ApplyCeiling()
        self.traceDirty = true
    elseif self.displayCeil ~= target then
        self.displayCeil = target
        self:ApplyCeiling()
    end

    local ox, oy = 0, 0
    if self.shakeTime > 0 then
        self.shakeTime = self.shakeTime - dt
        local a = self.shakeAmp * math.max(0, self.shakeTime) / 0.4
        ox, oy = (random() - 0.5) * 2 * a, (random() - 0.5) * 2 * a
        if self.shakeTime <= 0 then self.shakeAmp = 0 end
    end
    local wobble = 0
    if game.state == "PLAYING" and game.shotsUntilDrop and game.shotsUntilDrop <= 1 then
        wobble = math.sin(GetTime() * 40) * 1.2
    end
    self.boardLayer:ClearAllPoints()
    self.boardLayer:SetPoint("TOPLEFT", self.field, "TOPLEFT", ox + wobble, -(self.displayCeil) + oy)

    if game.shot and self.shotBall then
        ShowBall(self.shotBall, game.shot.color, game.shot.x, game.shot.y + self.displayCeil - game:CeilingY(), D)
    end

    local danger = game.grid:LowestRow() + (game.drops or 0) >= Game.VISIBLE_ROWS - 2
    self.death:SetAlpha(danger and (0.5 + 0.5 * math.sin(GetTime() * 8)) or 0.35)

    self:UpdateAim()

    for i = #self.effects, 1, -1 do
        local e = self.effects[i]
        e.t = e.t + dt
        if not e.update(e, dt) then
            if e.finish then e.finish(e) end
            table.remove(self.effects, i)
        end
    end
end
