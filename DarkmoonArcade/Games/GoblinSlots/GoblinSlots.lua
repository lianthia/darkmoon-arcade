local _, ns = ...

local GS = ns.GoblinSlots
local Game = GS.Game
local Arcade, Widgets, Scores, Media, Achievements, L = ns.Arcade, ns.Widgets, ns.Scores, ns.Media, ns.Achievements, ns.L

local W = 432
local CELL = 72
local GRID_X, GRID_Y = 36, 80
local REEL_START, REEL_STAGGER, REEL_TICK = 0.45, 0.15, 0.06
local REVEAL_STEP = 0.045

-- Item icons from the client (interface/icons/*).
local ICONS = {
    copper = 133788, fish = 133888, ale = 132792, ore = 134566, candle = 133750, murloc = 134169,
    silver = 133786, pickaxe = 134707, dwarf = 134159, kobold = 134168, key = 134235, dynamite = 133713,
    gold = 133784, gnome = 134164, chest = 132595, whelp = 134158, crown = 132768,
}
GS.ICONS = ICONS
local RARITY_COLORS = {
    common = { 1, 1, 1 }, uncommon = { 0.12, 1, 0 }, rare = { 0, 0.55, 1 }, legendary = { 1, 0.5, 0 },
}
local RARITY_KEYS = { common = "GS_COMMON", uncommon = "GS_UNCOMMON", rare = "GS_RARE", legendary = "GS_LEGENDARY" }
local NOT_READY = "Interface\\RaidFrame\\ReadyCheck-NotReady"

local Module = {
    id = "goblinslots",
    nameKey = "GS_NAME",
    descKey = "GS_DESC",
    helpKey = "GS_HELP",
    tile = "tiles/goblinslots",
}

Achievements.Register("goblinslots", {
    { id = "gs_rent1", nameKey = "GS_ACH_RENT1", descKey = "GS_ACH_RENT1_DESC", icon = ICONS.copper },
    { id = "gs_spin50", nameKey = "GS_ACH_SPIN50", descKey = "GS_ACH_SPIN50_DESC", icon = ICONS.silver },
    { id = "gs_rent5", nameKey = "GS_ACH_RENT5", descKey = "GS_ACH_RENT5_DESC", icon = ICONS.silver },
    { id = "gs_treasure", nameKey = "GS_ACH_TREASURE", descKey = "GS_ACH_TREASURE_DESC", icon = ICONS.chest },
    { id = "gs_feast", nameKey = "GS_ACH_FEAST", descKey = "GS_ACH_FEAST_DESC", icon = ICONS.ale },
    { id = "gs_murlocs", nameKey = "GS_ACH_MURLOCS", descKey = "GS_ACH_MURLOCS_DESC", icon = ICONS.murloc },
    { id = "gs_boom", nameKey = "GS_ACH_BOOM", descKey = "GS_ACH_BOOM_DESC", icon = ICONS.dynamite },
    { id = "gs_hoard", nameKey = "GS_ACH_HOARD", descKey = "GS_ACH_HOARD_DESC", icon = ICONS.whelp },
    { id = "gs_rent10", nameKey = "GS_ACH_RENT10", descKey = "GS_ACH_RENT10_DESC", icon = ICONS.gold },
    { id = "gs_spin200", nameKey = "GS_ACH_SPIN200", descKey = "GS_ACH_SPIN200_DESC", icon = ICONS.gold },
    { id = "gs_king", nameKey = "GS_ACH_KING", descKey = "GS_ACH_KING_DESC", icon = ICONS.crown },
    { id = "gs_rich", nameKey = "GS_ACH_RICH", descKey = "GS_ACH_RICH_DESC", icon = ICONS.gold },
    { id = "gs_rent15", nameKey = "GS_ACH_RENT15", descKey = "GS_ACH_RENT15_DESC", icon = ICONS.crown },
    { id = "gs_flight", nameKey = "GS_ACH_FLIGHT", descKey = "GS_ACH_FLIGHT_DESC", icon = "Interface\\TaxiFrame\\UI-Taxi-Icon-Green" },
})

local function Sound(name) Media.Play(name) end

local function SymbolName(id) return L["GS_SYM_" .. id] end
local function SymbolDesc(id) return L["GS_SYM_" .. id .. "_DESC"] end

local function ShareMessage(entry)
    return L.GS_SHARE:format(ns.FormatNumber(entry.score), entry.rents or 0)
end

local function SetIcon(texture, id)
    texture:SetTexture(ICONS[id])
    texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
end

local function SymbolTooltip(owner, id)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    local color = RARITY_COLORS[Game.SYMBOLS[id].rarity]
    GameTooltip:SetText(SymbolName(id), color[1], color[2], color[3])
    GameTooltip:AddLine(L[RARITY_KEYS[Game.SYMBOLS[id].rarity]], 0.62, 0.62, 0.62)
    GameTooltip:AddLine(SymbolDesc(id), 1, 1, 1, true)
    GameTooltip:Show()
end

function Module:BestScore()
    return Scores.Best(self.id, "default")
end

-- Build ------------------------------------------------------------------------------

local function Plate(parent, x, width, labelKey)
    local plate = CreateFrame("Frame", nil, parent)
    plate:SetSize(width, 54)
    plate:SetPoint("TOPLEFT", x, -12)
    local fill = plate:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    fill:SetColorTexture(0, 0, 0, 0.45)
    Widgets.Rim(plate, plate)
    local label = Widgets.LocalizedText(plate, 10, "gray", labelKey)
    label:SetPoint("TOP", 0, -6)
    plate.value = Widgets.Text(plate, 16, "gold")
    plate.value:SetPoint("TOP", label, "BOTTOM", 0, -3)
    plate.detail = Widgets.Text(plate, 10, "white")
    plate.detail:SetPoint("TOP", plate.value, "BOTTOM", 0, -2)
    return plate
end

function Module:Build(container)
    self.container = container
    self.effects = {}
    self.phase = "idle"

    local bg = container:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(Media.Tex("goblin/background"))
    bg:SetTexCoord(0, W / 512, 0, 462 / 512)

    self.rentPlate = Plate(container, 22, 190, "GS_RENT")
    self.goldPlate = Plate(container, 220, 190, "GS_GOLD")

    local board = CreateFrame("Frame", nil, container)
    board:SetSize(Game.COLS * CELL, Game.ROWS * CELL)
    board:SetPoint("TOPLEFT", GRID_X, -GRID_Y)
    local fill = board:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    fill:SetColorTexture(0.02, 0.03, 0.02, 0.6)
    Widgets.Rim(board, board)
    self.board = board

    self.cells = {}
    for r = 1, Game.ROWS do
        self.cells[r] = {}
        for c = 1, Game.COLS do
            local cell = CreateFrame("Frame", nil, board)
            cell:SetSize(CELL, CELL)
            cell:SetPoint("TOPLEFT", (c - 1) * CELL, -(r - 1) * CELL)
            cell:EnableMouse(true)
            local slot = cell:CreateTexture(nil, "BORDER")
            slot:SetTexture(Media.Tex("uldum/cell"))
            slot:SetPoint("TOPLEFT", 3, -3)
            slot:SetPoint("BOTTOMRIGHT", -3, 3)
            slot:SetVertexColor(1, 0.95, 0.8, 0.1)
            cell.icon = cell:CreateTexture(nil, "ARTWORK")
            cell.icon:SetSize(50, 50)
            cell.icon:SetPoint("CENTER")
            cell.cross = cell:CreateTexture(nil, "OVERLAY")
            cell.cross:SetTexture(NOT_READY)
            cell.cross:SetSize(30, 30)
            cell.cross:SetPoint("CENTER")
            cell.cross:Hide()
            cell.payout = cell:CreateFontString(nil, "OVERLAY")
            cell.payout:SetFont(Media.FontFile(), 14, "THICKOUTLINE")
            cell.payout:SetPoint("BOTTOMRIGHT", -4, 4)
            cell.payout:SetTextColor(1, 0.85, 0.2)
            cell:SetScript("OnEnter", function(frame)
                if frame.symbol then SymbolTooltip(frame, frame.symbol) end
            end)
            cell:SetScript("OnLeave", GameTooltip_Hide)
            self.cells[r][c] = cell
        end
    end

    local fx = CreateFrame("Frame", nil, board)
    fx:SetAllPoints()
    fx:SetFrameLevel(board:GetFrameLevel() + 10)
    self.fx = fx
    self.total = fx:CreateFontString(nil, "OVERLAY")
    self.total:SetFont(Media.FontFile(), 30, "THICKOUTLINE")
    self.total:SetPoint("CENTER")
    self.total:SetTextColor(1, 0.85, 0.2)
    self.total:Hide()

    -- Spin button centered below the machine; inventory and removals on their own row.
    local controlsY = GRID_Y + Game.ROWS * CELL + 12
    self.spinButton = Widgets.Button(container, 190, 32, "GS_SPIN", function() self:Spin() end)
    self.spinButton:SetPoint("TOP", 0, -controlsY)
    self.inventoryButton = Widgets.Button(container, 140, 22, nil, function() self.overlay:Show("inventory") end)
    self.inventoryButton:SetPoint("TOPLEFT", GRID_X, -(controlsY + 38))
    self.removalText = Widgets.Text(container, 11, "white")
    self.removalText:SetPoint("TOPRIGHT", container, "TOPLEFT", GRID_X + Game.COLS * CELL, -(controlsY + 43))

    local game = Game.New()
    self.game = game

    self.overlay = Widgets.NewOverlay(container)
    self:CreatePages()
    Widgets.ScoresPage(self.overlay, W, {
        gameId = self.id,
        detail = function(entry) return self:ScoreDetail(entry) end,
        shareMessage = ShareMessage,
        onBack = function() self.overlay:Show("menu") end,
    })
    Widgets.AchievementsPage(self.overlay, W, self.id, function() Widgets.BackFromSubPage(self) end)
    Widgets.HelpPage(self.overlay, W, "GS_RULES", "GS_HELP", function() Widgets.BackFromSubPage(self) end)

    self:ShowGrid(nil)
    self:UpdatePlates()
    self.overlay:Show("menu")
end

function Module:CreatePages()
    local menu = self.overlay:AddPage("menu")
    local title = Widgets.PageTitle(menu, "GS_NAME", -60)
    local tagline = Widgets.LocalizedText(menu, 14, "blue", "GS_TAGLINE")
    tagline:SetPoint("TOP", title, "BOTTOM", 0, -6)
    local play = Widgets.Button(menu, 200, 26, "NEW_GAME", function() self:NewGame() end)
    local scores = Widgets.Button(menu, 200, 26, "HIGHSCORES", function() self.overlay:Show("scores") end)
    Widgets.Stack(menu, { play, scores }, -190)

    -- Offer: three symbol cards and a skip button.
    local offer = self.overlay:AddPage("offer")
    local offerTitle = Widgets.PageTitle(offer, "GS_PICK", -28)
    local offerRent = Widgets.Text(offer, 12, "white")
    offerRent:SetPoint("TOP", offerTitle, "BOTTOM", 0, -6)
    local cards = {}
    for i = 1, Game.OFFER_SIZE do
        local card = CreateFrame("Button", nil, offer)
        card:SetSize(370, 74)
        card:SetPoint("TOP", 0, -96 - (i - 1) * 86)
        local cardFill = card:CreateTexture(nil, "BACKGROUND")
        cardFill:SetAllPoints()
        cardFill:SetColorTexture(0.08, 0.06, 0.1, 0.95)
        Widgets.Rim(card, card)
        local highlight = card:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints()
        highlight:SetColorTexture(1, 0.85, 0.4, 0.12)
        card.icon = card:CreateTexture(nil, "ARTWORK")
        card.icon:SetSize(48, 48)
        card.icon:SetPoint("LEFT", 14, 0)
        card.name = Widgets.Text(card, 14, "white")
        card.name:SetPoint("TOPLEFT", card.icon, "TOPRIGHT", 12, 2)
        card.rarity = Widgets.Text(card, 10, "gray")
        card.rarity:SetPoint("LEFT", card.name, "RIGHT", 8, 0)
        card.desc = Widgets.Text(card, 11, "white")
        card.desc:SetPoint("TOPLEFT", card.name, "BOTTOMLEFT", 0, -4)
        card.desc:SetWidth(280)
        card.desc:SetJustifyH("LEFT")
        card:SetScript("OnClick", function() self:Pick(card.symbol) end)
        cards[i] = card
    end
    local skip = Widgets.Button(offer, 160, 26, "GS_SKIP", function() self:Pick(nil) end)
    skip:SetPoint("TOP", 0, -362)
    offer.refresh = function()
        local game = self.game
        offerRent:SetText(L.GS_RENT .. ": " .. self:RentText())
        for i, card in ipairs(cards) do
            local id = game.offer and game.offer[i]
            card:SetShown(id ~= nil)
            if id then
                card.symbol = id
                SetIcon(card.icon, id)
                local rarity = Game.SYMBOLS[id].rarity
                local color = RARITY_COLORS[rarity]
                card.name:SetText(SymbolName(id))
                card.name:SetTextColor(color[1], color[2], color[3])
                card.rarity:SetText(L[RARITY_KEYS[rarity]])
                card.desc:SetText(SymbolDesc(id))
            end
        end
    end

    local rent = self.overlay:AddPage("rent")
    local rentTitle = Widgets.PageTitle(rent, "GS_PAID", -110)
    local rentDetail = Widgets.Text(rent, 13, "white")
    rentDetail:SetPoint("TOP", rentTitle, "BOTTOM", 0, -10)
    rentDetail:SetWidth(360)
    local rentBonus = Widgets.LocalizedText(rent, 13, "gold", "GS_REMOVAL_EARNED")
    rentBonus:SetPoint("TOP", rentDetail, "BOTTOM", 0, -8)
    local continue = Widgets.Button(rent, 200, 26, "GS_CONTINUE", function()
        self.overlay:Hide()
        self.phase = "idle"
        self:UpdatePlates()
    end)
    continue:SetPoint("TOP", 0, -250)
    rent.refresh = function(data)
        local game = self.game
        rentDetail:SetText(L.GS_PAID_DETAIL:format(ns.FormatNumber(data.paid), ns.FormatNumber(game:Rent()), game.spinsLeft))
    end

    local inventory = self.overlay:AddPage("inventory")
    local invTitle = Widgets.PageTitle(inventory, "GS_INVENTORY", -22)
    local invHint = Widgets.Text(inventory, 11, "white")
    invHint:SetPoint("TOP", invTitle, "BOTTOM", 0, -6)
    invHint:SetWidth(380)
    local slots = {}
    for i = 1, 60 do
        local slot = CreateFrame("Button", nil, inventory)
        slot:SetSize(40, 40)
        local col, row = (i - 1) % 8, math.floor((i - 1) / 8)
        slot:SetPoint("TOPLEFT", 40 + col * 44, -88 - row * 44)
        slot.icon = slot:CreateTexture(nil, "ARTWORK")
        slot.icon:SetAllPoints()
        local highlight = slot:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints()
        highlight:SetColorTexture(1, 0.3, 0.3, 0.3)
        slot:SetScript("OnEnter", function(button) SymbolTooltip(button, button.symbol) end)
        slot:SetScript("OnLeave", GameTooltip_Hide)
        slot:SetScript("OnClick", function(button)
            if self.game:Remove(button.index) then
                Sound("murlocblast/pop1")
                GameTooltip_Hide()
                inventory.refresh()
                self:UpdatePlates()
            end
        end)
        slots[i] = slot
    end
    local invBack = Widgets.Button(inventory, 200, 26, "BACK", function() self.overlay:Hide() end)
    invBack:SetPoint("BOTTOM", 0, 18)
    inventory.refresh = function()
        local game = self.game
        invHint:SetText(game.removals > 0 and L.GS_INVENTORY_HINT:format(game.removals) or L.GS_INVENTORY_NONE)
        -- Sorted by rarity and name so the list stays readable.
        local order = {}
        for index, id in ipairs(game.inventory) do order[#order + 1] = { index = index, id = id } end
        local rank = { legendary = 1, rare = 2, uncommon = 3, common = 4 }
        table.sort(order, function(a, b)
            local ra, rb = rank[Game.SYMBOLS[a.id].rarity], rank[Game.SYMBOLS[b.id].rarity]
            if ra ~= rb then return ra < rb end
            return a.id < b.id
        end)
        for i, slot in ipairs(slots) do
            local entry = order[i]
            slot:SetShown(entry ~= nil)
            if entry then
                slot.index, slot.symbol = entry.index, entry.id
                SetIcon(slot.icon, entry.id)
            end
        end
    end

    local over = self.overlay:AddPage("over")
    local overTitle = Widgets.PageTitle(over, "GS_BANKRUPT", -70)
    local reason = Widgets.Text(over, 13, "blue")
    reason:SetPoint("TOP", overTitle, "BOTTOM", 0, -6)
    local final = Widgets.Text(over, 18, "white")
    final:SetPoint("TOP", reason, "BOTTOM", 0, -12)
    local rents = Widgets.Text(over, 13, "white")
    rents:SetPoint("TOP", final, "BOTTOM", 0, -4)
    local record = Widgets.Text(over, 14, "gold")
    record:SetPoint("TOP", rents, "BOTTOM", 0, -6)
    local share = Widgets.ShareRow(over, function() return self.lastEntry and ShareMessage(self.lastEntry) end)
    share:SetPoint("TOP", 0, -230)
    local again = Widgets.Button(over, 200, 26, "AGAIN", function() self:NewGame() end)
    local overMenu = Widgets.Button(over, 200, 26, "MENU", function() self.overlay:Show("menu") end)
    Widgets.Stack(over, { again, overMenu }, -272)
    over.refresh = function(data)
        reason:SetText(L.GS_BANKRUPT_DETAIL:format(ns.FormatNumber(data.missing)))
        final:SetText(L.FINAL_SCORE:format(ns.FormatNumber(data.score)))
        rents:SetText(L.GS_RENTS:format(data.rents))
        record:SetText(data.rank == 1 and L.NEW_RECORD or "")
    end
end

-- Display -----------------------------------------------------------------------------

function Module:ShowGrid(grid)
    for r = 1, Game.ROWS do
        for c = 1, Game.COLS do
            local cell = self.cells[r][c]
            local id = grid and grid[r][c]
            cell.symbol = id
            if id then
                SetIcon(cell.icon, id)
                cell.icon:SetAlpha(1)
                cell.icon:Show()
            else
                cell.icon:Hide()
            end
            cell.cross:Hide()
            cell.payout:SetText("")
        end
    end
end

function Module:RentText()
    local game = self.game
    if game.spinsLeft <= 0 then return L.GS_RENT_NOW:format(ns.FormatNumber(game:Rent())) end
    return L.GS_RENT_DUE:format(ns.FormatNumber(game:Rent()), game.spinsLeft)
end

function Module:UpdatePlates()
    local game = self.game
    self.rentPlate.value:SetText(ns.FormatNumber(game:Rent()))
    self.rentPlate.detail:SetText(game.state == "READY" and "" or self:RentText())
    self.goldPlate.value:SetText(ns.FormatNumber(self.displayGold or game.gold))
    self.goldPlate.detail:SetText(L.GS_RENTS:format(game.rentsPaid or 0))
    self.inventoryButton:SetText(L.GS_SYMBOLS:format(#game.inventory))
    self.removalText:SetText(L.GS_REMOVALS:format(game.removals or 0))
    self.spinButton:SetEnabled(game.state == "SPIN" and self.phase == "idle")
    ns.Window:UpdateSidebar()
end

-- Game flow -------------------------------------------------------------------------

function Module:NewGame()
    self.game:Start()
    self.phase = "idle"
    self.displayGold = nil
    self.total:Hide()
    self:ShowGrid(nil)
    self.overlay:Hide()
    self:UpdatePlates()
end

function Module:Spin()
    if self.phase ~= "idle" or self.game.state ~= "SPIN" or self.overlay.current then return end
    local startGold = self.game.gold
    local result = self.game:Spin()
    if not result then return end
    self.result = result
    self.phase = "spinning"
    self.t = 0
    self.nextTick = 0
    self.stopped = {}
    self.startGold = startGold
    self.displayGold = startGold
    self.total:Hide()
    for r = 1, Game.ROWS do
        for c = 1, Game.COLS do
            self.cells[r][c].cross:Hide()
            self.cells[r][c].payout:SetText("")
        end
    end
    Sound("goblin/spin")
    self:UpdatePlates()
end

function Module:ReelStopTime(c)
    return REEL_START + (c - 1) * REEL_STAGGER
end

function Module:UpdateSpin(dt)
    self.t = self.t + dt
    local grid = self.result.grid
    self.nextTick = self.nextTick - dt
    local tick = self.nextTick <= 0
    if tick then self.nextTick = REEL_TICK end
    for c = 1, Game.COLS do
        if not self.stopped[c] then
            if self.t >= self:ReelStopTime(c) then
                self.stopped[c] = true
                for r = 1, Game.ROWS do
                    local cell = self.cells[r][c]
                    local id = grid[r][c]
                    cell.symbol = id
                    if id then
                        SetIcon(cell.icon, id)
                        cell.icon:Show()
                    else
                        cell.icon:Hide()
                    end
                end
                Sound("goblin/stop")
            elseif tick then
                for r = 1, Game.ROWS do
                    local id = Game.ORDER[math.random(#Game.ORDER)]
                    SetIcon(self.cells[r][c].icon, id)
                    self.cells[r][c].icon:Show()
                end
            end
        end
    end
    if self.t >= self:ReelStopTime(Game.COLS) + 0.15 then
        self.phase = "reveal"
        self.t = 0
        self.revealIndex = 0
    end
end

function Module:UpdateReveal(dt)
    self.t = self.t + dt
    local result = self.result
    local cellsTotal = Game.ROWS * Game.COLS
    while self.revealIndex < cellsTotal and self.t >= self.revealIndex * REVEAL_STEP do
        self.revealIndex = self.revealIndex + 1
        local r = math.floor((self.revealIndex - 1) / Game.COLS) + 1
        local c = (self.revealIndex - 1) % Game.COLS + 1
        local cell = self.cells[r][c]
        local amount = result.pay[r][c] or 0
        if result.destroyed[r][c] then
            cell.cross:Show()
            cell.icon:SetAlpha(0.35)
        end
        if amount > 0 then
            cell.payout:SetText("+" .. amount)
            self.displayGold = (self.displayGold or 0) + amount
            if self.revealIndex % 2 == 0 then Sound("goblin/coin") end
        end
        self:UpdatePlates()
    end
    if self.revealIndex >= cellsTotal and self.t >= cellsTotal * REVEAL_STEP + 0.3 then
        self.displayGold = nil
        self.total:SetText("+" .. ns.FormatNumber(result.total))
        self.total:Show()
        self.totalTime = 0
        if result.total >= 50 and ns.db.sound then PlaySound(SOUNDKIT.LOOT_WINDOW_COIN_SOUND) end
        self:CheckSpinAchievements(result)
        self.phase = "offer"
        self:UpdatePlates()
        self.overlay:Show("offer")
    end
end

function Module:CheckSpinAchievements(result)
    local e = result.events
    if result.total >= 50 then Achievements.Unlock("gs_spin50") end
    if result.total >= 200 then Achievements.Unlock("gs_spin200") end
    if (e.murlocs or 0) >= 6 then Achievements.Unlock("gs_murlocs") end
    if (e.crowned or 0) > 0 and (e.murlocs or 0) >= 4 then Achievements.Unlock("gs_king") end
    if (e.aleDrunk or 0) >= 3 then Achievements.Unlock("gs_feast") end
    if (e.blasted or 0) >= 6 then Achievements.Unlock("gs_boom") end
    if (e.chests or 0) > 0 then Achievements.Unlock("gs_treasure") end
    if (e.hoarded or 0) > 0 then Achievements.Unlock("gs_hoard") end
    if self.game.earned >= 10000 then Achievements.Unlock("gs_rich") end
end

function Module:Pick(id)
    if self.phase ~= "offer" then return end
    local game = self.game
    local rent = game:Rent()
    local outcome = game:Pick(id)
    self.total:Hide()
    if outcome == "paid" then
        Sound("goblin/register")
        Achievements.Unlock("gs_rent1")
        if game.rentsPaid >= 5 then Achievements.Unlock("gs_rent5") end
        if game.rentsPaid >= 10 then Achievements.Unlock("gs_rent10") end
        if game.rentsPaid >= 15 then Achievements.Unlock("gs_rent15") end
        if ns.Flight.current then Achievements.Unlock("gs_flight") end
        self.phase = "rent"
        self.overlay:Show("rent", { paid = rent })
    elseif outcome == "bankrupt" then
        self:Finish(rent - game.gold)
    else
        self.phase = "idle"
        self.overlay:Hide()
    end
    self:UpdatePlates()
end

function Module:Finish(missing)
    local game = self.game
    self.phase = "over"
    self.lastEntry = { score = game.earned, rents = game.rentsPaid }
    local rank = Scores.Record(self.id, "default", { score = game.earned, rents = game.rentsPaid })
    Sound("goblin/bankrupt")
    self.overlay:Show("over", { score = game.earned, rents = game.rentsPaid, missing = missing, rank = rank })
end

-- Arcade hooks ---------------------------------------------------------------------

function Module:Sidebar()
    local game = self.game
    local info = game.state ~= "READY" and (L.GS_RENT .. ": " .. self:RentText()) or L.GS_TAGLINE
    return { score = game.earned or 0, bucket = "default", info = info }
end

function Module:ScoreDetail(entry)
    return L.GS_RENTS:format(entry.rents or 0)
end

function Module:UpdateHud()
    ns.Window:UpdateSidebar()
end

function Module:ShowAchievements()
    Widgets.ShowSubPage(self, "achievements")
end

function Module:ShowHelp()
    Widgets.ShowSubPage(self, "help")
end

-- Turn-based: nothing runs on its own, so leaving or landing needs no pause.
function Module:Pause() end

function Module:Enter()
    self:UpdatePlates()
    self.overlay:Refresh()
end

function Module:Leave() end

function Module:RefreshTexts()
    self.overlay:Refresh()
    self:UpdatePlates()
end

function Module:OnKey(key)
    if key == "SPACE" and self.phase == "idle" and not self.overlay.current and self.game.state == "SPIN" then
        self:Spin()
        return true
    end
    return false
end

function Module:OnUpdate(dt)
    if self.phase == "spinning" then
        self:UpdateSpin(dt)
    elseif self.phase == "reveal" then
        self:UpdateReveal(dt)
    end
end

function Module:DecorateTile(tile, art)
    for i, id in ipairs({ "murloc", "gold", "dynamite" }) do
        local icon = tile:CreateTexture(nil, "OVERLAY")
        SetIcon(icon, id)
        icon:SetSize(36, 36)
        icon:SetPoint("CENTER", art, "TOPLEFT", 94 + (i - 1) * 54, -75)
    end
end

GS.Module = Module
Arcade.RegisterGame(Module)
