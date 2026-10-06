-- Spellbounce: physics and rules (pure logic, no WoW API).
-- An orb is launched from the top, bounces through the pegs and lights them; lit pegs vanish
-- when the shot ends. Clearing every target peg clears the map.

local _, ns = ...

local SB = ns.Spellbounce or {}
ns.Spellbounce = SB

local Maps = SB.Maps

local Game = {}
Game.__index = Game
SB.Game = Game

Game.WIDTH, Game.HEIGHT = 432, 462
Game.LAUNCH_X, Game.LAUNCH_Y = 216, 34
Game.BALL_R, Game.PEG_R, Game.BUMPER_R = 7, 9, 13
Game.GRAVITY, Game.SPEED = 560, 470
Game.ORBS = 10
Game.WELL_Y, Game.WELL_W = 444, 84
Game.MIN_ANGLE, Game.MAX_ANGLE = 0.06, math.pi - 0.06

Game.POINTS = { blue = 10, target = 100, power = 50, gold = 500 }
Game.FINALE_POINTS = 100
Game.ORB_BONUS = 1000
Game.MULTIPLIERS = { 1, 2, 3, 5 }
-- Lighting this many pegs with one shot earns an extra orb.
Game.BONUS_HITS = 10

-- Classes in menu order and the map you must have reached to unlock them.
Game.CLASSES = { "mage", "hunter", "priest", "shaman", "warlock", "rogue" }
Game.UNLOCK = { mage = 1, hunter = 1, priest = 1, shaman = 3, warlock = 5, rogue = 8 }

local STEP = 1 / 240
local REST, WALL_REST = 0.72, 0.9
local BUMPER_SPEED = 330
local ARCANE_RADIUS = 96
local CHAIN_JUMPS, CHAIN_RANGE = 5, 150
local FIRE_BOLTS = 5
local VANISH_TIME = 2.4
local SHIELD_SPEED = 430
local STUCK_SPEED, STUCK_TIME, MAX_FLIGHT, MAX_PEG_HITS = 40, 0.8, 14, 14

function Game.IsUnlocked(class, progress)
    return (Game.UNLOCK[class] or math.huge) <= (progress or 1)
end

function Game.New(random)
    local g = setmetatable({}, Game)
    g.random = random or math.random
    g.onEvent = function() end
    g.state = "READY"
    g.class = "mage"
    g.score = 0
    g.level = 1
    g.angle = math.pi / 2
    g.time = 0
    g.pegs = {}
    g.balls = {}
    g.orbs = Game.ORBS
    g.targetsTotal, g.targetsHit = 0, 0
    return g
end

function Game:Emit(name, data)
    self.onEvent(name, data)
end

function Game:MapIndex()
    return (self.level - 1) % Maps.COUNT + 1
end

-- Every lap through the ten maps adds more targets.
function Game:Lap()
    return math.floor((self.level - 1) / Maps.COUNT)
end

local function Shuffle(list, random)
    for i = #list, 2, -1 do
        local j = random(i)
        list[i], list[j] = list[j], list[i]
    end
end

function Game:LoadLevel(level)
    self.level = level
    self.pegs = Maps.Build(self:MapIndex())
    local free = {}
    for i, peg in ipairs(self.pegs) do
        peg.id = i
        peg.kind = peg.bumper and "bumper" or "blue"
        if not peg.bumper then free[#free + 1] = peg end
    end
    Shuffle(free, self.random)
    local targets = math.min(20 + 2 * self:Lap(), math.floor(#free * 0.45))
    for i, peg in ipairs(free) do
        if i <= targets then
            peg.kind = "target"
        elseif i <= targets + 2 then
            peg.kind = "power"
        elseif i == targets + 3 then
            peg.kind = "gold"
        end
    end
    self.targetsTotal, self.targetsHit = targets, 0
    self.orbs = Game.ORBS
    self.balls = {}
    self.shot = nil
    self.time = 0
    self.state = "PLAYING"
    self:Emit("level", { level = level })
end

function Game:StartRun(level, class)
    self.score = 0
    self.class = class or self.class
    self:LoadLevel(level or 1)
end

function Game:Pause()
    if self.state == "PLAYING" then self.state = "PAUSED" end
end

function Game:Resume()
    if self.state == "PAUSED" then self.state = "PLAYING" end
end

function Game:Multiplier()
    local share = self.targetsTotal > 0 and self.targetsHit / self.targetsTotal or 0
    if share >= 0.85 then return Game.MULTIPLIERS[4] end
    if share >= 0.65 then return Game.MULTIPLIERS[3] end
    if share >= 0.4 then return Game.MULTIPLIERS[2] end
    return Game.MULTIPLIERS[1]
end

function Game:TargetsLeft()
    return self.targetsTotal - self.targetsHit
end

function Game:WellX()
    local travel = Game.WIDTH / 2 - Game.WELL_W / 2 - 6
    return Game.WIDTH / 2 + math.sin(self.time * 0.9) * travel
end

-- Aiming ------------------------------------------------------------------------------

function Game:SetAim(angle)
    self.angle = math.max(Game.MIN_ANGLE, math.min(Game.MAX_ANGLE, angle))
end

function Game:AimAt(x, y)
    local dx, dy = x - Game.LAUNCH_X, y - Game.LAUNCH_Y
    if dy < 1 then dy = 1 end
    self:SetAim(math.atan2(dy, dx))
end

function Game:CanShoot()
    return self.state == "PLAYING" and #self.balls == 0 and self.orbs > 0
end

local function NewBall(x, y, vx, vy)
    return { x = x, y = y, vx = vx, vy = vy, age = 0, slow = 0, ghost = 0 }
end

function Game:Shoot()
    if not self:CanShoot() then return false end
    self.orbs = self.orbs - 1
    local vx, vy = math.cos(self.angle) * Game.SPEED, math.sin(self.angle) * Game.SPEED
    self.balls[1] = NewBall(Game.LAUNCH_X, Game.LAUNCH_Y, vx, vy)
    self.shot = { points = 0, hits = 0, targets = 0, caught = false, shields = 0, powers = 0 }
    self:Emit("shoot")
    return true
end

-- Path preview: the launch arc up to the first peg it touches.
function Game:Trace(maxTime)
    local x, y = Game.LAUNCH_X, Game.LAUNCH_Y
    local vx, vy = math.cos(self.angle) * Game.SPEED, math.sin(self.angle) * Game.SPEED
    local points = { { x, y } }
    local t, sample = 0, 0
    while t < maxTime do
        vy = vy + Game.GRAVITY * STEP
        x, y = x + vx * STEP, y + vy * STEP
        if x < Game.BALL_R or x > Game.WIDTH - Game.BALL_R then
            vx = -vx
            x = math.max(Game.BALL_R, math.min(Game.WIDTH - Game.BALL_R, x))
        end
        t, sample = t + STEP, sample + STEP
        for _, peg in ipairs(self.pegs) do
            if not peg.gone then
                local r = Game.BALL_R + (peg.bumper and Game.BUMPER_R or Game.PEG_R)
                if (x - peg.x) ^ 2 + (y - peg.y) ^ 2 < r * r then
                    points[#points + 1] = { x, y }
                    return points
                end
            end
        end
        if y > Game.HEIGHT then break end
        if sample >= 0.02 then
            sample = 0
            points[#points + 1] = { x, y }
        end
    end
    points[#points + 1] = { x, y }
    return points
end

-- Pegs and powers -------------------------------------------------------------------------

function Game:Light(peg, source)
    if peg.lit or peg.gone or peg.bumper then return false end
    local points = Game.POINTS[peg.kind] * self:Multiplier()
    peg.lit = true
    if peg.kind == "target" then
        self.targetsHit = self.targetsHit + 1
        self.shot.targets = self.shot.targets + 1
    end
    self.score = self.score + points
    self.shot.points = self.shot.points + points
    self.shot.hits = self.shot.hits + 1
    self:Emit("hit", { peg = peg, points = points, chain = self.shot.hits, source = source })
    if self.targetsHit == self.targetsTotal and peg.kind == "target" then
        self:Emit("lastTarget", { peg = peg })
    end
    if peg.kind == "power" then self:TriggerPower(peg) end
    return true
end

function Game:Unlit(except)
    local list = {}
    for _, peg in ipairs(self.pegs) do
        if not peg.lit and not peg.gone and not peg.bumper and peg ~= except then list[#list + 1] = peg end
    end
    return list
end

function Game:TriggerPower(origin)
    local class, affected = self.class, {}
    local ball = self.currentBall
    self.shot.powers = self.shot.powers + 1
    if class == "mage" then
        for _, peg in ipairs(self:Unlit(origin)) do
            if (peg.x - origin.x) ^ 2 + (peg.y - origin.y) ^ 2 <= ARCANE_RADIUS ^ 2 then affected[#affected + 1] = peg end
        end
    elseif class == "shaman" then
        local current = origin
        for _ = 1, CHAIN_JUMPS do
            local best, bestDist
            for _, peg in ipairs(self:Unlit(origin)) do
                local d = (peg.x - current.x) ^ 2 + (peg.y - current.y) ^ 2
                local taken = false
                for _, a in ipairs(affected) do if a == peg then taken = true end end
                if not taken and d <= CHAIN_RANGE ^ 2 and (not bestDist or d < bestDist) then best, bestDist = peg, d end
            end
            if not best then break end
            affected[#affected + 1] = best
            current = best
        end
    elseif class == "warlock" then
        local pool = self:Unlit(origin)
        Shuffle(pool, self.random)
        for i = 1, math.min(FIRE_BOLTS, #pool) do affected[i] = pool[i] end
    elseif class == "hunter" and ball then
        local speed = math.max(260, math.sqrt(ball.vx ^ 2 + ball.vy ^ 2))
        local angle = math.atan2(ball.vy, ball.vx)
        for _, offset in ipairs({ -0.45, 0.45 }) do
            self.balls[#self.balls + 1] = NewBall(ball.x, ball.y, math.cos(angle + offset) * speed, math.sin(angle + offset) * speed)
        end
    elseif class == "priest" then
        self.shot.shields = self.shot.shields + 1
    elseif class == "rogue" and ball then
        ball.ghost = VANISH_TIME
    end
    self:Emit("power", { class = class, x = origin.x, y = origin.y, pegs = affected, ball = ball })
    for _, peg in ipairs(affected) do self:Light(peg, class) end
end

-- Physics ---------------------------------------------------------------------------------

function Game:Collide(ball, peg)
    local radius = peg.bumper and Game.BUMPER_R or Game.PEG_R
    local dx, dy = ball.x - peg.x, ball.y - peg.y
    local rr = Game.BALL_R + radius
    if dx > rr or dx < -rr or dy > rr or dy < -rr then return end
    local d2 = dx * dx + dy * dy
    if d2 >= rr * rr then return end
    if ball.ghost > 0 and not peg.bumper then
        self:Light(peg, "ghost")
        return
    end
    local d = math.sqrt(d2)
    local nx, ny = 0, -1
    if d > 0 then nx, ny = dx / d, dy / d end
    ball.x, ball.y = peg.x + nx * rr, peg.y + ny * rr
    local vn = ball.vx * nx + ball.vy * ny
    if vn < 0 then
        local e = peg.bumper and 1 or REST
        ball.vx = ball.vx - (1 + e) * vn * nx
        ball.vy = ball.vy - (1 + e) * vn * ny
        if peg.bumper then
            local speed = math.sqrt(ball.vx ^ 2 + ball.vy ^ 2)
            if speed < BUMPER_SPEED then
                ball.vx, ball.vy = ball.vx / speed * BUMPER_SPEED, ball.vy / speed * BUMPER_SPEED
            end
            self:Emit("bump", { peg = peg })
        end
    end
    if not peg.bumper then
        peg.hits = (peg.hits or 0) + 1
        if not self:Light(peg, "ball") then
            self:Emit("rehit", { peg = peg })
            if peg.hits >= MAX_PEG_HITS then self:Unstick() end
        end
    end
end

-- Lit pegs that hold a ball in place vanish early.
function Game:Unstick()
    local removed = {}
    for _, peg in ipairs(self.pegs) do
        if peg.lit and not peg.gone then
            peg.gone = true
            removed[#removed + 1] = peg
        end
    end
    for _, ball in ipairs(self.balls) do ball.slow, ball.age = 0, 0 end
    if #removed > 0 then self:Emit("unstick", { pegs = removed }) end
end

function Game:StepBall(ball, dt)
    local R, W = Game.BALL_R, Game.WIDTH
    ball.vy = ball.vy + Game.GRAVITY * dt
    ball.x, ball.y = ball.x + ball.vx * dt, ball.y + ball.vy * dt
    ball.age = ball.age + dt
    if ball.ghost > 0 then ball.ghost = ball.ghost - dt end
    if ball.x < R then
        ball.x, ball.vx = R, math.abs(ball.vx) * WALL_REST
    elseif ball.x > W - R then
        ball.x, ball.vx = W - R, -math.abs(ball.vx) * WALL_REST
    end
    if ball.y < R then ball.y, ball.vy = R, math.abs(ball.vy) * WALL_REST end
    self.currentBall = ball
    for _, peg in ipairs(self.pegs) do
        if not peg.gone then self:Collide(ball, peg) end
    end
    self.currentBall = nil

    local speed2 = ball.vx * ball.vx + ball.vy * ball.vy
    if speed2 < STUCK_SPEED * STUCK_SPEED then ball.slow = ball.slow + dt else ball.slow = 0 end
    if ball.slow > STUCK_TIME or ball.age > MAX_FLIGHT then self:Unstick() end

    if ball.vy > 0 and ball.y >= Game.WELL_Y and ball.y - ball.vy * dt < Game.WELL_Y
        and math.abs(ball.x - self:WellX()) <= Game.WELL_W / 2 - 4 then
        return "caught"
    end
    if ball.y > Game.HEIGHT - R - 2 and self.shot.shields > 0 then
        self.shot.shields = self.shot.shields - 1
        ball.y = Game.HEIGHT - R - 2
        ball.vy = -math.max(math.abs(ball.vy), SHIELD_SPEED)
        self:Emit("shield", { x = ball.x })
    end
    if ball.y > Game.HEIGHT + R then return "lost" end
end

function Game:Update(dt)
    if self.state ~= "PLAYING" then return end
    dt = math.min(dt, 0.05)
    self.time = self.time + dt
    if #self.balls == 0 then return end
    local steps = math.ceil(dt / STEP)
    local h = dt / steps
    for _ = 1, steps do
        for i = #self.balls, 1, -1 do
            local ball = self.balls[i]
            local result = self:StepBall(ball, h)
            if result == "caught" then
                table.remove(self.balls, i)
                if not self.shot.caught then
                    self.shot.caught = true
                    self.orbs = self.orbs + 1
                end
                self:Emit("catch", { x = ball.x })
            elseif result == "lost" then
                table.remove(self.balls, i)
                self:Emit("lost", { x = ball.x })
            end
        end
        if #self.balls == 0 then break end
    end
    if #self.balls == 0 then self:EndShot() end
end

function Game:EndShot()
    local shot = self.shot
    local removed = {}
    for _, peg in ipairs(self.pegs) do
        if peg.lit and not peg.gone then
            peg.gone = true
            removed[#removed + 1] = peg
        end
    end
    self.shot = nil
    local bonus = shot.hits >= Game.BONUS_HITS and self.targetsHit < self.targetsTotal
    if bonus then self.orbs = self.orbs + 1 end
    self:Emit("shotEnd", {
        pegs = removed, points = shot.points, hits = shot.hits, caught = shot.caught, powers = shot.powers, bonusOrb = bonus,
    })
    if self.targetsHit >= self.targetsTotal then
        self:Clear()
    elseif self.orbs <= 0 then
        self.state = "OVER"
        self:Emit("over", { score = self.score, level = self.level })
    end
end

-- The finale: every remaining peg goes up in fireworks, unused orbs pay a bonus.
function Game:Clear()
    local remaining = {}
    for _, peg in ipairs(self.pegs) do
        if not peg.gone and not peg.bumper then remaining[#remaining + 1] = peg end
    end
    local pegBonus = #remaining * Game.FINALE_POINTS
    local orbBonus = self.orbs * Game.ORB_BONUS
    self.score = self.score + pegBonus + orbBonus
    self.state = "CLEAR"
    self:Emit("clear", { pegs = remaining, pegBonus = pegBonus, orbBonus = orbBonus, orbsLeft = self.orbs, level = self.level })
end
