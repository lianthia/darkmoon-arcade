local SB = ns.Spellbounce
local Game, Maps = SB.Game, SB.Maps
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

local function NewGame(class, seed)
    local g = Game.New(Rng(seed or 7))
    local events = {}
    g.onEvent = function(name, data) events[#events + 1] = { name = name, data = data } end
    g:StartRun(1, class or "mage")
    return g, events
end

local function Count(events, name)
    local n = 0
    for _, e in ipairs(events) do if e.name == name then n = n + 1 end end
    return n
end

-- A single peg of the given kind right below the launcher, all others removed.
local function Solo(g, kind, x, y)
    for _, peg in ipairs(g.pegs) do peg.gone = true end
    local peg = { id = 999, x = x or Game.LAUNCH_X, y = y or 200, kind = kind or "blue" }
    g.pegs[#g.pegs + 1] = peg
    return peg
end

local function RunShot(g, limit)
    for _ = 1, (limit or 2000) do
        g:Update(1 / 60)
        if #g.balls == 0 then return end
    end
    error("shot never ended")
end

test("every map has valid, well spaced pegs", function()
    for i = 1, Maps.COUNT do
        local pegs = Maps.Build(i)
        assert(#pegs >= 40, ("map %d has only %d pegs"):format(i, #pegs))
        for a = 1, #pegs do
            local p = pegs[a]
            assert(p.x >= 24 and p.x <= 408 and p.y >= 104 and p.y <= 408, ("map %d peg out of bounds"):format(i))
            for b = a + 1, #pegs do
                local q = pegs[b]
                local d = math.sqrt((p.x - q.x) ^ 2 + (p.y - q.y) ^ 2)
                assert(d >= Maps.MIN_DIST - 1, ("map %d pegs too close: %.1f"):format(i, d))
            end
        end
    end
end)

test("levels assign targets, powers and one gold peg", function()
    local g = NewGame()
    for level = 1, Maps.COUNT * 2 do
        g:LoadLevel(level)
        local kinds = {}
        for _, peg in ipairs(g.pegs) do kinds[peg.kind] = (kinds[peg.kind] or 0) + 1 end
        eq(kinds.target, g.targetsTotal, "targets")
        eq(kinds.power, 2, "powers")
        eq(kinds.gold, 1, "gold")
        assert(g.targetsTotal >= 15, "enough targets on level " .. level)
    end
end)

test("second lap has more targets", function()
    local g = NewGame()
    g:LoadLevel(1)
    local first = g.targetsTotal
    g:LoadLevel(1 + Maps.COUNT)
    assert(g.targetsTotal >= first, "lap two at least as many targets")
    eq(g:MapIndex(), 1, "map wraps")
end)

test("a straight shot lights the peg below and removes it after the shot", function()
    local g, events = NewGame()
    local peg = Solo(g, "blue")
    g:SetAim(math.pi / 2)
    assert(g:Shoot(), "can shoot")
    eq(g.orbs, Game.ORBS - 1, "orb used")
    assert(not g:Shoot(), "one orb at a time")
    RunShot(g)
    assert(peg.gone, "lit peg removed")
    eq(g.score, Game.POINTS.blue, "score")
    eq(Count(events, "shotEnd"), 1, "shot ended")
end)

test("multiplier grows with cleared targets", function()
    local g = NewGame()
    g.targetsTotal, g.targetsHit = 20, 0
    eq(g:Multiplier(), 1)
    g.targetsHit = 8
    eq(g:Multiplier(), 2)
    g.targetsHit = 13
    eq(g:Multiplier(), 3)
    g.targetsHit = 17
    eq(g:Multiplier(), 5)
end)

test("aim is clamped below the launcher", function()
    local g = NewGame()
    g:AimAt(0, 0)
    assert(g.angle >= Game.MIN_ANGLE and g.angle <= Game.MAX_ANGLE, "clamped")
    g:AimAt(Game.LAUNCH_X, 400)
    assert(math.abs(g.angle - math.pi / 2) < 1e-6, "straight down")
end)

test("the well returns an orb once per shot", function()
    local g, events = NewGame()
    Solo(g, "blue", 20, 140)
    g.time = 0
    g:SetAim(math.pi / 2)
    g:Shoot()
    -- Park the well under the launcher for the whole shot.
    g.WellX = function() return Game.LAUNCH_X end
    RunShot(g)
    eq(Count(events, "catch"), 1, "caught")
    eq(g.orbs, Game.ORBS, "orb refunded")
end)

test("losing the last orb ends the game", function()
    local g, events = NewGame()
    Solo(g, "target", 20, 140)
    g.targetsTotal, g.targetsHit = 1, 0
    g.orbs = 1
    g.WellX = function() return -500 end
    g:Shoot()
    RunShot(g)
    eq(g.state, "OVER")
    eq(Count(events, "over"), 1)
end)

test("hitting the last target clears the map with bonuses", function()
    local g, events = NewGame()
    Solo(g, "target")
    local extra = { id = 1000, x = 60, y = 380, kind = "blue" }
    g.pegs[#g.pegs + 1] = extra
    g.targetsTotal, g.targetsHit = 1, 0
    g.WellX = function() return -500 end
    g:Shoot()
    RunShot(g)
    eq(g.state, "CLEAR")
    local clear
    for _, e in ipairs(events) do if e.name == "clear" then clear = e.data end end
    eq(clear.pegBonus, Game.FINALE_POINTS, "remaining peg bonus")
    eq(clear.orbBonus, (Game.ORBS - 1) * Game.ORB_BONUS, "orb bonus")
    eq(Count(events, "lastTarget"), 1)
end)

test("mage power lights the pegs around it", function()
    local g = NewGame("mage")
    local power = Solo(g, "power", 216, 200)
    local near = { id = 1, x = 260, y = 230, kind = "blue" }
    local far = { id = 2, x = 40, y = 400, kind = "blue" }
    g.pegs[#g.pegs + 1] = near
    g.pegs[#g.pegs + 1] = far
    g.shot = { points = 0, hits = 0, targets = 0, shields = 0, powers = 0 }
    g:Light(power, "ball")
    assert(near.lit and not far.lit, "only near peg lit")
end)

test("shaman power chains to the nearest pegs", function()
    local g = NewGame("shaman")
    local power = Solo(g, "power", 100, 200)
    for i = 1, 8 do g.pegs[#g.pegs + 1] = { id = i, x = 100 + i * 34, y = 200, kind = "blue" } end
    g.shot = { points = 0, hits = 0, targets = 0, shields = 0, powers = 0 }
    g:Light(power, "ball")
    local lit = 0
    for _, peg in ipairs(g.pegs) do if peg.lit and peg ~= power then lit = lit + 1 end end
    eq(lit, 5, "five jumps")
    assert(g.pegs[#g.pegs - 7].lit and not g.pegs[#g.pegs].lit, "nearest first")
end)

test("warlock power rains on five random pegs", function()
    local g = NewGame("warlock")
    local power = Solo(g, "power", 216, 200)
    for i = 1, 12 do g.pegs[#g.pegs + 1] = { id = i, x = 30 + i * 30, y = 380, kind = "blue" } end
    g.shot = { points = 0, hits = 0, targets = 0, shields = 0, powers = 0 }
    g:Light(power, "ball")
    local lit = 0
    for _, peg in ipairs(g.pegs) do if peg.lit and peg ~= power then lit = lit + 1 end end
    eq(lit, 5)
end)

test("hunter power splits the orb in three", function()
    local g, events = NewGame("hunter")
    Solo(g, "power")
    g:Shoot()
    for _ = 1, 120 do
        g:Update(1 / 60)
        if Count(events, "power") > 0 then break end
    end
    eq(#g.balls, 3, "three orbs")
    RunShot(g)
    eq(Count(events, "shotEnd"), 1, "one shot")
end)

test("priest shield bounces the orb back once", function()
    local g, events = NewGame("priest")
    Solo(g, "power")
    g.WellX = function() return -500 end
    g:Shoot()
    RunShot(g)
    eq(Count(events, "shield"), 1, "shield used")
end)

test("rogue vanish passes through pegs while lighting them", function()
    local g = NewGame("rogue")
    local power = Solo(g, "power", 216, 150)
    local below = { id = 1, x = 216, y = 220, kind = "blue" }
    g.pegs[#g.pegs + 1] = below
    g.WellX = function() return -500 end
    g:Shoot()
    RunShot(g)
    assert(power.gone and below.gone, "both lit")
end)

test("a resting orb is freed", function()
    local g, events = NewGame()
    for _, peg in ipairs(g.pegs) do peg.gone = true end
    -- A cup of pegs the orb cannot leave without help.
    for i, x in ipairs({ 196, 236, 216 }) do
        g.pegs[#g.pegs + 1] = { id = i, x = x, y = i == 3 and 330 or 312, kind = "blue" }
    end
    g.WellX = function() return -500 end
    g:Shoot()
    RunShot(g, 3000)
    assert(Count(events, "unstick") + Count(events, "shotEnd") >= 1, "shot finished")
end)

test("lighting many pegs in one shot earns an orb", function()
    local g, events = NewGame()
    for _, peg in ipairs(g.pegs) do peg.gone = true end
    g.WellX = function() return -500 end
    g:Shoot()
    for i = 1, Game.BONUS_HITS do g:Light({ id = i, x = 0, y = 0, kind = "blue" }, "test") end
    RunShot(g)
    eq(g.orbs, Game.ORBS, "orb refunded")
    local last
    for _, e in ipairs(events) do if e.name == "shotEnd" then last = e.data end end
    assert(last.bonusOrb, "flagged")
end)

test("classes unlock with progress", function()
    assert(Game.IsUnlocked("mage", 1))
    assert(not Game.IsUnlocked("shaman", 2))
    assert(Game.IsUnlocked("shaman", 3))
    assert(not Game.IsUnlocked("rogue", 7))
    assert(Game.IsUnlocked("rogue", 8))
end)

test("trace ends at the first peg", function()
    local g = NewGame()
    Solo(g, "blue", 216, 200)
    g:SetAim(math.pi / 2)
    local points = g:Trace(1)
    local last = points[#points]
    assert(last[2] < 200 and last[2] > 170, "stops above the peg: " .. last[2])
end)

test("random runs never break the rules", function()
    for _, class in ipairs(Game.CLASSES) do
        local rng = Rng(99)
        local g = NewGame(class, 11)
        local shots = 0
        while g.state == "PLAYING" and shots < 40 do
            g:SetAim(Game.MIN_ANGLE + (Game.MAX_ANGLE - Game.MIN_ANGLE) * rng(1000) / 1000)
            assert(g:Shoot(), "shot allowed")
            RunShot(g, 6000)
            shots = shots + 1
            assert(g.targetsHit <= g.targetsTotal, "targets in range")
            assert(g.orbs >= 0, "orbs in range")
        end
        assert(g.state == "CLEAR" or g.state == "OVER", class .. " run finished: " .. g.state)
    end
end)

return passed, failed
