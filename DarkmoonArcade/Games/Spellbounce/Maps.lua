-- Spellbounce: peg layouts of the maps (pure logic, no WoW API).
-- Every map is a list of peg positions; which pegs become targets is decided per run.
-- Pegs with `motion` move over time: orbit (rotate around a center), slide (sway sideways)
-- or swing (hang from a pivot like a pendulum).

local _, ns = ...

local SB = ns.Spellbounce or {}
ns.Spellbounce = SB

local Maps = {}
SB.Maps = Maps

local W = 432
local MIN_X, MAX_X, MIN_Y, MAX_Y = 24, W - 24, 104, 408
-- Closest allowed distance between two peg centers; leaves room for the ball between most pegs.
Maps.MIN_DIST = 24

local function Builder()
    local pegs = {}
    local function Add(x, y, bumper, motion)
        if x < MIN_X or x > MAX_X or y < MIN_Y or y > MAX_Y then return end
        local min = bumper and Maps.MIN_DIST + 6 or Maps.MIN_DIST
        for _, p in ipairs(pegs) do
            local limit = (p.bumper or bumper) and Maps.MIN_DIST + 6 or min
            if (p.x - x) ^ 2 + (p.y - y) ^ 2 < limit * limit then return end
        end
        local peg = { x = math.floor(x + 0.5), y = math.floor(y + 0.5), bumper = bumper or nil, motion = motion }
        if motion then peg.bx, peg.by = x, y end
        pegs[#pegs + 1] = peg
    end
    return pegs, Add
end

-- Position of a moving peg at time `t`.
function Maps.Position(peg, t)
    local m = peg.motion
    if m.kind == "orbit" then
        local a = m.a + m.spin * t
        return m.cx + math.cos(a) * m.r, m.cy + math.sin(a) * m.r
    elseif m.kind == "slide" then
        return peg.bx + m.amp * math.sin(t * m.speed + m.phase), peg.by
    elseif m.kind == "swing" then
        local angle = m.amp * math.sin(t * m.speed)
        return m.px + math.sin(angle) * m.len, m.py + math.cos(angle) * m.len
    end
    return peg.x, peg.y
end

local function Orbit(Add, cx, cy, r, count, spin)
    for i = 0, count - 1 do
        local a = i / count * math.pi * 2
        Add(cx + math.cos(a) * r, cy + math.sin(a) * r, nil, { kind = "orbit", cx = cx, cy = cy, r = r, a = a, spin = spin })
    end
end

local function SlidingRow(Add, y, phase)
    for x = 54, 378, 46 do Add(x, y, nil, { kind = "slide", amp = 30, speed = 0.8, phase = phase }) end
end

local function Ring(Add, cx, cy, r, count, from, to)
    from, to = from or 0, to or math.pi * 2
    local full = to - from >= math.pi * 2 - 1e-6
    local steps = full and count or count - 1
    for i = 0, count - 1 do
        local a = from + (to - from) * i / steps
        Add(cx + math.cos(a) * r, cy + math.sin(a) * r)
    end
end

local function Line(Add, x1, y1, x2, y2, step)
    local len = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
    local n = math.floor(len / step)
    for i = 0, n do
        Add(x1 + (x2 - x1) * i / n, y1 + (y2 - y1) * i / n)
    end
end

Maps.LIST = {
    { -- Elwynn Meadow: staggered rows
        key = "meadow", background = 2,
        build = function(Add)
            for row = 0, 5 do
                local offset = row % 2 == 1 and 22 or 0
                for x = 40 + offset, 392, 44 do Add(x, 150 + row * 45) end
            end
        end,
    },
    { -- Darkmoon Tent: a tent with two poles and a row of benches
        key = "tent", background = 1,
        build = function(Add)
            Add(216, 116)
            for k = 1, 6 do
                for i = 0, k do Add(216 + (i - k / 2) * 40, 116 + k * 38) end
            end
            Add(48, 300, true)
            Add(384, 300, true)
            for k = 0, 3 do
                Add(40 + k * 26, 130 + k * 30)
                Add(392 - k * 26, 130 + k * 30)
            end
            for x = 64, 368, 48 do Add(x, 360) end
            for x = 40, 392, 48 do Add(x, 400) end
        end,
    },
    { -- Moonwell: rings around a bumper
        key = "moonwell", background = 3,
        build = function(Add)
            Add(216, 262, true)
            Ring(Add, 216, 262, 62, 10)
            Ring(Add, 216, 262, 112, 18)
            Ring(Add, 216, 262, 160, 26)
        end,
    },
    { -- Stranglethorn Tides: four waves
        key = "waves", background = 2,
        build = function(Add)
            for j = 0, 3 do
                for x = 36, 396, 30 do Add(x, 150 + j * 64 + 18 * math.sin(x / 45 + j)) end
            end
        end,
    },
    { -- Twin Moons: two moons above a smile
        key = "twins", background = 1,
        build = function(Add)
            for _, cx in ipairs({ 120, 312 }) do
                Add(cx, 210, true)
                Ring(Add, cx, 210, 66, 14)
            end
            for x = 40, 392, 32 do Add(x, 330 + 60 * ((x - 216) / 176) ^ 2) end
            Line(Add, 176, 150, 256, 150, 40)
        end,
    },
    { -- Arcane Vortex: a spiral
        key = "spiral", background = 3,
        build = function(Add)
            local a, r = 0, 26
            while r <= 156 do
                Add(216 + math.cos(a) * r, 258 + math.sin(a) * r)
                a = a + 30 / r
                r = 26 + 7.6 * a
            end
        end,
    },
    { -- Crossroads: two diagonals and a road
        key = "crossroads", background = 4,
        build = function(Add)
            Add(216, 176, true)
            Add(216, 352, true)
            Line(Add, 44, 124, 388, 404, 32)
            Line(Add, 388, 124, 44, 404, 32)
            for x = 36, 396, 32 do Add(x, 264) end
            for y = 120, 400, 32 do Add(216, y) end
            for _, x in ipairs({ 40, 392 }) do
                for y = 168, 360, 48 do Add(x, y) end
            end
        end,
    },
    { -- Titan Vaults: five diamonds
        key = "diamonds", background = 4,
        build = function(Add)
            for _, c in ipairs({ { 110, 186 }, { 322, 186 }, { 216, 264 }, { 110, 342 }, { 322, 342 } }) do
                local cx, cy = c[1], c[2]
                Add(cx, cy)
                local corners = { { 56, 0 }, { 0, 56 }, { -56, 0 }, { 0, -56 } }
                for i = 1, 4 do
                    local p, q = corners[i], corners[i % 4 + 1]
                    for k = 0, 2 do
                        Add(cx + p[1] + (q[1] - p[1]) * k / 3, cy + p[2] + (q[2] - p[2]) * k / 3)
                    end
                end
            end
        end,
    },
    { -- Lantern Lane: hanging lantern chains
        key = "lanterns", background = 1,
        build = function(Add)
            local lengths = { 5, 7, 4, 8, 4, 7, 5 }
            for i, len in ipairs(lengths) do
                local x = 48 + (i - 1) * 56
                for k = 0, len - 1 do Add(x, 120 + k * 30) end
            end
            for i = 0, 5 do
                Add(76 + i * 56, 196)
                Add(76 + i * 56, 300)
            end
            Add(132, 396, true)
            Add(300, 396, true)
        end,
    },
    { -- Darkmoon Rising: a crescent with stars
        key = "crescent", background = 3,
        build = function(Add)
            local cx, cy, r = 196, 262, 146
            local ox, oy, orad = 262, 232, 120
            for i = 0, 35 do
                local a = i / 36 * math.pi * 2
                local x, y = cx + math.cos(a) * r, cy + math.sin(a) * r
                if (x - ox) ^ 2 + (y - oy) ^ 2 > orad * orad then Add(x, y) end
            end
            for i = 0, 29 do
                local a = i / 30 * math.pi * 2
                local x, y = ox + math.cos(a) * orad, oy + math.sin(a) * orad
                if (x - cx) ^ 2 + (y - cy) ^ 2 < r * r then Add(x, y) end
            end
            for _, s in ipairs({ { 300, 190 }, { 330, 300 } }) do
                Add(s[1], s[2], true)
                Ring(Add, s[1], s[2], 30, 5, -math.pi / 2, math.pi * 1.5)
            end
            Add(232, 252)
            Ring(Add, 232, 252, 30, 5, -math.pi / 2, math.pi * 1.5)
        end,
    },
    { -- Darkmoon Carousel: two rings turning against each other
        key = "carousel", background = 1,
        build = function(Add)
            Add(216, 262, true)
            Orbit(Add, 216, 262, 66, 12, 0.5)
            Orbit(Add, 216, 262, 128, 22, -0.35)
        end,
    },
    { -- Shifting Tides: rows sliding back and forth
        key = "tides", background = 3,
        build = function(Add)
            for row = 0, 4 do SlidingRow(Add, 150 + row * 52, row * math.pi) end
        end,
    },
    { -- Ferris Wheel: a turning rim with spokes
        key = "wheel", background = 2,
        build = function(Add)
            Add(216, 262, true)
            Orbit(Add, 216, 262, 140, 28, 0.25)
            for spoke = 0, 3 do
                local a = spoke * math.pi / 2 + math.pi / 4
                for _, r in ipairs({ 44, 74, 104 }) do
                    Add(216 + math.cos(a) * r, 262 + math.sin(a) * r, nil,
                        { kind = "orbit", cx = 216, cy = 262, r = r, a = a, spin = 0.25 })
                end
            end
        end,
    },
    { -- Swinging Lanterns: chains swaying together above a row of benches
        key = "pendulum", background = 4,
        build = function(Add)
            for i = 0, 5 do
                local px = 66 + i * 60
                for k = 1, 4 do
                    Add(px, 108 + k * 30, nil, { kind = "swing", px = px, py = 108, len = k * 30, amp = 0.22, speed = 1.1 })
                end
            end
            for x = 42, 390, 48 do Add(x, 320) end
            Add(120, 384, true)
            Add(312, 384, true)
            for x = 216 - 48, 216 + 48, 48 do Add(x, 394) end
        end,
    },
    { -- Grand Carnival: a spinning center, still arcs and a sliding floor
        key = "carnival", background = 1,
        build = function(Add)
            Add(216, 236, true)
            Orbit(Add, 216, 236, 58, 10, 0.6)
            Ring(Add, 216, 236, 150, 9, math.pi * 0.95, math.pi * 1.45)
            Ring(Add, 216, 236, 150, 9, -math.pi * 0.45, math.pi * 0.05)
            SlidingRow(Add, 384, 0)
            for x = 70, 362, 73 do Add(x, 330) end
        end,
    },
}
Maps.COUNT = #Maps.LIST

function Maps.Get(index)
    return Maps.LIST[(index - 1) % Maps.COUNT + 1]
end

-- Fresh peg list for a map; positions only, kinds are assigned by the game.
function Maps.Build(index)
    local pegs, Add = Builder()
    Maps.Get(index).build(Add)
    return pegs
end
