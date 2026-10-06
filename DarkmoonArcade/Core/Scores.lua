local _, ns = ...

local Scores = {}
ns.Scores = Scores

Scores.MAX = 10

function Scores.List(gameId, bucket)
    local db = ns.db.scores
    db[gameId] = db[gameId] or {}
    db[gameId][bucket] = db[gameId][bucket] or {}
    return db[gameId][bucket]
end

function Scores.Best(gameId, bucket)
    local best = Scores.List(gameId, bucket)[1]
    return best and best.score or 0
end

-- Inserts `entry` ({ score, ... }) and returns its rank, or nil if it did not make the list.
function Scores.Record(gameId, bucket, entry)
    if not entry.score or entry.score <= 0 then return nil end
    if ns.Stats then ns.Stats.AddRun(gameId) end
    entry.time = entry.time or time()
    local list = Scores.List(gameId, bucket)
    local rank
    for i = 1, #list + 1 do
        if not list[i] or list[i].score < entry.score then
            table.insert(list, i, entry)
            rank = i
            break
        end
    end
    while #list > Scores.MAX do table.remove(list) end
    if rank and rank > Scores.MAX then return nil end
    if rank == 1 and ns.Guild then ns.Guild.Submit(gameId, bucket, entry.score) end
    return rank
end

function Scores.Reset()
    wipe(ns.db.scores)
end
