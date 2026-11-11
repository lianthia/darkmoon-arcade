-- Goblin Bridge Architect: the bridge and the vehicle as pure logic (no frames), so the tests can
-- run it. A bridge is a net of joints (nodes) and beams. The simulation is XPBD (extended position
-- based dynamics) with many small substeps: every beam is a stiff distance constraint whose force is
-- known exactly (lambda / h^2), so a beam can show its load and snap when the load is too high.
-- The vehicle is two wheels held apart by its chassis; the wheels roll on the road beams and the
-- ground and push their weight into the beams they touch.
--
-- Units: map pixels (y grows downwards), one grid cell = 1 m = 20 px, seconds.

local _, ns = ...
local BA = ns.BridgeArchitect or {}
ns.BridgeArchitect = BA

local P = {}
BA.Physics = P

local GRID = 20
P.GRID = GRID
P.W, P.H = 920, 496
P.GRAVITY = 400
P.SUBSTEPS = 16
local DAMPING = 0.4      -- velocity lost per second (a little air and joint friction)
local MAX_TIME = 30      -- a test ends after this long
local START_DELAY = 0.6  -- the bridge settles before the vehicle sets off
local LOAD_LAG = 0.06    -- seconds the load needs to follow the force

-- Materials: price per metre (gold), mass per metre, axial stiffness (force per unit strain),
-- strength (force at which it snaps), longest beam (m). Rope only pulls; road carries wheels.
BA.MATERIALS = {
    road = { cost = 30, mass = 0.4, stiffness = 8e5, strength = 12000, maxLen = 4, road = true, color = { 0.55, 0.38, 0.22 } },
    wood = { cost = 18, mass = 0.15, stiffness = 5e5, strength = 16000, maxLen = 4, color = { 0.82, 0.6, 0.33 } },
    steel = { cost = 45, mass = 0.4, stiffness = 1.5e6, strength = 45000, maxLen = 6, color = { 0.62, 0.66, 0.72 } },
    rope = { cost = 12, mass = 0.05, stiffness = 2.5e6, strength = 24000, maxLen = 14, rope = true, color = { 0.78, 0.7, 0.5 } },
}
BA.MATERIAL_ORDER = { "road", "wood", "steel", "rope" }

-- Vehicles: mass, speed (px/s), wheel base and radius (px). The model is drawn by the game.
BA.VEHICLES = {
    strider = { mass = 10, speed = 70, base = 26, radius = 7, display = 6978, len = 2.32, cx = -0.18, px = 42 },
    mule = { mass = 14, speed = 55, base = 30, radius = 7, display = 14546, len = 3.36, cx = 0.44, px = 48 },
    ram = { mass = 18, speed = 75, base = 34, radius = 8, display = 2736, len = 3.54, cx = 0.33, px = 52 },
    rocketcar = { mass = 16, speed = 130, base = 44, radius = 8, display = 10318, len = 8.87, cx = 0.37, px = 64 },
    shredder = { mass = 26, speed = 50, base = 36, radius = 9, display = 1269, len = 4.9, cx = 1.08, px = 58 },
    tallstrider = { mass = 12, speed = 80, base = 28, radius = 7, display = 38, len = 3.32, cx = -0.26, px = 46 },
    wolf = { mass = 16, speed = 95, base = 34, radius = 8, display = 207, len = 4.67, cx = -0.43, px = 54 },
    nightmare = { mass = 18, speed = 90, base = 36, radius = 8, display = 5228, len = 3.5, cx = 0.1, px = 52 },
    horse = { mass = 18, speed = 85, base = 36, radius = 8, display = 2402, len = 3.25, cx = 0.38, px = 52 },
    raptor = { mass = 18, speed = 105, base = 40, radius = 8, display = 6469, len = 6.46, cx = -1.1, px = 62 },
    golem = { mass = 30, speed = 40, base = 26, radius = 9, display = 71, len = 1.8, cx = -0.17, px = 40 },
    spidertank = { mass = 42, speed = 42, base = 50, radius = 10, display = 5926, len = 6.56, cx = 1.06, px = 74 },
    kodo = { mass = 36, speed = 45, base = 54, radius = 10, display = 7933, len = 10.63, cx = -1.97, px = 86 },
}

local function Dist(ax, ay, bx, by)
    local dx, dy = bx - ax, by - ay
    return math.sqrt(dx * dx + dy * dy)
end

local function Snap(v) return math.floor(v / GRID + 0.5) * GRID end
P.Snap = Snap

-- Building ---------------------------------------------------------------------------------------------

-- A new, empty bridge on `level`: only its anchors.
function P.NewBuild(level)
    local b = { nodes = {}, beams = {} }
    for _, a in ipairs(level.anchors) do
        b.nodes[#b.nodes + 1] = { x = a[1], y = a[2], anchor = true }
    end
    return b
end

function P.NodeAt(b, x, y, radius)
    local best, bestD = nil, (radius or GRID * 0.5) ^ 2
    for i, n in ipairs(b.nodes) do
        local d = (n.x - x) ^ 2 + (n.y - y) ^ 2
        if d <= bestD then best, bestD = i, d end
    end
    return best
end

-- Whether a new joint may stand at x, y: inside the field, above the water, not in the rock.
function P.CanStand(level, x, y)
    if x < 0 or x > P.W or y < GRID or y > level.water - 6 then return false end
    for _, r in ipairs(level.terrain) do
        if x > r[1] and x < r[2] and y > r[3] then return false end
    end
    return true
end

-- The beam between joints i and j on the same layer: road and frame are separate layers, so a road
-- can lie on a beam that strengthens it.
function P.BeamBetween(b, i, j, road)
    for k, beam in ipairs(b.beams) do
        if ((beam.a == i and beam.b == j) or (beam.a == j and beam.b == i))
            and (road == nil or (BA.MATERIALS[beam.mat].road or false) == road) then
            return k
        end
    end
end

-- The point a beam from node `from` towards x, y really ends at: on the grid, no longer than the
-- material allows.
function P.EndPoint(b, from, x, y, mat)
    local n = b.nodes[from]
    local maxLen = BA.MATERIALS[mat].maxLen * GRID
    local dx, dy = x - n.x, y - n.y
    local len = math.sqrt(dx * dx + dy * dy)
    if len > maxLen then
        -- The farthest grid point along the way that still fits.
        local best, bestD
        local tx, ty = n.x + dx / len * maxLen, n.y + dy / len * maxLen
        for gx = Snap(tx) - GRID, Snap(tx) + GRID, GRID do
            for gy = Snap(ty) - GRID, Snap(ty) + GRID, GRID do
                local l = Dist(n.x, n.y, gx, gy)
                if l <= maxLen + 0.01 and l > 0 then
                    local d = (gx - tx) ^ 2 + (gy - ty) ^ 2
                    if not bestD or d < bestD then best, bestD = { gx, gy }, d end
                end
            end
        end
        if best then return best[1], best[2] end
    end
    local other = P.NodeAt(b, x, y)
    if other then return b.nodes[other].x, b.nodes[other].y end
    return Snap(x), Snap(y)
end

-- Adds a beam of `mat` from node `from` to x, y (a joint there is made if needed).
-- Returns the beam index, or nil and why: "material", "short", "long", "blocked", "exists".
function P.AddBeam(b, level, from, x, y, mat)
    local m = BA.MATERIALS[mat]
    if not m then return nil, "material" end
    local n = b.nodes[from]
    if not n then return nil, "short" end
    local to = P.NodeAt(b, x, y, 1)
    if to == from then return nil, "short" end
    local len = Dist(n.x, n.y, x, y)
    if len < GRID * 0.9 then return nil, "short" end
    if len > m.maxLen * GRID + 0.01 then return nil, "long" end
    if not to then
        if not P.CanStand(level, x, y) then return nil, "blocked" end
        b.nodes[#b.nodes + 1] = { x = x, y = y }
        to = #b.nodes
    end
    local existing = P.BeamBetween(b, from, to, m.road or false)
    if existing then
        if b.beams[existing].mat == mat then return nil, "exists" end
        b.beams[existing].mat = mat
        return existing
    end
    b.beams[#b.beams + 1] = { a = from, b = to, mat = mat }
    return #b.beams
end

-- Removes beam k and every joint left without beams (anchors stay).
function P.RemoveBeam(b, k)
    table.remove(b.beams, k)
    local used = {}
    for _, beam in ipairs(b.beams) do
        used[beam.a], used[beam.b] = true, true
    end
    local map, nodes = {}, {}
    for i, n in ipairs(b.nodes) do
        if n.anchor or used[i] then
            nodes[#nodes + 1] = n
            map[i] = #nodes
        end
    end
    for _, beam in ipairs(b.beams) do
        beam.a, beam.b = map[beam.a], map[beam.b]
    end
    b.nodes = nodes
end

-- The beam closest to x, y (within `radius`), for removing.
function P.BeamAt(b, x, y, radius)
    local best, bestD = nil, (radius or 6) ^ 2
    for k, beam in ipairs(b.beams) do
        local a, c = b.nodes[beam.a], b.nodes[beam.b]
        local dx, dy = c.x - a.x, c.y - a.y
        local t = math.max(0, math.min(1, ((x - a.x) * dx + (y - a.y) * dy) / (dx * dx + dy * dy)))
        local d = (a.x + dx * t - x) ^ 2 + (a.y + dy * t - y) ^ 2
        if d < bestD then best, bestD = k, d end
    end
    return best
end

function P.BeamLength(b, beam)
    local a, c = b.nodes[beam.a], b.nodes[beam.b]
    return Dist(a.x, a.y, c.x, c.y)
end

function P.BeamCost(len, mat)
    return BA.MATERIALS[mat].cost * len / GRID
end

function P.Cost(b)
    local total = 0
    for _, beam in ipairs(b.beams) do total = total + P.BeamCost(P.BeamLength(b, beam), beam.mat) end
    return math.floor(total + 0.5)
end

-- Saved form: plain numbers only.
function P.Serialize(b)
    local out = { nodes = {}, beams = {} }
    for i, n in ipairs(b.nodes) do out.nodes[i] = { n.x, n.y, n.anchor and 1 or nil } end
    for i, beam in ipairs(b.beams) do out.beams[i] = { beam.a, beam.b, beam.mat } end
    return out
end

function P.Deserialize(data, level)
    local b = P.NewBuild(level)
    if type(data) ~= "table" or type(data.nodes) ~= "table" then return b end
    -- The level's anchors are kept as they are; saved joints follow.
    local map = {}
    for i, n in ipairs(data.nodes) do
        local found = n[3] and P.NodeAt(b, n[1], n[2], 1)
        if found then
            map[i] = found
        else
            b.nodes[#b.nodes + 1] = { x = n[1], y = n[2] }
            map[i] = #b.nodes
        end
    end
    for _, beam in ipairs(data.beams or {}) do
        local a, c = map[beam[1]], map[beam[2]]
        if a and c and a ~= c and BA.MATERIALS[beam[3]] then b.beams[#b.beams + 1] = { a = a, b = c, mat = beam[3] } end
    end
    return b
end

function P.Copy(b)
    return P.Deserialize(P.Serialize(b), { anchors = {} })
end

-- Simulation ---------------------------------------------------------------------------------------------

-- The ground the wheels roll on: the top and the sides of every rock.
local function StaticSegments(level)
    local segs = {}
    for _, r in ipairs(level.terrain) do
        segs[#segs + 1] = { r[1], r[3], r[2], r[3] }
        segs[#segs + 1] = { r[1], r[3], r[1], P.H + 200 }
        segs[#segs + 1] = { r[2], r[3], r[2], P.H + 200 }
    end
    return segs
end

function P.NewSim(build, level)
    local s = { t = 0, level = level, nodes = {}, beams = {}, events = {}, broken = 0, peak = 0 }
    local mass = {}
    for i, n in ipairs(build.nodes) do
        s.nodes[i] = { x = n.x, y = n.y, px = n.x, py = n.y, anchor = n.anchor }
        mass[i] = 0
    end
    for _, beam in ipairs(build.beams) do
        local m = BA.MATERIALS[beam.mat]
        local a, c = s.nodes[beam.a], s.nodes[beam.b]
        local len = Dist(a.x, a.y, c.x, c.y)
        local bm = m.mass * len / GRID
        mass[beam.a] = mass[beam.a] + bm / 2
        mass[beam.b] = mass[beam.b] + bm / 2
        s.beams[#s.beams + 1] = { a = beam.a, b = beam.b, mat = beam.mat, rest = len,
            compliance = len / m.stiffness, strength = m.strength, rope = m.rope, road = m.road,
            force = 0, smooth = 0, load = 0 }
    end
    for i, n in ipairs(s.nodes) do
        n.w = (n.anchor or mass[i] <= 0) and 0 or 1 / mass[i]
    end
    s.static = StaticSegments(level)
    -- The vehicle: two wheels on the ground at the start, rear wheel first.
    local v = BA.VEHICLES[level.vehicle]
    local sx, sy = level.start[1], level.start[2]
    local wheelW = 2 / v.mass
    s.wheels = {
        { x = sx - v.base / 2, y = sy - v.radius, px = sx - v.base / 2, py = sy - v.radius, w = wheelW, r = v.radius },
        { x = sx + v.base / 2, y = sy - v.radius, px = sx + v.base / 2, py = sy - v.radius, w = wheelW, r = v.radius },
    }
    s.vehicle = v
    s.lastX, s.stuckTime = sx, 0
    return s
end

-- Closest point on a segment.
local function Closest(px, py, ax, ay, bx, by)
    local dx, dy = bx - ax, by - ay
    local l2 = dx * dx + dy * dy
    local t = l2 > 0 and math.max(0, math.min(1, ((px - ax) * dx + (py - ay) * dy) / l2)) or 0
    return ax + dx * t, ay + dy * t, t
end

-- Pushes wheel `wh` out of a segment; for a beam the push goes into its two joints as well.
local function Collide(wh, ax, ay, bx, by, na, nb)
    local cx, cy, t = Closest(wh.x, wh.y, ax, ay, bx, by)
    local dx, dy = wh.x - cx, wh.y - cy
    local d = math.sqrt(dx * dx + dy * dy)
    if d >= wh.r then return false end
    local nx, ny
    if d > 1e-6 then
        nx, ny = dx / d, dy / d
    else
        local sx, sy = bx - ax, by - ay
        local l = math.sqrt(sx * sx + sy * sy)
        nx, ny = sy / l, -sx / l
        if ny > 0 then nx, ny = -nx, -ny end
    end
    local pen = wh.r - d
    local wa = na and na.w * (1 - t) ^ 2 or 0
    local wb = nb and nb.w * t * t or 0
    local wsum = wh.w + wa + wb
    if wsum <= 0 then return false end
    local k = pen / wsum
    wh.x, wh.y = wh.x + nx * k * wh.w, wh.y + ny * k * wh.w
    if na and na.w > 0 then
        na.x, na.y = na.x - nx * k * na.w * (1 - t), na.y - ny * k * na.w * (1 - t)
    end
    if nb and nb.w > 0 then
        nb.x, nb.y = nb.x - nx * k * nb.w * t, nb.y - ny * k * nb.w * t
    end
    -- The surface under the wheel, for driving along it.
    if ny < -0.3 then
        wh.ground = true
        wh.tx, wh.ty = -ny, nx
    end
    return true
end

local function Substep(s, h)
    -- Gravity is eased in while the bridge settles, so it does not get a sudden jolt.
    local g = P.GRAVITY * math.min(1, s.t / START_DELAY)
    local keep = 1 - DAMPING * h
    -- Predict.
    for _, n in ipairs(s.nodes) do
        if n.w > 0 then
            local vx, vy = (n.x - n.px) * keep, (n.y - n.py) * keep
            n.px, n.py = n.x, n.y
            n.x, n.y = n.x + vx, n.y + vy + g * h * h
        end
    end
    local driving = s.t >= START_DELAY
    for _, wh in ipairs(s.wheels) do
        local vx, vy = (wh.x - wh.px) * keep, (wh.y - wh.py) * keep
        wh.px, wh.py = wh.x, wh.y
        wh.x, wh.y = wh.x + vx, wh.y + vy + g * h * h
        wh.vx = vx / h
    end
    -- Beams.
    local h2 = h * h
    for _, beam in ipairs(s.beams) do
        if not beam.broken then
            local a, c = s.nodes[beam.a], s.nodes[beam.b]
            local wsum = a.w + c.w
            if wsum > 0 then
                local dx, dy = c.x - a.x, c.y - a.y
                local len = math.sqrt(dx * dx + dy * dy)
                if len > 1e-6 then
                    local C = len - beam.rest
                    if beam.rope and C < 0 then
                        beam.force = 0
                    else
                        local alpha = beam.compliance / h2
                        local dl = -C / (wsum + alpha)
                        -- Positive force: pulled (tension); negative: pushed.
                        beam.force = -dl / h2
                        local nx, ny = dx / len, dy / len
                        a.x, a.y = a.x - nx * dl * a.w, a.y - ny * dl * a.w
                        c.x, c.y = c.x + nx * dl * c.w, c.y + ny * dl * c.w
                    end
                end
            end
        end
    end
    -- The chassis keeps the wheels apart (rigid).
    local w1, w2 = s.wheels[1], s.wheels[2]
    do
        local dx, dy = w2.x - w1.x, w2.y - w1.y
        local len = math.sqrt(dx * dx + dy * dy)
        if len > 1e-6 then
            local C = (len - s.vehicle.base) / (w1.w + w2.w)
            local nx, ny = dx / len, dy / len
            w1.x, w1.y = w1.x + nx * C * w1.w, w1.y + ny * C * w1.w
            w2.x, w2.y = w2.x - nx * C * w2.w, w2.y - ny * C * w2.w
        end
    end
    -- Wheels on the road and the ground.
    for _, wh in ipairs(s.wheels) do
        wh.ground = false
        for _, beam in ipairs(s.beams) do
            if beam.road and not beam.broken then
                local a, c = s.nodes[beam.a], s.nodes[beam.b]
                Collide(wh, a.x, a.y, c.x, c.y, a, c)
            end
        end
        for _, seg in ipairs(s.static) do Collide(wh, seg[1], seg[2], seg[3], seg[4]) end
        -- Driving: on the ground the wheel is brought towards the vehicle's speed along the surface.
        if driving and wh.ground then
            local v = s.vehicle.speed
            local cur = ((wh.x - wh.px) * wh.tx + (wh.y - wh.py) * wh.ty) / h
            local dv = (v - cur) * 0.25
            wh.x, wh.y = wh.x + wh.tx * dv * h, wh.y + wh.ty * dv * h
        end
    end
    -- Loads and breaking. The load follows the force with a short lag, so the jolt of a wheel
    -- rolling over a joint does not snap a beam that carries the weight itself well.
    local follow = math.min(1, h / LOAD_LAG)
    for _, beam in ipairs(s.beams) do
        if not beam.broken then
            beam.smooth = beam.smooth + (math.abs(beam.force) - beam.smooth) * follow
            beam.load = beam.smooth / beam.strength
            if beam.load > s.peak then s.peak = beam.load end
            if beam.load > 1 then
                beam.broken = true
                s.broken = s.broken + 1
                local a, c = s.nodes[beam.a], s.nodes[beam.b]
                s.events[#s.events + 1] = { type = "break", x = (a.x + c.x) / 2, y = (a.y + c.y) / 2, mat = beam.mat }
            end
        end
    end
end

function P.Step(s, dt)
    if s.result then return end
    local n = P.SUBSTEPS
    local h = dt / n
    for _ = 1, n do Substep(s, h) end
    s.t = s.t + dt
    local level = s.level
    local x = (s.wheels[1].x + s.wheels[2].x) / 2
    local y = math.max(s.wheels[1].y, s.wheels[2].y)
    if x >= level.goal then
        s.result = "won"
    elseif y > level.water + 6 then
        s.result = "lost"
        s.why = "water"
    elseif s.t > MAX_TIME then
        s.result = "lost"
        s.why = "time"
    else
        -- Stuck: hardly any way made for a while.
        if s.t > START_DELAY then
            if math.abs(x - s.lastX) < 0.5 * dt * 20 then
                s.stuckTime = s.stuckTime + dt
            else
                s.stuckTime = 0
            end
            if s.stuckTime > 4 then
                s.result = "lost"
                s.why = "stuck"
            end
        end
        s.lastX = x
    end
    if s.result then s.events[#s.events + 1] = { type = s.result, why = s.why } end
end

-- Where the vehicle is: centre between the wheels and its tilt (radians, positive = nose up).
function P.VehiclePose(s)
    local w1, w2 = s.wheels[1], s.wheels[2]
    local x, y = (w1.x + w2.x) / 2, (w1.y + w2.y) / 2
    return x, y, math.atan2(w1.y - w2.y, w2.x - w1.x)
end

-- Runs a whole test (for the tests and bots): returns "won"/"lost", why, the simulation.
function P.Run(build, level, dt)
    local s = P.NewSim(build, level)
    dt = dt or 1 / 60
    while not s.result do P.Step(s, dt) end
    return s.result, s.why, s
end

-- Stars for a bridge that held: 1 within the budget, 2 and 3 when it was cheaper still.
function P.Stars(level, cost)
    if cost > level.budget then return 0 end
    if cost <= level.budget * (level.star3 or 0.7) then return 3 end
    if cost <= level.budget * (level.star2 or 0.85) then return 2 end
    return 1
end
