-- Jewels of Uldum: match-three rules (pure logic, no WoW API).
-- A move resolves completely and returns the list of steps the UI replays as animations.

local _, ns = ...

local JU = ns.JewelsOfUldum or {}
ns.JewelsOfUldum = JU

local Game = {}
Game.__index = Game
JU.Game = Game

Game.SIZE = 8
Game.COLORS = 7
Game.PRISM = 0
Game.BLITZ_TIME = 90
Game.MODES = { "classic", "blitz" }

local RUN_POINTS = { [3] = 50, [4] = 100 }
local LONG_RUN_POINTS = 250
local EXTRA_GEM_POINTS = 20

function Game.LevelTarget(level)
    return 1000 + (level - 1) * 750
end

function Game.New(random)
    local g = setmetatable({}, Game)
    g.random = random or math.random
    g.onEvent = function() end
    g.state = "READY"
    g.mode = "classic"
    g.score = 0
    g.level = 1
    g.levelPoints = 0
    g.board = {}
    return g
end

function Game:Emit(name, data)
    self.onEvent(name, data)
end

function Game:At(r, c)
    local row = self.board[r]
    return row and row[c]
end

function Game:RandomGem()
    return { color = self.random(Game.COLORS) }
end

local function SameColor(a, b)
    return a and b and a.color ~= Game.PRISM and a.color == b.color
end

-- Runs of three or more equal colors: { color, dir = "h"|"v", cells = { {r, c}, ... } }.
function Game:FindRuns()
    local runs, n = {}, Game.SIZE
    for r = 1, n do
        local c = 1
        while c <= n do
            local length = 1
            while c + length <= n and SameColor(self:At(r, c), self:At(r, c + length)) do length = length + 1 end
            if length >= 3 then
                local cells = {}
                for i = 0, length - 1 do cells[#cells + 1] = { r, c + i } end
                runs[#runs + 1] = { color = self:At(r, c).color, dir = "h", cells = cells }
            end
            c = c + length
        end
    end
    for c = 1, n do
        local r = 1
        while r <= n do
            local length = 1
            while r + length <= n and SameColor(self:At(r, c), self:At(r + length, c)) do length = length + 1 end
            if length >= 3 then
                local cells = {}
                for i = 0, length - 1 do cells[#cells + 1] = { r + i, c } end
                runs[#runs + 1] = { color = self:At(r, c).color, dir = "v", cells = cells }
            end
            r = r + length
        end
    end
    return runs
end

local function Key(r, c) return r * 16 + c end

function Game:Fill()
    repeat
        for r = 1, Game.SIZE do
            self.board[r] = {}
            for c = 1, Game.SIZE do
                local gem
                repeat
                    gem = self:RandomGem()
                    local left = c > 2 and SameColor(gem, self.board[r][c - 1]) and SameColor(gem, self.board[r][c - 2])
                    local up = r > 2 and SameColor(gem, self.board[r - 1][c]) and SameColor(gem, self.board[r - 2][c])
                until not left and not up
                self.board[r][c] = gem
            end
        end
    until self:FindMove()
end

function Game:Start(mode)
    self.mode = mode or self.mode
    self.score = 0
    self.level = 1
    self.levelPoints = 0
    self.timeLeft = Game.BLITZ_TIME
    self.state = "PLAYING"
    self:Fill()
    self:Emit("start", { mode = self.mode })
end

local function Adjacent(r1, c1, r2, c2)
    return math.abs(r1 - r2) + math.abs(c1 - c2) == 1
end

local function SwapCells(board, r1, c1, r2, c2)
    board[r1][c1], board[r2][c2] = board[r2][c2], board[r1][c1]
end

-- First move that creates a match or uses a prism, or nil.
function Game:FindMove()
    local n = Game.SIZE
    for r = 1, n do
        for c = 1, n do
            for _, d in ipairs({ { 0, 1 }, { 1, 0 } }) do
                local r2, c2 = r + d[1], c + d[2]
                if r2 <= n and c2 <= n then
                    local a, b = self.board[r][c], self.board[r2][c2]
                    if a.color == Game.PRISM or b.color == Game.PRISM then return { r, c, r2, c2 } end
                    SwapCells(self.board, r, c, r2, c2)
                    local found = #self:FindRuns() > 0
                    SwapCells(self.board, r, c, r2, c2)
                    if found then return { r, c, r2, c2 } end
                end
            end
        end
    end
end

function Game:Multiplier(cascade)
    return cascade * (self.mode == "classic" and self.level or 1)
end

-- Adds every gem caught by exploding power gems to `clear` (chains through other power gems).
function Game:Explode(clear, explosions)
    local queue = {}
    for key, cell in pairs(clear) do
        if cell.gem.special == "power" then queue[#queue + 1] = cell end
    end
    local extra = 0
    while #queue > 0 do
        local cell = table.remove(queue)
        explosions[#explosions + 1] = { cell.r, cell.c }
        for dr = -1, 1 do
            for dc = -1, 1 do
                local r, c = cell.r + dr, cell.c + dc
                local gem = self:At(r, c)
                if gem and not clear[Key(r, c)] then
                    local entry = { r = r, c = c, gem = gem }
                    clear[Key(r, c)] = entry
                    extra = extra + 1
                    if gem.special == "power" then queue[#queue + 1] = entry end
                end
            end
        end
    end
    return extra
end

function Game:ApplyClear(clear, created, cascade, basePoints, extra, explosions, kind)
    local cells = {}
    for _, cell in pairs(clear) do
        cells[#cells + 1] = { r = cell.r, c = cell.c, color = cell.gem.color, special = cell.gem.special }
        self.board[cell.r][cell.c] = nil
    end
    table.sort(cells, function(a, b) return a.r * 16 + a.c < b.r * 16 + b.c end)
    for _, spec in ipairs(created) do
        self.board[spec.r][spec.c] = { color = spec.color, special = spec.special }
    end
    local points = (basePoints + extra * EXTRA_GEM_POINTS) * self:Multiplier(cascade)
    self:AddPoints(points)
    return { type = "clear", kind = kind, cells = cells, created = created, cascade = cascade,
        points = points, explosions = explosions }
end

function Game:AddPoints(points)
    self.score = self.score + points
    if self.mode ~= "classic" then return end
    self.levelPoints = self.levelPoints + points
    while self.levelPoints >= Game.LevelTarget(self.level) do
        self.levelPoints = self.levelPoints - Game.LevelTarget(self.level)
        self.level = self.level + 1
        self.pendingLevelUp = true
    end
end

function Game:Gravity()
    local moves, spawns = {}, {}
    for c = 1, Game.SIZE do
        local write = Game.SIZE
        for r = Game.SIZE, 1, -1 do
            local gem = self.board[r][c]
            if gem then
                if r ~= write then
                    self.board[write][c] = gem
                    self.board[r][c] = nil
                    moves[#moves + 1] = { from = r, to = write, c = c }
                end
                write = write - 1
            end
        end
        for r = write, 1, -1 do
            local gem = self:RandomGem()
            self.board[r][c] = gem
            spawns[#spawns + 1] = { r = r, c = c, color = gem.color, above = write - r + 1 }
        end
    end
    return { type = "fall", moves = moves, spawns = spawns }
end

-- Clears matches until the board settles. `focus` marks the swapped cells for special placement.
function Game:Cascade(steps, focus, cascade)
    while true do
        local runs = self:FindRuns()
        if #runs == 0 then break end
        cascade = cascade + 1
        local clear, created, base = {}, {}, 0
        local count = {}
        for _, run in ipairs(runs) do
            local length = #run.cells
            base = base + (RUN_POINTS[length] or LONG_RUN_POINTS)
            for _, cell in ipairs(run.cells) do
                local key = Key(cell[1], cell[2])
                count[key] = (count[key] or 0) + 1
                clear[key] = { r = cell[1], c = cell[2], gem = self.board[cell[1]][cell[2]] }
            end
        end
        local reserved = {}
        local function Create(run, special, color)
            local spot
            for _, cell in ipairs(run.cells) do
                if focus and focus[Key(cell[1], cell[2])] and not reserved[Key(cell[1], cell[2])] then spot = cell end
            end
            spot = spot or run.cells[math.ceil(#run.cells / 2)]
            local key = Key(spot[1], spot[2])
            if reserved[key] then return end
            reserved[key] = true
            created[#created + 1] = { r = spot[1], c = spot[2], color = color, special = special }
        end
        for _, run in ipairs(runs) do
            if #run.cells >= 5 then
                Create(run, "prism", Game.PRISM)
            elseif #run.cells == 4 then
                Create(run, "power", run.color)
            end
        end
        -- Crossing runs (L and T shapes) also forge a power gem.
        for key, n in pairs(count) do
            if n > 1 and not reserved[key] then
                local cell = clear[key]
                reserved[key] = true
                created[#created + 1] = { r = cell.r, c = cell.c, color = cell.gem.color, special = "power" }
            end
        end
        local explosions = {}
        for _, spec in ipairs(created) do clear[Key(spec.r, spec.c)].keep = true end
        local extra = self:Explode(clear, explosions)
        for key, cell in pairs(clear) do
            if cell.keep then clear[key] = nil end
        end
        steps[#steps + 1] = self:ApplyClear(clear, created, cascade, base, extra, explosions, "match")
        steps[#steps + 1] = self:Gravity()
        if self.pendingLevelUp then
            self.pendingLevelUp = false
            steps[#steps + 1] = { type = "levelup", level = self.level }
        end
        focus = nil
    end
    return cascade
end

function Game:PrismSwap(steps, r1, c1, r2, c2)
    local a, b = self.board[r1][c1], self.board[r2][c2]
    local clear = {}
    if a.color == Game.PRISM and b.color == Game.PRISM then
        for r = 1, Game.SIZE do
            for c = 1, Game.SIZE do clear[Key(r, c)] = { r = r, c = c, gem = self.board[r][c] } end
        end
    else
        local target = a.color == Game.PRISM and b.color or a.color
        clear[Key(r1, c1)] = { r = r1, c = c1, gem = a }
        clear[Key(r2, c2)] = { r = r2, c = c2, gem = b }
        for r = 1, Game.SIZE do
            for c = 1, Game.SIZE do
                if self.board[r][c].color == target then clear[Key(r, c)] = { r = r, c = c, gem = self.board[r][c] } end
            end
        end
    end
    local explosions = {}
    self:Explode(clear, explosions)
    local total = 0
    for _ in pairs(clear) do total = total + 1 end
    steps[#steps + 1] = self:ApplyClear(clear, {}, 1, 0, total, explosions, "prism")
    steps[#steps + 1] = self:Gravity()
end

-- Tries to swap two cells. Returns the steps to animate, or nil when the move is not allowed.
function Game:Swap(r1, c1, r2, c2)
    if self.state ~= "PLAYING" or not Adjacent(r1, c1, r2, c2) then return nil end
    if not (self:At(r1, c1) and self:At(r2, c2)) then return nil end
    local steps = { { type = "swap", a = { r1, c1 }, b = { r2, c2 } } }
    local a, b = self.board[r1][c1], self.board[r2][c2]
    SwapCells(self.board, r1, c1, r2, c2)
    local cascade = 0
    if a.color == Game.PRISM or b.color == Game.PRISM then
        self:PrismSwap(steps, r2, c2, r1, c1)
        cascade = self:Cascade(steps, nil, 1)
    else
        if #self:FindRuns() == 0 then
            SwapCells(self.board, r1, c1, r2, c2)
            return { { type = "invalid", a = { r1, c1 }, b = { r2, c2 } } }
        end
        cascade = self:Cascade(steps, { [Key(r1, c1)] = true, [Key(r2, c2)] = true }, 0)
    end
    steps.cascade = cascade

    if not self:FindMove() then
        if self.mode == "classic" then
            self.state = "OVER"
            steps[#steps + 1] = { type = "over", reason = "nomoves" }
        else
            self:Fill()
            steps[#steps + 1] = { type = "reshuffle" }
        end
    end
    return steps
end

function Game:Update(dt)
    if self.state ~= "PLAYING" or self.mode ~= "blitz" then return end
    self.timeLeft = self.timeLeft - dt
    if self.timeLeft <= 0 then
        self.timeLeft = 0
        self.state = "OVER"
        self:Emit("timeup")
    end
end

function Game:Pause()
    if self.state == "PLAYING" then self.state = "PAUSED" end
end

function Game:Resume()
    if self.state == "PAUSED" then self.state = "PLAYING" end
end
