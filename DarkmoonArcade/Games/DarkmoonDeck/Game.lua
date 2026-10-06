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
Game.FORTUNE_PRICE = 4
Game.INTEREST_CAP = 5

-- Base points and multiplier of every hand, from weakest to strongest.
-- `lp`/`lm` are what every further level (bought as one of Sayge's fortunes) adds.
Game.HANDS = {
    { key = "high", points = 5, mult = 1, lp = 10, lm = 1 },
    { key = "pair", points = 10, mult = 2, lp = 15, lm = 1 },
    { key = "twopair", points = 20, mult = 2, lp = 20, lm = 1 },
    { key = "three", points = 30, mult = 3, lp = 20, lm = 2 },
    { key = "straight", points = 30, mult = 4, lp = 30, lm = 3 },
    { key = "flush", points = 35, mult = 4, lp = 25, lm = 2 },
    { key = "fullhouse", points = 40, mult = 4, lp = 25, lm = 2 },
    { key = "four", points = 60, mult = 7, lp = 30, lm = 3 },
    { key = "straightflush", points = 100, mult = 8, lp = 40, lm = 4 },
}
local HAND_INDEX = {}
for i, hand in ipairs(Game.HANDS) do HAND_INDEX[hand.key] = i end
Game.HAND_INDEX = HAND_INDEX

local GOALS = { 200, 450, 900, 1800, 3400, 6200, 11000, 19000 }
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
    { id = "ace", price = 5, icon = 134493 },
    { id = "twins", price = 5, icon = 351045 },
    { id = "eights", price = 5, icon = 351049 },
    { id = "smallfry", price = 5, icon = 351042 },
    { id = "scrapper", price = 5, icon = 351044 },
    { id = "blessing", price = 9, icon = 351043 },
    { id = "piggy", price = 5, icon = "Interface\\Icons\\INV_Misc_Coin_02" },
    { id = "gambler", price = 6, icon = "Interface\\Icons\\INV_Misc_Dice_01" },
    { id = "collector", price = 6, icon = "Interface\\Icons\\INV_Misc_Bag_10" },
    { id = "hoarder", price = 6, icon = "Interface\\Icons\\INV_Misc_Coin_01" },
    { id = "minimalist", price = 5, icon = "Interface\\Icons\\INV_Misc_Note_01" },
    { id = "perfectionist", price = 7, icon = "Interface\\Icons\\INV_Misc_Gem_Pearl_05" },
    { id = "momentum", price = 6, icon = "Interface\\Icons\\Ability_Rogue_SliceDice" },
    { id = "treasure", price = 5, icon = "Interface\\Icons\\INV_Misc_Map_01" },
    { id = "fourwinds", price = 7, icon = "Interface\\Icons\\Spell_Nature_Cyclone" },
    { id = "prophet", price = 5, icon = "Interface\\Icons\\Spell_Holy_MindVision" },
}
Game.FORTUNE_ICON = "Interface\\Icons\\Spell_Holy_MindVision"
local TRINKET = {}
for _, t in ipairs(Game.TRINKETS) do TRINKET[t.id] = t end
Game.TRINKET = TRINKET

-- Faire folk who run the boss attractions, each with a twist.
Game.BOSSES = { "silas", "sayge", "fozlebub", "paleo", "kerri", "burth", "selina", "flik" }
local WEAK_HANDS = { high = true, pair = true }

local SUIT_TRINKET = { elementals = "maelstrom", portals = "nether", warlords = "crusade", beasts = "wrath" }

function Game.Goal(ante, round)
    local base = GOALS[ante] or GOALS[#GOALS] * 1.8 ^ (ante - #GOALS)
    return math.floor(base * ROUND_FACTOR[round] / 10 + 0.5) * 10
end

function Game.CardPoints(card)
    return card.rank == 1 and 10 or card.rank
end

-- Evaluates up to five cards: hand key and the cards that score.
local function RankHigh(rank) return rank == 1 and 9 or rank end

-- The longest run of consecutive ranks (Ace low or high) among `cards`, as a card list.
local function FindStraight(cards, length)
    local byRank = {}
    for _, c in ipairs(cards) do byRank[c.rank] = byRank[c.rank] or c end
    for top = 9, length, -1 do
        local run = {}
        for r = top, top - length + 1, -1 do
            local card = byRank[r == 9 and 1 or r]
            if not card then break end
            run[#run + 1] = card
        end
        if #run == length then return run end
    end
end

local function FindFlush(cards, length)
    local bySuit = {}
    for _, c in ipairs(cards) do
        bySuit[c.suit] = bySuit[c.suit] or {}
        table.insert(bySuit[c.suit], c)
    end
    for _, list in pairs(bySuit) do
        if #list >= length then return list end
    end
end

-- Evaluates up to five cards: hand key and the cards that score. With `short`, straights and
-- flushes need only four cards.
function Game.Evaluate(cards, short)
    local n = #cards
    if n == 0 then return nil end
    if short and n >= 4 then
        local straight, flush = FindStraight(cards, 4), FindFlush(cards, 4)
        if straight and flush and FindFlush(straight, 4) then return "straightflush", straight end
        local key, scoring = Game.Evaluate(cards)
        if Game.HAND_INDEX[key] >= Game.HAND_INDEX.flush then return key, scoring end
        if flush then return "flush", flush end
        if straight and Game.HAND_INDEX[key] < Game.HAND_INDEX.straight then return "straight", straight end
        return key, scoring
    end
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
        return RankHigh(a.rank) > RankHigh(b.rank)
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
    self.levels = {}
    self.handsPlayed = 0
    self.bestHand = 0
    self.endless = false
    self.lastBoss = nil
    self:StartRound()
end

function Game:Round()
    return Game.ROUNDS[self.roundIndex]
end

function Game:StartRound()
    local round = self:Round()
    self.goal = Game.Goal(self.ante, round)
    self.roundScore = 0
    self.boss = nil
    if round == "boss" then
        -- Never the same Faire folk twice in a row.
        repeat self.boss = Game.BOSSES[self.random(#Game.BOSSES)] until self.boss ~= self.lastBoss or #Game.BOSSES < 2
        self.lastBoss = self.boss
    end
    self.plays = Game.PLAYS + (self.boss == "paleo" and -1 or 0) + (self:Has("blessing") and 1 or 0)
    self.playsMade, self.discardsUsed = 0, 0
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

-- Madness and the gambler change after every hand; rolling them in advance keeps the preview honest.
function Game:RollMadness()
    self.madness = self.random(13) - 1
    self.gamble = self.random(4) == 1
end

function Game:Level(key)
    return (self.levels and self.levels[key]) or 1
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
    local key, scoring = Game.Evaluate(cards, self:Has("fourwinds") ~= nil)
    if not key then return nil end
    local hand = Game.HANDS[HAND_INDEX[key]]
    local level = self:Level(key)
    local points, mult = hand.points + hand.lp * (level - 1), hand.mult + hand.lm * (level - 1)
    local notes = {}
    local factor = 1
    local allScore = #scoring == #cards
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
        elseif id == "ace" or id == "eights" or id == "smallfry" then
            local aces, eights, small = 0, 0, true
            for _, c in ipairs(scoring) do
                if c.rank == 1 then aces = aces + 1 end
                if c.rank == 8 then eights = eights + 1 end
                if c.rank == 1 or c.rank > 4 then small = false end
            end
            if id == "ace" and aces > 0 then
                points = points + 30 * aces
                Note(id, "+" .. 30 * aces)
            elseif id == "eights" and eights > 0 then
                mult = mult + 4 * eights
                Note(id, "+" .. 4 * eights)
            elseif id == "smallfry" and small then
                mult = mult + 8
                Note(id, "+8")
            end
        elseif id == "twins" and key == "twopair" then
            mult = mult + 8
            Note(id, "+8")
        elseif id == "scrapper" and (self.discardsUsed or 0) > 0 then
            mult = mult + 3 * self.discardsUsed
            Note(id, "+" .. 3 * self.discardsUsed)
        elseif id == "collector" then
            mult = mult + 2 * #self.trinkets
            Note(id, "+" .. 2 * #self.trinkets)
        elseif id == "hoarder" and (self.gold or 0) >= 4 then
            local bonus = math.floor(self.gold / 4)
            mult = mult + bonus
            Note(id, "+" .. bonus)
        elseif id == "minimalist" and #cards <= 3 then
            mult = mult + 15
            Note(id, "+15")
        elseif id == "momentum" and (t.stacks or 0) > 0 and key == t.key then
            mult = mult + 3 * t.stacks
            Note(id, "+" .. 3 * t.stacks)
        end
    end
    if self:Has("storms") and #cards == 5 then
        factor = factor * 2
        Note("storms", "x2")
    end
    if self:Has("perfectionist") and allScore then
        factor = factor * 1.5
        Note("perfectionist", "x1.5")
    end
    if self:Has("gambler") and self.gamble then
        factor = factor * 3
        Note("gambler", "x3")
    end
    mult = mult * factor
    local total = math.floor(points * mult)
    -- Bosses that void a hand.
    local voided = (self.boss == "kerri" and WEAK_HANDS[key]) or (self.boss == "burth" and (self.playsMade or 0) == 0)
        or (self.boss == "flik" and #cards < 5)
    if voided then total = 0 end
    return { key = key, scoring = scoring, points = points, mult = mult, total = total, notes = notes, level = level, voided = voided }
end

function Game:Play(indexes)
    if self.state ~= "PLAYING" or self.plays <= 0 then return nil end
    if #indexes == 0 or #indexes > Game.MAX_SELECT then return nil end
    local cards, seen = Pick(self.hand, indexes)
    local result = self:Score(cards)
    -- Lunacy grows after every paired hand, starting with the next one.
    local lunacy = self:Has("lunacy")
    if lunacy and PAIRED[result.key] then lunacy.stacks = (lunacy.stacks or 0) + 1 end
    local momentum = self:Has("momentum")
    if momentum then
        momentum.stacks = momentum.key == result.key and (momentum.stacks or 0) + 1 or 0
        momentum.key = result.key
    end
    if self:Has("treasure") then
        local found = 0
        for _, c in ipairs(result.scoring) do
            if c.rank == 1 or c.rank == 8 then found = found + 1 end
        end
        self.gold = self.gold + found
        result.gold = found
    end
    self.playsMade = self.playsMade + 1
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

function Game:CanDiscard()
    return self.state == "PLAYING" and self.discards > 0 and (self.boss ~= "selina" or self.gold >= 2)
end

function Game:Discard(indexes)
    if not self:CanDiscard() then return nil end
    if #indexes == 0 or #indexes > Game.MAX_SELECT then return nil end
    local cards, seen = Pick(self.hand, indexes)
    Remove(self.hand, seen)
    self.discards = self.discards - 1
    self.discardsUsed = self.discardsUsed + 1
    if self.boss == "selina" then self.gold = self.gold - 2 end
    local drawn = self:Draw()
    self:Emit("discard", { cards = cards, drawn = drawn })
    return drawn
end

function Game:WinRound()
    local round = self:Round()
    local cap = Game.INTEREST_CAP + (self:Has("piggy") and 5 or 0)
    local reward = ROUND_GOLD[round] + self.plays + math.min(cap, math.floor(self.gold / 5))
    if self:Has("nobles") then reward = reward + 2 end
    self.gold = self.gold + reward
    local data = { reward = reward, round = round, ante = self.ante, boss = self.boss, plays = self.plays, discards = self.discards }
    if round == "boss" and self.ante == Game.ANTES and not self.endless then
        self.state = "WON"
        self:Emit("won", data)
        return
    end
    self:OpenShop()
    self:Emit("roundWon", data)
end

function Game:OpenShop()
    self.state = "SHOP"
    self.rerollCost = Game.REROLL_COST
    self:RollOffers()
    self:RollFortunes()
end

-- After the eighth ante the Faire goes on, with ever higher goals.
function Game:ContinueEndless()
    if self.state ~= "WON" then return false end
    self.endless = true
    self:OpenShop()
    return true
end

function Game:RollFortunes()
    local keys = {}
    for _, hand in ipairs(Game.HANDS) do keys[#keys + 1] = hand.key end
    local a = self.random(#keys)
    local b = self.random(#keys - 1)
    if b >= a then b = b + 1 end
    self.fortunes = { keys[a], keys[b] }
end

function Game:BuyFortune(slot)
    local key = self.fortunes and self.fortunes[slot]
    if self.state ~= "SHOP" or not key or self.gold < Game.FORTUNE_PRICE then return false end
    self.gold = self.gold - Game.FORTUNE_PRICE
    self.levels[key] = self:Level(key) + (self:Has("prophet") and 2 or 1)
    self.fortunes[slot] = false
    self:Emit("shop")
    return true
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
