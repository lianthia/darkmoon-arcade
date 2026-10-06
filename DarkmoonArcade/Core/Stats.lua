-- Play statistics: time per game, finished runs, flights with the arcade open and
-- free-form counters that games add for their own highlights.

local _, ns = ...

local Stats = {}
ns.Stats = Stats

function Stats.DB()
    local db = ns.db
    db.stats = db.stats or {}
    local s = db.stats
    s.since = s.since or time()
    s.time = s.time or {}
    s.flightTime = s.flightTime or 0
    s.runs = s.runs or {}
    s.flights = s.flights or 0
    s.counters = s.counters or {}
    return s
end

function Stats.AddTime(gameId, seconds, inFlight)
    local s = Stats.DB()
    s.time[gameId] = (s.time[gameId] or 0) + seconds
    if inFlight then s.flightTime = s.flightTime + seconds end
end

function Stats.AddRun(gameId)
    local s = Stats.DB()
    s.runs[gameId] = (s.runs[gameId] or 0) + 1
end

function Stats.AddFlight()
    local s = Stats.DB()
    s.flights = s.flights + 1
end

function Stats.Bump(gameId, key, amount)
    local counters = Stats.DB().counters
    counters[gameId] = counters[gameId] or {}
    counters[gameId][key] = (counters[gameId][key] or 0) + (amount or 1)
end

function Stats.Get(gameId, key)
    local counters = Stats.DB().counters[gameId]
    return counters and counters[key] or 0
end

function Stats.TotalTime()
    local total = 0
    for _, seconds in pairs(Stats.DB().time) do total = total + seconds end
    return total
end

function Stats.TotalRuns()
    local total = 0
    for _, runs in pairs(Stats.DB().runs) do total = total + runs end
    return total
end

-- The game with the most time played, or nil before anything was played.
function Stats.Favorite()
    local best, bestTime
    for id, seconds in pairs(Stats.DB().time) do
        if ns.Arcade.games[id] and (not bestTime or seconds > bestTime) then best, bestTime = id, seconds end
    end
    return best
end

function Stats.Reset()
    ns.db.stats = nil
end

-- "2 h 05 min" or "4 min"; independent of the language.
function ns.FormatDuration(seconds)
    local minutes = math.floor((seconds or 0) / 60)
    if minutes >= 60 then return ("%d h %02d min"):format(math.floor(minutes / 60), minutes % 60) end
    return ("%d min"):format(minutes)
end
