-- Darkmoon Deck: rules of the card roguelite (pure logic, no WoW API).
-- Play poker hands from a 32-card Darkmoon deck to reach each attraction's goal; spend the
-- winnings on Darkmoon cards (trinkets) that change how hands score.

local _, ns = ...

local DD = ns.DarkmoonDeck or {}
ns.DarkmoonDeck = DD

local Game = {}
Game.__index = Game
DD.Game = Game

Game.SUITS = { "beasts", "elementals", "portals", "warlords" }
Game.RANKS = 8 -- Ace (1) through Eight, like the Darkmoon decks of old
Game.HAND_SIZE = 7
Game.MAX_SELECT = 5
Game.PLAYS, Game.DISCARDS = 4, 3
Game.MAX_TRINKETS = 5
Game.ANTES = 8
Game.ROUNDS = { "small", "big", "boss" }
Game.START_GOLD = 4
Game.REROLL_COST = 3

-- Base points and multiplier of every hand, from weakest to strongest.
Game.HANDS = {
    { key = "high", points = 5, mult = 1 },
    { key = "pair", points = 10, mult = 2 },
    { key = "twopair", points = 20, mult = 2 },
    { key = "three", points = 30, mult = 3 },
    { key = "straight", points = 30, mult = 4 },
    { key = "flush", points = 35, mult = 4 },
    { key = "fullhouse", points = 40, mult = 4 },
    { key = "four", points = 60, mult = 7 },
    { key = "straightflush", points = 100, mult = 8 },
}
local HAND_INDEX = {}
for i, hand in ipairs(Game.HANDS) do HAND_INDEX[hand.key] = i end
Game.HAND_INDEX = HAND_INDEX

local GOALS = { 150, 350, 700, 1300, 2300, 3800, 6000, 9500 }
local ROUND_FACTOR = { small = 1, big = 1.5, boss = 2 }
local ROUND_GOLD = { small = 3, big = 4, boss = 5 }
local PAIRED = { pair = true, twopair = true, three = true, fullhouse = true, four = true }
local SETS = { three = true, four = true, fullhouse = true }

-- Darkmoon cards for sale. `icon` is the client's tarot icon file ID.
Game.TRINKETS = {
    { id = "heroism", price = 4, icon = 134488 },
    { id = "bluedragon", price = 5, icon = 134484 },
    { id = "maelstrom", price = 5, icon = 134491 },
    { id = "nether", price = 5, icon = 134495 },
    { id = "crusade", price = 5, icon = 134485 },
    { id = "wrath", price = 5, icon = 134498 },
    { id = "storms", price = 8, icon = 134494 },
    { id = "madness", price = 4, icon = 134490 },
    { id = "vengeance", price = 5, icon = 134496 },
    { id = "furies", price = 5, icon = 134487 },
    { id = "lunacy", price = 6, icon = 134489 },
    { id = "blessings", price = 6, icon = 134483 },
    { id = "nobles", price = 5, icon = 351046 },
    { id = "rogues", price = 6, icon = 351047 },
    { id = "swords", price = 6, icon = 351048 },
}
local TRINKET = {}
for _, t in ipairs(Game.TRINKETS) do TRINKET[t.id] = t end
Game.TRINKET = TRINKET

-- Faire folk who run the boss attractions, each with a twist.
Game.BOSSES = { "silas", "sayge", "fozlebub", "paleo" }

local SUIT_TRINKET = { elementals = "maelstrom", portals = "nether", warlords = "crusade", beasts = "wrath" }

function Game.Goal(ante, round)
    local base = GOALS[ante] or GOALS[#GOALS] * 1.6 ^ (ante - #GOALS)
    return math.floor(base * ROUND_FACTOR[round] / 10 + 0.5) * 10
end

function Game.CardPoints(card)
    return card.rank == 1 and 10 or card.rank
end

-- Evaluates up to five cards: hand key and the cards that score.
function Game.Evaluate(cards)
    local n = #cards
    if n == 0 then return nil end
    local byRank, bySuit = {}, {}
    for _, c in ipairs(cards) do
        byRank[c.rank] = byRank[c.rank] or {}
        table.insert(byRank[c.rank], c)
        bySuit[c.suit] = (bySuit[c.suit] or 0) + 1
    end
    local groups = {}
    for rank, list in pairs(byRank) do groups[#groups + 1] = { rank = rank, cards = list } end
    table.sort(groups, function(a, b)
        if #a.cards ~= #b.cards then return #a.cards > #b.cards end
        return (a.rank == 1 and 9 or a.rank) > (b.rank == 1 and 9 or b.rank)
    end)

    local flush, straight = false, false
    if n == 5 then
        for _, count in pairs(bySuit) do if count == 5 then flush = true end end
        if #groups == 5 then
            local ranks = {}
            for _, c in ipairs(cards) do ranks[#ranks + 1] = c.rank end
            table.sort(ranks)
            if ranks[5] - ranks[1] == 4 then straight = true end
            -- The Ace also counts above the Eight.
            if ranks[1] == 1 and ranks[2] == 5 and ranks[5] == 8 then straight = true end
        end
    end

    local function Join(...)
        local out = {}
        for _, list in ipairs({ ... }) do
            for _, c in ipairs(list) do out[#out + 1] = c end
        end
        return out
    end

    if straight and flush then return "straightflush", cards end
    if #groups[1].cards == 4 then return "four", groups[1].cards end
    if #groups[1].cards == 3 and groups[2] and #groups[2].cards == 2 then return "fullhouse", cards end
    if flush then return "flush", cards end
    if straight then return "straight", cards end
    if #groups[1].cards == 3 then return "three", groups[1].cards end
    if #groups[1].cards == 2 and groups[2] and #groups[2].cards == 2 then return "twopair", Join(groups[1].cards, groups[2].cards) end
    if #groups[1].cards == 2 then return "pair", groups[1].cards end
    return "high", { groups[1].cards[1] }
end

function Game.New(random)
    local g = setmetatable({}, Game)
    g.random = random or math.random
    g.onEvent = function() end
    g.state = "READY"
    g.score = 0
    return g
end

function Game:Emit(name, data)
    self.onEvent(name, data)
end

function Game:Has(id)
    for _, t in ipairs(self.trinkets or {}) do
        if t.id == id then return t end
    end
end

-- Runs ---------------------------------------------------------------------------------

function Game:StartRun()
    self.score = 0
    self.ante = 1
    self.roundIndex = 1
    self.gold = Game.START_GOLD
    self.trinkets = {}
    self.handsPlayed = 0
    self.bestHand = 0
    self:StartRound()
end

function Game:Round()
    return Game.ROUNDS[self.roundIndex]
end

function Game:StartRound()
    local round = self:Round()
    self.goal = Game.Goal(self.ante, round)
    self.roundScore = 0
    self.boss = round == "boss" and Game.BOSSES[self.random(#Game.BOSSES)] or nil
    self.plays = Game.PLAYS + (self.boss == "paleo" and -1 or 0)
    self.discards = Game.DISCARDS + (self:Has("bluedragon") and 1 or 0)
    if self.boss == "silas" then self.discards = 0 end
    self.handSize = Game.HAND_SIZE + (self:Has("blessings") and 1 or 0) + (self.boss == "fozlebub" and -2 or 0)
    self.cursedSuit = self.boss == "sayge" and Game.SUITS[self.random(#Game.SUITS)] or nil
    self.deck = {}
    for s = 1, #Game.SUITS do
        for r = 1, Game.RANKS do self.deck[#self.deck + 1] = { suit = Game.SUITS[s], rank = r, id = s * 10 + r } end
    end
    for i = #self.deck, 2, -1 do
        local j = self.random(i)
        self.deck[i], self.deck[j] = self.deck[j], self.deck[i]
    end
    self.hand = {}
    self:Draw()
    self:RollMadness()
    self.state = "PLAYING"
    self:Emit("round", { ante = self.ante, round = round, goal = self.goal, boss = self.boss })
end

-- Madness changes after every hand; rolling it in advance keeps the preview honest.
function Game:RollMadness()
    self.madness = self.random(13) - 1
end

function Game:Draw()
    local drawn = {}
    while #self.hand < self.handSize and #self.deck > 0 do
        local card = table.remove(self.deck)
        self.hand[#self.hand + 1] = card
        drawn[#drawn + 1] = card
    end
    return drawn
end

local function Pick(hand, indexes)
    local picked, seen = {}, {}
    for _, i in ipairs(indexes) do
        if hand[i] and not seen[i] then
            seen[i] = true
            picked[#picked + 1] = hand[i]
        end
    end
    return picked, seen
end

local function Remove(hand, seen)
    for i = #hand, 1, -1 do
        if seen[i] then table.remove(hand, i) end
    end
end

-- Scores a set of cards without changing the run (also used for the preview).
function Game:Score(cards)
    local key, scoring = Game.Evaluate(cards)
    if not key then return nil end
    local hand = Game.HANDS[HAND_INDEX[key]]
    local points, mult = hand.points, hand.mult
    local notes = {}
    for _, c in ipairs(scoring) do
        if c.suit ~= self.cursedSuit then points = points + Game.CardPoints(c) end
    end
    local function Note(id, text) notes[#notes + 1] = { id = id, text = text } end
    for _, t in ipairs(self.trinkets or {}) do
        local id = t.id
        if id == "heroism" and PAIRED[key] then
            mult = mult + 4
            Note(id, "+4")
        elseif id == "storms" then
            -- Applied last, see below.
        elseif id == "maelstrom" or id == "nether" or id == "crusade" or id == "wrath" then
            local count = 0
            for _, c in ipairs(scoring) do
                if SUIT_TRINKET[c.suit] == id and c.suit ~= self.cursedSuit then count = count + 1 end
            end
            if count > 0 then
                mult = mult + 3 * count
                Note(id, "+" .. 3 * count)
            end
        elseif id == "madness" then
            mult = mult + self.madness
            Note(id, "+" .. self.madness)
        elseif id == "vengeance" and self.plays == 1 then
            mult = mult + 10
            Note(id, "+10")
        elseif id == "furies" and SETS[key] then
            points = points + 40
            Note(id, "+40")
        elseif id == "lunacy" and (t.stacks or 0) > 0 then
            mult = mult + t.stacks
            Note(id, "+" .. t.stacks)
        elseif id == "rogues" and (key == "straight" or key == "straightflush") then
            mult = mult + 12
            Note(id, "+12")
        elseif id == "swords" and (key == "flush" or key == "straightflush") then
            mult = mult + 12
            Note(id, "+12")
        end
    end
    if self:Has("storms") and #cards == 5 then
        mult = mult * 2
        Note("storms", "x2")
    end
    return { key = key, scoring = scoring, points = points, mult = mult, total = points * mult, notes = notes }
end

function Game:Play(indexes)
    if self.state ~= "PLAYING" or self.plays <= 0 then return nil end
    if #indexes == 0 or #indexes > Game.MAX_SELECT then return nil end
    local cards, seen = Pick(self.hand, indexes)
    local result = self:Score(cards)
    -- Lunacy grows after every paired hand, starting with the next one.
    local lunacy = self:Has("lunacy")
    if lunacy and PAIRED[result.key] then lunacy.stacks = (lunacy.stacks or 0) + 1 end
    Remove(self.hand, seen)
    self.plays = self.plays - 1
    self.handsPlayed = self.handsPlayed + 1
    self.roundScore = self.roundScore + result.total
    self.score = self.score + result.total
    self.bestHand = math.max(self.bestHand, result.total)
    result.cards = cards
    self:RollMadness()
    self:Emit("play", result)
    if self.roundScore >= self.goal then
        self:WinRound()
    elseif self.plays <= 0 then
        self.state = "OVER"
        self:Emit("over", { score = self.score, ante = self.ante })
    else
        result.drawn = self:Draw()
        self:Emit("draw", { cards = result.drawn })
    end
    return result
end

function Game:Discard(indexes)
    if self.state ~= "PLAYING" or self.discards <= 0 then return nil end
    if #indexes == 0 or #indexes > Game.MAX_SELECT then return nil end
    local cards, seen = Pick(self.hand, indexes)
    Remove(self.hand, seen)
    self.discards = self.discards - 1
    local drawn = self:Draw()
    self:Emit("discard", { cards = cards, drawn = drawn })
    return drawn
end

function Game:WinRound()
    local round = self:Round()
    local reward = ROUND_GOLD[round] + self.plays + math.min(5, math.floor(self.gold / 5))
    if self:Has("nobles") then reward = reward + 2 end
    self.gold = self.gold + reward
    local data = { reward = reward, round = round, ante = self.ante, boss = self.boss, plays = self.plays, discards = self.discards }
    if round == "boss" and self.ante >= Game.ANTES then
        self.state = "WON"
        self:Emit("won", data)
        return
    end
    self.state = "SHOP"
    self.rerollCost = Game.REROLL_COST
    self:RollOffers()
    self:Emit("roundWon", data)
end

-- Shop ------------------------------------------------------------------------------

function Game:RollOffers()
    local pool = {}
    for _, t in ipairs(Game.TRINKETS) do
        if not self:Has(t.id) then pool[#pool + 1] = t end
    end
    for i = #pool, 2, -1 do
        local j = self.random(i)
        pool[i], pool[j] = pool[j], pool[i]
    end
    self.offers = { pool[1], pool[2], pool[3] }
end

function Game:Reroll()
    if self.state ~= "SHOP" or self.gold < self.rerollCost then return false end
    self.gold = self.gold - self.rerollCost
    self.rerollCost = self.rerollCost + 1
    self:RollOffers()
    self:Emit("shop")
    return true
end

function Game:Buy(slot)
    local offer = self.offers and self.offers[slot]
    if self.state ~= "SHOP" or not offer or self.gold < offer.price or #self.trinkets >= Game.MAX_TRINKETS then return false end
    self.gold = self.gold - offer.price
    self.trinkets[#self.trinkets + 1] = { id = offer.id, stacks = 0 }
    self.offers[slot] = false
    self:Emit("shop")
    return true
end

function Game:SellPrice(index)
    local t = self.trinkets[index]
    return t and math.max(1, math.floor(TRINKET[t.id].price / 2)) or 0
end

function Game:Sell(index)
    if self.state ~= "SHOP" or not self.trinkets[index] then return false end
    self.gold = self.gold + self:SellPrice(index)
    table.remove(self.trinkets, index)
    self:Emit("shop")
    return true
end

function Game:NextRound()
    if self.state ~= "SHOP" then return end
    self.roundIndex = self.roundIndex + 1
    if self.roundIndex > #Game.ROUNDS then
        self.roundIndex = 1
        self.ante = self.ante + 1
    end
    self:StartRound()
end

function Game:Pause()
    if self.state == "PLAYING" then
        self.pausedFrom = self.state
        self.state = "PAUSED"
    end
end

function Game:Resume()
    if self.state == "PAUSED" then self.state = self.pausedFrom or "PLAYING" end
end

-- Best hand among the current cards; used for hints and tests.
function Game:BestPlay()
    local best, bestIndexes
    local hand = self.hand
    local n = #hand
    local function Try(indexes)
        local cards = {}
        for i, idx in ipairs(indexes) do cards[i] = hand[idx] end
        local key, scoring = Game.Evaluate(cards)
        local base = Game.HANDS[HAND_INDEX[key]]
        local points = base.points
        for _, c in ipairs(scoring) do points = points + Game.CardPoints(c) end
        local value = points * base.mult
        if not best or value > best then best, bestIndexes = value, { unpack(indexes) } end
    end
    local function Combine(start, chosen)
        if #chosen > 0 then Try(chosen) end
        if #chosen == Game.MAX_SELECT then return end
        for i = start, n do
            chosen[#chosen + 1] = i
            Combine(i + 1, chosen)
            chosen[#chosen] = nil
        end
    end
    Combine(1, {})
    return bestIndexes, best
end
