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

test("crossing runs forge a star gem that clears row and column", function()
    local game = Game.New(Rng(21))
    game:Start("classic")
    -- A pattern without runs, then ones that form an L once (4,1) moves right.
    for r = 1, Game.SIZE do
        for c = 1, Game.SIZE do game.board[r][c] = { color = (r * 3 + c) % 6 + 2 } end
    end
    for _, cell in ipairs({ { 2, 2 }, { 3, 2 }, { 4, 3 }, { 4, 4 }, { 4, 1 } }) do game.board[cell[1]][cell[2]] = { color = 1 } end
    -- Moving the 1 at (4,1) right completes a row and a column of ones crossing at (4,2).
    local steps = game:Swap(4, 1, 4, 2)
    local star = false
    for _, step in ipairs(steps) do
        if step.type == "clear" then
            for _, spec in ipairs(step.created) do if spec.special == "star" then star = true end end
        end
    end
    assert(star, "star gem created")
end)

test("a star gem clears its row and column", function()
    local game = Game.New(Rng(22))
    game:Start("classic")
    game.board[4][4] = { color = 1, special = "star" }
    local clear, explosions = {}, {}
    clear[4 * 16 + 4] = { r = 4, c = 4, gem = game.board[4][4] }
    game:Explode(clear, explosions)
    local count = 0
    for _ in pairs(clear) do count = count + 1 end
    eq(count, Game.SIZE * 2 - 1, "row and column")
end)

test("two special gems swapped together combine", function()
    local game = Game.New(Rng(23))
    game:Start("classic")
    game.board[4][4] = { color = 1, special = "power" }
    game.board[4][5] = { color = 2, special = "power" }
    local steps = game:Swap(4, 4, 4, 5)
    assert(steps.combo, "combo swap")
    local clear = steps[2]
    eq(clear.kind, "combo")
    assert(#clear.cells >= 25, "5x5 blast: " .. #clear.cells)
end)

test("time gems add seconds in blitz", function()
    local game = Game.New(Rng(24))
    game:Start("blitz")
    game.timeLeft = 10
    local clear = { [1 * 16 + 1] = { r = 1, c = 1, gem = { color = 1, time = Game.TIME_GEM_SECONDS } } }
    game:ApplyClear(clear, {}, 1, 50, 0, {}, "match")
    eq(game.timeLeft, 10 + Game.TIME_GEM_SECONDS)
    eq(game.timeGained, Game.TIME_GEM_SECONDS)
end)

test("zen never ends", function()
    local game = Game.New(Rng(25))
    game:Start("zen")
    game:Update(500)
    eq(game.state, "PLAYING")
    for _ = 1, 60 do
        local move = game:FindMove()
        assert(move, "always a move in zen")
        game:Swap(move[1], move[2], move[3], move[4])
    end
    eq(game.state, "PLAYING")
end)

return passed, failed
