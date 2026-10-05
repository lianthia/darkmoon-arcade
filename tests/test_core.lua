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

test("all levels load without floating bubbles", function()
    local g = Grid.New(8, 13, 16)
    for level = 1, 40 do
        Levels.Load(g, level)
        eq(#g:FindFloating(), 0, "Level " .. level)
        if g:Count() < 8 then error("Level " .. level .. " nearly empty") end
        if g:LowestRow() >= 10 then error("Level " .. level .. " too deep") end
    end
end)

test("procedural levels are deterministic", function()
    local a, b = Grid.New(8, 13, 16), Grid.New(8, 13, 16)
    Levels.Load(a, 17); Levels.Load(b, 17)
    for r = 0, 12 do
        for c = 0, 7 do eq(a:Get(r, c), b:Get(r, c)) end
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
    eq(game.grid:Get(0, 3) or game.grid:Get(0, 4), 2)
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
