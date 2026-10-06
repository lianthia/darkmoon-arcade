local _, ns = ...

local DD = ns.DarkmoonDeck
local Game = DD.Game
local Arcade, Widgets, Scores, Media, Achievements, L = ns.Arcade, ns.Widgets, ns.Scores, ns.Media, ns.Achievements, ns.L

-- The deck uses a wider playfield than the other games; the window grows for it.
local W, H = 620, 462
local CARD_W, CARD_H = 60, 86
local HAND_Y, RAISE = 352, 16
local PLAY_Y = 222
local DECK_X, DECK_Y = W + 50, HAND_Y
local PLAY_TIME, DISCARD_TIME = 1.9, 0.45
local POINTS_COLOR, MULT_COLOR = { 0.35, 0.7, 1 }, { 1, 0.35, 0.3 }

-- interface/icons/inv_misc_ticket_tarot_*: the four suits of the old Darkmoon decks (used for achievements).
local SUIT_ICONS = { beasts = 134482, elementals = 134486, portals = 134492, warlords = 134497 }
local SUIT_COLORS = {
    beasts = { 0.3, 0.62, 0.22 },
    elementals = { 0.88, 0.42, 0.12 },
    portals = { 0.52, 0.3, 0.86 },
    warlords = { 0.76, 0.16, 0.16 },
}
local CONFETTI = { { 0.4, 0.9, 0.35 }, { 1, 0.6, 0.2 }, { 0.75, 0.5, 1 }, { 1, 0.35, 0.35 }, { 1, 0.85, 0.3 } }
-- NPC IDs of the Faire folk, shown as models during their showdown.
local BOSS_NPCS = {
    silas = 14823, sayge = 14822, fozlebub = 14828, paleo = 14847,
    kerri = 14832, burth = 14827, selina = 10445, flik = 14860,
}
local RANK_TEXT = { "A", "2", "3", "4", "5", "6", "7", "8" }
local KEY_SELECT = { ["1"] = 1, ["2"] = 2, ["3"] = 3, ["4"] = 4, ["5"] = 5, ["6"] = 6, ["7"] = 7, ["8"] = 8, ["9"] = 9 }

local Module = {
    id = "darkmoondeck",
    rank = 2,
    fieldWidth = W,
    nameKey = "DD_NAME",
    descKey = "DD_DESC",
    helpKey = "DD_HELP",
    tile = "tiles/darkmoondeck",
    defaults = { preview = true, hands = 0, bestHand = 0, bossesBeaten = {}, sort = "rank", bestAnte = 0 },
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
    { id = "dd_level5", nameKey = "DD_ACH_LEVEL5", descKey = "DD_ACH_LEVEL5_DESC", icon = Game.FORTUNE_ICON },
    { id = "dd_nodiscard", nameKey = "DD_ACH_NODISCARD", descKey = "DD_ACH_NODISCARD_DESC", icon = 134496 },
    { id = "dd_straightflush", nameKey = "DD_ACH_STRAIGHTFLUSH", descKey = "DD_ACH_STRAIGHTFLUSH_DESC", icon = 351048 },
    { id = "dd_hand10k", nameKey = "DD_ACH_HAND10K", descKey = "DD_ACH_HAND10K_DESC", icon = 134490 },
    { id = "dd_hands", nameKey = "DD_ACH_HANDS", descKey = "DD_ACH_HANDS_DESC", icon = 351047 },
    { id = "dd_win", nameKey = "DD_ACH_WIN", descKey = "DD_ACH_WIN_DESC", icon = 134488 },
    { id = "dd_bosses", nameKey = "DD_ACH_BOSSES", descKey = "DD_ACH_BOSSES_DESC", icon = 134483 },
    { id = "dd_frugal", nameKey = "DD_ACH_FRUGAL", descKey = "DD_ACH_FRUGAL_DESC", icon = 351043 },
    { id = "dd_hand100k", nameKey = "DD_ACH_HAND100K", descKey = "DD_ACH_HAND100K_DESC", icon = 134491 },
    { id = "dd_ante10", nameKey = "DD_ACH_ANTE10", descKey = "DD_ACH_ANTE10_DESC", icon = 134495 },
    { id = "dd_flight", nameKey = "DD_ACH_FLIGHT", descKey = "DD_ACH_FLIGHT_DESC", icon = "Interface\\TaxiFrame\\UI-Taxi-Icon-Green" },
})
local GOALS = { hand1k = 1000, hand10k = 10000, hand100k = 100000, rich = 40, hands = 500, level = 5, frugal = 2, ante10 = 10 }

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

local function BossDesc(game)
    local desc = L["DD_BOSSDESC_" .. game.boss]
    if game.boss == "sayge" then desc = desc:format(L["DD_SUIT_" .. game.cursedSuit]) end
    return desc
end

local function HandName(key, level)
    local name = L["DD_HAND_" .. key]
    return (level and level > 1) and (name .. " " .. L.DD_LEVEL:format(level)) or name
end

local function ShareMessage(entry)
    return L.DD_SHARE:format(ns.FormatNumber(entry.score), entry.ante or 1)
end

local function ShowTooltip(owner, title, text)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(title, 1, 0.82, 0)
    GameTooltip:AddLine(text, 1, 1, 1, true)
    GameTooltip:Show()
end

local function FormatMult(mult)
    return mult == math.floor(mult) and tostring(mult) or ("%.1f"):format(mult)
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
    b.glow:SetSize(CARD_W + 30, CARD_H + 30)
    b.glow:SetBlendMode("ADD")
    b.face = b:CreateTexture(nil, "ARTWORK", nil, 0)
    b.face:SetAllPoints()
    b.face:SetTexture(Tex("front"))
    b.icon = b:CreateTexture(nil, "ARTWORK", nil, 1)
    b.icon:SetSize(38, 38)
    b.icon:SetPoint("CENTER", 0, -6)
    b.pip = b:CreateTexture(nil, "ARTWORK", nil, 1)
    b.pip:SetSize(15, 15)
    b.flash = b:CreateTexture(nil, "OVERLAY")
    b.flash:SetAllPoints()
    b.flash:SetTexture(Tex("front"))
    b.flash:SetBlendMode("ADD")
    b.flash:SetAlpha(0)
    b.rank = b:CreateFontString(nil, "OVERLAY")
    b.rank:SetFont(Media.FontFile(), 20, "")
    b.rank:SetPoint("TOPLEFT", 7, -5)
    b.pip:SetPoint("LEFT", b.rank, "RIGHT", 1, 0)
    b.corner = b:CreateFontString(nil, "OVERLAY")
    b.corner:SetFont(Media.FontFile(), 12, "")
    b.corner:SetPoint("BOTTOMRIGHT", -7, 5)
    b:SetScript("OnClick", function(button) self:ToggleCard(button.card) end)
    b:SetScript("OnEnter", function(button)
        if button.card and not button.played then button.hover = true end
    end)
    b:SetScript("OnLeave", function(button) button.hover = false end)
    return b
end

function Module:SetCardVisual(v, card)
    v.card = card
    v.played = false
    v.hover = false
    v.icon:SetTexture(Tex("suit_" .. card.suit))
    v.pip:SetTexture(Tex("suit_" .. card.suit))
    local c = SUIT_COLORS[card.suit]
    v.rank:SetText(RANK_TEXT[card.rank])
    v.corner:SetText(RANK_TEXT[card.rank])
    v.rank:SetTextColor(c[1], c[2], c[3])
    v.corner:SetTextColor(c[1], c[2], c[3])
    local cursed = card.suit == self.game.cursedSuit
    v.icon:SetDesaturated(cursed)
    v.pip:SetDesaturated(cursed)
    local shade = cursed and 0.6 or 1
    v.face:SetVertexColor(shade, shade, shade)
    v.flash:SetAlpha(0)
    v:SetAlpha(1)
    v.glow:Hide()
    v:Show()
end

function Module:VisualFor(card)
    local v = self.visuals[card]
    if not v then
        v = self.cardPool.Acquire()
        self:SetCardVisual(v, card)
        v.x, v.y = DECK_X, DECK_Y
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

-- Lays out the hand; selected cards stand higher, hovered ones a little.
function Module:LayoutHand()
    local hand = self.game.hand or {}
    local n = #hand
    local spacing = math.min(CARD_W + 8, (W - 40 - CARD_W) / math.max(1, n - 1))
    local left = W / 2 - spacing * (n - 1) / 2
    for i, card in ipairs(hand) do
        local v = self:VisualFor(card)
        v.tx = left + (i - 1) * spacing
        v.baseY = HAND_Y - (self.selected[card] and RAISE or 0)
        v.ty = v.baseY
        v:SetFrameLevel(self.cardLayer:GetFrameLevel() + i * 2)
        if self.selected[card] then
            v.glow:SetVertexColor(1, 0.8, 0.35)
            v.glow:Show()
        else
            v.glow:Hide()
        end
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
    self.busy, self.shake = 0, 0

    local bg = container:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(Tex("table"))
    bg:SetTexCoord(0, W / 1024, 0, H / 512)

    local stage = CreateFrame("Frame", nil, container)
    stage:SetSize(W, H)
    stage:SetPoint("TOPLEFT")
    self.stage = stage

    self:CreateInfoBar(stage)
    self:CreateTrinketRow(stage)
    self:CreateBossBox(stage)

    local cardLayer = CreateFrame("Frame", nil, stage)
    cardLayer:SetAllPoints()
    cardLayer:SetFrameLevel(stage:GetFrameLevel() + 5)
    self.cardLayer = cardLayer
    self.cardPool = Media.Pool(function() return self:CreateCardVisual() end, function(v)
        v:Hide()
        v.card = nil
    end)

    local fx = CreateFrame("Frame", nil, stage)
    fx:SetAllPoints()
    fx:SetFrameLevel(stage:GetFrameLevel() + 40)
    self.fxLayer = fx
    self.textPool = Media.Pool(function() return fx:CreateFontString(nil, "OVERLAY") end, function(fs) fs:Hide() end)
    self.texPool = Media.Pool(function() return fx:CreateTexture(nil, "OVERLAY") end, function(t)
        t:Hide()
        t:SetRotation(0)
    end)

    self:CreateScoreDisplay(fx)
    self.banner = Widgets.Text(fx, 24, "gold")
    self.banner:SetPoint("CENTER", fx, "TOPLEFT", W / 2, -(PLAY_Y - 10))
    self.bannerSub = Widgets.Text(fx, 14, "white")
    self.bannerSub:SetPoint("TOP", self.banner, "BOTTOM", 0, -6)

    self.preview = Widgets.Text(stage, 13, "blue")
    self.preview:SetPoint("CENTER", stage, "TOPLEFT", W / 2, -(HAND_Y - CARD_H / 2 - RAISE - 16))

    self.playButton = Widgets.Button(stage, 150, 26, nil, function() self:Play() end)
    self.playButton:SetPoint("BOTTOMLEFT", 24, 12)
    self.discardButton = Widgets.Button(stage, 150, 26, nil, function() self:Discard() end)
    self.discardButton:SetPoint("BOTTOMRIGHT", -24, 12)
    self.sortButton = Widgets.Button(stage, 130, 22, nil, function()
        Settings().sort = Settings().sort == "rank" and "suit" or "rank"
        self:SortHand()
        self:UpdateButtons()
    end)
    self.sortButton:SetPoint("BOTTOM", 0, 14)

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

function Module:CreateInfoBar(parent)
    local info = {}
    info.round = Widgets.Text(parent, 15, "gold")
    info.round:SetPoint("TOPLEFT", 18, -10)
    info.goal = Widgets.Text(parent, 15, "white")
    info.goal:SetPoint("TOPRIGHT", -18, -10)
    local track = parent:CreateTexture(nil, "ARTWORK")
    track:SetColorTexture(0, 0, 0, 0.55)
    track:SetPoint("TOPLEFT", 18, -32)
    track:SetSize(W - 36, 16)
    info.track = track
    info.bar = parent:CreateTexture(nil, "ARTWORK", nil, 1)
    info.bar:SetColorTexture(0.86, 0.66, 0.3, 0.95)
    info.bar:SetPoint("TOPLEFT", track, "TOPLEFT")
    info.bar:SetHeight(16)
    info.score = Widgets.Text(parent, 12, "white")
    info.score:SetPoint("CENTER", track, "CENTER")
    info.shown = 0

    -- Counters as three badges on the right.
    local badges = {}
    for i, key in ipairs({ "plays", "discards", "gold" }) do
        local badge = CreateFrame("Frame", nil, parent)
        badge:SetSize(92, 40)
        badge:SetPoint("TOPRIGHT", -18 - (3 - i) * 98, -58)
        local fill = badge:CreateTexture(nil, "BACKGROUND")
        fill:SetAllPoints()
        fill:SetColorTexture(0, 0, 0, 0.4)
        Widgets.Rim(badge, badge)
        badge.label = Widgets.LocalizedText(badge, 10, "gray", "DD_BADGE_" .. key:upper())
        badge.label:SetPoint("TOP", 0, -4)
        badge.value = Widgets.Text(badge, 17, key == "gold" and "gold" or "white")
        badge.value:SetPoint("BOTTOM", 0, 4)
        badges[key] = badge
    end
    info.badges = badges
    self.info = info
end

function Module:CreateTrinketRow(parent)
    self.trinketSlots = {}
    for i = 1, Game.MAX_TRINKETS do
        local slot = CreateFrame("Button", nil, parent)
        slot:SetSize(40, 40)
        slot:SetPoint("TOPLEFT", 18 + (i - 1) * 48, -58)
        slot.bg = slot:CreateTexture(nil, "BACKGROUND")
        slot.bg:SetAllPoints()
        slot.bg:SetColorTexture(0, 0, 0, 0.45)
        slot.glow = slot:CreateTexture(nil, "BACKGROUND", nil, 1)
        slot.glow:SetTexture(Media.Tex("glow"))
        slot.glow:SetBlendMode("ADD")
        slot.glow:SetPoint("CENTER")
        slot.glow:SetSize(76, 76)
        slot.glow:SetVertexColor(1, 0.6, 0.25)
        slot.glow:SetAlpha(0)
        slot.icon = slot:CreateTexture(nil, "ARTWORK")
        slot.icon:SetAllPoints()
        slot.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        slot.stacks = Widgets.Text(slot, 11, "white")
        slot.stacks:SetPoint("BOTTOMRIGHT", 2, -2)
        slot:SetScript("OnEnter", function(owner)
            if owner.trinket then ShowTooltip(owner, TrinketName(owner.trinket.id), TrinketDesc(owner.trinket)) end
        end)
        slot:SetScript("OnLeave", GameTooltip_Hide)
        slot.center = { 18 + (i - 1) * 48 + 20, 78 }
        self.trinketSlots[i] = slot
    end
end

function Module:CreateBossBox(parent)
    local box = CreateFrame("Frame", nil, parent)
    box:SetSize(W - 36, 46)
    box:SetPoint("TOPLEFT", 18, -104)
    local fill = box:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    fill:SetColorTexture(0.25, 0.02, 0.05, 0.45)
    Widgets.Rim(box, box)
    box.model = CreateFrame("PlayerModel", nil, box)
    box.model:SetSize(60, 60)
    box.model:SetPoint("LEFT", 2, 4)
    box.name = Widgets.Text(box, 14, "gold")
    box.name:SetPoint("TOPLEFT", 70, -6)
    box.desc = Widgets.Text(box, 12, "white")
    box.desc:SetPoint("TOPLEFT", box.name, "BOTTOMLEFT", 0, -3)
    box:Hide()
    self.bossBox = box
end

-- Points (blue) times multiplier (red) and the total next to them, like a fairground scoreboard.
function Module:CreateScoreDisplay(parent)
    local d = {}
    d.name = Widgets.Text(parent, 18, "gold")
    d.name:SetPoint("CENTER", parent, "TOPLEFT", W / 2, -(PLAY_Y - CARD_H / 2 - 30))
    for _, key in ipairs({ "points", "mult" }) do
        local box = CreateFrame("Frame", nil, parent)
        box:SetSize(96, 34)
        local color = key == "points" and POINTS_COLOR or MULT_COLOR
        local fill = box:CreateTexture(nil, "BACKGROUND")
        fill:SetAllPoints()
        fill:SetColorTexture(color[1] * 0.5, color[2] * 0.5, color[3] * 0.5, 0.85)
        box.text = Widgets.Text(box, 20, "white")
        box.text:SetPoint("CENTER")
        box:Hide()
        d[key] = box
    end
    d.points:SetPoint("CENTER", parent, "TOPLEFT", W / 2 - 62, -(PLAY_Y + CARD_H / 2 + 26))
    d.mult:SetPoint("CENTER", parent, "TOPLEFT", W / 2 + 62, -(PLAY_Y + CARD_H / 2 + 26))
    d.times = Widgets.Text(parent, 20, "white")
    d.times:SetPoint("CENTER", parent, "TOPLEFT", W / 2, -(PLAY_Y + CARD_H / 2 + 26))
    d.total = Widgets.Text(parent, 26, "gold")
    d.total:SetPoint("LEFT", d.mult, "RIGHT", 16, 0)
    self.display = d
end

function Module:ShowDisplay(shown)
    local d = self.display
    d.points:SetShown(shown)
    d.mult:SetShown(shown)
    if not shown then
        d.name:SetText("")
        d.times:SetText("")
        d.total:SetText("")
    end
end

function Module:CreatePages()
    local menu = self.overlay:AddPage("menu")
    local title = Widgets.PageTitle(menu, "DD_NAME", -70)
    local tagline = Widgets.LocalizedText(menu, 14, "blue", "DD_TAGLINE")
    tagline:SetPoint("TOP", title, "BOTTOM", 0, -6)
    local best = Widgets.Text(menu, 12, "gray")
    best:SetPoint("TOP", tagline, "BOTTOM", 0, -10)
    local newRun = Widgets.Button(menu, 200, 26, "NEW_GAME", function() self:NewRun() end)
    local scores = Widgets.Button(menu, 200, 26, "HIGHSCORES", function() self.overlay:Show("scores") end)
    Widgets.Stack(menu, { newRun, scores }, -210)
    menu.refresh = function()
        local ante = Settings().bestAnte or 0
        best:SetText(ante > 0 and L.DD_BEST_ANTE:format(ante) or "")
    end

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
        local pageTitle = Widgets.PageTitle(page, name == "won" and "DD_WON" or "GAME_OVER", -60)
        local reason = Widgets.Text(page, 14, "blue")
        reason:SetPoint("TOP", pageTitle, "BOTTOM", 0, -6)
        local final = Widgets.Text(page, 18, "white")
        final:SetPoint("TOP", reason, "BOTTOM", 0, -12)
        local record = Widgets.Text(page, 14, "gold")
        record:SetPoint("TOP", final, "BOTTOM", 0, -8)
        local share = Widgets.ShareRow(page, function() return self.lastEntry and ShareMessage(self.lastEntry) end)
        share:SetPoint("TOP", 0, -200)
        local buttons = {}
        if name == "won" then
            buttons[#buttons + 1] = Widgets.Button(page, 200, 26, "DD_ENDLESS", function() self:ContinueEndless() end)
        end
        buttons[#buttons + 1] = Widgets.Button(page, 200, 26, "AGAIN", function()
            if name == "won" then self:Record() end
            self:NewRun()
        end)
        buttons[#buttons + 1] = Widgets.Button(page, 200, 26, "MENU", function()
            if name == "won" then self:Record() end
            self:ShowMenu()
        end)
        Widgets.Stack(page, buttons, -244)
        page.refresh = function(data)
            if not data then return end
            reason:SetText(name == "won" and L.DD_WON_TEXT or L.DD_REACHED:format(data.ante))
            final:SetText(L.FINAL_SCORE:format(ns.FormatNumber(data.score)))
            record:SetText(data.rank == 1 and L.NEW_RECORD or "")
        end
    end

    self:CreateShopPage()
end

-- The wagon: three Darkmoon cards on display, two of Sayge's fortunes and your own cards.
function Module:CreateShopPage()
    local page = self.overlay:AddPage("shop")
    Widgets.PageTitle(page, "DD_SHOP", -14)
    local reward = Widgets.Text(page, 13, "blue")
    reward:SetPoint("TOP", 0, -44)
    local gold = Widgets.Text(page, 16, "gold")
    gold:SetPoint("TOP", 0, -62)

    local offers = {}
    for i = 1, 3 do
        local panel = CreateFrame("Frame", nil, page)
        panel:SetSize(184, 150)
        panel:SetPoint("TOP", page, "TOP", (i - 2) * 196, -86)
        local fill = panel:CreateTexture(nil, "BACKGROUND")
        fill:SetAllPoints()
        fill:SetColorTexture(0.12, 0.04, 0.16, 0.85)
        Widgets.Rim(panel, panel)
        panel.icon = panel:CreateTexture(nil, "ARTWORK")
        panel.icon:SetSize(42, 42)
        panel.icon:SetPoint("TOP", 0, -8)
        panel.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        panel.name = Widgets.Text(panel, 12, "gold")
        panel.name:SetPoint("TOP", panel.icon, "BOTTOM", 0, -4)
        panel.name:SetWidth(176)
        panel.desc = Widgets.Text(panel, 11, "white")
        panel.desc:SetPoint("TOP", panel.name, "BOTTOM", 0, -3)
        panel.desc:SetWidth(170)
        panel.buy = Widgets.Button(panel, 120, 22, nil, function()
            if self.game:Buy(i) then
                Coin()
                self:Sparkle(W / 2 + (i - 2) * 196, 160, { 1, 0.85, 0.4 })
                if #self.game.trinkets >= Game.MAX_TRINKETS then Achievements.Unlock("dd_full") end
                self:RefreshShop()
                self:RefreshTrinkets()
            end
        end)
        panel.buy:SetPoint("BOTTOM", 0, 6)
        offers[i] = panel
    end

    local fortunes = {}
    for i = 1, 2 do
        local panel = CreateFrame("Frame", nil, page)
        panel:SetSize(288, 48)
        panel:SetPoint("TOP", page, "TOP", (i - 1.5) * 300, -246)
        local fill = panel:CreateTexture(nil, "BACKGROUND")
        fill:SetAllPoints()
        fill:SetColorTexture(0.05, 0.08, 0.2, 0.85)
        Widgets.Rim(panel, panel)
        panel.icon = panel:CreateTexture(nil, "ARTWORK")
        panel.icon:SetSize(34, 34)
        panel.icon:SetPoint("LEFT", 8, 0)
        panel.icon:SetTexture(Game.FORTUNE_ICON)
        panel.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        panel.name = Widgets.Text(panel, 12, "gold")
        panel.name:SetPoint("TOPLEFT", panel.icon, "TOPRIGHT", 8, 0)
        panel.desc = Widgets.Text(panel, 11, "white")
        panel.desc:SetPoint("BOTTOMLEFT", panel.icon, "BOTTOMRIGHT", 8, 0)
        panel.buy = Widgets.Button(panel, 76, 22, nil, function()
            local key = self.game.fortunes[i]
            if self.game:BuyFortune(i) then
                Coin()
                Sound("mult")
                self:Sparkle(W / 2 + (i - 1.5) * 300, 270, { 0.5, 0.75, 1 })
                if self.game:Level(key) >= GOALS.level then Achievements.Unlock("dd_level5") end
                self:RefreshShop()
            end
        end)
        panel.buy:SetPoint("RIGHT", -8, 0)
        fortunes[i] = panel
    end

    local owned = Widgets.Text(page, 12, "white")
    owned:SetPoint("TOP", 0, -306)
    local slots = {}
    for i = 1, Game.MAX_TRINKETS do
        local slot = CreateFrame("Button", nil, page)
        slot:SetSize(34, 34)
        slot:SetPoint("TOP", page, "TOP", (i - 3) * 90, -324)
        slot.tex = slot:CreateTexture(nil, "ARTWORK")
        slot.tex:SetAllPoints()
        slot.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        slot:SetScript("OnEnter", function(owner)
            if owner.trinket then ShowTooltip(owner, TrinketName(owner.trinket.id), TrinketDesc(owner.trinket)) end
        end)
        slot:SetScript("OnLeave", GameTooltip_Hide)
        slot.sell = Widgets.Button(page, 82, 20, nil, function()
            if self.game:Sell(i) then
                Coin()
                self:RefreshShop()
                self:RefreshTrinkets()
            end
        end)
        slot.sell:SetPoint("TOP", slot, "BOTTOM", 0, -3)
        slots[i] = slot
    end

    local nextGoal = Widgets.Text(page, 12, "gray")
    nextGoal:SetPoint("BOTTOM", 0, 46)
    local reroll = Widgets.Button(page, 170, 26, nil, function()
        if self.game:Reroll() then
            Sound("shuffle")
            self:RefreshShop()
        end
    end)
    reroll:SetPoint("BOTTOMLEFT", 30, 14)
    local continue = Widgets.Button(page, 170, 26, "DD_CONTINUE", function() self:NextRound() end)
    continue:SetPoint("BOTTOMRIGHT", -30, 14)

    self.shop = { reward = reward, gold = gold, offers = offers, fortunes = fortunes, owned = owned, slots = slots, nextGoal = nextGoal, reroll = reroll }
    page.refresh = function() self:RefreshShop() end
end

function Module:RefreshShop()
    local shop, game = self.shop, self.game
    if not shop or game.state ~= "SHOP" then return end
    shop.reward:SetText(L.DD_REWARD:format(self.lastReward or 0))
    shop.gold:SetText(L.DD_GOLD:format(game.gold))
    for i, panel in ipairs(shop.offers) do
        local offer = game.offers[i]
        panel:SetShown(offer ~= nil)
        if offer then
            panel.icon:SetTexture(offer.icon)
            panel.icon:SetDesaturated(false)
            panel.name:SetText(TrinketName(offer.id))
            panel.desc:SetText(TrinketDesc({ id = offer.id, stacks = 0 }))
            panel.buy:SetText(L.DD_BUY:format(offer.price))
            panel.buy:SetEnabled(game.gold >= offer.price and #game.trinkets < Game.MAX_TRINKETS)
            panel.buy:Show()
        elseif offer == false then
            panel:Show()
            panel.icon:SetDesaturated(true)
            panel.name:SetText(L.DD_SOLD)
            panel.desc:SetText("")
            panel.buy:Hide()
        end
    end
    for i, panel in ipairs(shop.fortunes) do
        local key = game.fortunes and game.fortunes[i]
        panel:SetShown(key ~= nil)
        if key then
            local hand = Game.HANDS[Game.HAND_INDEX[key]]
            local steps = game:Has("prophet") and 2 or 1
            panel.name:SetText(L.DD_FORTUNE:format(L["DD_HAND_" .. key]))
            panel.desc:SetText(L.DD_FORTUNE_DESC:format(game:Level(key) + steps, hand.lp * steps, hand.lm * steps))
            panel.icon:SetDesaturated(false)
            panel.buy:SetText(L.DD_BUY:format(Game.FORTUNE_PRICE))
            panel.buy:SetEnabled(game.gold >= Game.FORTUNE_PRICE)
            panel.buy:Show()
        elseif key == false then
            panel:Show()
            panel.icon:SetDesaturated(true)
            panel.name:SetText(L.DD_SOLD)
            panel.desc:SetText("")
            panel.buy:Hide()
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

function Module:After(delay, fn)
    self:AddEffect(delay, function()
        fn()
        return false
    end)
end

function Module:Popup(x, y, text, size, color, delay, rise)
    local fs = self.textPool.Acquire()
    fs:SetFont(Media.FontFile(), size, "OUTLINE")
    fs:SetTextColor(color[1], color[2], color[3])
    fs:SetText(text)
    fs:Hide()
    self:AddEffect(delay or 0, function(e)
        local p = e.t / 0.9
        if p >= 1 then return false end
        fs:Show()
        Place(fs, x, y - (rise or 24) * (1 - (1 - p) ^ 3))
        fs:SetAlpha(p < 0.6 and 1 or (1 - (p - 0.6) / 0.4))
        return true
    end, function() self.textPool.Release(fs) end)
end

function Module:Burst(x, y, color, count, speed, delay, gravity)
    for _ = 1, count do
        local tex = self.texPool.Acquire()
        tex:SetTexture(Media.Tex("spark"))
        tex:SetBlendMode("ADD")
        tex:SetVertexColor(color[1], color[2], color[3])
        tex:SetSize(14, 14)
        local angle = math.random() * math.pi * 2
        local v = (speed or 120) * (0.4 + math.random() * 0.8)
        local px, py, vx, vy = x, y, math.cos(angle) * v, math.sin(angle) * v
        local life = 0.5 + math.random() * 0.4
        self:AddEffect(delay or 0, function(e, dt)
            local p = e.t / life
            if p >= 1 then return false end
            vy = vy + (gravity or 0) * dt
            px, py = px + vx * dt, py + vy * dt
            Place(tex, px, py)
            tex:SetAlpha(1 - p)
            tex:Show()
            return true
        end, function() self.texPool.Release(tex) end)
    end
end

function Module:Ring(x, y, color, from, to, duration, delay)
    local tex = self.texPool.Acquire()
    tex:SetTexture(Media.Tex("ring"))
    tex:SetBlendMode("ADD")
    tex:SetVertexColor(color[1], color[2], color[3])
    self:AddEffect(delay or 0, function(e)
        local p = e.t / duration
        if p >= 1 then return false end
        local s = from + (to - from) * p
        tex:SetSize(s, s)
        tex:SetAlpha(1 - p)
        Place(tex, x, y)
        tex:Show()
        return true
    end, function() self.texPool.Release(tex) end)
end

function Module:Sparkle(x, y, color)
    self:Burst(x, y, color, 14, 140)
    self:Ring(x, y, color, 20, 110, 0.4)
end

function Module:FlashCard(v, color, delay)
    self:AddEffect(delay or 0, function(e)
        local p = e.t / 0.35
        if p >= 1 then
            v.flash:SetAlpha(0)
            return false
        end
        v.flash:SetVertexColor(color[1], color[2], color[3])
        v.flash:SetAlpha(0.7 * (1 - p))
        return true
    end)
end

function Module:FlashSlot(slot, delay)
    self:AddEffect(delay or 0, function(e)
        local p = e.t / 0.5
        if p >= 1 then
            slot.glow:SetAlpha(0)
            return false
        end
        slot.glow:SetAlpha(1 - p)
        return true
    end)
end

function Module:Shake(amount, duration)
    self.shake = math.max(self.shake, duration)
    self.shakeAmount = amount
end

function Module:ShowBanner(text, sub, color)
    self.banner:SetText(text)
    self.banner:SetTextColor(color[1], color[2], color[3])
    self.banner:SetAlpha(1)
    self.bannerSub:SetText(sub or "")
    self.bannerSub:SetAlpha(1)
    self.bannerTime = 1.8
end

function Module:HideBanner()
    self.bannerTime = 0
    self.banner:SetText("")
    self.bannerSub:SetText("")
end

function Module:Confetti()
    for i = 1, 5 do
        self:Burst(60 + (i - 1) * (W - 120) / 4, 40, CONFETTI[i], 12, 160, (i - 1) * 0.08, 220)
    end
end

function Module:ClearEffects()
    for _, e in ipairs(self.effects) do
        if e.finish then e.finish(e) end
    end
    wipe(self.effects)
    self:HideBanner()
end

-- Game flow ------------------------------------------------------------------------------

function Module:ShowMenu()
    self:ClearEffects()
    self:ClearCards()
    self:ShowDisplay(false)
    self.game.state = "READY"
    self:UpdateBoss()
    self:RefreshTrinkets()
    self:UpdatePreview()
    self:UpdateButtons()
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
    local game = self.game
    self:ClearCards()
    self:ShowDisplay(false)
    Sound("shuffle")
    self:SortHand()
    for i, card in ipairs(game.hand) do self.visuals[card].delay = 0.25 + (i - 1) * 0.06 end
    self:After(0.25, function() Sound("deal") end)
    self.roundDiscards = game.discards
    local settings = Settings()
    settings.bestAnte = math.max(settings.bestAnte or 0, game.ante)
    if game.ante >= 4 then Achievements.Unlock("dd_ante4") end
    if game.ante >= GOALS.ante10 then Achievements.Unlock("dd_ante10") end
    if game.boss then
        self:ShowBanner(L["DD_BOSS_" .. game.boss], BossDesc(game), { 1, 0.45, 0.35 })
        Sound("mult")
        self:Shake(4, 0.35)
    else
        self:ShowBanner(RoundName(game), L.DD_GOAL:format(ns.FormatNumber(game.goal)), { 1, 0.82, 0.3 })
    end
    self:UpdateBoss()
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

function Module:ContinueEndless()
    if self.game:ContinueEndless() then self.overlay:Show("shop") end
end

function Module:Play()
    local game = self.game
    if game.state ~= "PLAYING" or self.busy > 0 then return end
    local indexes = self:SelectedIndexes()
    if #indexes == 0 then return end
    local result = game:Play(indexes)
    if not result then return end
    wipe(self.selected)
    self.preview:SetText("")
    self:HideBanner()

    -- Played cards line up in the middle of the table, scoring cards a little higher.
    local scoring = {}
    for _, c in ipairs(result.scoring) do scoring[c] = true end
    local n = #result.cards
    local positions = {}
    for i, card in ipairs(result.cards) do
        local v = self.visuals[card]
        positions[card] = W / 2 + (i - (n + 1) / 2) * (CARD_W + 8)
        if v then
            v.tx, v.ty = positions[card], PLAY_Y - (scoring[card] and 12 or 0)
            v.glow:Hide()
            v.played = true
            v:SetAlpha(scoring[card] and 1 or 0.55)
        end
    end

    local d = self.display
    self:ShowDisplay(true)
    d.name:SetText(HandName(result.key, result.level))
    local base = Game.HANDS[Game.HAND_INDEX[result.key]]
    local level = result.level or 1
    local points = base.points + base.lp * (level - 1)
    d.points.text:SetText(ns.FormatNumber(points))
    d.mult.text:SetText(base.mult + base.lm * (level - 1))
    d.times:SetText("×")
    d.total:SetText("")

    -- Count the scoring cards into the points box one by one.
    local t, count = 0.3, 0
    for _, card in ipairs(result.cards) do
        if scoring[card] then
            count = count + 1
            local add = card.suit == game.cursedSuit and 0 or Game.CardPoints(card)
            local v = self.visuals[card]
            local x = positions[card]
            local chip = math.min(5, count)
            self:After(t, function()
                points = points + add
                d.points.text:SetText(ns.FormatNumber(points))
                Sound("chip" .. chip)
            end)
            if v then self:FlashCard(v, POINTS_COLOR, t) end
            self:Popup(x, PLAY_Y - CARD_H / 2 - 22, "+" .. add, 15, POINTS_COLOR, t)
            self:Burst(x, PLAY_Y - 12, SUIT_COLORS[card.suit], 5, 90, t)
            t = t + 0.14
        end
    end
    for _, note in ipairs(result.notes) do
        local slot = self:SlotFor(note.id)
        if slot then
            self:FlashSlot(slot, t)
            self:Popup(slot.center[1], slot.center[2] + 30, note.text, 15, MULT_COLOR, t)
        end
        t = t + 0.14
    end
    self:After(t, function()
        d.points.text:SetText(ns.FormatNumber(result.points))
        d.mult.text:SetText(FormatMult(result.mult))
        Sound("mult")
        self:Burst(W / 2 + 62, PLAY_Y + CARD_H / 2 + 26, MULT_COLOR, 12, 130)
    end)
    t = t + 0.25
    self:After(t, function()
        if result.voided then
            d.total:SetText("= 0")
            self:Popup(W / 2, PLAY_Y, L.DD_VOID, 20, { 1, 0.4, 0.35 })
        else
            d.total:SetText("= " .. ns.FormatNumber(result.total))
            local big = result.total >= game.goal * 0.5
            self:Ring(W / 2 + 200, PLAY_Y + CARD_H / 2 + 26, { 1, 0.82, 0.3 }, 20, big and 220 or 120, 0.5)
            if big then self:Shake(5, 0.4) end
        end
        if (result.gold or 0) > 0 then
            self:Popup(W - 60, 80, L.DD_GOLD_GAIN:format(result.gold), 15, { 1, 0.85, 0.3 }, 0.1)
            Coin()
        end
        self:UpdateHud()
    end)

    local settings = Settings()
    settings.hands = settings.hands + 1
    settings.bestHand = math.max(settings.bestHand, result.total)
    if settings.hands >= GOALS.hands then Achievements.Unlock("dd_hands") end
    if result.key == "four" then Achievements.Unlock("dd_four") end
    if result.key == "straightflush" then Achievements.Unlock("dd_straightflush") end
    if result.total >= GOALS.hand1k then Achievements.Unlock("dd_hand1k") end
    if result.total >= GOALS.hand10k then Achievements.Unlock("dd_hand10k") end
    if result.total >= GOALS.hand100k then Achievements.Unlock("dd_hand100k") end

    self.busy = math.max(PLAY_TIME, t + 0.9)
    self.afterBusy = function()
        for _, card in ipairs(result.cards) do self:ReleaseVisual(card) end
        self:ShowDisplay(false)
        self:AfterPlay()
    end
    self:UpdateButtons()
end

function Module:AfterPlay()
    local game = self.game
    if game.state == "SHOP" or game.state == "WON" then
        Media.Play("spellbounce/clear")
        self:Confetti()
        Achievements.Unlock("dd_first")
        if game.boss then
            Achievements.Unlock("dd_boss")
            if game.discards == self.roundDiscards then Achievements.Unlock("dd_nodiscard") end
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
            if #game.trinkets <= GOALS.frugal then Achievements.Unlock("dd_frugal") end
            self:After(0.8, function()
                if game.state == "WON" then self.overlay:Show("won", { score = game.score, ante = game.ante }) end
            end)
        else
            self:ShowBanner(L.DD_ROUND_WON, L.DD_REWARD:format(self.lastReward or 0), { 1, 0.82, 0.3 })
            self:After(1.1, function()
                self:HideBanner()
                if game.state == "SHOP" then self.overlay:Show("shop") end
            end)
        end
    elseif game.state == "OVER" then
        Media.Play("murlocblast/gameover")
        self:Shake(6, 0.5)
        local rank = self:Record()
        self:After(0.8, function()
            self.overlay:Show("over", { score = game.score, ante = game.ante, rank = rank })
        end)
    else
        Sound("deal")
        self:SortHand()
    end
    self:UpdatePreview()
    self:UpdateButtons()
    self:UpdateHud()
    self:RefreshTrinkets()
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
            v.tx, v.ty = -70, HAND_Y + 30 + i * 6
            v.played = true
            v.glow:Hide()
        end
    end
    Sound("deal")
    if game.boss == "selina" then self:Popup(W - 60, 80, "-2", 15, { 1, 0.4, 0.35 }) end
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
    if self.finished then return self.lastRank end
    self.finished = true
    self.lastEntry = { score = game.score, ante = game.ante }
    self.lastRank = Scores.Record(self.id, "default", { score = game.score, ante = game.ante })
    return self.lastRank
end

function Module:AbandonRun()
    local state = self.game.state
    if self.game.score > 0 and (state == "PAUSED" or state == "SHOP") then self:Record() end
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
    local active = self.game.state ~= "READY"
    for i, slot in ipairs(self.trinketSlots) do
        local trinket = active and trinkets[i] or nil
        slot.trinket = trinket
        if trinket then
            slot.icon:SetTexture(Game.TRINKET[trinket.id].icon)
            slot.icon:Show()
            local stacks = (trinket.id == "lunacy" or trinket.id == "momentum") and (trinket.stacks or 0) or 0
            slot.stacks:SetText(stacks > 0 and stacks or "")
        else
            slot.icon:Hide()
            slot.stacks:SetText("")
        end
        slot:SetShown(active)
    end
end

function Module:UpdateBoss()
    local game, box = self.game, self.bossBox
    if game.state == "READY" or not game.boss then
        box:Hide()
        return
    end
    box.name:SetText(L["DD_BOSS_" .. game.boss])
    box.desc:SetText(BossDesc(game))
    local npc = BOSS_NPCS[game.boss]
    if npc then
        pcall(box.model.SetCreature, box.model, npc)
        pcall(box.model.SetPortraitZoom, box.model, 0.8)
    end
    box:Show()
end

function Module:UpdatePreview()
    local game = self.game
    local indexes = self:SelectedIndexes()
    if game.state ~= "PLAYING" or self.busy > 0 then
        self.preview:SetText("")
    elseif #indexes == 0 then
        self.preview:SetText(L.DD_SELECT_HINT)
    elseif Settings().preview then
        local cards = {}
        for i, idx in ipairs(indexes) do cards[i] = game.hand[idx] end
        local result = game:Score(cards)
        local text = L.DD_PREVIEW:format(HandName(result.key, result.level), ns.FormatNumber(result.points), FormatMult(result.mult))
        if result.voided then text = text .. "  ·  " .. L.DD_VOID end
        self.preview:SetText(text)
    else
        self.preview:SetText("")
    end
end

function Module:UpdateButtons()
    local game = self.game
    local playing = game.state == "PLAYING" and self.busy <= 0
    local selected = self:CountSelected()
    self.playButton:SetText(L.DD_PLAY)
    self.discardButton:SetText(L.DD_DISCARD)
    self.sortButton:SetText(Settings().sort == "rank" and L.DD_SORT_SUIT or L.DD_SORT_RANK)
    self.playButton:SetEnabled(playing and selected > 0)
    self.discardButton:SetEnabled(playing and selected > 0 and game:CanDiscard())
    self.sortButton:SetEnabled(playing)
    local show = game.state ~= "READY"
    self.playButton:SetShown(show)
    self.discardButton:SetShown(show)
    self.sortButton:SetShown(show)
end

function Module:UpdateHud()
    local game, info = self.game, self.info
    local active = (game.state ~= "READY" and game.goal) and true or false
    for _, badge in pairs(info.badges) do badge:SetShown(active) end
    info.track:SetShown(active)
    info.bar:SetShown(active)
    if active then
        info.round:SetText(L.DD_ANTE:format(game.ante) .. "  ·  " .. RoundName(game))
        info.goal:SetText(L.DD_GOAL:format(ns.FormatNumber(game.goal)))
        info.target = game.roundScore
        info.badges.plays.value:SetText(game.plays)
        info.badges.discards.value:SetText(game.discards)
        info.badges.gold.value:SetText(game.gold)
    else
        info.round:SetText("")
        info.goal:SetText("")
        info.score:SetText("")
        info.target, info.shown = 0, 0
    end
    ns.Window:UpdateSidebar()
end

-- The round score bar counts up instead of jumping.
function Module:UpdateScoreBar(dt)
    local info, game = self.info, self.game
    if not game.goal or game.state == "READY" then return end
    local target = math.min(info.target or 0, game.roundScore)
    if game.state == "PLAYING" and self.busy <= 0 then target = game.roundScore end
    if info.shown > target then info.shown = 0 end
    if info.shown ~= target or info.goalShown ~= game.goal then
        info.goalShown = game.goal
        local step = math.max(1, (target - info.shown) * math.min(1, dt * 6))
        info.shown = math.min(target, info.shown + step)
        info.bar:SetWidth(math.max(1, (W - 36) * math.min(1, info.shown / game.goal)))
        info.score:SetText(L.DD_ROUND_SCORE:format(ns.FormatNumber(math.floor(info.shown))))
    end
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
    self:UpdateBoss()
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
        Settings().sort = Settings().sort == "rank" and "suit" or "rank"
        self:SortHand()
        self:UpdateButtons()
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
    -- Cards glide toward their places; hovered hand cards lift a little.
    local k = math.min(1, dt * 12)
    for _, v in pairs(self.visuals) do
        if v.delay and v.delay > 0 then
            v.delay = v.delay - dt
        elseif v.tx then
            local ty = v.ty
            if v.hover and not v.played and self.busy <= 0 then ty = (v.baseY or ty) - 5 end
            local dx, dy = v.tx - v.x, ty - v.y
            if math.abs(dx) > 0.3 or math.abs(dy) > 0.3 then
                v.x, v.y = v.x + dx * k, v.y + dy * k
                Place(v, v.x, v.y)
            elseif v.x ~= v.tx or v.y ~= ty then
                v.x, v.y = v.tx, ty
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
    if (self.bannerTime or 0) > 0 then
        self.bannerTime = self.bannerTime - dt
        local alpha = math.min(1, self.bannerTime / 0.4)
        self.banner:SetAlpha(alpha)
        self.bannerSub:SetAlpha(alpha)
        if self.bannerTime <= 0 then self:HideBanner() end
    end
    if self.shake > 0 then
        self.shake = self.shake - dt
        local a = (self.shakeAmount or 4) * math.max(0, self.shake) / 0.4
        self.stage:ClearAllPoints()
        if self.shake > 0 then
            self.stage:SetPoint("TOPLEFT", (math.random() - 0.5) * 2 * a, (math.random() - 0.5) * 2 * a)
        else
            self.stage:SetPoint("TOPLEFT")
        end
    end
    self:UpdateScoreBar(dt)
end

function Module:DecorateTile(tile, art)
    for i, suit in ipairs(Game.SUITS) do
        local icon = tile:CreateTexture(nil, "OVERLAY")
        icon:SetTexture(Tex("suit_" .. suit))
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
        { L.DD_STAT_ANTE, tostring(settings.bestAnte or 0) },
    }
end

DD.Module = Module
Arcade.RegisterGame(Module)
