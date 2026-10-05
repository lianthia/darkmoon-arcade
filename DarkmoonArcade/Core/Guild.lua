-- Guild leaderboard: personal bests travel as hidden addon messages to guild members
-- who run Darkmoon Arcade as well. Nothing is posted to the guild chat.

local _, ns = ...

local Guild = {}
ns.Guild = Guild

local PREFIX = "DMArcade"
local SEP = "\t"
local REPLY_COOLDOWN = 60
local SEND_SPACING = 0.3

local lastReply = 0
local outbox, sending = {}, false

local function PlayerName()
    return UnitName("player")
end

local function Flush()
    local message = table.remove(outbox, 1)
    if not message then
        sending = false
        return
    end
    if IsInGuild() then pcall(C_ChatInfo.SendAddonMessage, PREFIX, message, "GUILD") end
    C_Timer.After(SEND_SPACING, Flush)
end

local function Send(message)
    outbox[#outbox + 1] = message
    if not sending then
        sending = true
        Flush()
    end
end

local function Store(gameId, bucket, name, score)
    local guild = ns.db.guild
    guild[gameId] = guild[gameId] or {}
    guild[gameId][bucket] = guild[gameId][bucket] or {}
    local entry = guild[gameId][bucket][name]
    if not entry or entry.score < score then
        guild[gameId][bucket][name] = { score = score, time = time() }
        return true
    end
end

function Guild.Submit(gameId, bucket, score)
    if not IsInGuild() or score <= 0 then return end
    Send(table.concat({ "S", gameId, bucket, score }, SEP))
end

function Guild.BroadcastBests()
    for gameId, buckets in pairs(ns.db.scores) do
        for bucket, list in pairs(buckets) do
            if list[1] then Guild.Submit(gameId, bucket, list[1].score) end
        end
    end
end

-- Top `count` guild entries for a game and bucket, the player's own best included.
function Guild.Top(gameId, bucket, count)
    local merged = {}
    local stored = ns.db.guild[gameId] and ns.db.guild[gameId][bucket] or {}
    for name, entry in pairs(stored) do
        merged[#merged + 1] = { name = name, score = entry.score }
    end
    local own = ns.Scores.Best(gameId, bucket)
    if own > 0 then merged[#merged + 1] = { name = PlayerName(), score = own, own = true } end
    table.sort(merged, function(a, b) return a.score > b.score end)
    while #merged > count do table.remove(merged) end
    return merged
end

local function OnMessage(text, sender)
    local name = Ambiguate(sender, "short")
    if name == PlayerName() then return end
    local kind, gameId, bucket, score = strsplit(SEP, text)
    if kind == "S" then
        score = tonumber(score)
        if gameId and bucket and score and ns.Arcade.games[gameId] and Store(gameId, bucket, name, score) then
            ns.Window:UpdateSidebar()
        end
    elseif kind == "R" and GetTime() - lastReply > REPLY_COOLDOWN then
        lastReply = GetTime()
        C_Timer.After(1 + math.random() * 4, Guild.BroadcastBests)
    end
end

function Guild.Init()
    ns.db.guild = ns.db.guild or {}
    C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("CHAT_MSG_ADDON")
    frame:SetScript("OnEvent", function(_, _, prefix, text, channel, sender)
        if prefix == PREFIX and channel == "GUILD" then
            ns.SafeCall("Guild", OnMessage, text, sender)
        end
    end)
    -- Ask the guild for their bests a little after login, once the guild roster is known.
    C_Timer.After(15, function()
        if IsInGuild() then
            Send("R")
            Guild.BroadcastBests()
        end
    end)
end
