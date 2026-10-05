-- Game state and physics (pure logic, no WoW API).
-- Field coordinates: (0, 0) is the top-left corner of the playfield, y grows downwards.

local _, ns = ...

local Grid, Levels = ns.Grid, ns.Levels

local Game = {}
Game.__index = Game
ns.Game = Game

Game.COLS = 8
Game.RADIUS = 16
Game.VISIBLE_ROWS = 12
Game.WIDTH = Game.COLS * Game.RADIUS * 2
Game.HEIGHT = 400
Game.LAUNCH_Y = 372
Game.SHOT_SPEED = 780
Game.MIN_ANGLE = math.rad(8)
Game.HIT_FACTOR = 0.82
Game.MAX_COMBO = 5

function Game.New(random)
    local g = setmetatable({}, Game)
    g.random = random or math.random
    g.grid = Grid.New(Game.COLS, Game.VISIBLE_ROWS + 1, Game.RADIUS)
    g.rowHeight = g.grid.rowHeight
    g.deathY = Game.RADIUS * 2 + (Game.VISIBLE_ROWS - 1) * g.rowHeight
    g.launchX = Game.WIDTH / 2
    g.launchY = Game.LAUNCH_Y
    g.angle = math.pi / 2
    g.state = "READY"
    g.score = 0
    g.level = 1
    g.drops = 0
    g.shotsUntilDrop = 0
    g.onEvent = function() end
    return g
end

function Game:Emit(name, data)
    self.onEvent(name, data)
end

function Game:CeilingY()
    return self.drops * self.rowHeight
end

function Game:CellPosition(r, c)
    local x, y = self.grid:CellCenter(r, c)
    return x, y + self:CeilingY()
end

function Game:PickColor()
    local colors = self.grid:ColorsPresent()
    if #colors == 0 then return 1 end
    return colors[self.random(#colors)]
end

function Game:StartLevel(level, keepScore)
    self.level = level
    if not keepScore then self.score = 0 end
    local meta = Levels.Load(self.grid, level)
    self.dropInterval = meta.drop
    self.shotsUntilDrop = meta.drop
    self.drops = 0
    self.shots = 0
    self.combo = 0
    self.shot = nil
    self.current = self:PickColor()
    self.next = self:PickColor()
    self.state = "PLAYING"
    self:Emit("level", { level = level })
    self:Emit("board")
end

function Game:SetAim(angle)
    if angle < Game.MIN_ANGLE then angle = Game.MIN_ANGLE end
    if angle > math.pi - Game.MIN_ANGLE then angle = math.pi - Game.MIN_ANGLE end
    self.angle = angle
end

function Game:AimAt(x, y)
    local dx, dy = x - self.launchX, self.launchY - y
    if dy < 1 then dy = 1 end
    self:SetAim(math.atan2(dy, dx))
end

function Game:Swap()
    if self.state ~= "PLAYING" or self.shot then return end
    self.current, self.next = self.next, self.current
    self:Emit("swap")
end

function Game:Shoot()
    if self.state ~= "PLAYING" or self.shot then return end
    self.shot = {
        x = self.launchX,
        y = self.launchY,
        vx = math.cos(self.angle) * Game.SHOT_SPEED,
        vy = -math.sin(self.angle) * Game.SHOT_SPEED,
        color = self.current,
    }
    self.current = self.next
    self.next = self:PickColor()
    self.shots = self.shots + 1
    self:Emit("shoot", self.shot)
end

-- Advances a body by one substep. Returns "wall", "hit" or nil.
function Game:Step(body, h)
    local r = Game.RADIUS
    body.x = body.x + body.vx * h
    body.y = body.y + body.vy * h
    local bounced
    if body.x < r then
        body.x = 2 * r - body.x
        body.vx = -body.vx
        bounced = true
    elseif body.x > Game.WIDTH - r then
        body.x = 2 * (Game.WIDTH - r) - body.x
        body.vx = -body.vx
        bounced = true
    end
    if self:Collides(body.x, body.y) then return "hit" end
    if bounced then return "wall" end
end

function Game:Collides(x, y)
    local ceil = self:CeilingY()
    local localY = y - ceil
    if localY <= Game.RADIUS then return true end
    local grid = self.grid
    local limit = (grid.diameter * Game.HIT_FACTOR) ^ 2
    local approxRow = math.floor((localY - grid.radius) / grid.rowHeight + 0.5)
    for r = approxRow - 1, approxRow + 1 do
        if r >= 0 and r < grid.rows then
            local row = grid.cells[r]
            for c = 0, grid:RowWidth(r) - 1 do
                if row[c] then
                    local cx, cy = grid:CellCenter(r, c)
                    if (cx - x) ^ 2 + (cy - localY) ^ 2 < limit then return true end
                end
            end
        end
    end
    return false
end

function Game:Update(dt)
    if self.state ~= "PLAYING" or not self.shot then return end
    local shot = self.shot
    local distance = Game.SHOT_SPEED * dt
    local steps = math.max(1, math.ceil(distance / (Game.RADIUS * 0.4)))
    local h = dt / steps
    for _ = 1, steps do
        local result = self:Step(shot, h)
        if result == "wall" then
            self:Emit("bounce", shot)
        elseif result == "hit" then
            self:Land(shot)
            return
        end
    end
end

-- Polyline for the aim guide: start, wall bounces, end point.
function Game:Trace(maxLength)
    local body = {
        x = self.launchX,
        y = self.launchY,
        vx = math.cos(self.angle),
        vy = -math.sin(self.angle),
    }
    local points = { { body.x, body.y } }
    local h = Game.RADIUS * 0.4
    local travelled = 0
    while travelled < maxLength do
        local result = self:Step(body, h)
        travelled = travelled + h
        if result == "wall" then
            points[#points + 1] = { body.x, body.y }
        elseif result == "hit" then
            break
        end
    end
    points[#points + 1] = { body.x, body.y }
    return points
end

local function cellsToPayload(game, cells, colors)
    local payload = {}
    for i = 1, #cells do
        local x, y = game:CellPosition(cells[i][1], cells[i][2])
        payload[i] = { x = x, y = y, color = colors[i] }
    end
    return payload
end

function Game:RemoveCells(cells)
    local colors = {}
    for i = 1, #cells do
        colors[i] = self.grid:Get(cells[i][1], cells[i][2])
    end
    local payload = cellsToPayload(self, cells, colors)
    for i = 1, #cells do
        self.grid:Set(cells[i][1], cells[i][2], nil)
    end
    return payload
end

function Game:AddScore(points)
    self.score = self.score + points
    self:Emit("score", { score = self.score, points = points })
end

function Game:Land(shot)
    self.shot = nil
    local grid = self.grid
    local r, c = grid:NearestEmpty(shot.x, shot.y - self:CeilingY())
    if not r then
        self:GameOver()
        return
    end
    grid:Set(r, c, shot.color)
    local lx, ly = self:CellPosition(r, c)
    self:Emit("land", { r = r, c = c, x = lx, y = ly, color = shot.color })

    local group = grid:FindGroup(r, c)
    if #group >= 3 then
        self.combo = math.min(self.combo + 1, Game.MAX_COMBO)
        local popped = self:RemoveCells(group)
        local popPoints = #popped * 10 * self.combo
        self:Emit("pop", { cells = popped, points = popPoints, combo = self.combo })
        local dropped = self:RemoveCells(grid:FindFloating())
        local dropPoints = 0
        if #dropped > 0 then
            dropPoints = 10 * 2 ^ math.min(#dropped, 10) * self.combo
            self:Emit("drop", { cells = dropped, points = dropPoints })
        end
        self:AddScore(popPoints + dropPoints)
    else
        self.combo = 0
    end

    if grid:Count() == 0 then
        local par = 10 + self.level * 2
        local bonus = 500 + math.max(0, par - self.shots) * 100
        self:AddScore(bonus)
        self.state = "CLEAR"
        self:Emit("clear", { bonus = bonus, level = self.level })
        return
    end

    self.shotsUntilDrop = self.shotsUntilDrop - 1
    if self.shotsUntilDrop <= 0 then
        self.drops = self.drops + 1
        self.shotsUntilDrop = self.dropInterval
        self:Emit("ceiling", { drops = self.drops })
    elseif self.shotsUntilDrop <= 2 then
        self:Emit("warn", { shotsLeft = self.shotsUntilDrop })
    end

    if self:IsOverflowing() then
        self:GameOver()
        return
    end

    -- Never hand out a color that no longer exists on the board.
    local present = {}
    for _, color in ipairs(grid:ColorsPresent()) do present[color] = true end
    if not present[self.current] then self.current = self:PickColor() end
    if not present[self.next] then self.next = self:PickColor() end
    self:Emit("board")
end

function Game:IsOverflowing()
    return self.grid:LowestRow() + self.drops >= Game.VISIBLE_ROWS
end

function Game:GameOver()
    self.state = "OVER"
    self:Emit("over", { score = self.score, level = self.level })
end

function Game:Pause()
    if self.state == "PLAYING" then
        self.state = "PAUSED"
        self:Emit("pause")
    end
end

function Game:Resume()
    if self.state == "PAUSED" then
        self.state = "PLAYING"
        self:Emit("resume")
    end
end
