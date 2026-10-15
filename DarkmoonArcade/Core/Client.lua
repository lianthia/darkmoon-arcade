-- Which client the addon runs in (WoW: Forever or retail), and the few calls that differ between them.
-- Both clients load the same files; retail's own data (maps, creature displays) lives in files that
-- step aside on Forever (Games/Mercenaries/Retail.lua).

local _, ns = ...

local interface = GetBuildInfo and select(4, GetBuildInfo()) or 0
-- Forever reports 1.x interfaces (16001), retail 11.x and later.
ns.IS_RETAIL = (tonumber(interface) or 0) >= 100000

-- Retail moved the chat call into C_ChatInfo.
function ns.SendChat(message, channel, target)
    local send = C_ChatInfo and C_ChatInfo.SendChatMessage or SendChatMessage
    send(message, channel, nil, target)
end
