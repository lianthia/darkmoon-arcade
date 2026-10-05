-- Handmade levels first, then procedural levels that are deterministic per level number.

local _, ns = ...

local Levels = {}
ns.Levels = Levels

-- Color indices: 1 red, 2 yellow, 3 green, 4 blue, 5 purple, 6 orange
local LETTERS = { R = 1, Y = 2, G = 3, B = 4, P = 5, O = 6 }
Levels.LETTERS = LETTERS
Levels.MAX_COLORS = 6

-- Even rows have 8 characters, odd rows 7. "." is empty.
Levels.handmade = {
    {
        drop = 9,
        "RRYYBBRR",
        "RYYBBRR",
        "YYBBRRYY",
        "YBBRRYY",
    },
    {
        drop = 9,
        "BBBRRBBB",
        "BBRYRBB",
        "YYRYYRYY",
        "YRRYRRY",
    },
    {
        drop = 8,
        "RRRRGGGG",
        "YYYBBBB",
        "RRRRGGGG",
        "YYYBBBB",
        "GG....RR",
    },
    {
        drop = 8,
        "GGBBBBGG",
        "GYRRRYG",
        "YYRBBRYY",
        "Y.RBR.Y",
        "..GBBG..",
    },
    {
        drop = 8,
        "PPRRGGPP",
        "PRRGGBP",
        "YYBBYYBB",
        "RYBBYBR",
        "RR.GG.RR",
        "P.....P",
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

function Levels.ColorCount(level)
    return math.min(Levels.MAX_COLORS, 3 + math.floor((level - 1) / 3))
end

function Levels.DropInterval(level)
    return math.max(5, 9 - math.floor(level / 4))
end

local function LoadHandmade(grid, data)
    for i = 1, #data do
        local r = i - 1
        local line = data[i]
        for c = 0, grid:RowWidth(r) - 1 do
            local ch = line:sub(c + 1, c + 1)
            grid:Set(r, c, LETTERS[ch])
        end
    end
end

local function LoadProcedural(grid, level)
    local rand = NewRng(level * 7919 + 13)
    local colors = Levels.ColorCount(level)
    local rows = math.min(9, 4 + math.floor(level / 2))
    local holeChance = (level >= 8) and 12 or 0
    for r = 0, rows - 1 do
        for c = 0, grid:RowWidth(r) - 1 do
            local color
            local roll = rand(100)
            if roll <= 30 and c > 0 and grid:Get(r, c - 1) then
                color = grid:Get(r, c - 1)
            elseif roll <= 55 and r > 0 then
                local neighbors = grid:Neighbors(r, c)
                for i = 1, #neighbors do
                    local n = neighbors[i]
                    if n[1] == r - 1 and grid:Get(n[1], n[2]) then
                        color = grid:Get(n[1], n[2])
                        break
                    end
                end
            end
            color = color or rand(colors)
            if r > 1 and rand(100) <= holeChance then color = nil end
            grid:Set(r, c, color)
        end
    end
end

function Levels.Load(grid, level)
    grid:Clear()
    local data = Levels.handmade[level]
    if data then
        LoadHandmade(grid, data)
    else
        LoadProcedural(grid, level)
    end
    -- Procedural holes can leave islands behind.
    local floating = grid:FindFloating()
    for i = 1, #floating do
        grid:Set(floating[i][1], floating[i][2], nil)
    end
    return {
        drop = (data and data.drop) or Levels.DropInterval(level),
        handmade = data ~= nil,
    }
end
