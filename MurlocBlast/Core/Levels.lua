-- Handmade levels first, then procedural levels that are deterministic per level number.

local _, ns = ...

local Levels = {}
ns.Levels = Levels

-- 1 red, 2 yellow, 3 green, 4 blue, 5 purple, 6 orange, 7 pearl, 8 pink
local LETTERS = { R = 1, Y = 2, G = 3, B = 4, P = 5, O = 6, W = 7, K = 8, X = 9 }
Levels.LETTERS = LETTERS
Levels.MAX_COLORS = 8
Levels.STONE = 9
Levels.BOMB = 10

function Levels.IsColor(value)
    return type(value) == "number" and value <= Levels.MAX_COLORS
end

Levels.DIFFICULTIES = { "easy", "normal", "hard" }

Levels.difficulty = {
    easy = { colorShift = -1, maxColors = 5, dropShift = 3, stoneFrom = 12, stoneRate = 1, guide = 900 },
    normal = { colorShift = 0, maxColors = 6, dropShift = 0, stoneFrom = 6, stoneRate = 2, guide = 340 },
    hard = { colorShift = 1, maxColors = 8, dropShift = -2, stoneFrom = 3, stoneRate = 3, guide = 130 },
}

-- Even rows have 12 characters, odd rows 11. "." is empty, "X" is stone.
Levels.handmade = {
    {
        drop = 9,
        "RRRYYYBBBRRR",
        "RRYYYBBBRRR",
        "YYYBBBRRRYYY",
        "YYBBBRRRYYY",
    },
    {
        drop = 9,
        "BBBBRRRRBBBB",
        "BBBRYYRBBB.",
        "YYYRYYYYRYYY",
        "YYRRYYYRRYY",
        "...RR..RR...",
    },
    {
        drop = 8,
        "RRRRGGGGBBBB",
        "YYYYBBBBRRR",
        "RRRRGGGGBBBB",
        "YYYYBBBBRRR",
        "GG..RR..YY..",
    },
    {
        drop = 8,
        "GGBBBXXBBBGG",
        "GYRRRYRRRYG",
        "YYRBBRRBBRYY",
        "Y.RBR..RBR.",
        "..GBBG.GBBG.",
    },
    {
        drop = 8,
        "PPRRGGXXGGRR",
        "PRRGGBBGGRR",
        "YYBBYYPPYYBB",
        "RYBBYPPYBBR",
        "RR.GG..GG.RR",
        "P....PP....",
    },
}

-- Park-Miller RNG: exact in doubles, so identical in WoW and in the LuaJIT test runner.
local function NewRng(seed)
    local state = (seed % 2147483646) + 1
    return function(n)
        state = (state * 16807) % 2147483647
        return (state % n) + 1
    end
end
Levels.NewRng = NewRng

local function Settings(difficulty)
    return Levels.difficulty[difficulty] or Levels.difficulty.normal
end

function Levels.ColorCount(level, difficulty)
    local s = Settings(difficulty)
    local count = 3 + math.floor((level - 1) / 3) + s.colorShift
    return math.max(3, math.min(s.maxColors, count))
end

function Levels.DropInterval(level, difficulty)
    return math.max(4, 9 - math.floor(level / 4) + Settings(difficulty).dropShift)
end

function Levels.StoneChance(level, difficulty)
    local s = Settings(difficulty)
    if level < s.stoneFrom then return 0 end
    return math.min(14, (level - s.stoneFrom + 1) * s.stoneRate)
end

local function LoadHandmade(grid, data)
    for i = 1, #data do
        local r = i - 1
        local line = data[i]
        for c = 0, grid:RowWidth(r) - 1 do
            grid:Set(r, c, LETTERS[line:sub(c + 1, c + 1)])
        end
    end
end

local function LoadProcedural(grid, level, difficulty)
    local rand = NewRng(level * 7919 + 13)
    local colors = Levels.ColorCount(level, difficulty)
    local stones = Levels.StoneChance(level, difficulty)
    local rows = math.min(9, 4 + math.floor(level / 2))
    local holeChance = (level >= 8) and 12 or 0
    for r = 0, rows - 1 do
        for c = 0, grid:RowWidth(r) - 1 do
            local color
            local roll = rand(100)
            local left = c > 0 and grid:Get(r, c - 1)
            if roll <= 30 and Levels.IsColor(left) then
                color = left
            elseif roll <= 55 and r > 0 then
                local neighbors = grid:Neighbors(r, c)
                for i = 1, #neighbors do
                    local n = neighbors[i]
                    local above = grid:Get(n[1], n[2])
                    if n[1] == r - 1 and Levels.IsColor(above) then
                        color = above
                        break
                    end
                end
            end
            color = color or rand(colors)
            if r > 0 and rand(100) <= stones then color = Levels.STONE end
            if r > 1 and rand(100) <= holeChance then color = nil end
            grid:Set(r, c, color)
        end
    end
end

function Levels.Load(grid, level, difficulty)
    grid:Clear()
    local data = Levels.handmade[level]
    if data then
        LoadHandmade(grid, data)
    else
        LoadProcedural(grid, level, difficulty)
    end
    -- Procedural holes can leave islands behind.
    local floating = grid:FindFloating()
    for i = 1, #floating do
        grid:Set(floating[i][1], floating[i][2], nil)
    end
    local drop = data and (data.drop + Settings(difficulty).dropShift) or Levels.DropInterval(level, difficulty)
    return {
        drop = math.max(4, drop),
        guide = Settings(difficulty).guide,
    }
end
