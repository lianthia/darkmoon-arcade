-- Flappy Griffin game state and physics (pure logic, no WoW API).
-- Field coordinates: (0, 0) is the top-left corner, y grows downwards.

local _, ns = ...

local FG = ns.FlappyGriffin or {}
ns.FlappyGriffin = FG

local Game = {}
Game.__index = Game
FG.Game = Game

Game.WIDTH, Game.HEIGHT = 432, 462
Game.GROUND = 46
Game.GRIFFIN_X = 120
Game.RADIUS = 15
Game.GRAVITY = 1500
Game.FLAP = -430
Game.MAX_FALL = 640
Game.PILLAR_W = 66
Game.SPACING = 220
Game.SPEED_START, Game.SPEED_MAX, Game.SPEED_STEP = 150, 235, 2
Game.GAP_START, Game.GAP_MIN, Game.GAP_STEP = 152, 112, 1.2
Game.GAP_MARGIN = 50
Game.MAX_GAP_SHIFT = 170
Game.TICKET_CHANCE = 35
Game.TICKET_POINTS = 2
Game.TICKET_RADIUS = 13

Game.MEDALS = {
    { score = 100, key = "darkmoon" },
    { score = 50, key = "gold" },
    { score = 25, key = "silver" },
    { score = 10, key = "bronze" },
}

function Game.Medal(score)
    for _, medal in ipairs(Game.MEDALS) do
        if score >= medal.score then return medal.key end
    end
end

-- The next medal above `score`, or nil once the best one is reached.
function Game.NextMedal(score)
    for i = #Game.MEDALS, 1, -1 do
        local medal = Game.MEDALS[i]
        if score < medal.score then return medal end
    end
end

function Game.New(random)
    local g = setmetatable({}, Game)
    g.random = random or math.random
    g.onEvent = function() end
    g:Reset()
    return g
end

function Game:Emit(name, data)
    self.onEvent(name, data)
end

function Game:Reset()
    self.state = "READY"
    self.y = Game.HEIGHT * 0.42
    self.vy = 0
    self.time = 0
    self.distance = 0
    self.score = 0
    self.pillars = {}
    self.lastGapY = nil
end

function Game:Speed()
    return math.min(Game.SPEED_MAX, Game.SPEED_START + self.score * Game.SPEED_STEP)
end

function Game:Gap()
    return math.max(Game.GAP_MIN, Game.GAP_START - self.score * Game.GAP_STEP)
end

function Game:Flap()
    if self.state == "READY" then
        self.state = "PLAYING"
        self:Emit("start")
    end
    if self.state ~= "PLAYING" then return end
    self.vy = Game.FLAP
    self:Emit("flap")
end

function Game:SpawnPillar()
    local gap = self:Gap()
    local low = Game.GAP_MARGIN + gap / 2
    local high = Game.HEIGHT - Game.GROUND - Game.GAP_MARGIN - gap / 2
    if self.lastGapY then
        low = math.max(low, self.lastGapY - Game.MAX_GAP_SHIFT)
        high = math.min(high, self.lastGapY + Game.MAX_GAP_SHIFT)
    end
    local gapY = low + (self.random(1000) - 1) / 999 * (high - low)
    self.lastGapY = gapY
    local pillar = { x = Game.WIDTH + Game.PILLAR_W / 2, gapY = gapY, gap = gap }
    if self.random(100) <= Game.TICKET_CHANCE then
        pillar.ticket = { y = gapY + (self.random(3) - 2) * gap * 0.25 }
    end
    self.pillars[#self.pillars + 1] = pillar
    self:Emit("spawn", pillar)
end

local function CircleHitsRect(cx, cy, r, left, top, right, bottom)
    if bottom <= top then return false end
    local nx = math.max(left, math.min(cx, right))
    local ny = math.max(top, math.min(cy, bottom))
    return (cx - nx) ^ 2 + (cy - ny) ^ 2 < r * r
end

function Game:HitsPillar(pillar)
    local half = Game.PILLAR_W / 2
    local left, right = pillar.x - half, pillar.x + half
    local r = Game.RADIUS
    return CircleHitsRect(Game.GRIFFIN_X, self.y, r, left, -1000, right, pillar.gapY - pillar.gap / 2)
        or CircleHitsRect(Game.GRIFFIN_X, self.y, r, left, pillar.gapY + pillar.gap / 2, right, Game.HEIGHT)
end

function Game:Fall(dt)
    self.vy = math.min(Game.MAX_FALL, self.vy + Game.GRAVITY * dt)
    self.y = self.y + self.vy * dt
    if self.y < Game.RADIUS then
        self.y = Game.RADIUS
        self.vy = 0
    end
    return self.y + Game.RADIUS >= Game.HEIGHT - Game.GROUND
end

function Game:Crash()
    self.state = "DYING"
    self.vy = math.max(self.vy, -150)
    self:Emit("hit")
end

function Game:Finish()
    self.y = Game.HEIGHT - Game.GROUND - Game.RADIUS
    self.state = "OVER"
    self:Emit("over", { score = self.score, medal = Game.Medal(self.score) })
end

function Game:Update(dt)
    self.time = self.time + dt
    if self.state == "READY" then
        self.y = Game.HEIGHT * 0.42 + math.sin(self.time * 4) * 6
        self.distance = self.distance + Game.SPEED_START * dt
    elseif self.state == "PLAYING" then
        local speed = self:Speed()
        self.distance = self.distance + speed * dt
        local last = self.pillars[#self.pillars]
        if not last or last.x <= Game.WIDTH - Game.SPACING then self:SpawnPillar() end

        for i = #self.pillars, 1, -1 do
            local pillar = self.pillars[i]
            pillar.x = pillar.x - speed * dt
            if not pillar.passed and pillar.x + Game.PILLAR_W / 2 < Game.GRIFFIN_X - Game.RADIUS then
                pillar.passed = true
                self.score = self.score + 1
                self:Emit("score", { score = self.score, points = 1 })
                if pillar.ticket and not pillar.ticket.taken then self:Emit("ticketMissed") end
            end
            local ticket = pillar.ticket
            if ticket and not ticket.taken then
                local d2 = (pillar.x - Game.GRIFFIN_X) ^ 2 + (ticket.y - self.y) ^ 2
                if d2 < (Game.RADIUS + Game.TICKET_RADIUS) ^ 2 then
                    ticket.taken = true
                    self.score = self.score + Game.TICKET_POINTS
                    self:Emit("ticket", { x = pillar.x, y = ticket.y, score = self.score })
                end
            end
            if pillar.x < -Game.PILLAR_W then
                table.remove(self.pillars, i)
                self:Emit("despawn", pillar)
            end
        end

        if self:Fall(dt) then
            self:Crash()
            self:Finish()
            return
        end
        for _, pillar in ipairs(self.pillars) do
            if self:HitsPillar(pillar) then
                self:Crash()
                return
            end
        end
    elseif self.state == "DYING" then
        if self:Fall(dt) then self:Finish() end
    end
end

function Game:Pause()
    if self.state == "PLAYING" or self.state == "READY" then
        self.pausedFrom = self.state
        self.state = "PAUSED"
    end
end

function Game:Resume()
    if self.state == "PAUSED" then
        self.state = self.pausedFrom or "PLAYING"
    end
end
