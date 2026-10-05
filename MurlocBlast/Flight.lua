-- Flight time estimates. Known routes use the last measured duration; unknown routes are
-- estimated from the route length in yards, calibrated per continent by finished flights.

local _, ns = ...

local Flight = {}
ns.Flight = Flight

local DEFAULT_SECONDS_PER_YARD = 1 / 30
local TAKEOFF_SECONDS = 4

local pending

local function ContinentMapID()
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

local function WorldPos(mapID, x, y)
    local _, pos = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(x, y))
    if pos then return pos:GetXY() end
end

local function RouteLength(mapID, node)
    local hops = GetNumRoutes(node)
    if not hops or hops < 1 then return nil end
    local length = 0
    for hop = 1, hops do
        local x1, y1 = WorldPos(mapID, TaxiGetSrcX(node, hop), TaxiGetSrcY(node, hop))
        local x2, y2 = WorldPos(mapID, TaxiGetDestX(node, hop), TaxiGetDestY(node, hop))
        if not (x1 and x2) then return nil end
        length = length + math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
    end
    return length
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
    local db = ns.db
    plan.known = db.flights[plan.key]
    local ok, mapID = pcall(ContinentMapID)
    if ok and mapID then
        local okLength, length = pcall(RouteLength, mapID, node)
        if okLength and length then
            plan.mapID, plan.length = mapID, length
        end
    end
    if plan.known then
        plan.estimate = plan.known
    elseif plan.length then
        local rate = db.flightRate[plan.mapID] or DEFAULT_SECONDS_PER_YARD
        plan.estimate = plan.length * rate + TAKEOFF_SECONDS
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
    pending = nil
end

function Flight:Finish()
    local flight = self.current
    self.current = nil
    if not flight or not flight.key or not flight.startTime then return end
    local duration = GetTime() - flight.startTime
    if duration < 10 then return end
    local db = ns.db
    db.flights[flight.key] = duration
    if flight.length and flight.length > 0 then
        local measured = (duration - TAKEOFF_SECONDS) / flight.length
        local old = db.flightRate[flight.mapID]
        db.flightRate[flight.mapID] = old and (old * 0.7 + measured * 0.3) or measured
    end
end

-- Returns destination, remaining seconds (or elapsed when unknown), and whether it is exact.
function Flight:Status()
    local flight = self.current
    if not flight then return nil end
    local elapsed = GetTime() - (flight.startTime or GetTime())
    if flight.estimate then
        return flight.to, math.max(0, flight.estimate - elapsed), flight.known ~= nil, true
    end
    return flight.to, elapsed, false, false
end
