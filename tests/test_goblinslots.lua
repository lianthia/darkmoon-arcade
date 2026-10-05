local Game = ns.GoblinSlots.Game
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

-- rows of symbol ids, "." for empty
local function Grid(rows)
    local grid = {}
    for r, row in ipairs(rows) do
        grid[r] = {}
        for c, id in ipairs(row) do grid[r][c] = id ~= "." and id or nil end
    end
    return grid
end

test("plain coins add up", function()
    local result = Game.Evaluate(Grid({
        { "copper", "silver", "gold", ".", "." },
        { ".", ".", ".", ".", "." }, { ".", ".", ".", ".", "." }, { ".", ".", ".", ".", "." },
    }))
    eq(result.total, 1 + 3 + 7)
end)

test("murlocs eat neighboring fish and like company", function()
    local result = Game.Evaluate(Grid({
        { "murloc", "fish", ".", ".", "." },
        { "murloc", ".", ".", ".", "fish" },
        { ".", ".", ".", ".", "." }, { ".", ".", ".", ".", "." },
    }))
    -- both murlocs touch the first fish; the first one eats it. Each murloc: 1 + 1 neighbor.
    eq(result.destroyed[1][2], true)
    eq(result.events.fishEaten, 1)
    eq(result.total, Game.RULES.murlocEatsFish + 2 + 2 + 1)
end)

test("pickaxe triples ore, kobold doubles candles", function()
    local result = Game.Evaluate(Grid({
        { "ore", "pickaxe", "candle", "kobold", "." },
        { ".", ".", ".", ".", "." }, { ".", ".", ".", ".", "." }, { ".", ".", ".", ".", "." },
    }))
    eq(result.pay[1][1], 3)
    eq(result.pay[1][3], 2)
end)

test("dynamite blasts its neighbors and itself", function()
    local result = Game.Evaluate(Grid({
        { "copper", "copper", "copper", ".", "." },
        { "copper", "dynamite", "copper", ".", "." },
        { "copper", "copper", "copper", ".", "." },
        { ".", ".", ".", ".", "gold" },
    }))
    eq(result.events.blasted, 8)
    eq(result.pay[2][2], 8 * Game.RULES.dynamiteBlast)
    eq(result.total, 8 * Game.RULES.dynamiteBlast + 7)
end)

test("a key opens one chest for a big payout", function()
    local result = Game.Evaluate(Grid({
        { "chest", "key", "key", ".", "." },
        { ".", ".", ".", ".", "." }, { ".", ".", ".", ".", "." }, { ".", ".", ".", ".", "." },
    }))
    eq(result.events.chests, 1)
    eq(result.total, Game.RULES.chestKey + 1)
end)

test("crown pays per murloc on the board", function()
    local result = Game.Evaluate(Grid({
        { "crown", ".", ".", ".", "murloc" },
        { ".", ".", ".", ".", "." }, { "murloc", ".", ".", ".", "." }, { ".", ".", ".", ".", "." },
    }))
    eq(result.pay[1][1], 2 + 2 * Game.RULES.crownPerMurloc)
end)

test("destroyed symbols leave the inventory", function()
    local game = Game.New(Rng(1))
    game:Start()
    game.inventory = { "dynamite" }
    for _ = 1, 30 do game.inventory[#game.inventory + 1] = "copper" end
    game.state = "SPIN"
    local before = #game.inventory
    local result = game:Spin()
    eq(#game.inventory, before - (result.events.blasted or 0) - 1)
end)

test("rent is collected or the run ends", function()
    local game = Game.New(Rng(2))
    game:Start()
    game.spinsLeft = 1
    game:Spin()
    game.gold = 0
    eq(game:Pick(nil), "bankrupt")
    eq(game.state, "OVER")

    game:Start()
    game.spinsLeft = 1
    game:Spin()
    game.gold = 1000
    eq(game:Pick("silver"), "paid")
    eq(game.rentsPaid, 1)
    eq(game.removals, 1)
    eq(game.gold, 1000 - Game.RentAmount(1))
end)

test("offers have three distinct symbols", function()
    local game = Game.New(Rng(3))
    game:Start()
    for _ = 1, 50 do
        local offer = game:MakeOffer()
        eq(#offer, 3)
        if offer[1] == offer[2] or offer[2] == offer[3] or offer[1] == offer[3] then error("duplicate offer") end
    end
end)

test("bot plays 30 runs to bankruptcy without errors", function()
    for seed = 1, 30 do
        local game = Game.New(Rng(seed * 7))
        game:Start()
        local guard = 0
        while game.state ~= "OVER" and guard < 500 do
            guard = guard + 1
            game:Spin()
            game:Pick(game.offer[1])
        end
        if game.state ~= "OVER" and game.rentsPaid < 5 then error("run did not progress") end
    end
end)

return passed, failed
