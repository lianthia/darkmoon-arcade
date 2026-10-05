local _, ns = ...

local Game, Board, Levels, Media, Flight, L = ns.Game, ns.Board, ns.Levels, ns.Media, ns.Flight, ns.L

local Window = {}
ns.Window = Window

local PAD = 14
local HEADER = 54
local FOOTER = 30
local KEY_TURN_SPEED = 1.9
local MAX_SCORES = 10
local SCALES = { 0.7, 0.8, 0.9, 1.0, 1.1, 1.2, 1.3, 1.4 }

local AIM_LEFT = { LEFT = true, A = true }
local AIM_RIGHT = { RIGHT = true, D = true }
local SHOOT = { SPACE = true, UP = true, W = true }
local SWAP = { DOWN = true, S = true, TAB = true }

local refreshers = {}

local function OnRefresh(fn)
    refreshers[#refreshers + 1] = fn
end

local function Text(parent, size, color)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject(Media.Font(size, color))
    return fs
end

local function Button(parent, width, height)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width or 200, height or 26)
    b:SetNormalFontObject(Media.Font(12, "gold", ""))
    b:SetHighlightFontObject(Media.Font(12, "white", ""))
    b:SetDisabledFontObject(Media.Font(12, "gray", ""))
    return b
end

local function LocalizedButton(parent, key, width, height, onClick)
    local b = Button(parent, width, height)
    b:SetScript("OnClick", onClick)
    OnRefresh(function() b:SetText(L[key]) end)
    return b
end

local function Cycler(parent, width, onStep)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(width, 26)
    local function Arrow(dir, point)
        local b = CreateFrame("Button", nil, f)
        b:SetSize(26, 26)
        b:SetPoint(point)
        local page = dir < 0 and "Prev" or "Next"
        b:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. page .. "Page-Up")
        b:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. page .. "Page-Down")
        b:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
        b:SetScript("OnClick", function()
            PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
            onStep(dir)
        end)
    end
    Arrow(-1, "LEFT")
    Arrow(1, "RIGHT")
    f.label = Text(f, 13, "white")
    f.label:SetPoint("CENTER")
    return f
end

local function Cycle(list, current, dir)
    local index = 1
    for i, v in ipairs(list) do
        if v == current then index = i end
    end
    return list[(index - 1 + dir) % #list + 1]
end

local function DifficultyName(difficulty)
    return L[difficulty:upper()]
end

-- Window ---------------------------------------------------------------------

function Window:Create()
    local f = CreateFrame("Frame", "MurlocBlastFrame", UIParent, "BackdropTemplate")
    f:SetSize(Game.WIDTH + PAD * 2, Game.HEIGHT + HEADER + FOOTER)
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        local point, _, relPoint, x, y = frame:GetPoint()
        ns.db.position = { point, relPoint, x, y }
    end)
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    f:Hide()
    tinsert(UISpecialFrames, "MurlocBlastFrame")
    self.frame = f
    self:ApplyScale()
    self:RestorePosition()

    self:CreateHeader()
    self:CreateFooter()

    local border = f:CreateTexture(nil, "BORDER")
    border:SetColorTexture(0, 0, 0, 0.85)
    border:SetPoint("TOPLEFT", PAD - 2, -(HEADER - 2))
    border:SetSize(Game.WIDTH + 4, Game.HEIGHT + 4)

    local field = Board:Create(f)
    field:SetPoint("TOPLEFT", PAD, -HEADER)
    self.field = field

    self:CreatePages()
    self:SetupInput()

    local game = Game.New()
    game.difficulty = ns.db.difficulty
    self.game = game
    Board:Attach(game)
    game.onEvent = function(name, data)
        Board:OnGameEvent(name, data)
        self:OnGameEvent(name, data)
    end

    self:RefreshTexts()
    self:ShowMenuBoard()

    f:SetScript("OnUpdate", function(_, elapsed) self:OnUpdate(math.min(elapsed, 0.05)) end)
    f:SetScript("OnHide", function() self:OnHidden() end)
    f:SetScript("OnShow", function() self:OnShown() end)
end

function Window:CreateHeader()
    local f = self.frame
    local header = f:CreateTexture(nil, "ARTWORK")
    header:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    header:SetSize(280, 64)
    header:SetPoint("TOP", 0, 12)
    local title = Text(f, 13, "gold")
    title:SetPoint("TOP", header, "TOP", 0, -14)
    title:SetText(L.TITLE)

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)

    local gear = CreateFrame("Button", nil, f)
    gear:SetSize(20, 20)
    gear:SetPoint("TOPLEFT", 14, -12)
    gear:SetNormalTexture("Interface\\Icons\\INV_Misc_Gear_01")
    gear:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    gear:SetScript("OnClick", function() self:OpenOptions() end)
    gear:SetScript("OnEnter", function(button)
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.OPTIONS)
        GameTooltip:Show()
    end)
    gear:SetScript("OnLeave", GameTooltip_Hide)

    self.levelText = Text(f, 11, "white")
    self.levelText:SetPoint("BOTTOMLEFT", f, "TOPLEFT", PAD + 2, -(HEADER - 6))
    self.scoreText = Text(f, 18, "gold")
    self.scoreText:SetPoint("BOTTOM", f, "TOP", 0, -(HEADER - 4))
    self.bestText = Text(f, 11, "gray")
    self.bestText:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", -(PAD + 2), -(HEADER - 6))
end

function Window:CreateFooter()
    local f = self.frame
    local icon = f:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\Minimap\\Tracking\\FlightMaster")
    icon:SetSize(16, 16)
    icon:SetPoint("BOTTOMLEFT", PAD + 2, 10)
    self.flightIcon = icon
    self.flightText = Text(f, 11, "blue")
    self.flightText:SetPoint("LEFT", icon, "RIGHT", 4, 0)
    self.difficultyText = Text(f, 11, "gray")
    self.difficultyText:SetPoint("BOTTOMRIGHT", -(PAD + 2), 12)
end

function Window:ApplyScale()
    self.frame:SetScale(ns.db.scale)
end

function Window:RestorePosition()
    local f, pos = self.frame, ns.db.position
    f:ClearAllPoints()
    if pos then
        f:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    end
end

function Window:RefreshTexts()
    for _, fn in ipairs(refreshers) do fn() end
    Board:RefreshTexts()
    self:UpdateHud()
    if self.currentPage and self.pages[self.currentPage].refresh then
        self.pages[self.currentPage].refresh(self.pageData)
    end
end

-- Pages ----------------------------------------------------------------------

function Window:CreatePages()
    local o = CreateFrame("Frame", nil, self.field)
    o:SetAllPoints()
    o:SetFrameLevel(self.field:GetFrameLevel() + 20)
    o:EnableMouse(true)
    local shade = o:CreateTexture(nil, "BACKGROUND")
    shade:SetAllPoints()
    shade:SetColorTexture(0, 0.03, 0.06, 0.74)
    self.overlay = o
    self.pages = {}

    self:CreateMenuPage()
    self:CreatePausePage()
    self:CreateResultPages()
    self:CreateScoresPage()
    self:CreateOptionsPage()
end

function Window:NewPage(name)
    local page = CreateFrame("Frame", nil, self.overlay)
    page:SetAllPoints()
    page:Hide()
    self.pages[name] = page
    return page
end

local function PageTitle(page, key, y)
    local fs = Text(page, 28, "gold")
    fs:SetPoint("TOP", 0, y or -60)
    if key then OnRefresh(function() fs:SetText(L[key]) end) end
    return fs
end

local function HelpText(page)
    local fs = Text(page, 10, "gray")
    fs:SetPoint("BOTTOM", 0, 64)
    fs:SetWidth(Game.WIDTH - 30)
    OnRefresh(function() fs:SetText(L.HELP) end)
    return fs
end

local function Stack(page, buttons, top)
    for i, b in ipairs(buttons) do
        b:SetPoint("TOP", page, "TOP", 0, top - (i - 1) * 32)
    end
end

function Window:ShareRow(page, anchorY, getEntry)
    local row = CreateFrame("Frame", nil, page)
    row:SetSize(330, 24)
    row:SetPoint("TOP", 0, anchorY)
    local label = Text(row, 12, "white")
    label:SetPoint("LEFT")
    OnRefresh(function() label:SetText(L.SHARE) end)
    local last
    for _, channel in ipairs({ "SAY", "PARTY", "GUILD" }) do
        local b = Button(row, 78, 22)
        if last then b:SetPoint("LEFT", last, "RIGHT", 4, 0) else b:SetPoint("LEFT", label, "RIGHT", 8, 0) end
        b:SetScript("OnClick", function() self:Share(channel, getEntry()) end)
        OnRefresh(function() b:SetText(L[channel]) end)
        last = b
    end
    return row
end

function Window:CreateMenuPage()
    local page = self:NewPage("menu")
    local title = PageTitle(page, "TITLE", -48)
    local tagline = Text(page, 14, "blue")
    tagline:SetPoint("TOP", title, "BOTTOM", 0, -6)
    OnRefresh(function() tagline:SetText(L.TAGLINE) end)
    local flight = Text(page, 12, "white")
    flight:SetPoint("TOP", tagline, "BOTTOM", 0, -10)
    page.flight = flight

    local diffLabel = Text(page, 11, "gray")
    diffLabel:SetPoint("TOP", 0, -150)
    OnRefresh(function() diffLabel:SetText(L.DIFFICULTY) end)
    local diff = Cycler(page, 200, function(dir)
        ns.db.difficulty = Cycle(Levels.DIFFICULTIES, ns.db.difficulty, dir)
        self.game.difficulty = ns.db.difficulty
        self:UpdateHud()
        page.refresh()
    end)
    diff:SetPoint("TOP", diffLabel, "BOTTOM", 0, -2)

    local newGame = LocalizedButton(page, "NEW_GAME", nil, nil, function() self:StartGame(1) end)
    local continue = Button(page)
    continue:SetScript("OnClick", function() self:StartGame(self:Progress()) end)
    local scores = LocalizedButton(page, "HIGHSCORES", nil, nil, function() self:ShowPage("scores") end)
    local options = LocalizedButton(page, "OPTIONS", nil, nil, function() self:ShowPage("options", { back = "menu" }) end)
    Stack(page, { newGame, continue, scores, options }, -200)
    HelpText(page)

    page.refresh = function()
        diff.label:SetText(DifficultyName(ns.db.difficulty))
        local progress = self:Progress()
        continue:SetText(L.CONTINUE:format(progress))
        continue:SetEnabled(progress > 1)
        local dest = Flight:Status()
        flight:SetText(dest and L.FLIGHT_TO:format(dest) or "")
    end
end

function Window:CreatePausePage()
    local page = self:NewPage("pause")
    local title = PageTitle(page, "PAUSED", -90)
    local landed = Text(page, 14, "blue")
    landed:SetPoint("TOP", title, "BOTTOM", 0, -8)
    local resume = LocalizedButton(page, "RESUME", nil, nil, function() self:Resume() end)
    local options = LocalizedButton(page, "OPTIONS", nil, nil, function() self:ShowPage("options", { back = "pause" }) end)
    local menu = LocalizedButton(page, "MENU", nil, nil, function() self:AbandonRun() end)
    Stack(page, { resume, options, menu }, -190)
    HelpText(page)
    page.refresh = function(data)
        landed:SetText((data and data.landed) and L.LANDED or "")
    end
end

function Window:CreateResultPages()
    local clear = self:NewPage("clear")
    local clearTitle = PageTitle(clear, "LEVEL_CLEAR", -100)
    local bonus = Text(clear, 16, "white")
    bonus:SetPoint("TOP", clearTitle, "BOTTOM", 0, -10)
    local clearScore = Text(clear, 14, "gold")
    clearScore:SetPoint("TOP", bonus, "BOTTOM", 0, -8)
    local nextLevel = LocalizedButton(clear, "NEXT_LEVEL", nil, nil, function() self:StartLevel(self.game.level + 1) end)
    local clearMenu = LocalizedButton(clear, "MENU", nil, nil, function() self:AbandonRun() end)
    Stack(clear, { nextLevel, clearMenu }, -230)
    clear.refresh = function(data)
        bonus:SetText(L.BONUS:format(ns.FormatNumber(data.bonus)))
        clearScore:SetText(L.FINAL_SCORE:format(ns.FormatNumber(self.game.score)))
    end

    local over = self:NewPage("over")
    local overTitle = PageTitle(over, "GAME_OVER", -90)
    local final = Text(over, 16, "white")
    final:SetPoint("TOP", overTitle, "BOTTOM", 0, -10)
    local record = Text(over, 14, "gold")
    record:SetPoint("TOP", final, "BOTTOM", 0, -8)
    self:ShareRow(over, -190, function() return self.lastEntry end)
    local again = LocalizedButton(over, "AGAIN", nil, nil, function() self:StartGame(self.game.level) end)
    local overMenu = LocalizedButton(over, "MENU", nil, nil, function() self:ShowMenuBoard() end)
    Stack(over, { again, overMenu }, -240)
    over.refresh = function(data)
        final:SetText(L.FINAL_SCORE:format(ns.FormatNumber(data.score)))
        record:SetText(data.rank == 1 and L.NEW_RECORD or "")
    end
end

function Window:CreateScoresPage()
    local page = self:NewPage("scores")
    local title = PageTitle(page, "HIGHSCORES", -30)
    page.difficulty = ns.db.difficulty
    local diff = Cycler(page, 200, function(dir)
        page.difficulty = Cycle(Levels.DIFFICULTIES, page.difficulty, dir)
        page.refresh()
    end)
    diff:SetPoint("TOP", title, "BOTTOM", 0, -8)

    local rows = {}
    for i = 1, MAX_SCORES do
        local y = -112 - (i - 1) * 20
        local row = {
            rank = Text(page, 12, "gray"),
            score = Text(page, 13, "gold"),
            level = Text(page, 12, "white"),
            date = Text(page, 11, "gray"),
        }
        row.rank:SetPoint("TOPRIGHT", page, "TOPLEFT", 70, y)
        row.score:SetPoint("TOPRIGHT", page, "TOPLEFT", 190, y)
        row.level:SetPoint("TOPLEFT", page, "TOPLEFT", 214, y)
        row.date:SetPoint("TOPLEFT", page, "TOPLEFT", 300, y)
        rows[i] = row
    end
    local empty = Text(page, 12, "gray")
    empty:SetPoint("TOP", 0, -150)
    empty:SetWidth(Game.WIDTH - 60)

    self:ShareRow(page, -330, function()
        local best = ns.db.scores[page.difficulty][1]
        return best and { score = best.score, level = best.level, difficulty = page.difficulty }
    end)
    local back = LocalizedButton(page, "BACK", nil, nil, function() self:ShowPage("menu") end)
    back:SetPoint("TOP", 0, -366)

    page.refresh = function()
        diff.label:SetText(DifficultyName(page.difficulty))
        local list = ns.db.scores[page.difficulty]
        for i, row in ipairs(rows) do
            local entry = list[i]
            if entry then
                row.rank:SetText(i .. ".")
                row.score:SetText(ns.FormatNumber(entry.score))
                row.level:SetText(L.LEVEL:format(entry.level))
                row.date:SetText(date("%d.%m.%y", entry.time))
            end
            for _, fs in pairs(row) do fs:SetShown(entry ~= nil) end
        end
        empty:SetText(#list == 0 and L.NO_SCORES or "")
    end
end

function Window:CreateOptionsPage()
    local page = self:NewPage("options")
    PageTitle(page, "OPTIONS", -30)
    local checks = {
        { "sound", "OPT_SOUND" },
        { "voices", "OPT_VOICES" },
        { "symbols", "OPT_SYMBOLS", function() Board:SyncBoard() end },
        { "minimap", "OPT_MINIMAP", function() ns.Minimap:Update() end },
        { "flight", "OPT_FLIGHT" },
        { "flightTime", "OPT_FLIGHT_TIME" },
    }
    local items = {}
    for i, def in ipairs(checks) do
        local cb = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        cb:SetSize(26, 26)
        cb:SetPoint("TOPLEFT", 70, -80 - (i - 1) * 30)
        local label = Text(page, 12, "white")
        label:SetPoint("LEFT", cb, "RIGHT", 4, 0)
        cb:SetScript("OnClick", function(button)
            ns.db[def[1]] = button:GetChecked() and true or false
            if def[3] then def[3]() end
        end)
        OnRefresh(function() label:SetText(L[def[2]]) end)
        items[#items + 1] = cb
        cb.key = def[1]
    end

    local function Row(key, y)
        local label = Text(page, 12, "white")
        label:SetPoint("TOPLEFT", 74, y - 6)
        OnRefresh(function() label:SetText(L[key]) end)
    end

    Row("OPT_LANGUAGE", -270)
    local language = Cycler(page, 170, function(dir)
        ns.db.language = Cycle(ns.LANGUAGES, ns.db.language, dir)
        self:ApplyLanguage()
    end)
    language:SetPoint("TOPRIGHT", page, "TOPRIGHT", -60, -270)

    Row("OPT_SCALE", -302)
    local scale = Cycler(page, 170, function(dir)
        local current = ns.db.scale
        local index = 1
        for i, v in ipairs(SCALES) do
            if math.abs(v - current) < 0.01 then index = i end
        end
        index = math.max(1, math.min(#SCALES, index + dir))
        ns.db.scale = SCALES[index]
        self:ApplyScale()
        page.refresh()
    end)
    scale:SetPoint("TOPRIGHT", page, "TOPRIGHT", -60, -302)

    local back = LocalizedButton(page, "BACK", nil, nil, function()
        self:ShowPage(page.back or "menu", self.pauseData)
    end)
    back:SetPoint("TOP", 0, -356)

    page.refresh = function(data)
        if data and data.back then page.back = data.back end
        for _, cb in ipairs(items) do cb:SetChecked(ns.db[cb.key]) end
        local code = ns.db.language
        local display = code == "auto" and ns.language or code
        language.label:SetFont(Media.FontFile(display), 13, "OUTLINE")
        language.label:SetText(code == "auto" and L.LANG_AUTO or ns.LANGUAGE_NAMES[code])
        scale.label:SetText(("%d%%"):format(ns.db.scale * 100 + 0.5))
    end
end

function Window:ShowPage(name, data)
    for pageName, page in pairs(self.pages) do
        page:SetShown(pageName == name)
    end
    self.currentPage, self.pageData = name, data
    if self.pages[name].refresh then self.pages[name].refresh(data) end
    self.overlay:Show()
end

function Window:HideOverlay()
    self.overlay:Hide()
    self.currentPage = nil
end

function Window:ApplyLanguage()
    ns.SetLanguage(ns.db.language)
    Media.ApplyLanguageFonts()
    self:RefreshTexts()
end

-- Game flow ------------------------------------------------------------------

function Window:Progress()
    return ns.db.progress[ns.db.difficulty] or 1
end

function Window:ShowMenuBoard()
    local game = self.game
    game.state = "READY"
    game.drops = 0
    game.shot = nil
    game.score = 0
    game.level = 1
    Levels.Load(game.grid, 1, game.difficulty)
    Board:Reset()
    Board:SyncBoard()
    self:UpdateHud()
    self:ShowPage("menu")
end

function Window:StartGame(level)
    self.game.difficulty = ns.db.difficulty
    self.game:StartLevel(level, false)
    self:HideOverlay()
end

function Window:StartLevel(level)
    self.game:StartLevel(level, true)
    self:HideOverlay()
end

-- Leaving a run early still counts towards the highscores.
function Window:AbandonRun()
    if self.game.score > 0 and (self.game.state == "PAUSED" or self.game.state == "CLEAR") then
        self:RecordScore()
    end
    self:ShowMenuBoard()
end

function Window:Pause(landed)
    local game = self.game
    if game.state == "PLAYING" then
        game:Pause()
        self.pauseData = { landed = landed }
        self:ShowPage("pause", self.pauseData)
    elseif landed and game.state == "PAUSED" then
        self.pauseData = { landed = true }
        self:ShowPage("pause", self.pauseData)
    end
end

function Window:Resume()
    self.game:Resume()
    self:HideOverlay()
end

function Window:OpenOptions()
    self.frame:Show()
    if self.game.state == "PLAYING" then
        self.game:Pause()
        self.pauseData = {}
    end
    local back = self.game.state == "PAUSED" and "pause" or "menu"
    self:ShowPage("options", { back = back })
end

function Window:UpdateHud()
    local game = self.game
    if not game then return end
    self.levelText:SetText(L.LEVEL:format(game.level))
    self.scoreText:SetText(ns.FormatNumber(game.score))
    local best = ns.db.scores[game.difficulty][1]
    self.bestText:SetText(L.BEST:format(ns.FormatNumber(best and best.score or 0)))
    self.difficultyText:SetText(DifficultyName(game.difficulty))
end

-- Inserts the current run into the highscore list and returns its rank (or nil).
function Window:RecordScore()
    local game = self.game
    local list = ns.db.scores[game.difficulty]
    local entry = { score = game.score, level = game.level, time = time() }
    self.lastEntry = { score = game.score, level = game.level, difficulty = game.difficulty }
    local rank
    for i = 1, #list + 1 do
        if not list[i] or list[i].score < entry.score then
            table.insert(list, i, entry)
            rank = i
            break
        end
    end
    while #list > MAX_SCORES do table.remove(list) end
    if rank and rank > MAX_SCORES then rank = nil end
    return rank
end

function Window:Share(channel, entry)
    if not entry then return end
    if channel == "PARTY" then
        if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
            channel = "INSTANCE_CHAT"
        elseif IsInRaid() then
            channel = "RAID"
        elseif not IsInGroup() then
            ns.Print(L.NOT_IN_GROUP)
            return
        end
    elseif channel == "GUILD" and not IsInGuild() then
        ns.Print(L.NOT_IN_GUILD)
        return
    end
    local message = L.SHARE_MSG:format(ns.FormatNumber(entry.score), entry.level, DifficultyName(entry.difficulty))
    SendChatMessage(message, channel)
end

function Window:OnGameEvent(name, data)
    local game, db = self.game, ns.db
    if name == "score" or name == "level" then
        self:UpdateHud()
    elseif name == "clear" then
        db.progress[game.difficulty] = math.max(self:Progress(), game.level + 1)
        self:UpdateHud()
        C_Timer.After(1.2, function()
            if game.state == "CLEAR" then self:ShowPage("clear", data) end
        end)
    elseif name == "over" then
        local rank = self:RecordScore()
        self:UpdateHud()
        C_Timer.After(1.1, function()
            if game.state == "OVER" then
                self:ShowPage("over", { score = game.score, rank = rank })
            end
        end)
    end
end

-- Input ----------------------------------------------------------------------

function Window:SetupInput()
    local f, field = self.frame, self.field
    self.keysHeld = {}

    field:EnableMouse(true)
    field:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then
            self:AimAtCursor()
            self.game:Shoot()
        elseif button == "RightButton" then
            self.game:Swap()
        end
    end)

    f:EnableKeyboard(true)
    f:SetScript("OnKeyDown", function(frame, key)
        local handled = self:OnKey(key)
        if not InCombatLockdown() then frame:SetPropagateKeyboardInput(not handled) end
    end)
    f:SetScript("OnKeyUp", function(_, key)
        self.keysHeld[key] = nil
    end)
end

function Window:OnKey(key)
    local game = self.game
    if key == "P" and (game.state == "PLAYING" or (game.state == "PAUSED" and self.currentPage == "pause")) then
        if game.state == "PLAYING" then self:Pause() else self:Resume() end
        return true
    end
    if game.state ~= "PLAYING" then return false end
    if AIM_LEFT[key] or AIM_RIGHT[key] then
        self.keysHeld[key] = true
        return true
    elseif SHOOT[key] then
        game:Shoot()
        return true
    elseif SWAP[key] then
        game:Swap()
        return true
    end
    return false
end

function Window:AimAtCursor()
    local field = self.field
    local left, top = field:GetLeft(), field:GetTop()
    if not left then return end
    local scale = field:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    self.game:AimAt(cx / scale - left, top - cy / scale)
end

function Window:UpdateFlightInfo()
    local dest, seconds, exact, isEstimate = Flight:Status()
    if not dest or not ns.db.flightTime then
        self.flightIcon:Hide()
        self.flightText:SetText("")
        return
    end
    self.flightIcon:Show()
    local timeText = isEstimate and ((exact and "" or "~") .. ns.FormatTime(seconds)) or ns.FormatTime(seconds)
    local label = dest ~= nil and dest ~= "" and L.FLIGHT_TO:format(dest) or L.IN_FLIGHT
    self.flightText:SetText(label .. "  ·  " .. timeText)
end

function Window:OnUpdate(dt)
    local game = self.game
    if game.state == "PLAYING" then
        local turn = 0
        for key in pairs(self.keysHeld) do
            if AIM_LEFT[key] then turn = turn + 1 elseif AIM_RIGHT[key] then turn = turn - 1 end
        end
        if turn ~= 0 then
            game:SetAim(game.angle + turn * KEY_TURN_SPEED * dt)
        elseif self.field:IsMouseOver() then
            local cx, cy = GetCursorPosition()
            if cx ~= self.lastCursorX or cy ~= self.lastCursorY then
                self.lastCursorX, self.lastCursorY = cx, cy
                self:AimAtCursor()
            end
        end
    end
    game:Update(dt)
    Board:Update(dt)

    self.infoTimer = (self.infoTimer or 0) - dt
    if self.infoTimer <= 0 then
        self.infoTimer = 0.25
        self:UpdateFlightInfo()
    end
end

function Window:OnShown()
    PlaySound(SOUNDKIT.IG_MAINMENU_OPEN)
    if self.currentPage == "menu" then self.pages.menu.refresh() end
end

function Window:OnHidden()
    wipe(self.keysHeld)
    if self.game.state == "PLAYING" then
        self:Pause()
    end
    PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)
end

function Window:Toggle()
    if self.frame:IsShown() then self.frame:Hide() else self.frame:Show() end
end
