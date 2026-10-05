-- Error capture: errors in guarded code are printed once and kept in DarkmoonArcadeDB.errors,
-- so they survive a /reload and can be read from the SavedVariables file.

local _, ns = ...

local MAX_ERRORS = 20
local seen = {}

local function Record(label, err)
    local message = label .. ": " .. tostring(err)
    if seen[message] then return end
    seen[message] = true
    print("|cffff4040Darkmoon Arcade error|r " .. message)
    if ns.db then
        ns.db.errors = ns.db.errors or {}
        table.insert(ns.db.errors, 1, {
            message = message,
            stack = debugstack and debugstack(3, 12, 0) or nil,
            time = date and date("%Y-%m-%d %H:%M:%S") or nil,
        })
        while #ns.db.errors > MAX_ERRORS do table.remove(ns.db.errors) end
    end
end

-- Calls fn(...) and returns true plus its first result, or false after recording the error.
function ns.SafeCall(label, fn, ...)
    local ok, result = xpcall(fn, function(err)
        Record(label, err)
        return err
    end, ...)
    return ok, result
end
