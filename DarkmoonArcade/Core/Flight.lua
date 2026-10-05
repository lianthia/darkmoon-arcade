-- Flight time. Known routes use the last measured duration. Unknown routes are estimated live:
-- the player's speed on the taxi map and the remaining route length share one coordinate space,
-- so no yard conversion is involved.

local _, ns = ...

local Flight = {}
ns.Flight = Flight

local SAMPLE_INTERVAL = 0.5
local SPEED_SMOOTHING = 0.3
local MIN_SAMPLES = 4
-- Route hops are straight lines; the real path curves a little.
local DEFAULT_CURVE = 1.1

local pending

local function TaxiMapID()
    if GetTaxiMapID then
        local id = GetTaxiMapID()
        if id and id > 0 then return id end
    end
    local mapID = C_Map.GetBestMapForUnit("player")
    while mapID do
        local info = C_Map.GetMapInfo(mapID)
        if not info then return nil end
        if info.mapType == Enum.UIMapType.Continent then return mapID end
        mapID = info.parentMapID
    end
end

local function Distance(a, b)
    return math.sqrt((a[1] - b[1]) ^ 2 + (a[2] - b[2]) ^ 2)
end

local function RoutePoints(node)
    local hops = GetNumRoutes(node)
    if not hops or hops < 1 then return nil end
    local points = { { TaxiGetSrcX(node, 1), TaxiGetSrcY(node, 1) } }
    for hop = 1, hops do
        points[#points + 1] = { TaxiGetDestX(node, hop), TaxiGetDestY(node, hop) }
    end
    for _, p in ipairs(points) do
        if type(p[1]) ~= "number" or type(p[2]) ~= "number" then return nil end
    end
    return points
end

local function PathLength(points)
    local length = 0
    for i = 1, #points - 1 do length = length + Distance(points[i], points[i + 1]) end
    return length
end

-- Remaining route length from `pos`, measured from its projection onto the nearest hop.
local function Remaining(points, pos)
    local bestIndex, bestDist, bestProj = 1, math.huge, points[1]
    for i = 1, #points - 1 do
        local a, b = points[i], points[i + 1]
        local dx, dy = b[1] - a[1], b[2] - a[2]
        local len2 = dx * dx + dy * dy
        local t = len2 > 0 and ((pos[1] - a[1]) * dx + (pos[2] - a[2]) * dy) / len2 or 0
        t = math.max(0, math.min(1, t))
        local proj = { a[1] + dx * t, a[2] + dy * t }
        local d = Distance(pos, proj)
        if d < bestDist then bestIndex, bestDist, bestProj = i, d, proj end
    end
    local remaining = Distance(bestProj, points[bestIndex + 1])
    for i = bestIndex + 1, #points - 1 do remaining = remaining + Distance(points[i], points[i + 1]) end
    return remaining
end

local function Plan(node)
    local from
    for i = 1, NumTaxiNodes() do
        if TaxiNodeGetType(i) == "CURRENT" then from = i end
    end
    local plan = {
        from = from and TaxiNodeName(from) or "?",
        to = TaxiNodeName(node),
    }
    plan.key = plan.from .. " > " .. plan.to
    plan.known = ns.db.flights[plan.key]
    local okMap, mapID = pcall(TaxiMapID)
    local okPoints, points = pcall(RoutePoints, node)
    if okMap and mapID and okPoints and points then
        plan.mapID, plan.points, plan.length = mapID, points, PathLength(points)
    end
    return plan
end

function Flight:Init()
    hooksecurefunc("TakeTaxiNode", function(node)
        local ok, plan = pcall(Plan, node)
        pending = ok and plan or nil
    end)
end

function Flight:Start()
    self.current = pending or {}
    self.current.startTime = GetTime()
    self.current.samples = 0
    pending = nil
    if self.ticker then self.ticker:Cancel() end
    self.ticker = C_Timer.NewTicker(SAMPLE_INTERVAL, function() ns.SafeCall("Flight", self.Sample, self) end)
end

function Flight:Finish()
    local flight = self.current
    self.current = nil
    if self.ticker then
        self.ticker:Cancel()
        self.ticker = nil
    end
    if not flight or not flight.key or not flight.startTime then return end
    local duration = GetTime() - flight.startTime
    if duration < 10 then return end
    local db = ns.db
    db.flights[flight.key] = duration
    if flight.mapID and flight.length and flight.length > 0 then
        local rate = duration / flight.length
        local old = db.flightRate[flight.mapID]
        db.flightRate[flight.mapID] = old and (old * 0.6 + rate * 0.4) or rate
    end
end

local function PlayerPosition(mapID)
    local ok, pos = pcall(C_Map.GetPlayerMapPosition, mapID, "player")
    if not ok or not pos then return nil end
    local okXY, x, y = pcall(pos.GetXY, pos)
    if okXY and type(x) == "number" and type(y) == "number" and (x > 0 or y > 0) then return { x, y } end
end

-- Samples the player's position; called regularly while the arcade window is open.
function Flight:Sample()
    local flight = self.current
    if not (flight and flight.points) then return end
    local now = GetTime()
    if flight.lastTime and now - flight.lastTime < SAMPLE_INTERVAL then return end
    local pos = PlayerPosition(flight.mapID)
    if not pos then return end
    if flight.lastPos then
        local speed = Distance(pos, flight.lastPos) / (now - flight.lastTime)
        if speed > 0 then
            flight.speed = flight.speed and (flight.speed * (1 - SPEED_SMOOTHING) + speed * SPEED_SMOOTHING) or speed
            flight.samples = flight.samples + 1
        end
    end
    flight.lastPos, flight.lastTime = pos, now
    flight.remainingPath = Remaining(flight.points, pos)
end

-- Destination, seconds (remaining, or elapsed when unknown), exact?, estimate available?
function Flight:Status()
    local flight = self.current
    if not flight then return nil end
    local elapsed = GetTime() - (flight.startTime or GetTime())
    local dest = flight.to or ""
    if flight.known then
        return dest, math.max(0, flight.known - elapsed), true, true
    end
    if flight.speed and flight.samples >= MIN_SAMPLES and flight.remainingPath then
        return dest, flight.remainingPath * DEFAULT_CURVE / flight.speed, false, true
    end
    local rate = flight.mapID and ns.db.flightRate[flight.mapID]
    if rate and flight.length then
        return dest, math.max(0, flight.length * rate - elapsed), false, true
    end
    return dest, elapsed, false, false
end
