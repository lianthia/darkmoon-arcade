local BA = ns.BridgeArchitect
local P = BA.Physics
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

-- A beam from the joint at x1, y1 (which must exist) to x2, y2.
local function B(b, level, x1, y1, x2, y2, mat)
    local from = P.NodeAt(b, x1, y1, 1)
    assert(from, ("no joint at %d,%d"):format(x1, y1))
    local k, why = P.AddBeam(b, level, from, x2, y2, mat)
    assert(k, ("beam %d,%d-%d,%d %s: %s"):format(x1, y1, x2, y2, mat, tostring(why)))
end

-- A truss over a road along `pts` ({x, y} joints, the first and last existing): a top chord `h`
-- above the inner joints, verticals, end posts and diagonals falling towards the middle.
local function Truss(b, level, pts, h, chord, web, deck, howe)
    chord, web, deck = chord or "wood", web or chord or "wood", deck or "road"
    local n = #pts - 1
    for i = 1, n do B(b, level, pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2], deck) end
    for i = 2, n do B(b, level, pts[i][1], pts[i][2], pts[i][1], pts[i][2] - h, web) end
    for i = 2, n - 1 do B(b, level, pts[i][1], pts[i][2] - h, pts[i + 1][1], pts[i + 1][2] - h, chord) end
    B(b, level, pts[1][1], pts[1][2], pts[2][1], pts[2][2] - h, chord)
    B(b, level, pts[n + 1][1], pts[n + 1][2], pts[n][1], pts[n][2] - h, chord)
    local mid = (n + 2) / 2
    for i = 2, n do
        if howe then
            -- Diagonals rising towards the middle instead.
            if i < mid and i + 1 <= n then
                B(b, level, pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2] - h, web)
            elseif i > mid and i - 1 >= 2 then
                B(b, level, pts[i][1], pts[i][2], pts[i - 1][1], pts[i - 1][2] - h, web)
            end
        elseif i < mid then
            B(b, level, pts[i][1], pts[i][2] - h, pts[i + 1][1], pts[i + 1][2], web)
        elseif i > mid then
            B(b, level, pts[i][1], pts[i][2] - h, pts[i - 1][1], pts[i - 1][2], web)
        end
    end
end

-- The same over a level span from x1 to x2 in `n` panels.
local function Pratt(b, level, x1, x2, y, n, h, chord, web, under)
    local pts = {}
    for i = 0, n do pts[#pts + 1] = { x1 + i * (x2 - x1) / n, y } end
    Truss(b, level, pts, h, chord, web)
    -- A beam under the road, carrying the pull of the lower chord.
    if under then
        for i = 1, n do B(b, level, pts[i][1], y, pts[i + 1][1], y, under) end
    end
end

-- A suspension bridge: a rope cable from hook to hook sagging to `low`, hangers every `step` down
-- to a road from x1 to x2 at height y.
local function Suspension(b, level, hookL, hookR, x1, x2, y, step, low, cable)
    cable = cable or "rope"
    local xs = {}
    for x = x1, x2, step do xs[#xs + 1] = x end
    if xs[#xs] ~= x2 then xs[#xs + 1] = x2 end
    for i = 1, #xs - 1 do B(b, level, xs[i], y, xs[i + 1], y, "road") end
    local mid, half = (hookL[1] + hookR[1]) / 2, (hookR[1] - hookL[1]) / 2
    local prev = hookL
    for i = 2, #xs - 1 do
        local x = xs[i]
        local f = 1 - ((x - mid) / half) ^ 2
        local cy = P.Snap(hookL[2] + (low - hookL[2]) * f)
        B(b, level, prev[1], prev[2], x, cy, cable)
        B(b, level, x, cy, x, y, "rope")
        prev = { x, cy }
    end
    B(b, level, prev[1], prev[2], hookR[1], hookR[2], cable)
end

-- Reference bridges: every level must be solvable within its budget.
local SOLUTIONS = {
    gorge = function(b, l) Pratt(b, l, 340, 580, 300, 4, 40) end,
    wider = function(b, l) Pratt(b, l, 300, 620, 300, 8, 60) end,
    pillar = function(b, l)
        -- Posts up from the rock pillar, then a truss on each side.
        B(b, l, 440, 380, 440, 320, "wood")
        B(b, l, 440, 320, 440, 280, "wood")
        B(b, l, 480, 380, 480, 320, "wood")
        B(b, l, 480, 320, 480, 280, "wood")
        B(b, l, 440, 320, 480, 280, "wood")
        B(b, l, 440, 380, 480, 320, "wood")
        Pratt(b, l, 200, 440, 280, 6, 60)
        Pratt(b, l, 480, 720, 280, 6, 60)
        B(b, l, 440, 280, 480, 280, "road")
    end,
    uneven = function(b, l)
        Truss(b, l, { { 300, 240 }, { 340, 260 }, { 380, 280 }, { 420, 300 }, { 460, 300 }, { 500, 300 }, { 540, 300 }, { 580, 300 } }, 60, "wood", "wood", "road", true)
        -- Struts from the lower anchors under the ends.
        B(b, l, 300, 300, 340, 260, "wood")
        B(b, l, 580, 360, 540, 300, "wood")
    end,
    steel = function(b, l) Pratt(b, l, 260, 660, 300, 10, 60, "steel", "steel", "steel") end,
    crane = function(b, l) Suspension(b, l, { 160, 120 }, { 760, 120 }, 180, 740, 300, 40, 240) end,
    caravan = function(b, l)
        B(b, l, 440, 400, 440, 340, "steel")
        B(b, l, 440, 340, 440, 300, "steel")
        B(b, l, 480, 400, 480, 340, "steel")
        B(b, l, 480, 340, 480, 300, "steel")
        B(b, l, 440, 340, 480, 300, "steel")
        B(b, l, 440, 400, 480, 340, "steel")
        Pratt(b, l, 240, 440, 300, 5, 60, "steel", "wood")
        Pratt(b, l, 480, 680, 300, 5, 60, "steel", "wood")
        B(b, l, 440, 300, 480, 300, "road")
    end,
    thrifty = function(b, l) Suspension(b, l, { 200, 140 }, { 720, 140 }, 220, 700, 280, 40, 240) end,
    -- Chapter 2.
    vines = function(b, l) Suspension(b, l, { 220, 140 }, { 700, 140 }, 240, 680, 300, 40, 220) end,
    island = function(b, l)
        Pratt(b, l, 260, 420, 300, 4, 40)
        Pratt(b, l, 520, 680, 300, 4, 40)
    end,
    ruins = function(b, l) Pratt(b, l, 280, 600, 300, 8, 60) end,
    drop = function(b, l)
        Truss(b, l, { { 300, 240 }, { 340, 260 }, { 380, 280 }, { 420, 300 }, { 460, 300 }, { 500, 300 }, { 540, 300 }, { 580, 300 } },
            60, "wood", "wood", "road", true)
        B(b, l, 300, 300, 340, 260, "wood")
        B(b, l, 580, 360, 540, 300, "wood")
    end,
    lava = function(b, l) Pratt(b, l, 260, 620, 300, 9, 60, "steel", "steel", "steel") end,
    forge = function(b, l)
        for _, x in ipairs({ 360, 400, 520, 560 }) do
            B(b, l, x, 380, x, 340, "steel")
            B(b, l, x, 340, x, 300, "steel")
        end
        B(b, l, 360, 340, 400, 300, "steel")
        B(b, l, 520, 340, 560, 300, "steel")
        B(b, l, 360, 380, 400, 340, "steel")
        B(b, l, 520, 380, 560, 340, "steel")
        Pratt(b, l, 200, 360, 300, 4, 40, "steel", "steel", "steel")
        Pratt(b, l, 400, 520, 300, 3, 40, "steel", "steel", "steel")
        Pratt(b, l, 560, 720, 300, 4, 40, "steel", "steel", "steel")
        for _, x in ipairs({ 360, 520 }) do
            B(b, l, x, 300, x + 40, 300, "road")
            B(b, l, x, 300, x + 40, 300, "steel")
        end
    end,
    glacier = function(b, l) Suspension(b, l, { 140, 100 }, { 780, 100 }, 160, 760, 300, 40, 230) end,
    golem = function(b, l) Pratt(b, l, 280, 640, 300, 9, 60, "steel", "steel", "steel") end,
    -- Chapter 3.
    dunes = function(b, l) Suspension(b, l, { 120, 80 }, { 800, 80 }, 140, 780, 300, 40, 220) end,
    oasis = function(b, l) Pratt(b, l, 300, 620, 300, 8, 60) end,
    crater = function(b, l)
        B(b, l, 420, 360, 420, 300, "steel")
        B(b, l, 460, 360, 460, 300, "steel")
        B(b, l, 420, 360, 460, 300, "steel")
        Pratt(b, l, 220, 420, 300, 5, 60, "steel", "steel", "steel")
        Pratt(b, l, 460, 700, 300, 6, 60, "steel", "steel", "steel")
        B(b, l, 420, 300, 460, 300, "road")
    end,
    climb = function(b, l)
        local pts = { { 300, 300 }, { 340, 300 }, { 380, 300 }, { 420, 300 }, { 460, 280 }, { 500, 260 }, { 540, 240 }, { 580, 240 } }
        Truss(b, l, pts, 40, "steel", "wood", "road")
        for i = 1, #pts - 1 do B(b, l, pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2], "steel") end
    end,
    giants = function(b, l)
        for _, x in ipairs({ 440, 480 }) do
            B(b, l, x, 380, x, 340, "steel")
            B(b, l, x, 340, x, 300, "steel")
        end
        B(b, l, 440, 340, 480, 300, "steel")
        B(b, l, 440, 380, 480, 340, "steel")
        Pratt(b, l, 200, 440, 300, 6, 60, "steel", "steel", "steel")
        Pratt(b, l, 480, 720, 300, 6, 60, "steel", "steel", "steel")
        B(b, l, 440, 300, 480, 300, "road")
    end,
    deep = function(b, l) Pratt(b, l, 240, 680, 300, 11, 60, "steel", "wood", "steel") end,
    gadgetzan = function(b, l)
        Suspension(b, l, { 160, 100 }, { 760, 100 }, 180, 740, 300, 40, 230, "steel")
        for x = 180, 700, 40 do B(b, l, x, 300, x + 40, 300, "steel") end
    end,
    grand = function(b, l)
        for _, x in ipairs({ 440, 480 }) do
            B(b, l, x, 400, x, 340, "steel")
            B(b, l, x, 340, x, 300, "steel")
        end
        B(b, l, 440, 340, 480, 300, "steel")
        B(b, l, 440, 400, 480, 340, "steel")
        Pratt(b, l, 160, 440, 300, 7, 60, "steel", "steel", "steel")
        Pratt(b, l, 480, 760, 300, 7, 60, "steel", "steel", "steel")
        B(b, l, 440, 300, 480, 300, "road")
    end,
}

test("building rules", function()
    local level = BA.LEVELS[1]
    local b = P.NewBuild(level)
    eq(#b.nodes, #level.anchors, "anchors")
    local k = P.AddBeam(b, level, 1, 400, 300, "road")
    assert(k, "road beam")
    eq(#b.nodes, 5, "new joint")
    local _, why = P.AddBeam(b, level, 1, 440, 300, "road")
    eq(why, "long", "too long")
    _, why = P.AddBeam(b, level, 1, 300, 320, "wood")
    eq(why, "blocked", "inside the rock")
    _, why = P.AddBeam(b, level, 1, 400, 300, "road")
    eq(why, "exists", "twice")
    eq(P.Cost(b), 90, "cost of 3 m road")
    P.RemoveBeam(b, 1)
    eq(#b.nodes, #level.anchors, "orphan joint removed")
    -- The end point is pulled back to the longest beam that fits.
    local ex, ey = P.EndPoint(b, 1, 500, 300, "road")
    eq(ex, 420, "end x")
    eq(ey, 300, "end y")
end)

test("saving keeps the bridge", function()
    local level = BA.LEVELS[1]
    local b = P.NewBuild(level)
    SOLUTIONS.gorge(b, level)
    local c = P.Deserialize(P.Serialize(b), level)
    eq(#c.nodes, #b.nodes, "nodes")
    eq(#c.beams, #b.beams, "beams")
    eq(P.Cost(c), P.Cost(b), "cost")
end)

test("a plain road falls, a truss holds", function()
    local level = BA.LEVELS[1]
    local b = P.NewBuild(level)
    for x = 340, 520, 60 do B(b, level, x, 300, x + 60, 300, "road") end
    local result = P.Run(b, level)
    eq(result, "lost", "plain road")
    local t = P.NewBuild(level)
    SOLUTIONS.gorge(t, level)
    local r2, why, s = P.Run(t, level)
    local maxLoad = 0
    for _, beam in ipairs(s.beams) do maxLoad = math.max(maxLoad, beam.load) end
    eq(r2, "won", "truss (" .. tostring(why) .. ", broken " .. s.broken .. ")")
end)

test("reference bridges hold within budget", function()
    for _, level in ipairs(BA.LEVELS) do
        local solve = SOLUTIONS[level.id]
        assert(solve, "no reference bridge for " .. level.id)
        do
            local b = P.NewBuild(level)
            solve(b, level)
            local cost = P.Cost(b)
            local result, why, s = P.Run(b, level)
            print(("  bridge %-8s cost %5d / %5d  stars %d  %s %s  t=%.1f broken %d"):format(level.id, cost, level.budget,
                P.Stars(level, cost), result, why or "", s.t, s.broken))
            assert(cost <= level.budget, level.id .. " over budget")
            eq(result, "won", level.id)
        end
    end
end)

return passed, failed
