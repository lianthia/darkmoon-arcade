local _, ns = ...

local Achievements = { list = {}, byId = {} }
ns.Achievements = Achievements

-- defs: { id, nameKey, descKey, icon } in display order.
function Achievements.Register(gameId, defs)
    for _, def in ipairs(defs) do
        def.game = gameId
        Achievements.list[#Achievements.list + 1] = def
        Achievements.byId[def.id] = def
    end
end

function Achievements.IsDone(id)
    return ns.db.achievements[id] ~= nil
end

function Achievements.Unlock(id)
    local def = Achievements.byId[id]
    if not def or Achievements.IsDone(id) then return end
    ns.db.achievements[id] = time()
    if ns.Toast then ns.Toast:Show(def) end
    if ns.Window then ns.Window:UpdateSidebar() end
end

function Achievements.ForGame(gameId)
    local result = {}
    for _, def in ipairs(Achievements.list) do
        if def.game == gameId then result[#result + 1] = def end
    end
    return result
end

function Achievements.Count(gameId)
    local done, total = 0, 0
    for _, def in ipairs(Achievements.ForGame(gameId)) do
        total = total + 1
        if Achievements.IsDone(def.id) then done = done + 1 end
    end
    return done, total
end
