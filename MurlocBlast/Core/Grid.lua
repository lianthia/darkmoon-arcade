-- Hex grid (pure logic, no WoW API). Even rows hold `cols` cells, odd rows `cols - 1`
-- shifted right by one radius. Coordinates are relative to the ceiling, y grows downwards.

local _, ns = ...

local Grid = {}
Grid.__index = Grid
ns.Grid = Grid

local SQRT3_2 = math.sqrt(3) / 2

function Grid.New(cols, rows, radius)
    local g = setmetatable({}, Grid)
    g.cols = cols
    g.rows = rows
    g.radius = radius
    g.diameter = radius * 2
    g.rowHeight = g.diameter * SQRT3_2
    g.cells = {}
    for r = 0, rows - 1 do
        g.cells[r] = {}
    end
    return g
end

function Grid:RowWidth(r)
    return (r % 2 == 0) and self.cols or (self.cols - 1)
end

function Grid:IsValid(r, c)
    return r >= 0 and r < self.rows and c >= 0 and c < self:RowWidth(r)
end

function Grid:Get(r, c)
    local row = self.cells[r]
    return row and row[c]
end

function Grid:Set(r, c, value)
    self.cells[r][c] = value
end

function Grid:Clear()
    for r = 0, self.rows - 1 do
        self.cells[r] = {}
    end
end

function Grid:CellCenter(r, c)
    local x = self.radius + c * self.diameter + ((r % 2 == 1) and self.radius or 0)
    local y = self.radius + r * self.rowHeight
    return x, y
end

local EVEN_OFFSETS = { { 0, -1 }, { 0, 1 }, { -1, -1 }, { -1, 0 }, { 1, -1 }, { 1, 0 } }
local ODD_OFFSETS = { { 0, -1 }, { 0, 1 }, { -1, 0 }, { -1, 1 }, { 1, 0 }, { 1, 1 } }

function Grid:Neighbors(r, c)
    local offsets = (r % 2 == 0) and EVEN_OFFSETS or ODD_OFFSETS
    local result = {}
    for i = 1, #offsets do
        local nr, nc = r + offsets[i][1], c + offsets[i][2]
        if self:IsValid(nr, nc) then
            result[#result + 1] = { nr, nc }
        end
    end
    return result
end

function Grid:Each(fn)
    for r = 0, self.rows - 1 do
        local row = self.cells[r]
        for c = 0, self:RowWidth(r) - 1 do
            local v = row[c]
            if v then fn(r, c, v) end
        end
    end
end

function Grid:Count()
    local n = 0
    self:Each(function() n = n + 1 end)
    return n
end

function Grid:LowestRow()
    local lowest = -1
    self:Each(function(r) if r > lowest then lowest = r end end)
    return lowest
end

-- Sorted so that color picks stay deterministic for a given RNG.
function Grid:ColorsPresent()
    local seen, list = {}, {}
    self:Each(function(_, _, v)
        if not seen[v] then
            seen[v] = true
            list[#list + 1] = v
        end
    end)
    table.sort(list)
    return list
end

local function key(r, c) return r * 100 + c end

function Grid:FindGroup(r, c)
    local color = self:Get(r, c)
    if not color then return {} end
    local visited = { [key(r, c)] = true }
    local stack = { { r, c } }
    local group = {}
    while #stack > 0 do
        local cell = table.remove(stack)
        group[#group + 1] = cell
        local neighbors = self:Neighbors(cell[1], cell[2])
        for i = 1, #neighbors do
            local nr, nc = neighbors[i][1], neighbors[i][2]
            local k = key(nr, nc)
            if not visited[k] and self:Get(nr, nc) == color then
                visited[k] = true
                stack[#stack + 1] = { nr, nc }
            end
        end
    end
    return group
end

-- Occupied cells without a path to the ceiling (row 0).
function Grid:FindFloating()
    local visited = {}
    local stack = {}
    for c = 0, self:RowWidth(0) - 1 do
        if self:Get(0, c) then
            visited[key(0, c)] = true
            stack[#stack + 1] = { 0, c }
        end
    end
    while #stack > 0 do
        local cell = table.remove(stack)
        local neighbors = self:Neighbors(cell[1], cell[2])
        for i = 1, #neighbors do
            local nr, nc = neighbors[i][1], neighbors[i][2]
            local k = key(nr, nc)
            if not visited[k] and self:Get(nr, nc) then
                visited[k] = true
                stack[#stack + 1] = { nr, nc }
            end
        end
    end
    local floating = {}
    self:Each(function(r, c)
        if not visited[key(r, c)] then
            floating[#floating + 1] = { r, c }
        end
    end)
    return floating
end

function Grid:IsAttached(r, c)
    if r == 0 then return true end
    local neighbors = self:Neighbors(r, c)
    for i = 1, #neighbors do
        if self:Get(neighbors[i][1], neighbors[i][2]) then return true end
    end
    return false
end

-- Nearest free cell to (x, y); attached cells within reach win over closer unattached ones.
function Grid:NearestEmpty(x, y)
    local approxRow = math.floor((y - self.radius) / self.rowHeight + 0.5)
    local maxAttachedDist = (self.diameter * 1.25) ^ 2
    local best, bestDist, anyBest, anyDist
    for r = approxRow - 1, approxRow + 1 do
        if r >= 0 and r < self.rows then
            for c = 0, self:RowWidth(r) - 1 do
                if not self:Get(r, c) then
                    local cx, cy = self:CellCenter(r, c)
                    local d = (cx - x) ^ 2 + (cy - y) ^ 2
                    if not anyBest or d < anyDist then
                        anyBest, anyDist = { r, c }, d
                    end
                    if d <= maxAttachedDist and (not best or d < bestDist) and self:IsAttached(r, c) then
                        best, bestDist = { r, c }, d
                    end
                end
            end
        end
    end
    best = best or anyBest
    if best then return best[1], best[2] end
end
