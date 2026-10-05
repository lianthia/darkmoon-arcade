local _, ns = ...

local MB = ns.MurlocBlast
local Game, Board, Levels = MB.Game, MB.Board, MB.Levels
local Arcade, Widgets, Scores, L = ns.Arcade, ns.Widgets, ns.Scores, ns.L

local KEY_TURN_SPEED = 1.9
local AIM_LEFT = { LEFT = true, A = true }
local AIM_RIGHT = { RIGHT = true, D = true }
local SHOOT = { SPACE = true, UP = true, W = true }
local SWAP = { DOWN = true, S = true, TAB = true }

local Module = {
    id = "murlocblast",
    nameKey = "MB_NAME",
    descKey = "MB_DESC",
    tile = "tiles/murlocblast",
    defaults = {
        difficulty = "normal",
        symbols = true,
        progress = {},
    },
}

function MB.Settings()
    return Arcade.Settings(Module)
end

local function DifficultyName(difficulty)
    return L[difficulty:upper()]
end

local function ShareMessage(entry, difficulty)
    return L.MB_SHARE:format(ns.FormatNumber(entry.score), entry.level, DifficultyName(difficulty))
end

function Module:Progress()
    local settings = MB.Settings()
    return settings.progress[settings.difficulty] or 1
end

function Module:BestScore()
    return Scores.Best(self.id, MB.Settings().difficulty)
end

function Module:Build(container)
    local field = Board:Create(container)
    field:SetPoint("TOPLEFT")
    self.field = field
    self.keysHeld = {}

    local game = Game.New()
    game.difficulty = MB.Settings().difficulty
    self.game = game
    Board:Attach(game)
    game.onEvent = function(name, data)
        Board:OnGameEvent(name, data)
        self:OnGameEvent(name, data)
    end

    field:EnableMouse(true)
    field:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then
            self:AimAtCursor()
            game:Shoot()
        elseif button == "RightButton" then
            game:Swap()
        end
    end)

    self.overlay = Widgets.NewOverlay(field)
    self:CreateMenuPage()
    self:CreatePausePage()
    self:CreateResultPages()
    Widgets.ScoresPage(self.overlay, Game.WIDTH, {
        gameId = self.id,
        buckets = Levels.DIFFICULTIES,
        bucketName = DifficultyName,
        detail = function(entry) return L.LEVEL:format(entry.level) end,
        shareMessage = ShareMessage,
        onBack = function() self.overlay:Show("menu") end,
    })
    self:ShowMenuBoard()
end

function Module:CreateMenuPage()
    local page = self.overlay:AddPage("menu")
    local title = Widgets.PageTitle(page, "MB_NAME", -48)
    local tagline = Widgets.LocalizedText(page, 14, "blue", "MB_TAGLINE")
    tagline:SetPoint("TOP", title, "BOTTOM", 0, -6)

    local diffLabel = Widgets.LocalizedText(page, 11, "gray", "DIFFICULTY")
    diffLabel:SetPoint("TOP", 0, -140)
    local diff = Widgets.Cycler(page, 200, function(dir)
        local settings = MB.Settings()
        settings.difficulty = Widgets.Cycle(Levels.DIFFICULTIES, settings.difficulty, dir)
        self.game.difficulty = settings.difficulty
        self:UpdateHud()
        page.refresh()
    end)
    diff:SetPoint("TOP", diffLabel, "BOTTOM", 0, -2)

    local newGame = Widgets.Button(page, 200, 26, "NEW_GAME", function() self:StartGame(1) end)
    local continue = Widgets.Button(page, 200, 26, nil, function() self:StartGame(self:Progress()) end)
    local scores = Widgets.Button(page, 200, 26, "HIGHSCORES", function()
        self.overlay:Show("scores", { bucket = MB.Settings().difficulty })
    end)
    Widgets.Stack(page, { newGame, continue, scores }, -196)
    Widgets.HelpText(page, "MB_HELP", Game.WIDTH - 30)

    page.refresh = function()
        diff.label:SetText(DifficultyName(MB.Settings().difficulty))
        local progress = self:Progress()
        continue:SetText(L.MB_CONTINUE:format(progress))
        continue:SetEnabled(progress > 1)
    end
end

function Module:CreatePausePage()
    local page = self.overlay:AddPage("pause")
    local title = Widgets.PageTitle(page, "PAUSED", -90)
    local landed = Widgets.Text(page, 14, "blue")
    landed:SetPoint("TOP", title, "BOTTOM", 0, -8)
    local resume = Widgets.Button(page, 200, 26, "RESUME", function() self:Resume() end)
    local menu = Widgets.Button(page, 200, 26, "MENU", function() self:AbandonRun() end)
    Widgets.Stack(page, { resume, menu }, -190)
    Widgets.HelpText(page, "MB_HELP", Game.WIDTH - 30)
    page.refresh = function(data)
        landed:SetText((data and data.landed) and L.LANDED or "")
    end
end

function Module:CreateResultPages()
    local clear = self.overlay:AddPage("clear")
    local clearTitle = Widgets.PageTitle(clear, "MB_LEVEL_CLEAR", -100)
    local bonus = Widgets.Text(clear, 16, "white")
    bonus:SetPoint("TOP", clearTitle, "BOTTOM", 0, -10)
    local clearScore = Widgets.Text(clear, 14, "gold")
    clearScore:SetPoint("TOP", bonus, "BOTTOM", 0, -8)
    local nextLevel = Widgets.Button(clear, 200, 26, "MB_NEXT_LEVEL", function() self:StartLevel(self.game.level + 1) end)
    local clearMenu = Widgets.Button(clear, 200, 26, "MENU", function() self:AbandonRun() end)
    Widgets.Stack(clear, { nextLevel, clearMenu }, -230)
    clear.refresh = function(data)
        bonus:SetText(L.MB_BONUS:format(ns.FormatNumber(data.bonus)))
        clearScore:SetText(L.FINAL_SCORE:format(ns.FormatNumber(self.game.score)))
    end

    local over = self.overlay:AddPage("over")
    local overTitle = Widgets.PageTitle(over, "GAME_OVER", -90)
    local final = Widgets.Text(over, 16, "white")
    final:SetPoint("TOP", overTitle, "BOTTOM", 0, -10)
    local record = Widgets.Text(over, 14, "gold")
    record:SetPoint("TOP", final, "BOTTOM", 0, -8)
    local share = Widgets.ShareRow(over, function()
        return self.lastEntry and ShareMessage(self.lastEntry, self.lastEntry.difficulty)
    end)
    share:SetPoint("TOP", 0, -190)
    local again = Widgets.Button(over, 200, 26, "AGAIN", function() self:StartGame(self.game.level) end)
    local overMenu = Widgets.Button(over, 200, 26, "MENU", function() self:ShowMenuBoard() end)
    Widgets.Stack(over, { again, overMenu }, -240)
    over.refresh = function(data)
        final:SetText(L.FINAL_SCORE:format(ns.FormatNumber(data.score)))
        record:SetText(data.rank == 1 and L.NEW_RECORD or "")
    end
end

-- Game flow ----------------------------------------------------------------------

function Module:ShowMenuBoard()
    local game = self.game
    game.state = "READY"
    game.drops = 0
    game.shot = nil
    game.score = 0
    game.level = 1
    game.difficulty = MB.Settings().difficulty
    Levels.Load(game.grid, 1, game.difficulty)
    Board:Reset()
    Board:SyncBoard()
    self:UpdateHud()
    self.overlay:Show("menu")
end

function Module:StartGame(level)
    self.game.difficulty = MB.Settings().difficulty
    self.game:StartLevel(level, false)
    self.overlay:Hide()
end

function Module:StartLevel(level)
    self.game:StartLevel(level, true)
    self.overlay:Hide()
end

function Module:RecordScore()
    local game = self.game
    self.lastEntry = { score = game.score, level = game.level, difficulty = game.difficulty }
    return Scores.Record(self.id, game.difficulty, { score = game.score, level = game.level })
end

-- Leaving a run early still counts towards the highscores.
function Module:AbandonRun()
    local state = self.game.state
    if self.game.score > 0 and (state == "PAUSED" or state == "CLEAR") then
        self:RecordScore()
    end
    self:ShowMenuBoard()
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

function Module:UpdateHud()
    local game = self.game
    ns.Window:SetHud(
        L.LEVEL:format(game.level) .. "  ·  " .. DifficultyName(game.difficulty),
        ns.FormatNumber(game.score),
        L.BEST:format(ns.FormatNumber(Scores.Best(self.id, game.difficulty))))
end

function Module:OnGameEvent(name, data)
    local game = self.game
    if name == "score" or name == "level" then
        self:UpdateHud()
    elseif name == "clear" then
        local settings = MB.Settings()
        settings.progress[game.difficulty] = math.max(self:Progress(), game.level + 1)
        C_Timer.After(1.2, function()
            if game.state == "CLEAR" then self.overlay:Show("clear", data) end
        end)
    elseif name == "over" then
        local rank = self:RecordScore()
        self:UpdateHud()
        C_Timer.After(1.1, function()
            if game.state == "OVER" then self.overlay:Show("over", { score = game.score, rank = rank }) end
        end)
    end
end

-- Arcade hooks -------------------------------------------------------------------

function Module:Enter()
    self:UpdateHud()
    self.overlay:Refresh()
end

function Module:Leave()
    wipe(self.keysHeld)
    self:Pause({})
end

function Module:RefreshTexts()
    Board:RefreshTexts()
    self.overlay:Refresh()
    self:UpdateHud()
end

function Module:OnKey(key)
    local game = self.game
    if key == "P" and (game.state == "PLAYING" or (game.state == "PAUSED" and self.overlay.current == "pause")) then
        if game.state == "PLAYING" then self:Pause({}) else self:Resume() end
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

function Module:OnKeyUp(key)
    self.keysHeld[key] = nil
end

function Module:AimAtCursor()
    local field = self.field
    local left, top = field:GetLeft(), field:GetTop()
    if not left then return end
    local scale = field:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    self.game:AimAt(cx / scale - left, top - cy / scale)
end

function Module:OnUpdate(dt)
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
end

function Module:DecorateTile(tile, art)
    local model = CreateFrame("PlayerModel", nil, tile)
    model:SetSize(84, 84)
    model:SetPoint("BOTTOMRIGHT", art, "BOTTOMRIGHT", 6, -4)
    pcall(model.SetCreature, model, 46)
    pcall(model.SetFacing, model, -0.5)
end

function Module:RegisterSettings(category, _, checkbox)
    checkbox(category, MB.Settings(), "symbols", L.MB_OPT_SYMBOLS, L.MB_OPT_SYMBOLS_TIP, true, function()
        if self.game then Board:SyncBoard() end
    end)
end

Arcade.RegisterGame(Module)
