local Game = ns.FlappyGriffin.Game
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

local function Run(game, seconds, onFrame)
    for _ = 1, math.floor(seconds * 60) do
        if onFrame then onFrame(game) end
        game:Update(1 / 60)
    end
end

-- Flaps whenever the gryphon sinks below the next gap's centre: a decent autopilot.
local function Autopilot(game)
    if game.state ~= "PLAYING" then return end
    local target = Game.HEIGHT * 0.45
    for _, pillar in ipairs(game.pillars) do
        if pillar.x + Game.PILLAR_W / 2 > Game.GRIFFIN_X - Game.RADIUS then
            target = pillar.gapY + 12
            break
        end
    end
    if game.y > target and game.vy > -50 then game:Flap() end
end

test("ready state hovers until the first flap", function()
    local game = Game.New(Rng(1))
    Run(game, 2)
    eq(game.state, "READY")
    eq(#game.pillars, 0)
    game:Flap()
    eq(game.state, "PLAYING")
    if game.vy >= 0 then error("flap should push upwards") end
end)

test("without flapping the gryphon hits the ground", function()
    local events = {}
    local game = Game.New(Rng(2))
    game.onEvent = function(name) events[#events + 1] = name end
    game:Flap()
    Run(game, 3)
    eq(game.state, "OVER")
    eq(events[#events], "over")
end)

test("ceiling blocks without killing", function()
    local game = Game.New(Rng(3))
    game:Flap()
    for _ = 1, 30 do
        game:Flap()
        game:Update(1 / 30)
    end
    if game.y < Game.RADIUS then error("left the screen") end
end)

test("autopilot passes pillars and scores", function()
    local game = Game.New(Rng(4))
    game:Flap()
    Run(game, 40, Autopilot)
    if game.score < 10 then error("score too low: " .. game.score .. " (" .. game.state .. ")") end
end)

test("gaps stay within the field and shrink with score", function()
    local game = Game.New(Rng(5))
    for score = 0, 120, 10 do
        game.score = score
        for _ = 1, 20 do
            game:SpawnPillar()
            local p = game.pillars[#game.pillars]
            if p.gapY - p.gap / 2 < Game.GAP_MARGIN - 0.01 then error("gap too high") end
            if p.gapY + p.gap / 2 > Game.HEIGHT - Game.GROUND - Game.GAP_MARGIN + 0.01 then error("gap too low") end
        end
    end
    game.score = 0
    local wide = game:Gap()
    game.score = 200
    if game:Gap() >= wide or game:Gap() < Game.GAP_MIN then error("gap scaling") end
end)

test("tickets add points", function()
    local game = Game.New(Rng(6))
    game:Flap()
    game.pillars = { { x = Game.GRIFFIN_X, gapY = game.y, gap = 400, ticket = { y = game.y } } }
    game:Update(1 / 60)
    eq(game.pillars[1].ticket.taken, true)
    eq(game.score, Game.TICKET_POINTS)
end)

test("medals by score", function()
    eq(Game.Medal(5), nil)
    eq(Game.Medal(10), "bronze")
    eq(Game.Medal(30), "silver")
    eq(Game.Medal(99), "gold")
    eq(Game.Medal(150), "darkmoon")
end)

test("next medal goal", function()
    eq(Game.NextMedal(0).key, "bronze")
    eq(Game.NextMedal(10).key, "silver")
    eq(Game.NextMedal(99).key, "darkmoon")
    eq(Game.NextMedal(100), nil)
end)

test("pause freezes the run", function()
    local game = Game.New(Rng(7))
    game:Flap()
    game:Pause()
    local y = game.y
    Run(game, 1)
    eq(game.y, y)
    game:Resume()
    eq(game.state, "PLAYING")
end)

return passed, failed
