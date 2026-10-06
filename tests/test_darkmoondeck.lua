local Game = ns.DarkmoonDeck.Game
local passed, failed = 0, 0

local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
    else
        failed = failed + 1
        print("FAIL " .. name .. ": " .. tostring(err))
    end
end

local function eq(a, b, msg)
    if a ~= b then error((msg or "") .. " expected " .. tostring(b) .. ", got " .. tostring(a), 2) end
end

local function Rng(seed)
    return function(n) seed = (seed * 16807) % 2147483647; return seed % n + 1 end
end

-- "A1 5b 8p": rank (A or digit) followed by suit initial (b, e, p, w).
local SUITS = { b = "beasts", e = "elementals", p = "portals", w = "warlords" }
local function Cards(text)
    local cards = {}
    for token in text:gmatch("%S+") do
        local rank = token:sub(1, 1) == "A" and 1 or tonumber(token:sub(1, 1))
        cards[#cards + 1] = { rank = rank, suit = SUITS[token:sub(2, 2)] }
    end
    return cards
end

local function NewGame(seed)
    local g = Game.New(Rng(seed or 3))
    g:StartRun()
    return g
end

test("hands are recognized", function()
    eq((Game.Evaluate(Cards("Ab"))), "high", "single card")
    eq((Game.Evaluate(Cards("3b 3e"))), "pair")
    eq((Game.Evaluate(Cards("3b 3e 5b 5p"))), "twopair")
    eq((Game.Evaluate(Cards("7b 7e 7p 2w"))), "three")
    eq((Game.Evaluate(Cards("2b 3e 4p 5w 6b"))), "straight")
    eq((Game.Evaluate(Cards("4b 5e 6p 7w 8b"))), "straight")
    eq((Game.Evaluate(Cards("5b 6e 7p 8w Ab"))), "straight", "ace above the eight")
    eq((Game.Evaluate(Cards("Ab 2e 3p 4w 5b"))), "straight", "ace below the two")
    eq((Game.Evaluate(Cards("2b 4b 6b 7b 8b"))), "flush")
    eq((Game.Evaluate(Cards("2b 2e 2p 6w 6b"))), "fullhouse")
    eq((Game.Evaluate(Cards("8b 8e 8p 8w 2b"))), "four")
    eq((Game.Evaluate(Cards("3p 4p 5p 6p 7p"))), "straightflush")
    eq((Game.Evaluate(Cards("Ab 3e 5p 7w 8b"))), "high")
end)

test("only the matching cards score", function()
    local _, scoring = Game.Evaluate(Cards("7b 7e 2p 5w"))
    eq(#scoring, 2)
    local _, high = Game.Evaluate(Cards("Ab 3e 5p"))
    eq(#high, 1)
    eq(high[1].rank, 1, "the ace is the high card")
end)

test("score is points times multiplier", function()
    local g = NewGame()
    local result = g:Score(Cards("7b 7e"))
    eq(result.points, 10 + 7 + 7)
    eq(result.mult, 2)
    eq(result.total, 48)
end)

test("trinkets change the score", function()
    local g = NewGame()
    g.trinkets = { { id = "heroism" }, { id = "maelstrom" }, { id = "storms" } }
    local result = g:Score(Cards("7e 7b 2p 5w 8b"))
    -- Pair: 10 + 14 points, multiplier 2 + 4 (heroism) + 3 (one scoring elemental), doubled for five cards.
    eq(result.points, 24)
    eq(result.mult, (2 + 4 + 3) * 2)
end)

test("the cursed suit scores no points", function()
    local g = NewGame()
    g.cursedSuit = "beasts"
    local result = g:Score(Cards("7b 7e"))
    eq(result.points, 10 + 7)
end)

test("playing reaches the goal and opens the shop", function()
    local g = NewGame()
    g.goal = 1
    local indexes = g:BestPlay()
    g:Play(indexes)
    eq(g.state, "SHOP")
    assert(g.gold > Game.START_GOLD, "reward paid")
    eq(#g.offers, 3, "three offers")
end)

test("running out of plays ends the run", function()
    local g = NewGame()
    g.goal = 10 ^ 9
    for _ = 1, Game.PLAYS do g:Play({ 1 }) end
    eq(g.state, "OVER")
end)

test("discards draw new cards", function()
    local g = NewGame()
    local before = g.hand[1]
    g:Discard({ 1, 2 })
    eq(#g.hand, g.handSize)
    eq(g.discards, Game.DISCARDS - 1)
    assert(g.hand[1] ~= before or g.hand[2] ~= before, "cards replaced")
end)

test("shop: buy, sell and reroll", function()
    local g = NewGame()
    g.goal = 1
    g:Play({ 1 })
    g.gold = 30
    local offer = g.offers[1]
    assert(g:Buy(1), "bought")
    eq(#g.trinkets, 1)
    eq(g.gold, 30 - offer.price)
    assert(not g:Buy(1), "slot is empty now")
    local gold = g.gold
    assert(g:Reroll(), "rerolled")
    eq(g.gold, gold - Game.REROLL_COST)
    for _, o in ipairs(g.offers) do assert(o.id ~= offer.id, "owned trinkets are not offered") end
    assert(g:Sell(1), "sold")
    eq(#g.trinkets, 0)
end)

test("rounds lead to the boss and the next ante", function()
    local g = NewGame()
    for round = 1, 3 do
        eq(g:Round(), Game.ROUNDS[round])
        g.goal = 1
        g:Play({ 1 })
        g:NextRound()
    end
    eq(g.ante, 2)
    eq(g:Round(), "small")
end)

test("bosses bend the rules", function()
    local g = NewGame()
    g.roundIndex = 3
    for index, boss in ipairs(Game.BOSSES) do
        g.random = function(n) return math.min(index, n) end
        g:StartRound()
        eq(g.boss, boss)
        if boss == "silas" then eq(g.discards, 0) end
        if boss == "sayge" then assert(g.cursedSuit, "a suit is cursed") end
        if boss == "fozlebub" then eq(#g.hand, Game.HAND_SIZE - 2) end
        if boss == "paleo" then eq(g.plays, Game.PLAYS - 1) end
    end
end)

test("lunacy grows with paired hands", function()
    local g = NewGame()
    g.trinkets = { { id = "lunacy", stacks = 0 } }
    g.hand = Cards("4b 4e 2p 3w 5b 6e 8p")
    g.goal = 10 ^ 9
    g:Play({ 1, 2 })
    eq(g.trinkets[1].stacks, 1)
end)

test("best play finds four of a kind", function()
    local g = NewGame()
    g.hand = Cards("8b 8e 8p 8w 2b 3e 5p")
    local indexes = g:BestPlay()
    local cards = {}
    for i, idx in ipairs(indexes) do cards[i] = g.hand[idx] end
    eq((Game.Evaluate(cards)), "four")
end)

test("fortunes level up hands", function()
    local g = NewGame()
    g.goal = 1
    g:Play({ 1 })
    g.gold = 10
    local key = g.fortunes[1]
    assert(g:BuyFortune(1), "bought")
    eq(g:Level(key), 2)
    eq(g.gold, 10 - Game.FORTUNE_PRICE)
    g.levels.pair = 3
    local result = g:Score(Cards("7b 7e"))
    eq(result.points, 10 + 15 * 2 + 14)
    eq(result.mult, 2 + 1 * 2)
end)

test("four winds allows four-card straights and flushes", function()
    eq((Game.Evaluate(Cards("2b 3e 4p 5w 8b"), true)), "straight")
    eq((Game.Evaluate(Cards("2b 4b 6b 8b 3e"), true)), "flush")
    eq((Game.Evaluate(Cards("5p 6p 7p 8p 2b"), true)), "straightflush")
    eq((Game.Evaluate(Cards("2b 3e 4p 5w 8b"))), "high", "not without the trinket")
    eq((Game.Evaluate(Cards("3b 3e 3p 7w 7b"), true)), "fullhouse", "stronger hands stay")
end)

test("new bosses void hands", function()
    local g = NewGame()
    g.boss = "kerri"
    eq(g:Score(Cards("7b 7e")).total, 0, "kerri: pairs score nothing")
    assert(g:Score(Cards("7b 7e 3p 3w")).total > 0, "kerri: two pair scores")
    g.boss, g.playsMade = "burth", 0
    eq(g:Score(Cards("7b 7e")).total, 0, "burth: first hand")
    g.playsMade = 1
    assert(g:Score(Cards("7b 7e")).total > 0, "burth: later hands")
    g.boss = "flik"
    eq(g:Score(Cards("7b 7e")).total, 0, "flik: only five cards")
    g.boss, g.gold, g.discards = "selina", 1, 3
    assert(not g:CanDiscard(), "selina: discards cost gold")
end)

test("multiplying trinkets stack", function()
    local g = NewGame()
    g.trinkets = { { id = "storms" }, { id = "perfectionist" }, { id = "gambler" } }
    g.gamble = true
    local result = g:Score(Cards("2b 3e 4p 5w 6b"))
    eq(result.mult, 4 * 2 * 1.5 * 3)
    eq(result.total, math.floor(result.points * result.mult))
end)

test("the faire goes on after the eighth ante", function()
    local g = NewGame()
    g.ante, g.roundIndex = Game.ANTES, 3
    g:StartRound()
    g.goal = 1
    g:Play({ 1 })
    eq(g.state, "WON")
    assert(g:ContinueEndless(), "continued")
    eq(g.state, "SHOP")
    g:NextRound()
    eq(g.ante, Game.ANTES + 1)
    assert(g.goal > Game.Goal(Game.ANTES, "small"), "higher goal")
end)

test("winning the last boss wins the run", function()
    local g = NewGame()
    g.ante, g.roundIndex = Game.ANTES, 3
    g:StartRound()
    g.goal = 1
    g:Play({ 1 })
    eq(g.state, "WON")
end)

return passed, failed
