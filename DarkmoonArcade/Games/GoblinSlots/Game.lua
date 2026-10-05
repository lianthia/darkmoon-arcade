-- Goblin Slot Machine: a deck-building slot machine (pure logic, no WoW API).
-- Owned symbols land on a 5x4 grid each spin; symbols pay gold and interact with their neighbors.
-- Every few spins the goblin banker collects rent; whoever cannot pay is bankrupt.

local _, ns = ...

local GS = ns.GoblinSlots or {}
ns.GoblinSlots = GS

local Game = {}
Game.__index = Game
GS.Game = Game

Game.COLS, Game.ROWS = 5, 4
Game.OFFER_SIZE = 3
Game.RENTS = { 25, 50, 100, 150, 225, 300, 375, 450, 550, 650, 777, 888, 1000 }
Game.START = { "copper", "copper", "murloc", "fish", "ale", "ore" }

local RARITY_WEIGHTS = {
    { common = 70, uncommon = 25, rare = 5, legendary = 0 },
    { common = 55, uncommon = 32, rare = 11, legendary = 2 },
    { common = 42, uncommon = 36, rare = 18, legendary = 4 },
    { common = 32, uncommon = 38, rare = 24, legendary = 6 },
}

-- value: base gold. Interactions are resolved in Game:Evaluate.
Game.SYMBOLS = {
    copper = { rarity = "common", value = 1, coin = true },
    fish = { rarity = "common", value = 1 },
    ale = { rarity = "common", value = 1 },
    ore = { rarity = "common", value = 1 },
    candle = { rarity = "common", value = 1 },
    murloc = { rarity = "common", value = 1 },
    silver = { rarity = "uncommon", value = 3, coin = true },
    pickaxe = { rarity = "uncommon", value = 1 },
    dwarf = { rarity = "uncommon", value = 2 },
    kobold = { rarity = "uncommon", value = 2 },
    key = { rarity = "uncommon", value = 1 },
    dynamite = { rarity = "uncommon", value = 0 },
    gold = { rarity = "rare", value = 7, coin = true },
    gnome = { rarity = "rare", value = 3 },
    chest = { rarity = "rare", value = 2 },
    whelp = { rarity = "legendary", value = 5 },
    crown = { rarity = "legendary", value = 2 },
}

Game.ORDER = { "copper", "fish", "ale", "ore", "candle", "murloc", "silver", "pickaxe", "dwarf", "kobold",
    "key", "dynamite", "gold", "gnome", "chest", "whelp", "crown" }

local RULES = {
    murlocEatsFish = 5,
    dwarfDrinksAle = 6,
    pickaxeOre = 3,
    koboldBoost = 2,
    gnomeTinker = 1,
    dynamiteBlast = 3,
    chestKey = 40,
    whelpHoard = 20,
    crownPerMurloc = 3,
}
Game.RULES = RULES

function Game.RentAmount(index)
    local list = Game.RENTS
    if index <= #list then return list[index] end
    return list[#list] + (index - #list) * 150
end

function Game.SpinsForRent(index)
    return math.min(8, 5 + math.floor((index - 1) / 2))
end

function Game.New(random)
    local g = setmetatable({}, Game)
    g.random = random or math.random
    g.onEvent = function() end
    g.state = "READY"
    g.gold, g.earned, g.rentIndex, g.rentsPaid, g.removals = 0, 0, 1, 0, 0
    g.spinsLeft = Game.SpinsForRent(1)
    g.inventory = {}
    return g
end

function Game:Start()
    self.inventory = {}
    for _, id in ipairs(Game.START) do self.inventory[#self.inventory + 1] = id end
    self.gold, self.earned, self.spins = 0, 0, 0
    self.rentIndex, self.rentsPaid, self.removals = 1, 0, 0
    self.spinsLeft = Game.SpinsForRent(1)
    self.grid, self.offer = nil, nil
    self.state = "SPIN"
end

function Game:Rent()
    return Game.RentAmount(self.rentIndex)
end

local function Neighbors(r, c)
    local result = {}
    for dr = -1, 1 do
        for dc = -1, 1 do
            local nr, nc = r + dr, c + dc
            if (dr ~= 0 or dc ~= 0) and nr >= 1 and nr <= Game.ROWS and nc >= 1 and nc <= Game.COLS then
                result[#result + 1] = { nr, nc }
            end
        end
    end
    return result
end
Game.Neighbors = Neighbors

-- Places the inventory on the grid; empty slots are nil.
function Game:Layout()
    local slots = {}
    for i = 1, Game.ROWS * Game.COLS do slots[i] = i end
    for i = #slots, 2, -1 do
        local j = self.random(i)
        slots[i], slots[j] = slots[j], slots[i]
    end
    local grid = {}
    for r = 1, Game.ROWS do grid[r] = {} end
    local pool = {}
    for _, id in ipairs(self.inventory) do pool[#pool + 1] = id end
    for i = #pool, 2, -1 do
        local j = self.random(i)
        pool[i], pool[j] = pool[j], pool[i]
    end
    for i = 1, math.min(#pool, #slots) do
        local slot = slots[i] - 1
        grid[math.floor(slot / Game.COLS) + 1][slot % Game.COLS + 1] = pool[i]
    end
    return grid
end

-- Resolves a grid: returns per-cell payouts, destroyed cells and noteworthy events.
function Game.Evaluate(grid)
    local R, C = Game.ROWS, Game.COLS
    local pay, destroyed, events = {}, {}, {}
    for r = 1, R do pay[r] = {}; destroyed[r] = {} end
    local function At(r, c) return not destroyed[r][c] and grid[r][c] or nil end
    local function Count(name) events[name] = (events[name] or 0) + 1 end

    -- Destruction first: dynamite, keys opening chests, whelps, murlocs, dwarves.
    for r = 1, R do
        for c = 1, C do
            if At(r, c) == "dynamite" then
                local bonus = 0
                for _, n in ipairs(Neighbors(r, c)) do
                    local id = At(n[1], n[2])
                    if id and id ~= "dynamite" then
                        destroyed[n[1]][n[2]] = true
                        bonus = bonus + RULES.dynamiteBlast
                        Count("blasted")
                    end
                end
                destroyed[r][c] = true
                pay[r][c] = bonus
            end
        end
    end
    local eaters = {
        { eater = "chest", food = "key", bonus = RULES.chestKey, event = "chests", one = true, eaterDies = true },
        { eater = "whelp", food = "gold", bonus = RULES.whelpHoard, event = "hoarded" },
        { eater = "murloc", food = "fish", bonus = RULES.murlocEatsFish, event = "fishEaten" },
        { eater = "dwarf", food = "ale", bonus = RULES.dwarfDrinksAle, event = "aleDrunk" },
    }
    for _, rule in ipairs(eaters) do
        for r = 1, R do
            for c = 1, C do
                if At(r, c) == rule.eater then
                    for _, n in ipairs(Neighbors(r, c)) do
                        if At(n[1], n[2]) == rule.food then
                            destroyed[n[1]][n[2]] = true
                            pay[r][c] = (pay[r][c] or 0) + rule.bonus
                            Count(rule.event)
                            if rule.one then
                                if rule.eaterDies then
                                    destroyed[r][c] = true
                                    pay[r][c] = rule.bonus
                                end
                                break
                            end
                        end
                    end
                end
            end
        end
    end

    local murlocs = 0
    for r = 1, R do
        for c = 1, C do
            if At(r, c) == "murloc" then murlocs = murlocs + 1 end
        end
    end
    events.murlocs = murlocs

    -- Payouts of everything still standing.
    for r = 1, R do
        for c = 1, C do
            local id = At(r, c)
            if id then
                local value = Game.SYMBOLS[id].value
                local neighbors = Neighbors(r, c)
                if id == "murloc" then
                    for _, n in ipairs(neighbors) do
                        if At(n[1], n[2]) == "murloc" then value = value + 1 end
                    end
                elseif id == "crown" then
                    value = value + murlocs * RULES.crownPerMurloc
                    if murlocs > 0 then Count("crowned") end
                end
                for _, n in ipairs(neighbors) do
                    local other = At(n[1], n[2])
                    if id == "ore" and other == "pickaxe" then value = value * RULES.pickaxeOre end
                    if (id == "ore" or id == "candle") and other == "kobold" then value = value * RULES.koboldBoost end
                    if other == "gnome" then value = value + RULES.gnomeTinker end
                end
                pay[r][c] = (pay[r][c] or 0) + value
            end
        end
    end

    local total = 0
    for r = 1, R do
        for c = 1, C do total = total + (pay[r][c] or 0) end
    end
    return { pay = pay, destroyed = destroyed, total = total, events = events }
end

function Game:RemoveDestroyed(grid, destroyed)
    for r = 1, Game.ROWS do
        for c = 1, Game.COLS do
            if destroyed[r][c] and grid[r][c] then
                for i, id in ipairs(self.inventory) do
                    if id == grid[r][c] then
                        table.remove(self.inventory, i)
                        break
                    end
                end
            end
        end
    end
end

function Game:RollRarity()
    local weights = RARITY_WEIGHTS[math.min(#RARITY_WEIGHTS, math.ceil(self.rentIndex / 2))]
    local roll = self.random(100)
    for _, rarity in ipairs({ "common", "uncommon", "rare", "legendary" }) do
        roll = roll - weights[rarity]
        if roll <= 0 then return rarity end
    end
    return "common"
end

function Game:MakeOffer()
    local offer, taken = {}, {}
    for _ = 1, Game.OFFER_SIZE do
        local rarity = self:RollRarity()
        local candidates = {}
        for _, id in ipairs(Game.ORDER) do
            if Game.SYMBOLS[id].rarity == rarity and not taken[id] then candidates[#candidates + 1] = id end
        end
        if #candidates == 0 then
            for _, id in ipairs(Game.ORDER) do
                if not taken[id] then candidates[#candidates + 1] = id end
            end
        end
        local id = candidates[self.random(#candidates)]
        taken[id] = true
        offer[#offer + 1] = id
    end
    return offer
end

-- Spins once. Returns the layout and its evaluation; the game then waits for a pick.
function Game:Spin()
    if self.state ~= "SPIN" then return nil end
    local grid = self:Layout()
    local result = Game.Evaluate(grid)
    self:RemoveDestroyed(grid, result.destroyed)
    self.grid = grid
    self.gold = self.gold + result.total
    self.earned = self.earned + result.total
    self.spins = self.spins + 1
    self.spinsLeft = self.spinsLeft - 1
    self.offer = self:MakeOffer()
    self.state = "PICK"
    result.grid = grid
    return result
end

-- Takes an offered symbol (or nothing) and settles rent when it is due.
-- Returns "continue", "paid" or "bankrupt".
function Game:Pick(id)
    if self.state ~= "PICK" then return nil end
    if id then self.inventory[#self.inventory + 1] = id end
    self.offer = nil
    if self.spinsLeft > 0 then
        self.state = "SPIN"
        return "continue"
    end
    local rent = self:Rent()
    if self.gold < rent then
        self.state = "OVER"
        return "bankrupt"
    end
    self.gold = self.gold - rent
    self.rentsPaid = self.rentsPaid + 1
    self.removals = self.removals + 1
    self.rentIndex = self.rentIndex + 1
    self.spinsLeft = Game.SpinsForRent(self.rentIndex)
    self.state = "SPIN"
    return "paid"
end

function Game:Remove(index)
    if self.removals <= 0 or not self.inventory[index] then return false end
    table.remove(self.inventory, index)
    self.removals = self.removals - 1
    return true
end
