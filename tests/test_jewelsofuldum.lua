local Game = ns.JewelsOfUldum.Game
local passed, failed = 0, 0

local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
    else
        failed = failed + 1
        print("FAIL " .. name .. ": " .. tostring(err))
    end
end

local function eq(a, b, msg)
    if a ~= b then error((msg or "") .. " expected " .. tostring(b) .. ", got " .. tostring(a), 2) end
end

local function Rng(seed)
    return function(n) seed = (seed * 16807) % 2147483647; return seed % n + 1 end
end

-- Builds a board from rows of digits (1-7 colors, 0 prism, letters for power gems: a=1 ... g=7).
local function Board(game, rows)
    for r, line in ipairs(rows) do
        game.board[r] = {}
        for c = 1, #line do
            local ch = line:sub(c, c)
            local digit = tonumber(ch)
            if digit then
                game.board[r][c] = { color = digit, special = digit == 0 and "prism" or nil }
            else
                game.board[r][c] = { color = ch:byte() - 96, special = "power" }
            end
        end
    end
    game.state = "PLAYING"
end

local function Full(game)
    for r = 1, Game.SIZE do
        for c = 1, Game.SIZE do
            if not game.board[r][c] then return false end
        end
    end
    return true
end

local CHECKER = {
    "12121212", "34343434", "56565656", "21212121",
    "43434343", "65656565", "12121212", "34343434",
}

test("new boards have no matches but at least one move", function()
    for seed = 1, 30 do
        local game = Game.New(Rng(seed))
        game:Start("classic")
        eq(#game:FindRuns(), 0, "seed " .. seed)
        if not game:FindMove() then error("no move, seed " .. seed) end
    end
end)

test("swap without a match is undone", function()
    local game = Game.New(Rng(1))
    Board(game, CHECKER)
    local steps = game:Swap(1, 1, 1, 2)
    eq(steps[1].type, "invalid")
    eq(game.board[1][1].color, 1)
end)

test("non-adjacent swap is rejected", function()
    local game = Game.New(Rng(1))
    Board(game, CHECKER)
    eq(game:Swap(1, 1, 3, 3), nil)
end)

test("three in a row clear and the board refills", function()
    local game = Game.New(Rng(2))
    local rows = { unpack(CHECKER) }
    rows[1] = "11717121"
    rows[2] = "34143434"
    Board(game, rows)
    -- swapping (1,3) down with (2,3) makes 1-1-1 in row 1
    local steps = game:Swap(1, 3, 2, 3)
    eq(steps[1].type, "swap")
    eq(steps[2].type, "clear")
    if game.score <= 0 then error("no points") end
    if not Full(game) then error("board has holes") end
end)

test("four in a row forge a power gem", function()
    local game = Game.New(Rng(3))
    local rows = { unpack(CHECKER) }
    rows[1] = "11214343"
    rows[2] = "34143434"
    Board(game, rows)
    local steps = game:Swap(1, 3, 2, 3)
    local clear = steps[2]
    eq(#clear.created, 1)
    eq(clear.created[1].special, "power")
end)

test("five in a row forge a prism", function()
    local game = Game.New(Rng(4))
    local rows = { unpack(CHECKER) }
    rows[1] = "11211565"
    rows[2] = "34143434"
    Board(game, rows)
    local steps = game:Swap(1, 3, 2, 3)
    eq(steps[2].created[1].special, "prism")
end)

test("prism clears every gem of the swapped color", function()
    local game = Game.New(Rng(5))
    local rows = { unpack(CHECKER) }
    rows[1] = "02121212"
    Board(game, rows)
    local twos = 0
    for r = 1, 8 do for c = 1, 8 do if game.board[r][c].color == 2 then twos = twos + 1 end end end
    local steps = game:Swap(1, 1, 1, 2)
    eq(steps[2].kind, "prism")
    eq(#steps[2].cells, twos + 1)
end)

test("power gems explode their surroundings", function()
    local game = Game.New(Rng(6))
    local rows = { unpack(CHECKER) }
    rows[1] = "aa717121"
    rows[2] = "34143434"
    Board(game, rows)
    local steps = game:Swap(1, 3, 2, 3)
    if #steps[2].explosions == 0 then error("no explosion") end
    if #steps[2].cells <= 4 then error("explosion too small") end
end)

test("classic levels up and multiplies points", function()
    local game = Game.New(Rng(7))
    game:Start("classic")
    game:AddPoints(Game.LevelTarget(1) + 10)
    eq(game.level, 2)
    eq(game:Multiplier(2), 4)
end)

test("blitz ends when the time is up", function()
    local game = Game.New(Rng(8))
    local ended = false
    game.onEvent = function(name) if name == "timeup" then ended = true end end
    game:Start("blitz")
    for _ = 1, Game.BLITZ_TIME * 10 + 5 do game:Update(0.1) end
    eq(game.state, "OVER")
    eq(ended, true)
end)

test("bot plays 40 games without errors", function()
    for seed = 1, 40 do
        local game = Game.New(Rng(seed * 31))
        game:Start(seed % 2 == 0 and "classic" or "blitz")
        local moves = 0
        while game.state == "PLAYING" and moves < 300 do
            local move = game:FindMove()
            if not move then error("no move while playing") end
            local steps = game:Swap(move[1], move[2], move[3], move[4])
            if not steps or steps[1].type == "invalid" then error("hint move was invalid") end
            if not Full(game) then error("board has holes") end
            eq(#game:FindRuns(), 0, "board settled")
            moves = moves + 1
        end
    end
end)

return passed, failed
