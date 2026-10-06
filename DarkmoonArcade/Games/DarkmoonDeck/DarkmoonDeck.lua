local _, ns = ...

local DD = ns.DarkmoonDeck
local Game = DD.Game
local Arcade, Widgets, Scores, Media, Achievements, L = ns.Arcade, ns.Widgets, ns.Scores, ns.Media, ns.Achievements, ns.L

local W, H = 432, 462
local CARD_W, CARD_H = 54, 78
local HAND_Y, RAISE = 340, 14
local PLAY_Y = 205
local DECK_X, DECK_Y = W + 40, HAND_Y
local PLAY_TIME, DISCARD_TIME = 1.5, 0.45

-- interface/icons/inv_misc_ticket_tarot_*: the four suits of the old Darkmoon decks.
local SUIT_ICONS = { beasts = 134482, elementals = 134486, portals = 134492, warlords = 134497 }
local SUIT_COLORS = {
    beasts = { 0.35, 0.65, 0.25 },
    elementals = { 0.85, 0.42, 0.1 },
    portals = { 0.55, 0.3, 0.85 },
    warlords = { 0.8, 0.18, 0.18 },
}
local RANK_TEXT = { "A", "2", "3", "4", "5", "6", "7", "8" }
local KEY_SELECT = { ["1"] = 1, ["2"] = 2, ["3"] = 3, ["4"] = 4, ["5"] = 5, ["6"] = 6, ["7"] = 7, ["8"] = 8, ["9"] = 9 }

local Module = {
    id = "darkmoondeck",
    rank = 6,
    nameKey = "DD_NAME",
    descKey = "DD_DESC",
    helpKey = "DD_HELP",
    tile = "tiles/darkmoondeck",
    defaults = { preview = true, hands = 0, bestHand = 0, bossesBeaten = {}, sort = "rank" },
}

local function Tex(name) return Media.Tex("deck/" .. name) end
local function Sound(name) Media.Play("deck/" .. name) end
local function Settings() return Arcade.Settings(Module) end

local function Coin()
    if ns.db.sound and SOUNDKIT and SOUNDKIT.LOOT_WINDOW_COIN_SOUND then PlaySound(SOUNDKIT.LOOT_WINDOW_COIN_SOUND) end
end

local function Place(region, x, y)
    region:ClearAllPoints()
    region:SetPoint("CENTER", region:GetParent(), "TOPLEFT", x, -y)
end

Achievements.Register("darkmoondeck", {
    { id = "dd_first", nameKey = "DD_ACH_FIRST", descKey = "DD_ACH_FIRST_DESC", icon = SUIT_ICONS.beasts },
    { id = "dd_boss", nameKey = "DD_ACH_BOSS", descKey = "DD_ACH_BOSS_DESC", icon = 134493 },
    { id = "dd_four", nameKey = "DD_ACH_FOUR", descKey = "DD_ACH_FOUR_DESC", icon = SUIT_ICONS.warlords },
    { id = "dd_hand1k", nameKey = "DD_ACH_HAND1K", descKey = "DD_ACH_HAND1K_DESC", icon = 134494 },
    { id = "dd_ante4", nameKey = "DD_ACH_ANTE4", descKey = "DD_ACH_ANTE4_DESC", icon = SUIT_ICONS.portals },
    { id = "dd_full", nameKey = "DD_ACH_FULL", descKey = "DD_ACH_FULL_DESC", icon = 134484 },
    { id = "dd_rich", nameKey = "DD_ACH_RICH", descKey = "DD_ACH_RICH_DESC", icon = 351046 },
    { id = "dd_nodiscard", nameKey = "DD_ACH_NODISCARD", descKey = "DD_ACH_NODISCARD_DESC", icon = 134496 },
    { id = "dd_straightflush", nameKey = "DD_ACH_STRAIGHTFLUSH", descKey = "DD_ACH_STRAIGHTFLUSH_DESC", icon = 351048 },
    { id = "dd_bosses", nameKey = "DD_ACH_BOSSES", descKey = "DD_ACH_BOSSES_DESC", icon = 134483 },
    { id = "dd_hand10k", nameKey = "DD_ACH_HAND10K", descKey = "DD_ACH_HAND10K_DESC", icon = 134490 },
    { id = "dd_hands", nameKey = "DD_ACH_HANDS", descKey = "DD_ACH_HANDS_DESC", icon = 351047 },
    { id = "dd_win", nameKey = "DD_ACH_WIN", descKey = "DD_ACH_WIN_DESC", icon = 134488 },
    { id = "dd_flight", nameKey = "DD_ACH_FLIGHT", descKey = "DD_ACH_FLIGHT_DESC", icon = "Interface\\TaxiFrame\\UI-Taxi-Icon-Green" },
})
local GOALS = { hand1k = 1000, hand10k = 10000, rich = 40, hands = 500 }

local function RoundName(game)
    return L["DD_ROUND_" .. game:Round()]
end

local function TrinketName(id)
    return L.DD_CARD:format(L["DD_T_" .. id])
end

local function TrinketDesc(trinket)
    local text = L["DD_TD_" .. trinket.id]
    return trinket.id == "lunacy" and text:format(trinket.stacks or 0) or text
end

local function BossText(game)
    if not game.boss then return "" end
    local desc = L["DD_BOSSDESC_" .. game.boss]
    if game.boss == "sayge" then desc = desc:format(L["DD_SUIT_" .. game.cursedSuit]) end
    return L.DD_BOSS:format(L["DD_BOSS_" .. game.boss], desc)
end

local function ShareMessage(entry)
    return L.DD_SHARE:format(ns.FormatNumber(entry.score), entry.ante or 1)
end

local function ShowTrinketTooltip(owner, trinket)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(TrinketName(trinket.id), 1, 0.82, 0)
    GameTooltip:AddLine(TrinketDesc(trinket), 1, 1, 1, true)
    GameTooltip:Show()
end

function Module:BestScore()
    return Scores.Best(self.id, "default")
end

-- Cards ------------------------------------------------------------------------------

function Module:CreateCardVisual()
    local b = CreateFrame("Button", nil, self.cardLayer)
    b:SetSize(CARD_W, CARD_H)
    b:RegisterForClicks("LeftButtonUp")
    b.glow = b:CreateTexture(nil, "BACKGROUND")
    b.glow:SetTexture(Tex("glow"))
    b.glow:SetPoint("CENTER")
    b.glow:SetSize(CARD_W + 26, CARD_H + 26)
    b.glow:SetBlendMode("ADD")
    b.glow:SetVertexColor(1, 0.8, 0.35)
    b.face = b:CreateTexture(nil, "ARTWORK", nil, 0)
    b.face:SetAllPoints()
    b.face:SetTexture(Tex("front"))
    b.icon = b:CreateTexture(nil, "ARTWORK", nil, 1)
    b.icon:SetSize(30, 30)
    b.icon:SetPoint("CENTER", 0, -6)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.rank = b:CreateFontString(nil, "OVERLAY")
    b.rank:SetFont(Media.FontFile(), 18, "")
    b.rank:SetPoint("TOPLEFT", 6, -5)
    b.corner = b:CreateFontString(nil, "OVERLAY")
    b.corner:SetFont(Media.FontFile(), 11, "")
    b.corner:SetPoint("BOTTOMRIGHT", -6, 5)
    b:SetScript("OnClick", function(button) self:ToggleCard(button.card) end)
    return b
end

function Module:SetCardVisual(v, card)
    v.card = card
    v.icon:SetTexture(SUIT_ICONS[card.suit])
    local c = SUIT_COLORS[card.suit]
    v.rank:SetText(RANK_TEXT[card.rank])
    v.corner:SetText(RANK_TEXT[card.rank])
    v.rank:SetTextColor(c[1], c[2], c[3])
    v.corner:SetTextColor(c[1], c[2], c[3])
    local cursed = card.suit == self.game.cursedSuit
    v.icon:SetDesaturated(cursed)
    v.face:SetVertexColor(cursed and 0.6 or 1, cursed and 0.6 or 1, cursed and 0.6 or 1)
    v.alpha, v.scale = 1, 1
    v:SetAlpha(1)
    v.glow:Hide()
    v:Show()
end

function Module:VisualFor(card, x, y)
    local v = self.visuals[card]
    if not v then
        v = self.cardPool.Acquire()
        self:SetCardVisual(v, card)
        v.x, v.y = x or DECK_X, y or DECK_Y
        v.tx, v.ty = nil, nil
        Place(v, v.x, v.y)
        self.visuals[card] = v
    end
    return v
end

function Module:ReleaseVisual(card)
    local v = self.visuals[card]
    if v then
        self.visuals[card] = nil
        self.cardPool.Release(v)
    end
end

function Module:ClearCards()
    for card in pairs(self.visuals) do self:ReleaseVisual(card) end
    wipe(self.selected)
end

-- Lays out the hand; selected cards stand a little higher.
function Module:LayoutHand()
    local hand = self.game.hand or {}
    local n = #hand
    local spacing = math.min(CARD_W + 4, (W - 24 - CARD_W) / math.max(1, n - 1))
    local left = W / 2 - spacing * (n - 1) / 2
    for i, card in ipairs(hand) do
        local v = self:VisualFor(card)
        v.tx = left + (i - 1) * spacing
        v.ty = HAND_Y - (self.selected[card] and RAISE or 0)
        v:SetFrameLevel(self.cardLayer:GetFrameLevel() + i)
        v.glow:SetShown(self.selected[card] and true or false)
    end
end

function Module:SelectedIndexes()
    local indexes = {}
    for i, card in ipairs(self.game.hand or {}) do
        if self.selected[card] then indexes[#indexes + 1] = i end
    end
    return indexes
end

function Module:CountSelected()
    local n = 0
    for _ in pairs(self.selected) do n = n + 1 end
    return n
end

function Module:ToggleCard(card)
    if self.game.state ~= "PLAYING" or self.busy > 0 or not card then return end
    if self.selected[card] then
        self.selected[card] = nil
    elseif self:CountSelected() < Game.MAX_SELECT then
        self.selected[card] = true
    else
        return
    end
    Sound("select")
    self:LayoutHand()
    self:UpdatePreview()
    self:UpdateButtons()
end

function Module:SortHand()
    local hand = self.game.hand
    if not hand then return end
    local suitOrder = {}
    for i, suit in ipairs(Game.SUITS) do suitOrder[suit] = i end
    local function RankValue(card) return card.rank == 1 and 9 or card.rank end
    if Settings().sort == "suit" then
        table.sort(hand, function(a, b)
            if a.suit ~= b.suit then return suitOrder[a.suit] < suitOrder[b.suit] end
            return RankValue(a) > RankValue(b)
        end)
    else
        table.sort(hand, function(a, b)
            if a.rank ~= b.rank then return RankValue(a) > RankValue(b) end
            return suitOrder[a.suit] < suitOrder[b.suit]
        end)
    end
    self:LayoutHand()
end

-- Build ------------------------------------------------------------------------------------

function Module:Build(container)
    self.container = container
    self.visuals, self.selected, self.effects = {}, {}, {}
    self.busy = 0

    local bg = container:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(Tex("table"))
    bg:SetTexCoord(0, W / 512, 0, H / 512)

    self:CreateInfoBar(container)
    self:CreateTrinketRow(container)

    local cardLayer = CreateFrame("Frame", nil, container)
    cardLayer:SetAllPoints()
    cardLayer:SetFrameLevel(container:GetFrameLevel() + 5)
    self.cardLayer = cardLayer
    self.cardPool = Media.Pool(function() return self:CreateCardVisual() end, function(v)
        v:Hide()
        v.card = nil
    end)

    local fx = CreateFrame("Frame", nil, container)
    fx:SetAllPoints()
    fx:SetFrameLevel(container:GetFrameLevel() + 30)
    self.fxLayer = fx
    self.textPool = Media.Pool(function() return fx:CreateFontString(nil, "OVERLAY") end, function(fs) fs:Hide() end)

    self.handName = Widgets.Text(fx, 18, "gold")
    self.handName:SetPoint("CENTER", fx, "TOPLEFT", W / 2, -(PLAY_Y - 70))
    self.handScore = Widgets.Text(fx, 22, "white")
    self.handScore:SetPoint("CENTER", fx, "TOPLEFT", W / 2, -(PLAY_Y + 54))
    self.preview = Widgets.Text(container, 13, "blue")
    self.preview:SetPoint("CENTER", container, "TOPLEFT", W / 2, -(HAND_Y - CARD_H / 2 - RAISE - 14))

    self.playButton = Widgets.Button(container, 130, 26, nil, function() self:Play() end)
    self.playButton:SetPoint("BOTTOMLEFT", 18, 14)
    self.discardButton = Widgets.Button(container, 130, 26, nil, function() self:Discard() end)
    self.discardButton:SetPoint("BOTTOMRIGHT", -18, 14)
    self.sortButton = Widgets.Button(container, 116, 22, nil, function()
        Settings().sort = Settings().sort == "rank" and "suit" or "rank"
        self:SortHand()
        self:UpdateButtons()
    end)
    self.sortButton:SetPoint("BOTTOM", 0, 16)

    local game = Game.New()
    game.onEvent = function(name, data)
        if name == "roundWon" or name == "won" then self.lastReward = data.reward end
    end
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
    Widgets.HelpPage(self.overlay, W, "DD_RULES", "DD_HELP", function() Widgets.BackFromSubPage(self) end)
    self:ShowMenu()
end

function Module:CreateInfoBar(container)
    local info = {}
    info.round = Widgets.Text(container, 13, "gold")
    info.round:SetPoint("TOPLEFT", 16, -10)
    info.goal = Widgets.Text(container, 13, "white")
    info.goal:SetPoint("TOPRIGHT", -16, -10)
    local track = container:CreateTexture(nil, "ARTWORK")
    track:SetColorTexture(0, 0, 0, 0.55)
    track:SetPoint("TOPLEFT", 16, -30)
    track:SetSize(W - 32, 14)
    info.bar = container:CreateTexture(nil, "ARTWORK", nil, 1)
    info.bar:SetColorTexture(0.86, 0.66, 0.3, 0.95)
    info.bar:SetPoint("TOPLEFT", track, "TOPLEFT")
    info.bar:SetHeight(14)
    info.score = Widgets.Text(container, 11, "white")
    info.score:SetPoint("CENTER", track, "CENTER")
    info.plays = Widgets.Text(container, 12, "white")
    info.plays:SetPoint("TOPLEFT", 16, -52)
    info.gold = Widgets.Text(container, 12, "gold")
    info.gold:SetPoint("TOPRIGHT", -16, -52)
    info.boss = Widgets.Text(container, 11, "blue")
    info.boss:SetPoint("TOP", 0, -70)
    info.boss:SetWidth(W - 40)
    self.info = info
end

function Module:CreateTrinketRow(container)
    self.trinketSlots = {}
    for i = 1, Game.MAX_TRINKETS do
        local slot = CreateFrame("Button", nil, container)
        slot:SetSize(34, 34)
        slot:SetPoint("CENTER", container, "TOPLEFT", W / 2 + (i - 3) * 42, -106)
        slot.bg = slot:CreateTexture(nil, "BACKGROUND")
        slot.bg:SetAllPoints()
        slot.bg:SetColorTexture(0, 0, 0, 0.45)
        slot.icon = slot:CreateTexture(nil, "ARTWORK")
        slot.icon:SetAllPoints()
        slot.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        slot:SetScript("OnEnter", function(owner)
            if owner.trinket then ShowTrinketTooltip(owner, owner.trinket) end
        end)
        slot:SetScript("OnLeave", GameTooltip_Hide)
        self.trinketSlots[i] = slot
    end
end

function Module:CreatePages()
    local menu = self.overlay:AddPage("menu")
    local title = Widgets.PageTitle(menu, "DD_NAME", -60)
    local tagline = Widgets.LocalizedText(menu, 14, "blue", "DD_TAGLINE")
    tagline:SetPoint("TOP", title, "BOTTOM", 0, -6)
    local newRun = Widgets.Button(menu, 200, 26, "NEW_GAME", function() self:NewRun() end)
    local scores = Widgets.Button(menu, 200, 26, "HIGHSCORES", function() self.overlay:Show("scores") end)
    Widgets.Stack(menu, { newRun, scores }, -200)

    local pause = self.overlay:AddPage("pause")
    local pauseTitle = Widgets.PageTitle(pause, "PAUSED", -100)
    local landed = Widgets.Text(pause, 14, "blue")
    landed:SetPoint("TOP", pauseTitle, "BOTTOM", 0, -8)
    local resume = Widgets.Button(pause, 200, 26, "RESUME", function() self:Resume() end)
    local pauseMenu = Widgets.Button(pause, 200, 26, "MENU", function() self:AbandonRun() end)
    Widgets.Stack(pause, { resume, pauseMenu }, -190)
    pause.refresh = function(data) landed:SetText((data and data.landed) and L.LANDED or "") end

    for _, name in ipairs({ "over", "won" }) do
        local page = self.overlay:AddPage(name)
        local pageTitle = Widgets.PageTitle(page, name == "won" and "DD_WON" or "GAME_OVER", -70)
        local reason = Widgets.Text(page, 14, "blue")
        reason:SetPoint("TOP", pageTitle, "BOTTOM", 0, -6)
        local final = Widgets.Text(page, 18, "white")
        final:SetPoint("TOP", reason, "BOTTOM", 0, -12)
        local record = Widgets.Text(page, 14, "gold")
        record:SetPoint("TOP", final, "BOTTOM", 0, -8)
        local share = Widgets.ShareRow(page, function() return self.lastEntry and ShareMessage(self.lastEntry) end)
        share:SetPoint("TOP", 0, -220)
        local again = Widgets.Button(page, 200, 26, "AGAIN", function() self:NewRun() end)
        local back = Widgets.Button(page, 200, 26, "MENU", function() self:ShowMenu() end)
        Widgets.Stack(page, { again, back }, -262)
        page.refresh = function(data)
            if not data then return end
            reason:SetText(name == "won" and L.DD_WON_TEXT or L.DD_REACHED:format(data.ante))
            final:SetText(L.FINAL_SCORE:format(ns.FormatNumber(data.score)))
            record:SetText(data.rank == 1 and L.NEW_RECORD or "")
        end
    end

    self:CreateShopPage()
end

function Module:CreateShopPage()
    local page = self.overlay:AddPage("shop")
    Widgets.PageTitle(page, "DD_SHOP", -18)
    local reward = Widgets.Text(page, 13, "blue")
    reward:SetPoint("TOP", 0, -50)
    local gold = Widgets.Text(page, 14, "gold")
    gold:SetPoint("TOP", 0, -68)

    local offers = {}
    for i = 1, 3 do
        local y = -96 - (i - 1) * 66
        local row = {}
        row.icon = CreateFrame("Button", nil, page)
        row.icon:SetSize(40, 40)
        row.icon:SetPoint("TOPLEFT", 26, y)
        row.tex = row.icon:CreateTexture(nil, "ARTWORK")
        row.tex:SetAllPoints()
        row.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        row.name = Widgets.Text(page, 13, "gold")
        row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 10, 0)
        row.desc = Widgets.Text(page, 11, "white")
        row.desc:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -3)
        row.desc:SetWidth(230)
        row.desc:SetJustifyH("LEFT")
        row.buy = Widgets.Button(page, 96, 24, nil, function()
            if self.game:Buy(i) then
                Coin()
                if #self.game.trinkets >= Game.MAX_TRINKETS then Achievements.Unlock("dd_full") end
                self:RefreshShop()
            end
        end)
        row.buy:SetPoint("TOPRIGHT", -20, y - 8)
        offers[i] = row
    end

    local owned = Widgets.Text(page, 12, "white")
    owned:SetPoint("TOP", 0, -298)
    local slots = {}
    for i = 1, Game.MAX_TRINKETS do
        local slot = CreateFrame("Button", nil, page)
        slot:SetSize(32, 32)
        slot:SetPoint("TOP", page, "TOP", (i - 3) * 80, -318)
        slot.tex = slot:CreateTexture(nil, "ARTWORK")
        slot.tex:SetAllPoints()
        slot.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        slot:SetScript("OnEnter", function(owner)
            if owner.trinket then ShowTrinketTooltip(owner, owner.trinket) end
        end)
        slot:SetScript("OnLeave", GameTooltip_Hide)
        slot.sell = Widgets.Button(page, 76, 20, nil, function()
            if self.game:Sell(i) then
                Coin()
                self:RefreshShop()
                self:RefreshTrinkets()
            end
        end)
        slot.sell:SetPoint("TOP", slot, "BOTTOM", 0, -4)
        slots[i] = slot
    end

    local nextGoal = Widgets.Text(page, 11, "gray")
    nextGoal:SetPoint("TOP", 0, -388)
    local reroll = Widgets.Button(page, 150, 26, nil, function()
        if self.game:Reroll() then
            Sound("shuffle")
            self:RefreshShop()
        end
    end)
    reroll:SetPoint("BOTTOMLEFT", 26, 18)
    local continue = Widgets.Button(page, 150, 26, "DD_CONTINUE", function() self:NextRound() end)
    continue:SetPoint("BOTTOMRIGHT", -26, 18)

    self.shop = { page = page, reward = reward, gold = gold, offers = offers, owned = owned, slots = slots, nextGoal = nextGoal, reroll = reroll }
    page.refresh = function(data)
        if data and data.reward then self.shop.lastReward = data.reward end
        self:RefreshShop()
    end
end

function Module:RefreshShop()
    local shop, game = self.shop, self.game
    if not shop or game.state ~= "SHOP" then return end
    shop.reward:SetText(L.DD_REWARD:format(shop.lastReward or 0))
    shop.gold:SetText(L.DD_GOLD:format(game.gold))
    for i, row in ipairs(shop.offers) do
        local offer = game.offers[i]
        local show = offer ~= nil
        row.icon:SetShown(show)
        row.name:SetShown(show)
        row.desc:SetShown(show)
        row.buy:SetShown(show)
        if offer then
            row.tex:SetTexture(offer.icon)
            row.tex:SetDesaturated(false)
            row.name:SetText(TrinketName(offer.id))
            row.desc:SetText(TrinketDesc({ id = offer.id, stacks = 0 }))
            row.buy:SetText(L.DD_BUY:format(offer.price))
            row.buy:SetEnabled(game.gold >= offer.price and #game.trinkets < Game.MAX_TRINKETS)
            row.icon:SetScript("OnEnter", function(owner) ShowTrinketTooltip(owner, { id = offer.id, stacks = 0 }) end)
            row.icon:SetScript("OnLeave", GameTooltip_Hide)
        elseif offer == false then
            row.icon:Show()
            row.name:Show()
            row.tex:SetDesaturated(true)
            row.name:SetText(L.DD_SOLD)
            row.desc:SetText("")
            row.buy:Hide()
        end
    end
    shop.owned:SetText(L.DD_YOUR_CARDS:format(#game.trinkets, Game.MAX_TRINKETS))
    for i, slot in ipairs(shop.slots) do
        local trinket = game.trinkets[i]
        slot.trinket = trinket
        slot:SetShown(trinket ~= nil)
        slot.sell:SetShown(trinket ~= nil)
        if trinket then
            slot.tex:SetTexture(Game.TRINKET[trinket.id].icon)
            slot.sell:SetText(L.DD_SELL:format(game:SellPrice(i)))
        end
    end
    local nextRound = game.roundIndex % #Game.ROUNDS + 1
    local nextAnte = game.ante + (nextRound == 1 and 1 or 0)
    shop.nextGoal:SetText(L.DD_NEXT_GOAL:format(L["DD_ROUND_" .. Game.ROUNDS[nextRound]],
        ns.FormatNumber(Game.Goal(nextAnte, Game.ROUNDS[nextRound]))))
    shop.reroll:SetText(L.DD_REROLL:format(game.rerollCost))
    shop.reroll:SetEnabled(game.gold >= game.rerollCost)
    if game.gold >= GOALS.rich then Achievements.Unlock("dd_rich") end
    self:UpdateHud()
end

-- Effects -------------------------------------------------------------------------------

function Module:AddEffect(delay, update, finish)
    self.effects[#self.effects + 1] = { t = -delay, update = update, finish = finish }
end

function Module:Popup(x, y, text, size, color, delay)
    local fs = self.textPool.Acquire()
    fs:SetFont(Media.FontFile(), size, "OUTLINE")
    fs:SetTextColor(color[1], color[2], color[3])
    fs:SetText(text)
    fs:Hide()
    self:AddEffect(delay or 0, function(e)
        local p = e.t / 0.8
        if p >= 1 then return false end
        fs:Show()
        Place(fs, x, y - 22 * (1 - (1 - p) ^ 3))
        fs:SetAlpha(p < 0.6 and 1 or (1 - (p - 0.6) / 0.4))
        return true
    end, function() self.textPool.Release(fs) end)
end

function Module:ClearEffects()
    for _, e in ipairs(self.effects) do
        if e.finish then e.finish(e) end
    end
    wipe(self.effects)
end

-- Game flow ------------------------------------------------------------------------------

function Module:ShowMenu()
    self:ClearEffects()
    self:ClearCards()
    self.game.state = "READY"
    self.handName:SetText("")
    self.handScore:SetText("")
    self:UpdateHud()
    self.overlay:Show("menu")
end

function Module:NewRun()
    self:ClearEffects()
    self:ClearCards()
    self.finished = false
    self.game:StartRun()
    self.overlay:Hide()
    self:BeginRound()
end

function Module:BeginRound()
    self:ClearCards()
    self.handName:SetText("")
    self.handScore:SetText("")
    Sound("shuffle")
    self:SortHand()
    for i, card in ipairs(self.game.hand) do
        local v = self.visuals[card]
        v.delay = (i - 1) * 0.05
    end
    self.roundDiscards = self.game.discards
    if self.game.ante >= 4 then Achievements.Unlock("dd_ante4") end
    self:RefreshTrinkets()
    self:UpdatePreview()
    self:UpdateButtons()
    self:UpdateHud()
end

function Module:NextRound()
    self.game:NextRound()
    self.overlay:Hide()
    self:BeginRound()
end

function Module:Play()
    local game = self.game
    if game.state ~= "PLAYING" or self.busy > 0 then return end
    local indexes = self:SelectedIndexes()
    if #indexes == 0 then return end
    local result = game:Play(indexes)
    if not result then return end
    wipe(self.selected)

    -- Played cards line up in the middle of the table, scoring cards a little higher.
    local scoring = {}
    for _, c in ipairs(result.scoring) do scoring[c] = true end
    local n = #result.cards
    for i, card in ipairs(result.cards) do
        local v = self.visuals[card]
        if v then
            v.tx = W / 2 + (i - (n + 1) / 2) * (CARD_W + 6)
            v.ty = PLAY_Y - (scoring[card] and 10 or 0)
            v.glow:SetShown(scoring[card] or false)
            v.played = true
        end
    end
    self.handName:SetText(L["DD_HAND_" .. result.key])
    self.handScore:SetText(("%s × %s"):format(ns.FormatNumber(result.points), result.mult))
    self.preview:SetText("")
    local k = 0
    for i, card in ipairs(result.cards) do
        if scoring[card] then
            k = k + 1
            local x = W / 2 + (i - (n + 1) / 2) * (CARD_W + 6)
            local points = card.suit == game.cursedSuit and 0 or Game.CardPoints(card)
            self:Popup(x, PLAY_Y - CARD_H / 2 - 18, "+" .. points, 14, { 0.6, 0.85, 1 }, 0.2 + k * 0.12)
            self:AddEffect(0.2 + k * 0.12, function() Sound("chip" .. math.min(k, 5)) return false end)
        end
    end
    for j, note in ipairs(result.notes) do
        local slot = self:SlotFor(note.id)
        if slot then
            local _, _, _, sx, sy = slot:GetPoint()
            self:Popup(sx or W / 2, 84, note.text, 14, { 1, 0.5, 0.3 }, 0.3 + k * 0.12 + j * 0.12)
        end
    end
    self:AddEffect(0.45 + k * 0.12, function()
        Sound("mult")
        self.handScore:SetText(ns.FormatNumber(result.total))
        return false
    end)

    local settings = Settings()
    settings.hands = settings.hands + 1
    settings.bestHand = math.max(settings.bestHand, result.total)
    if settings.hands >= GOALS.hands then Achievements.Unlock("dd_hands") end
    if result.key == "four" then Achievements.Unlock("dd_four") end
    if result.key == "straightflush" then Achievements.Unlock("dd_straightflush") end
    if result.total >= GOALS.hand1k then Achievements.Unlock("dd_hand1k") end
    if result.total >= GOALS.hand10k then Achievements.Unlock("dd_hand10k") end

    self.busy = PLAY_TIME
    self.afterBusy = function()
        for _, card in ipairs(result.cards) do self:ReleaseVisual(card) end
        self.handName:SetText("")
        self.handScore:SetText("")
        self:AfterPlay()
    end
    self:UpdateButtons()
    self:UpdateHud()
    self:RefreshTrinkets()
end

function Module:AfterPlay()
    local game = self.game
    if game.state == "SHOP" or game.state == "WON" then
        Media.Play("spellbounce/clear")
        Achievements.Unlock("dd_first")
        if game.boss then
            Achievements.Unlock("dd_boss")
            if game.discards == self.roundDiscards then
                Achievements.Unlock("dd_nodiscard")
            end
            local beaten = Settings().bossesBeaten
            beaten[game.boss] = true
            local count = 0
            for _ in pairs(beaten) do count = count + 1 end
            if count >= #Game.BOSSES then Achievements.Unlock("dd_bosses") end
        end
        if ns.Flight.current then Achievements.Unlock("dd_flight") end
        Coin()
        self:ClearCards()
        if game.state == "WON" then
            Achievements.Unlock("dd_win")
            local rank = self:Record()
            self.overlay:Show("won", { score = game.score, ante = game.ante, rank = rank })
        else
            self.overlay:Show("shop", { reward = self.lastReward })
        end
    elseif game.state == "OVER" then
        Media.Play("murlocblast/gameover")
        local rank = self:Record()
        self.overlay:Show("over", { score = game.score, ante = game.ante, rank = rank })
    else
        Sound("deal")
        self:SortHand()
    end
    self:UpdatePreview()
    self:UpdateButtons()
    self:UpdateHud()
end

function Module:Discard()
    local game = self.game
    if game.state ~= "PLAYING" or self.busy > 0 then return end
    local indexes = self:SelectedIndexes()
    local discarded = {}
    for _, i in ipairs(indexes) do discarded[#discarded + 1] = game.hand[i] end
    if not game:Discard(indexes) then return end
    wipe(self.selected)
    for i, card in ipairs(discarded) do
        local v = self.visuals[card]
        if v then
            v.tx, v.ty = -60, HAND_Y + 40 + i * 4
            v.played = true
            v.glow:Hide()
        end
    end
    Sound("deal")
    self.busy = DISCARD_TIME
    self.afterBusy = function()
        for _, card in ipairs(discarded) do self:ReleaseVisual(card) end
        self:SortHand()
        self:UpdatePreview()
        self:UpdateButtons()
    end
    self:UpdateButtons()
    self:UpdateHud()
end

function Module:Record()
    local game = self.game
    self.finished = true
    self.lastEntry = { score = game.score, ante = game.ante }
    return Scores.Record(self.id, "default", { score = game.score, ante = game.ante })
end

function Module:AbandonRun()
    local state = self.game.state
    if self.game.score > 0 and not self.finished and (state == "PAUSED" or state == "SHOP") then self:Record() end
    self:ShowMenu()
end

function Module:Pause(info)
    local game = self.game
    if not game then return end
    if game.state == "PLAYING" then
        game:Pause()
        self.overlay:Show("pause", info)
    elseif info.landed and game.state == "PAUSED" then
        self.overlay:Show("pause", info)
    end
end

function Module:Resume()
    self.game:Resume()
    self.overlay:Hide()
end

-- HUD ---------------------------------------------------------------------------------------

function Module:SlotFor(id)
    for _, slot in ipairs(self.trinketSlots) do
        if slot.trinket and slot.trinket.id == id then return slot end
    end
end

function Module:RefreshTrinkets()
    local trinkets = self.game.trinkets or {}
    for i, slot in ipairs(self.trinketSlots) do
        local trinket = trinkets[i]
        slot.trinket = trinket
        if trinket then
            slot.icon:SetTexture(Game.TRINKET[trinket.id].icon)
            slot.icon:Show()
        else
            slot.icon:Hide()
        end
        slot:SetShown(self.game.state ~= "READY")
    end
end

function Module:UpdatePreview()
    local game = self.game
    local indexes = self:SelectedIndexes()
    if game.state ~= "PLAYING" then
        self.preview:SetText("")
    elseif #indexes == 0 then
        self.preview:SetText(L.DD_SELECT_HINT)
    elseif Settings().preview then
        local cards = {}
        for i, idx in ipairs(indexes) do cards[i] = game.hand[idx] end
        local result = game:Score(cards)
        self.preview:SetText(L.DD_PREVIEW:format(L["DD_HAND_" .. result.key], ns.FormatNumber(result.points), result.mult))
    else
        self.preview:SetText("")
    end
end

function Module:UpdateButtons()
    local game = self.game
    local playing = game.state == "PLAYING" and self.busy <= 0
    local selected = self:CountSelected()
    self.playButton:SetText(L.DD_PLAY .. " (" .. (game.plays or 0) .. ")")
    self.discardButton:SetText(L.DD_DISCARD .. " (" .. (game.discards or 0) .. ")")
    self.sortButton:SetText(Settings().sort == "rank" and L.DD_SORT_SUIT or L.DD_SORT_RANK)
    self.playButton:SetEnabled(playing and selected > 0)
    self.discardButton:SetEnabled(playing and selected > 0 and (game.discards or 0) > 0)
    self.sortButton:SetEnabled(playing)
    local show = game.state ~= "READY"
    self.playButton:SetShown(show)
    self.discardButton:SetShown(show)
    self.sortButton:SetShown(show)
end

function Module:UpdateHud()
    local game, info = self.game, self.info
    local active = game.state ~= "READY" and game.goal
    if active then
        info.round:SetText(L.DD_ANTE:format(game.ante) .. "  ·  " .. RoundName(game))
        info.goal:SetText(L.DD_GOAL:format(ns.FormatNumber(game.goal)))
        info.bar:SetWidth(math.max(1, (W - 32) * math.min(1, game.roundScore / game.goal)))
        info.score:SetText(L.DD_ROUND_SCORE:format(ns.FormatNumber(game.roundScore)))
        info.plays:SetText(L.DD_PLAYS:format(game.plays) .. "    " .. L.DD_DISCARDS:format(game.discards))
        info.gold:SetText(L.DD_GOLD:format(game.gold))
        info.boss:SetText(BossText(game))
    else
        info.round:SetText("")
        info.goal:SetText("")
        info.bar:SetWidth(1)
        info.score:SetText("")
        info.plays:SetText("")
        info.gold:SetText("")
        info.boss:SetText("")
    end
    info.bar:SetShown(active and true or false)
    ns.Window:UpdateSidebar()
end

-- Arcade hooks -------------------------------------------------------------------------------

function Module:Sidebar()
    local game = self.game
    local info = game.goal and game.state ~= "READY" and (L.DD_ANTE:format(game.ante) .. "  ·  " .. RoundName(game)) or ""
    return { score = game.score, bucket = "default", info = info }
end

function Module:ScoreDetail(entry)
    return L.DD_ANTE:format(entry.ante or 1)
end

function Module:ShowAchievements()
    Widgets.ShowSubPage(self, "achievements")
end

function Module:ShowHelp()
    Widgets.ShowSubPage(self, "help")
end

function Module:Enter()
    self:UpdateHud()
    self.overlay:Refresh()
end

function Module:Leave()
    self:Pause({})
end

function Module:RefreshTexts()
    self.overlay:Refresh()
    self:UpdatePreview()
    self:UpdateButtons()
    self:UpdateHud()
end

function Module:OnKey(key)
    local game = self.game
    if key == "P" and (game.state == "PLAYING" or (game.state == "PAUSED" and self.overlay.current == "pause")) then
        if game.state == "PLAYING" then self:Pause({}) else self:Resume() end
        return true
    end
    if game.state ~= "PLAYING" or self.overlay.current then return false end
    local index = KEY_SELECT[key]
    if index then
        self:ToggleCard(game.hand[index])
        return true
    elseif key == "SPACE" or key == "ENTER" then
        self:Play()
        return true
    elseif key == "D" then
        self:Discard()
        return true
    elseif key == "S" then
        self.sortButton:Click()
        return true
    end
    return false
end

function Module:OnUpdate(dt)
    if self.busy > 0 then
        self.busy = self.busy - dt
        if self.busy <= 0 then
            self.busy = 0
            local after = self.afterBusy
            self.afterBusy = nil
            if after then after() end
        end
    end
    -- Cards glide toward their places.
    local k = math.min(1, dt * 12)
    for _, v in pairs(self.visuals) do
        if v.delay and v.delay > 0 then
            v.delay = v.delay - dt
        elseif v.tx then
            local dx, dy = v.tx - v.x, v.ty - v.y
            if math.abs(dx) > 0.3 or math.abs(dy) > 0.3 then
                v.x, v.y = v.x + dx * k, v.y + dy * k
                Place(v, v.x, v.y)
            elseif v.x ~= v.tx or v.y ~= v.ty then
                v.x, v.y = v.tx, v.ty
                Place(v, v.x, v.y)
            end
        end
    end
    for i = #self.effects, 1, -1 do
        local e = self.effects[i]
        e.t = e.t + dt
        if e.t >= 0 and not e.update(e, dt) then
            if e.finish then e.finish(e) end
            table.remove(self.effects, i)
        end
    end
end

function Module:DecorateTile(tile, art)
    for i, suit in ipairs(Game.SUITS) do
        local icon = tile:CreateTexture(nil, "OVERLAY")
        icon:SetTexture(SUIT_ICONS[suit])
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        icon:SetSize(24, 24)
        icon:SetPoint("TOPLEFT", art, "TOPLEFT", 14 + (i - 1) * 28, -14)
    end
end

function Module:Options()
    return {
        { kind = "check", tbl = Settings(), key = "preview", label = "DD_OPT_PREVIEW", tip = "DD_OPT_PREVIEW_TIP", default = true },
    }
end

function Module:StatLines()
    local settings = Settings()
    return {
        { L.DD_STAT_HANDS, ns.FormatNumber(settings.hands or 0) },
        { L.DD_STAT_BEST, ns.FormatNumber(settings.bestHand or 0) },
    }
end

DD.Module = Module
Arcade.RegisterGame(Module)
