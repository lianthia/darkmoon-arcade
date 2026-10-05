local _, ns = ...

local Game, Board, Levels, Media, L = ns.Game, ns.Board, ns.Levels, ns.Media, ns.L

local Window = {}
ns.Window = Window

local PAD = 14
local HEADER = 54
local KEY_TURN_SPEED = 1.9

local AIM_LEFT = { LEFT = true, A = true }
local AIM_RIGHT = { RIGHT = true, D = true }
local SHOOT = { SPACE = true, UP = true, W = true }
local SWAP = { DOWN = true, S = true, TAB = true }

local function GoldText(parent, size)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(Media.FONT, size, "OUTLINE")
    fs:SetTextColor(1, 0.82, 0.2)
    return fs
end

function Window:Create()
    local f = CreateFrame("Frame", "MurlocBlastFrame", UIParent, "BackdropTemplate")
    f:SetSize(Game.WIDTH + PAD * 2, Game.HEIGHT + PAD + HEADER)
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

    local header = f:CreateTexture(nil, "ARTWORK")
    header:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    header:SetSize(256, 64)
    header:SetPoint("TOP", 0, 12)
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", header, "TOP", 0, -14)
    title:SetText(L.TITLE)

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)

    self.levelText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.levelText:SetPoint("BOTTOMLEFT", f, "TOPLEFT", PAD + 2, -(HEADER - 6))
    self.scoreText = GoldText(f, 18)
    self.scoreText:SetPoint("BOTTOM", f, "TOP", 0, -(HEADER - 4))
    self.bestText = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    self.bestText:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", -(PAD + 2), -(HEADER - 6))

    local frameBorder = f:CreateTexture(nil, "BORDER")
    frameBorder:SetColorTexture(0, 0, 0, 0.85)
    frameBorder:SetPoint("TOPLEFT", PAD - 2, -(HEADER - 2))
    frameBorder:SetSize(Game.WIDTH + 4, Game.HEIGHT + 4)

    local field = Board:Create(f)
    field:SetPoint("TOPLEFT", PAD, -HEADER)
    self.field = field

    self:CreateOverlay()
    self:SetupInput()

    local game = Game.New()
    self.game = game
    Board:Attach(game)
    game.onEvent = function(name, data)
        Board:OnGameEvent(name, data)
        self:OnGameEvent(name, data)
    end
    self:ShowMenuBoard()

    f:SetScript("OnUpdate", function(_, elapsed) self:OnUpdate(math.min(elapsed, 0.05)) end)
    f:SetScript("OnHide", function() self:OnHidden() end)
    f:SetScript("OnShow", function() self:OnShown() end)
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

-- The menu shows the first level as a backdrop without starting a game.
function Window:ShowMenuBoard()
    local game = self.game
    game.state = "READY"
    game.drops = 0
    game.shot = nil
    Levels.Load(game.grid, 1)
    Board:Reset()
    Board:SyncBoard()
    self:UpdateHud()
    self:ShowOverlay("menu")
end

function Window:CreateOverlay()
    local o = CreateFrame("Frame", nil, self.field)
    o:SetAllPoints()
    o:SetFrameLevel(self.field:GetFrameLevel() + 20)
    o:EnableMouse(true)
    local shade = o:CreateTexture(nil, "BACKGROUND")
    shade:SetAllPoints()
    shade:SetColorTexture(0, 0.03, 0.06, 0.72)

    o.title = GoldText(o, 30)
    o.title:SetPoint("CENTER", 0, 92)
    o.subtitle = o:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    o.subtitle:SetPoint("TOP", o.title, "BOTTOM", 0, -8)
    o.info = o:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    o.info:SetPoint("TOP", o.subtitle, "BOTTOM", 0, -10)

    o.primary = CreateFrame("Button", nil, o, "UIPanelButtonTemplate")
    o.primary:SetSize(170, 26)
    o.primary:SetPoint("CENTER", 0, -6)
    o.secondary = CreateFrame("Button", nil, o, "UIPanelButtonTemplate")
    o.secondary:SetSize(170, 26)
    o.secondary:SetPoint("TOP", o.primary, "BOTTOM", 0, -8)

    o.help = o:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    o.help:SetPoint("BOTTOM", 0, 70)
    o.help:SetWidth(Game.WIDTH - 20)
    o.help:SetText(L.HELP)

    self.overlay = o
end

local function SetButton(button, text, onClick)
    if text then
        button:SetText(text)
        button:SetScript("OnClick", onClick)
        button:Show()
    else
        button:Hide()
    end
end

function Window:ShowOverlay(kind, data)
    local o, game, db = self.overlay, self.game, ns.db
    o.subtitle:SetText("")
    o.info:SetText("")
    o.help:Hide()
    if kind == "menu" then
        o.title:SetText(L.TITLE)
        o.subtitle:SetText(L.TAGLINE)
        o.help:Show()
        SetButton(o.primary, L.NEW_GAME, function() self:StartGame(1) end)
        if db.maxLevel > 1 then
            SetButton(o.secondary, L.CONTINUE:format(db.maxLevel), function() self:StartGame(db.maxLevel) end)
        else
            SetButton(o.secondary)
        end
    elseif kind == "pause" then
        o.title:SetText(L.PAUSED)
        if data and data.landed then o.subtitle:SetText(L.LANDED) end
        o.help:Show()
        SetButton(o.primary, L.RESUME, function() self:Resume() end)
        SetButton(o.secondary, L.MENU, function() self:ShowMenuBoard() end)
    elseif kind == "clear" then
        o.title:SetText(L.LEVEL_CLEAR)
        o.subtitle:SetText(L.BONUS:format(ns.FormatNumber(data.bonus)))
        o.info:SetText(L.FINAL_SCORE:format(ns.FormatNumber(game.score)))
        SetButton(o.primary, L.NEXT_LEVEL, function() self:StartLevel(game.level + 1) end)
        SetButton(o.secondary, L.MENU, function() self:ShowMenuBoard() end)
    elseif kind == "over" then
        o.title:SetText(L.GAME_OVER)
        o.subtitle:SetText(L.FINAL_SCORE:format(ns.FormatNumber(data.score)))
        if data.record then o.info:SetText(L.NEW_RECORD) end
        SetButton(o.primary, L.AGAIN, function() self:StartGame(game.level) end)
        SetButton(o.secondary, L.MENU, function() self:ShowMenuBoard() end)
    end
    o:Show()
end

function Window:HideOverlay()
    self.overlay:Hide()
end

function Window:StartGame(level)
    self.game:StartLevel(level, false)
    self:HideOverlay()
end

function Window:StartLevel(level)
    self.game:StartLevel(level, true)
    self:HideOverlay()
end

function Window:Pause(landed)
    if self.game.state == "PLAYING" then
        self.game:Pause()
        self:ShowOverlay("pause", { landed = landed })
    elseif landed and self.game.state == "PAUSED" then
        self:ShowOverlay("pause", { landed = true })
    end
end

function Window:Resume()
    self.game:Resume()
    self:HideOverlay()
end

function Window:UpdateHud()
    local game, db = self.game, ns.db
    self.levelText:SetText(L.LEVEL:format(game.level))
    self.scoreText:SetText(ns.FormatNumber(game.score))
    self.bestText:SetText(L.BEST:format(ns.FormatNumber(db.highscore)))
end

function Window:RecordScore()
    local db, game = ns.db, self.game
    if game.score > db.highscore then
        db.highscore = game.score
        return true
    end
    return false
end

function Window:OnGameEvent(name, data)
    local game, db = self.game, ns.db
    if name == "score" or name == "level" then
        self:UpdateHud()
    elseif name == "clear" then
        db.maxLevel = math.max(db.maxLevel, game.level + 1)
        self:RecordScore()
        self:UpdateHud()
        C_Timer.After(1.2, function()
            if game.state == "CLEAR" then self:ShowOverlay("clear", data) end
        end)
    elseif name == "over" then
        local record = self:RecordScore()
        self:UpdateHud()
        C_Timer.After(1.1, function()
            if game.state == "OVER" then
                self:ShowOverlay("over", { score = game.score, record = record })
            end
        end)
    end
end

-- Input ------------------------------------------------------------------

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
        local handled = self:OnKey(key, true)
        if not InCombatLockdown() then frame:SetPropagateKeyboardInput(not handled) end
    end)
    f:SetScript("OnKeyUp", function(_, key)
        self.keysHeld[key] = nil
    end)
end

function Window:OnKey(key, down)
    local game = self.game
    if key == "P" and (game.state == "PLAYING" or game.state == "PAUSED") then
        if game.state == "PLAYING" then self:Pause() else self:Resume() end
        return true
    end
    if game.state ~= "PLAYING" then return false end
    if AIM_LEFT[key] or AIM_RIGHT[key] then
        self.keysHeld[key] = down
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
end

function Window:OnShown()
    PlaySound(SOUNDKIT.IG_MAINMENU_OPEN)
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
