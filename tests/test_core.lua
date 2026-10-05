local Grid, Levels, Game = ns.Grid, ns.Levels, ns.Game
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

test("row widths alternate 8/7", function()
    local g = Grid.New(8, 12, 16)
    eq(g:RowWidth(0), 8); eq(g:RowWidth(1), 7)
    eq(g:IsValid(1, 7), false); eq(g:IsValid(0, 7), true)
end)

test("neighbors are symmetric and one diameter apart", function()
    local g = Grid.New(8, 12, 16)
    for r = 0, 11 do
        for c = 0, g:RowWidth(r) - 1 do
            for _, n in ipairs(g:Neighbors(r, c)) do
                local back = false
                for _, m in ipairs(g:Neighbors(n[1], n[2])) do
                    if m[1] == r and m[2] == c then back = true end
                end
                if not back then error(("asymmetric %d,%d -> %d,%d"):format(r, c, n[1], n[2])) end
                local x1, y1 = g:CellCenter(r, c)
                local x2, y2 = g:CellCenter(n[1], n[2])
                local d = math.sqrt((x1 - x2) ^ 2 + (y1 - y2) ^ 2)
                if math.abs(d - 32) > 0.01 then error("neighbor distance " .. d) end
            end
        end
    end
end)

test("group and floating detection", function()
    local g = Grid.New(8, 12, 16)
    g:Set(0, 0, 1); g:Set(0, 1, 1); g:Set(1, 0, 1)
    g:Set(2, 0, 2) -- hangs from (1,0)
    eq(#g:FindGroup(0, 0), 3)
    eq(#g:FindFloating(), 0)
    g:Set(1, 0, nil)
    local f = g:FindFloating()
    eq(#f, 1); eq(f[1][1], 2)
end)

test("NearestEmpty prefers attached cells", function()
    local g = Grid.New(8, 12, 16)
    g:Set(0, 3, 1)
    local x, y = g:CellCenter(1, 3)
    local r, c = g:NearestEmpty(x, y + 3)
    eq(r, 1); eq(c, 3)
end)

test("handmade rows have the right width", function()
    for i, data in ipairs(Levels.handmade) do
        for r = 1, #data do
            local expected = (r % 2 == 1) and 12 or 11
            eq(#data[r], expected, ("level %d row %d"):format(i, r))
        end
    end
end)

test("all levels load without floating bubbles", function()
    local g = Grid.New(12, 13, 18)
    for _, difficulty in ipairs(Levels.DIFFICULTIES) do
    for level = 1, 40 do
        Levels.Load(g, level, difficulty)
        eq(#g:FindFloating(), 0, "Level " .. level)
        if g:Count() < 8 then error("Level " .. level .. " nearly empty") end
        if g:LowestRow() >= 10 then error("Level " .. level .. " too deep") end
    end
    end
end)

test("difficulty changes colors, ceiling speed and stones", function()
    if not (Levels.ColorCount(20, "easy") < Levels.ColorCount(20, "hard")) then error("colors") end
    eq(Levels.ColorCount(30, "hard"), 8)
    if not (Levels.DropInterval(10, "easy") > Levels.DropInterval(10, "hard")) then error("drop") end
    eq(Levels.StoneChance(5, "easy"), 0)
    if Levels.StoneChance(5, "hard") <= 0 then error("stones on hard") end
end)

local function NewGame()
    local game = Game.New(function() return 1 end)
    game:StartLevel(1)
    game.grid:Clear()
    return game, game.grid
end

local function LandAt(game, r, c, color)
    local x, y = game.grid:CellCenter(r, c)
    game:Land({ x = x, y = y + game:CeilingY(), color = color })
end

test("stones never pop but fall when cut loose", function()
    local game, g = NewGame()
    g:Set(0, 0, 1); g:Set(0, 1, 1)
    g:Set(1, 0, Levels.STONE)
    g:Set(0, 5, 2)
    eq(#g:ColorsPresent(), 2)
    LandAt(game, 0, 2, 1)
    eq(g:Get(1, 0), nil, "stone should drop")
    eq(g:Get(0, 5), 2)
end)

test("board with only stones left counts as cleared", function()
    local game, g = NewGame()
    g:Set(0, 0, 1); g:Set(0, 1, 1); g:Set(0, 4, Levels.STONE)
    LandAt(game, 0, 2, 1)
    eq(game.state, "CLEAR")
    eq(g:Count(), 0)
end)

test("bomb clears its surroundings including stones", function()
    local game, g = NewGame()
    for c = 0, 11 do g:Set(0, c, (c % 2 == 0) and Levels.STONE or 2) end
    g:Set(0, 11, 3)
    LandAt(game, 1, 5, Levels.BOMB)
    eq(g:Get(0, 5), nil); eq(g:Get(0, 6), nil); eq(g:Get(1, 5), nil)
    if not g:Get(0, 11) then error("far cell should survive") end
end)

test("every third combo grants a bomb", function()
    local game, g = NewGame()
    g:Set(0, 11, 4)
    for i = 0, 2 do
        g:Set(0, i * 3, 1); g:Set(0, i * 3 + 1, 1)
        LandAt(game, 1, i * 3, 1)
    end
    eq(game.combo, 3)
    eq(game.next, Levels.BOMB)
end)

test("procedural levels are deterministic", function()
    local a, b = Grid.New(12, 13, 18), Grid.New(12, 13, 18)
    Levels.Load(a, 17, "hard"); Levels.Load(b, 17, "hard")
    for r = 0, 12 do
        for c = 0, 11 do eq(a:Get(r, c), b:Get(r, c)) end
    end
end)

test("shot hits the ceiling and snaps into row 0", function()
    local game = Game.New(function() return 1 end)
    game:StartLevel(1)
    game.grid:Clear(); game.grid:Set(0, 0, 1)
    game.current = 2
    game:SetAim(math.pi / 2)
    game:Shoot()
    for _ = 1, 200 do game:Update(1 / 60) if not game.shot then break end end
    eq(game.shot, nil)
    eq(game.grid:Get(0, 5) or game.grid:Get(0, 6), 2)
end)

test("three of a kind pop and hanging bubbles drop", function()
    local game = Game.New(function() return 1 end)
    local events = {}
    game.onEvent = function(name, data) events[name] = data end
    game:StartLevel(1)
    local g = game.grid
    g:Clear()
    g:Set(0, 3, 1); g:Set(0, 4, 1) -- two reds on the ceiling
    g:Set(1, 3, 2)                 -- yellow hangs from (0,3) and (0,4)
    g:Set(0, 0, 3)                 -- anchor so the board is not cleared
    game:Land({ x = select(1, g:CellCenter(0, 5)), y = select(2, g:CellCenter(0, 5)) + 1, color = 1 })
    if not events.pop then error("no pop") end
    eq(#events.pop.cells, 3)
    if not events.drop then error("no drop") end
    eq(#events.drop.cells, 1)
    eq(g:Count(), 1)
end)

test("bot plays 30 games without errors", function()
    local seed = 1
    local rng = function(n) seed = (seed * 16807) % 2147483647; return (seed % n) + 1 end
    for run = 1, 30 do
        local game = Game.New(rng)
        game.difficulty = Levels.DIFFICULTIES[(run % 3) + 1]
        game:StartLevel((run % 12) + 1)
        local guard = 0
        while game.state == "PLAYING" and guard < 400 do
            guard = guard + 1
            game:SetAim(math.rad(10 + rng(160)))
            game:Shoot()
            local ticks = 0
            while game.shot and ticks < 600 do game:Update(1 / 60); ticks = ticks + 1 end
            if game.shot then error("shot got stuck") end
        end
        if game.state == "PLAYING" then error("game never ends") end
    end
end)

test("aim trace bounces off walls", function()
    local game = Game.New()
    game:StartLevel(1)
    game:SetAim(math.rad(30))
    local pts = game:Trace(1200)
    if #pts < 3 then error("expected a bounce") end
end)

return passed, failed
