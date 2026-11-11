-- Goblin Bridge Architect: makes the reference bridges as cheap as it can (greedy local search), so
-- the three star mark of every level can be set to a bridge that is known to hold.
-- Run through tools/optimize_bridges.py. Moves: drop a beam, a cheaper material, a joint one cell aside.
-- A bridge counts only when it wins with nothing broken and the highest load stays under SAFE.

local BA = ns.BridgeArchitect
local P = BA.Physics
local SAFE = 0.92
local MAT_BY_COST = { "rope", "wood", "road", "steel" }

local O = {}

local function Allowed(level, mat)
    for _, m in ipairs(level.materials) do
        if m == mat then return true end
    end
    return false
end

-- Plain copy keeping anchors.
local function Clone(b)
    local c = { nodes = {}, beams = {} }
    for i, n in ipairs(b.nodes) do c.nodes[i] = { x = n.x, y = n.y, anchor = n.anchor } end
    for i, beam in ipairs(b.beams) do c.beams[i] = { a = beam.a, b = beam.b, mat = beam.mat } end
    return c
end

local function Valid(b, level)
    for i, n in ipairs(b.nodes) do
        if not n.anchor and not P.CanStand(level, n.x, n.y) then return false end
        for j = i + 1, #b.nodes do
            local m = b.nodes[j]
            if m.x == n.x and m.y == n.y then return false end
        end
    end
    local seen = {}
    for _, beam in ipairs(b.beams) do
        local m = BA.MATERIALS[beam.mat]
        local len = P.BeamLength(b, beam)
        if len > m.maxLen * P.GRID + 0.01 or len < P.GRID * 0.9 then return false end
        local lo, hi = math.min(beam.a, beam.b), math.max(beam.a, beam.b)
        local key = lo .. ":" .. hi .. ":" .. (m.road and "r" or "f")
        if seen[key] then return false end
        seen[key] = true
    end
    return true
end

-- Wins cleanly? Returns ok, peak.
local function Holds(b, level)
    local s = P.NewSim(b, level)
    while not s.result do
        P.Step(s, 1 / 60)
        if s.broken > 0 or s.peak > SAFE then return false, s.peak end
    end
    return s.result == "won", s.peak
end
O.Holds = Holds

-- Drops joints no beam uses (anchors stay) and renumbers.
local function Compact(b)
    local used = {}
    for _, beam in ipairs(b.beams) do used[beam.a], used[beam.b] = true, true end
    local map, nodes = {}, {}
    for i, n in ipairs(b.nodes) do
        if n.anchor or used[i] then
            nodes[#nodes + 1] = n
            map[i] = #nodes
        end
    end
    for _, beam in ipairs(b.beams) do beam.a, beam.b = map[beam.a], map[beam.b] end
    b.nodes = nodes
    return b
end

local function Shuffle(t)
    for i = #t, 2, -1 do
        local j = math.random(i)
        t[i], t[j] = t[j], t[i]
    end
    return t
end

-- All candidate changes of b, cheapest first is not needed: first improvement, random order.
local function Candidates(b, level)
    local out = {}
    for k, beam in ipairs(b.beams) do
        if not BA.MATERIALS[beam.mat].road then
            out[#out + 1] = function()
                local c = Clone(b)
                table.remove(c.beams, k)
                return Compact(c)
            end
            local cur = BA.MATERIALS[beam.mat].cost
            for _, mat in ipairs(MAT_BY_COST) do
                local m = BA.MATERIALS[mat]
                if not m.road and m.cost < cur and Allowed(level, mat) then
                    out[#out + 1] = function()
                        local c = Clone(b)
                        c.beams[k].mat = mat
                        return c
                    end
                end
            end
        end
    end
    local G = P.GRID
    local steps = { { G, 0 }, { -G, 0 }, { 0, G }, { 0, -G }, { G, G }, { -G, G }, { G, -G }, { -G, -G } }
    for i, n in ipairs(b.nodes) do
        if not n.anchor then
            for _, d in ipairs(steps) do
                out[#out + 1] = function()
                    local c = Clone(b)
                    c.nodes[i].x, c.nodes[i].y = n.x + d[1], n.y + d[2]
                    return c
                end
            end
        end
    end
    -- Merging two neighbouring joints (pulls a short beam out).
    for k, beam in ipairs(b.beams) do
        local na, nb = b.nodes[beam.a], b.nodes[beam.b]
        if not na.anchor or not nb.anchor then
            out[#out + 1] = function()
                local c = Clone(b)
                local keep, gone = beam.a, beam.b
                if c.nodes[gone].anchor then keep, gone = gone, keep end
                local beams = {}
                for _, e in ipairs(c.beams) do
                    if e.a == gone then e.a = keep end
                    if e.b == gone then e.b = keep end
                    if e.a ~= e.b then beams[#beams + 1] = e end
                end
                c.beams = beams
                return Compact(c)
            end
        end
    end
    return Shuffle(out)
end

-- Greedy descent from b; returns the best bridge, its cost and peak.
function O.Optimize(level, b, seed, maxEvals, log)
    math.randomseed(seed or 1)
    SAFE = 0.92
    local ok, peak = Holds(b, level)
    if not ok then
        -- A reference already near its limit: allow what it needs, no more.
        local r, _, s = P.Run(b, level)
        if r ~= "won" or s.broken > 0 then return nil, "reference does not hold" end
        SAFE = s.peak + 0.005
        ok, peak = Holds(b, level)
    end
    local cost = P.Cost(b)
    local evals = 0
    local improved = true
    while improved and evals < (maxEvals or 4000) do
        improved = false
        for _, make in ipairs(Candidates(b, level)) do
            local c = make()
            local cc = P.Cost(c)
            if cc < cost and Valid(c, level) then
                evals = evals + 1
                local ok2, pk = Holds(c, level)
                if ok2 then
                    b, cost, peak, improved = c, cc, pk, true
                    if log then log(cost, peak, evals) end
                    break
                end
                if evals >= (maxEvals or 4000) then break end
            end
        end
    end
    return b, cost, peak, evals
end

function O.Serialize(b)
    local parts = { "{ nodes = {" }
    for _, n in ipairs(b.nodes) do
        parts[#parts + 1] = ("{%d,%d%s},"):format(n.x, n.y, n.anchor and ",1" or "")
    end
    parts[#parts + 1] = "}, beams = {"
    for _, beam in ipairs(b.beams) do
        parts[#parts + 1] = ('{%d,%d,"%s"},'):format(beam.a, beam.b, beam.mat)
    end
    parts[#parts + 1] = "} }"
    return table.concat(parts)
end

return O
