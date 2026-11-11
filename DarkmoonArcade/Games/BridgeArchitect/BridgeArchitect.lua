-- Goblin Bridge Architect: the game module (prototype). The field shows a gorge from the side: sky,
-- far hills, the rocks (client tilesets), the river and the bridge. In building mode beams are drawn
-- by dragging from a joint; in a test the physics (Physics.lua) runs and the vehicle, a client model
-- in a ModelScene, crosses. The toolbar, the top bar and the menus live in UI.lua.

local ADDON, ns = ...
local BA = ns.BridgeArchitect
local P = BA.Physics
local Arcade, Media, L = ns.Arcade, ns.Media, ns.L

local W, H = 920, 560
local FW, FH = P.W, P.H -- the field (the toolbar sits below it)
local GRID = P.GRID
BA.W, BA.H = W, H
local STEP = 1 / 60
local PPY = 20 -- pixels per yard in the vehicle's scene
local PITCH_SIGN = -1

local Module = {
    id = "bridgearchitect",
    rank = -1,
    fullArea = true,
    fieldWidth = W,
    fieldHeight = H,
    nameKey = "GBA_NAME",
    descKey = "GBA_DESC",
    genreKey = "GBA_GENRE",
    taglineKey = "GBA_CARD_TEXT",
    helpKey = "GBA_HELP",
    tile = "tiles/bridgearchitect",
    -- The launcher's spotlight: the teaser art (media/launcher/bridgearchitect, 910x512 of 1024x512).
    -- Before Mercenaries in the order (rank), so it takes the spotlight wherever it is registered.
    featured = true,
    spotlight = {
        art = "launcher/bridgearchitect",
        banner = { 0.0407, 0.8480, 0, 1 },
        card = { 0, 0.8887, 0.0545, 0.9455 },
        titleSize = 32,
    },
    updated = "1.6.0",
    defaults = { best = {}, builds = {}, level = 1, tests = 0, broken = 0 },
}
BA.Module = Module

function Module:Store()
    local s = Arcade.Settings(self)
    s.best, s.builds = s.best or {}, s.builds or {}
    return s
end

local function Tex(name) return Media.Tex("bridge/" .. name) end
BA.Tex = Tex

-- Sounds: client files, played at most every `gap` seconds per kind.
local SFX = {
    wood = { 565846, 565682 },
    steel = { 565339, 566071 },
    rope = { 565321, 565322 },
    splash = { 540232, 540233 },
    lava = { 568315, 568733 },
    cheer = { 541890, 542010 },
    laugh = { 541902 },
}
local lastSound = {}
function BA.Play(kind, gap)
    local ids = SFX[kind]
    if not ids or (ns.db and not ns.db.sound) then return end
    local now = GetTime()
    if lastSound[kind] and now - lastSound[kind] < (gap or 0.1) then return end
    lastSound[kind] = now
    PlaySoundFile(ids[math.random(#ids)], "SFX")
end

function BA.UiSound(kit)
    if ns.db and not ns.db.sound then return end
    if kit then pcall(PlaySound, kit, "SFX") end
end

-- Building ---------------------------------------------------------------------------------------------

function Module:Build(container)
    self.container = container
    local bg = container:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.05, 0.04, 0.04, 1)
    self.realClock = 0
    self.material = "road"
    self:BuildField(container)
    self:BuildInput()
    self:BuildBars(container)
    self:BuildMenus(container)
    self:ShowMenu()
end

function Module:BuildField(container)
    local f = CreateFrame("Frame", nil, container)
    f:SetSize(FW, FH)
    f:SetPoint("TOPLEFT")
    f:SetClipsChildren(true)
    self.field = f
    local base = f:GetFrameLevel()
    local function Layer(offset)
        local l = CreateFrame("Frame", nil, f)
        l:SetAllPoints()
        l:SetFrameLevel(base + offset)
        return l
    end
    self.backLayer = Layer(1)   -- sky, hills, rocks, river
    self.beamLayer = Layer(3)   -- the bridge (flyers far away at 2, the vehicle at 5)
    self.weatherLayer = Layer(6) -- snow, rain, embers in front of it all
    self.fxLayer = Layer(8)     -- splinters, coins, labels
    self.hudLayer = Layer(10)   -- messages over the field

    local back = self.backLayer
    self.sky = back:CreateTexture(nil, "BACKGROUND", nil, -8)
    self.sky:SetAllPoints()
    self.horizon = back:CreateTexture(nil, "BACKGROUND", nil, -7)
    self.horizon:SetPoint("BOTTOMLEFT", 0, FH - 460)
    self.horizon:SetPoint("BOTTOMRIGHT", 0, FH - 460)
    self.horizon:SetHeight(360)
    self.horizon:SetTexture(Tex("gradient"))
    self.stars = back:CreateTexture(nil, "BACKGROUND", nil, -6)
    self.stars:SetAllPoints()
    self.stars:SetTexture(Tex("stars"), "REPEAT", "REPEAT")
    self.stars:SetTexCoord(0, FW / 256, 0, FH / 256)
    self.stars:SetBlendMode("ADD")
    self.hills = back:CreateTexture(nil, "BACKGROUND", nil, -3)
    -- Far mesas behind the gorge, faded into the haze (without the art's sandy foot).
    self.hills:SetPoint("BOTTOMLEFT", 0, FH - 330)
    self.hills:SetPoint("BOTTOMRIGHT", 0, FH - 330)
    self.hills:SetHeight(150)
    self.hills:SetTexture(Media.Tex("flappy/mountains_desert"), "REPEAT", "CLAMP")
    self.hills:SetTexCoord(0, 1.6, 0, 0.74)
    -- The far wall of the gorge, dark, behind the rocks.
    self.backWall = back:CreateTexture(nil, "BACKGROUND", nil, -2)
    self.backWallShade = back:CreateTexture(nil, "BACKGROUND", nil, -1)
    self.backWallShade:SetTexture(Tex("gradient"))
    self.water = back:CreateTexture(nil, "BORDER", nil, 0)
    self.ripples = back:CreateTexture(nil, "BORDER", nil, 1)
    self.ripples:SetTexture(Tex("ripples"), "REPEAT", "REPEAT")
    self.waterShade = back:CreateTexture(nil, "BORDER", nil, 2)
    self.waterShade:SetTexture(Tex("gradient"))
    self.rocks, self.cranes = {}, {}
    self.grid = back:CreateTexture(nil, "OVERLAY", nil, 0)
    self.grid:SetAllPoints()
    self.grid:SetTexture(Tex("grid"), "REPEAT", "REPEAT")
    self.grid:SetTexCoord(0, FW / GRID, 0, FH / GRID)
    self.grid:SetVertexColor(1, 1, 1, 0.35)
    self.goalFlag = back:CreateTexture(nil, "OVERLAY", nil, 2)
    self.goalFlag:SetTexture(Tex("flag"))
    self.goalFlag:SetSize(32, 48)

    -- The vehicle: a client model in a side-on scene, or its portrait where there are no scenes.
    local ok, scene = pcall(CreateFrame, "ModelScene", nil, f)
    if ok and scene and scene.CreateActor then
        scene:SetAllPoints()
        scene:SetFrameLevel(base + 5)
        if scene.EnableMouse then scene:EnableMouse(false) end
        self.scene = scene
        self:SetupCamera(scene)
        self.actor = scene:CreateActor()
        self.actor:Hide()
    end
    self.token = self.fxLayer:CreateTexture(nil, "ARTWORK")
    self.token:SetSize(40, 40)
    self.token:Hide()

    -- Pools.
    local beamLayer, fx = self.beamLayer, self.fxLayer
    self.beamPool = Media.Pool(function()
        local l = beamLayer:CreateLine(nil, "ARTWORK")
        return l
    end, function(l)
        l:Hide()
        l:SetVertexColor(1, 1, 1, 1)
    end)
    -- Every beam casts a soft shadow onto the gorge's far wall.
    self.shadowPool = Media.Pool(function()
        local l = beamLayer:CreateLine(nil, "BACKGROUND", nil, 1)
        l:SetColorTexture(0, 0, 0, 1)
        return l
    end, function(l) l:Hide() end)
    self.jointPool = Media.Pool(function()
        local t = beamLayer:CreateTexture(nil, "OVERLAY")
        return t
    end, function(t) t:Hide() end)
    self.fxPool = Media.Pool(function() return fx:CreateTexture(nil, "ARTWORK") end, function(t)
        t:Hide()
        t:SetAlpha(1)
        t:SetVertexColor(1, 1, 1, 1)
        t:SetBlendMode("BLEND")
        if t.SetRotation then t:SetRotation(0) end
    end)
    self.preview = beamLayer:CreateLine(nil, "OVERLAY", nil, 2)
    self.preview:Hide()
    self.previewJoint = beamLayer:CreateTexture(nil, "OVERLAY", nil, 3)
    self.previewJoint:SetTexture(Tex("joint"))
    self.previewJoint:SetSize(12, 12)
    self.previewJoint:Hide()
    self.reach = beamLayer:CreateTexture(nil, "BACKGROUND")
    self.reach:SetTexture(Media.Tex("ring"))
    self.reach:Hide()
    self.hoverRing = beamLayer:CreateTexture(nil, "OVERLAY", nil, 4)
    self.hoverRing:SetTexture(Media.Tex("glow"))
    self.hoverRing:SetBlendMode("ADD")
    self.hoverRing:SetSize(30, 30)
    self.hoverRing:Hide()
    self.label = fx:CreateFontString(nil, "OVERLAY")
    self.label:SetFont(Media.FontFile(), 11, "OUTLINE")
    self.label:Hide()
    self.beamVis, self.shadowVis, self.jointVis, self.effects = {}, {}, {}, {}
    self:BuildAmbience(f, back, self.weatherLayer, base)
end

function Module:BuildInput()
    local input = CreateFrame("Frame", nil, self.field)
    input:SetAllPoints()
    input:SetFrameLevel(self.field:GetFrameLevel() + 9)
    input:EnableMouse(true)
    input:SetScript("OnMouseDown", function(_, button) self:OnFieldDown(button) end)
    input:SetScript("OnMouseUp", function(_, button) self:OnFieldUp(button) end)
    self.input = input
end

-- The cursor in field pixels, or nil when it is off the field.
function Module:Cursor()
    local f = self.field
    if not f:IsMouseOver() then return nil end
    local scale = f:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    local left, top = f:GetLeft(), f:GetTop()
    if not left or not top then return nil end
    return cx / scale - left, top - cy / scale
end

-- Drawing the level -------------------------------------------------------------------------------------

local function PlaceRect(t, layer, l, top, r, b)
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", layer, "TOPLEFT", l, -top)
    t:SetPoint("BOTTOMRIGHT", layer, "TOPLEFT", r, -b)
end

function Module:DrawLevel()
    local level = self.level
    local zone = BA.ZONES[level.zone]
    local back = self.backLayer
    local zenith, horizon = zone.sky[2], zone.sky[1]
    self.sky:SetColorTexture(zenith[1], zenith[2], zenith[3], 1)
    self.horizon:SetVertexColor(horizon[1], horizon[2], horizon[3], 1)
    -- Mixed towards the horizon's colour: far away.
    -- Grey first, then the zone's own haze: snowy hills in Winterspring, dark ones at night.
    self.hills:SetDesaturated(true)
    local function Haze(i) return math.min(1, (zone.far[i] + horizon[i]) / 2 * 1.35) end
    self.hills:SetVertexColor(Haze(1), Haze(2), Haze(3), 0.85)
    local wy = level.water
    local wc = zone.water
    local wallTop = 330
    PlaceRect(self.backWall, back, 0, wallTop, FW, wy)
    self.backWall:SetTexture(zone.rock, "REPEAT", "REPEAT")
    self.backWall:SetTexCoord(0, FW / 160, wallTop / 160, wy / 160)
    self.backWall:SetVertexColor(zone.tint[1] * 0.42, zone.tint[2] * 0.38, zone.tint[3] * 0.4)
    PlaceRect(self.backWallShade, back, 0, wallTop, FW, wy)
    self.backWallShade:SetVertexColor(0, 0, 0, 0.6)
    PlaceRect(self.water, back, 0, wy, FW, FH)
    if zone.lava then
        -- Lava: the client's own, glowing, the ripples bright.
        self.water:SetTexture(zone.lava, "REPEAT", "REPEAT")
        self.water:SetTexCoord(0, FW / 128, 0, (FH - wy) / 128)
        self.water:SetVertexColor(1, 0.75, 0.55)
    else
        self.water:SetColorTexture(wc[1], wc[2], wc[3], 1)
    end
    self.stars:SetShown(zone.stars and true or false)
    self.stars:SetAlpha(0.8)
    PlaceRect(self.ripples, back, 0, wy, FW, FH)
    if zone.lava then
        self.ripples:SetVertexColor(1, 0.7, 0.25, 0.9)
        self.ripples:SetBlendMode("ADD")
    else
        self.ripples:SetVertexColor(0.8, 0.95, 1, 0.8)
        self.ripples:SetBlendMode("BLEND")
    end
    PlaceRect(self.waterShade, back, 0, wy, FW, FH)
    self.waterShade:SetVertexColor(0, 0.04, 0.08, 0.7)
    -- Rocks: the tileset's rock, its ground on top, shaded at the edges and towards the water.
    for _, r in ipairs(self.rocks) do
        for _, t in pairs(r) do t:Hide() end
    end
    for i, rect in ipairs(level.terrain) do
        local r = self.rocks[i]
        if not r then
            r = {
                body = back:CreateTexture(nil, "ARTWORK", nil, 0),
                top = back:CreateTexture(nil, "ARTWORK", nil, 1),
                lip = back:CreateTexture(nil, "ARTWORK", nil, 2),
                shade = back:CreateTexture(nil, "ARTWORK", nil, 3),
                edgeL = back:CreateTexture(nil, "ARTWORK", nil, 3),
                edgeR = back:CreateTexture(nil, "ARTWORK", nil, 3),
            }
            self.rocks[i] = r
        end
        local l, rt, top = math.max(rect[1], 0), math.min(rect[2], FW), rect[3]
        local w, h = rt - l, FH - top
        PlaceRect(r.body, back, l, top, rt, FH)
        r.body:SetTexture(zone.rock, "REPEAT", "REPEAT")
        r.body:SetTexCoord(l / 128, rt / 128, top / 128, FH / 128)
        r.body:SetVertexColor(zone.tint[1] * 0.8, zone.tint[2] * 0.75, zone.tint[3] * 0.72)
        PlaceRect(r.top, back, l, top - 4, rt, top + 10)
        r.top:SetTexture(zone.top, "REPEAT", "REPEAT")
        r.top:SetTexCoord(l / 64, rt / 64, 0, 14 / 64)
        r.top:SetVertexColor(zone.tint[1], zone.tint[2], zone.tint[3])
        PlaceRect(r.lip, back, l, top + 10, rt, top + 14)
        r.lip:SetColorTexture(0, 0, 0, 0.35)
        PlaceRect(r.shade, back, l, top + 14, rt, FH)
        r.shade:SetTexture(Tex("gradient"))
        r.shade:SetVertexColor(0, 0, 0, 0.55)
        PlaceRect(r.edgeL, back, l, top, l + 6, FH)
        r.edgeL:SetColorTexture(0, 0, 0, rect[1] > 0 and 0.3 or 0)
        PlaceRect(r.edgeR, back, rt - 6, top, rt, FH)
        r.edgeR:SetColorTexture(0, 0, 0, rect[2] < FW and 0.3 or 0)
        for _, t in pairs(r) do t:Show() end
        local _ = w + h
    end
    -- Cranes standing on the rocks, their hooks are anchors.
    for _, c in ipairs(self.cranes) do c:Hide() end
    for i, hook in ipairs(level.cranes or {}) do
        local c = self.cranes[i]
        if not c then
            c = back:CreateTexture(nil, "ARTWORK", nil, 4)
            c:SetTexture(Tex("crane"))
            self.cranes[i] = c
        end
        local left = hook[1] < FW / 2
        local ground = level.start[2]
        -- The crane image: 128 x 256, hook at about (117, 28). Mirrored for the left side's hook to
        -- point inwards from the mast standing further out.
        local scale = (ground - hook[2] + 28) / 256
        local w, h = 128 * scale, 256 * scale
        local hx, hy = 117 * scale, 28 * scale
        c:ClearAllPoints()
        if left then
            c:SetTexCoord(0, 1, 0, 1)
            c:SetPoint("TOPLEFT", back, "TOPLEFT", hook[1] - hx, -(hook[2] - hy))
        else
            c:SetTexCoord(1, 0, 0, 1)
            c:SetPoint("TOPLEFT", back, "TOPLEFT", hook[1] - (w - hx), -(hook[2] - hy))
        end
        c:SetSize(w, h)
        c:Show()
    end
    self.goalFlag:ClearAllPoints()
    local goalTop = level.start[2]
    for _, rect in ipairs(level.terrain) do
        if level.goal >= rect[1] and level.goal <= rect[2] then goalTop = rect[3] end
    end
    self.goalFlag:SetPoint("BOTTOMLEFT", back, "TOPLEFT", level.goal, -goalTop - 2)
    self:SetAmbience(level.zone)
end

-- The bridge ---------------------------------------------------------------------------------------------

local BEAM_LOOK = {
    road = { tex = "beam_road", width = 9 },
    wood = { tex = "beam_wood", width = 6 },
    steel = { tex = "beam_steel", width = 7 },
    rope = { tex = "beam_rope", width = 3 },
}
BA.BEAM_LOOK = BEAM_LOOK

local function SetLine(l, layer, x1, y1, x2, y2)
    l:SetStartPoint("TOPLEFT", layer, x1, -y1)
    l:SetEndPoint("TOPLEFT", layer, x2, -y2)
end

-- Load colour: the material's own look, warming to yellow and red.
local function LoadColor(load)
    if load < 0.2 then return 1, 1, 1 end
    if load < 0.6 then
        local f = (load - 0.2) / 0.4
        return 1, 1, 1 - 0.75 * f
    end
    local f = math.min(1, (load - 0.6) / 0.4)
    return 1, 1 - 0.8 * f, 0.25 - 0.2 * f
end

-- Builds the beam and joint visuals for the current bridge (building) or simulation (testing).
function Module:SyncBridge()
    local nodes, beams
    local s = self.sim
    if s then
        nodes, beams = s.nodes, s.beams
    else
        nodes, beams = self.build.nodes, self.build.beams
    end
    local layer = self.beamLayer
    -- Frame beams first, roads on top.
    local order = {}
    for i, beam in ipairs(beams) do
        if not BA.MATERIALS[beam.mat].road then order[#order + 1] = i end
    end
    for i, beam in ipairs(beams) do
        if BA.MATERIALS[beam.mat].road then order[#order + 1] = i end
    end
    local n = 0
    for _, i in ipairs(order) do
        local beam = beams[i]
        if not beam.broken then
            n = n + 1
            local l = self.beamVis[n]
            if not l then
                l = self.beamPool.Acquire()
                self.beamVis[n] = l
            end
            local look = BEAM_LOOK[beam.mat]
            local a, b = nodes[beam.a], nodes[beam.b]
            local sh = self.shadowVis[n]
            if not sh then
                sh = self.shadowPool.Acquire()
                self.shadowVis[n] = sh
            end
            sh:SetThickness(look.width * 0.8)
            SetLine(sh, layer, a.x + 4, a.y + 6, b.x + 4, b.y + 6)
            sh:SetAlpha(0.22)
            sh:Show()
            l:SetTexture(Tex(look.tex))
            l:SetThickness(look.width)
            SetLine(l, layer, a.x, a.y, b.x, b.y)
            local hot = self.hoverBeam == i and not s
            if s then
                l:SetVertexColor(LoadColor(beam.load or 0))
            elseif hot then
                l:SetVertexColor(1, 0.45, 0.4)
            else
                l:SetVertexColor(1, 1, 1)
            end
            -- A road over a frame beam: drawn on its own layer above.
            l:SetDrawLayer("ARTWORK", BA.MATERIALS[beam.mat].road and 2 or 0)
            l:Show()
        end
    end
    for i = n + 1, #self.beamVis do
        self.beamPool.Release(self.beamVis[i])
        self.beamVis[i] = nil
    end
    for i = n + 1, #self.shadowVis do
        self.shadowPool.Release(self.shadowVis[i])
        self.shadowVis[i] = nil
    end
    -- Joints: bolts, anchors in gold.
    local used = {}
    for _, beam in ipairs(beams) do
        if not beam.broken then used[beam.a], used[beam.b] = true, true end
    end
    local j = 0
    for i, node in ipairs(nodes) do
        if node.anchor or used[i] or not s then
            j = j + 1
            local t = self.jointVis[j]
            if not t then
                t = self.jointPool.Acquire()
                self.jointVis[j] = t
            end
            t:SetTexture(Tex(node.anchor and "anchor" or "joint"))
            local size = node.anchor and 13 or 9
            t:SetSize(size, size)
            t:ClearAllPoints()
            t:SetPoint("CENTER", layer, "TOPLEFT", node.x, -node.y)
            t:Show()
        end
    end
    for i = j + 1, #self.jointVis do
        self.jointPool.Release(self.jointVis[i])
        self.jointVis[i] = nil
    end
end

-- The vehicle -------------------------------------------------------------------------------------------

function Module:SetupVehicle()
    local v = BA.VEHICLES[self.level.vehicle]
    self.vehicleDef = v
    local a = self.actor
    if a then
        if pcall(a.SetModelByCreatureDisplayID, a, v.display) then
            -- Scaled to its length on the field (px), from the model's own size (yards).
            self.vehicleScale = v.px / PPY / v.len
            pcall(a.SetScale, a, self.vehicleScale)
            pcall(a.SetYaw, a, -math.pi / 2)
            a:Show()
            self.token:Hide()
            return
        end
        a:Hide()
    end
    if SetPortraitTextureFromCreatureDisplayID then SetPortraitTextureFromCreatureDisplayID(self.token, v.display) end
    self.token:Show()
end

-- Puts the vehicle on the field: centre x, wheel-contact y, tilt (nose up positive).
function Module:PlaceVehicle(x, y, tilt, moving)
    local v = self.vehicleDef
    local a = self.actor
    if a and a:IsShown() then
        local s = self.vehicleScale or 1
        -- Shift the model so the middle of its body sits between the wheels.
        local off = v.cx * s * PPY
        local px = x - off * math.cos(tilt)
        local py = y + off * math.sin(tilt)
        local wy, wz = -(px - FW / 2) / PPY, -(py - FH / 2) / PPY
        pcall(a.SetPosition, a, 0, wy / s, wz / s)
        pcall(a.SetPitch, a, PITCH_SIGN * tilt)
        local anim = moving and 4 or 0
        if a.anim ~= anim then
            a.anim = anim
            pcall(a.SetAnimation, a, anim, 0, 1)
        end
    else
        self.token:ClearAllPoints()
        self.token:SetPoint("BOTTOM", self.fxLayer, "TOPLEFT", x, -y)
    end
end

function Module:VehicleAtStart()
    local level = self.level
    self:PlaceVehicle(level.start[1], level.start[2], 0, false)
end

-- Levels ----------------------------------------------------------------------------------------------

function Module:StartLevel(index)
    local level = BA.LEVELS[index]
    if not level then return end
    local store = self:Store()
    store.level = index
    self.level = level
    self:StopTest(true)
    self.build = P.Deserialize(store.builds[level.id], level)
    self.undo = {}
    self.clearArmed = nil
    self.result = nil
    -- The first material the level offers.
    self.material = level.materials[1]
    self:DrawLevel()
    self:SetupVehicle()
    self:VehicleAtStart()
    self:SyncBridge()
    self.overlay:Hide()
    self.topBar:Show()
    self.toolBar:Show()
    self:HideResult()
    self:ShowForeman(L["GBA_LI_" .. level.id])
    self:RefreshBars()
end

function Module:SaveBuild()
    if not (self.level and self.build) then return end
    self:Store().builds[self.level.id] = P.Serialize(self.build)
end

function Module:PushUndo()
    local u = self.undo
    u[#u + 1] = P.Serialize(self.build)
    if #u > 60 then table.remove(u, 1) end
end

function Module:Undo()
    if self.sim then return end
    local data = table.remove(self.undo)
    if not data then return end
    self.build = P.Deserialize(data, self.level)
    BA.UiSound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
    self:Changed()
end

function Module:Clear()
    if self.sim or #self.build.beams == 0 then return end
    if not self.clearArmed or self.realClock - self.clearArmed > 3 then
        self.clearArmed = self.realClock
        self:RefreshBars()
        return
    end
    self.clearArmed = nil
    self:PushUndo()
    self.build = P.NewBuild(self.level)
    self:Changed()
end

function Module:Changed()
    self:SaveBuild()
    self:SyncBridge()
    self:RefreshBars()
end

function Module:SetMaterial(mat)
    if not (self.level and tContains(self.level.materials, mat)) then return end
    self.material = mat
    self.erasing = false
    BA.UiSound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    self:RefreshBars()
end

function Module:ToggleErase()
    self.erasing = not self.erasing
    BA.UiSound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    self:RefreshBars()
end

-- Building with the mouse ------------------------------------------------------------------------------

function Module:OnFieldDown(button)
    if not self.level or self.overlay.current then return end
    local x, y = self:Cursor()
    if not x then return end
    if self.sim then return end
    self:HideForeman()
    if button == "RightButton" then
        if self.dragFrom then
            self.dragFrom = nil
            return
        end
        self:RemoveAt(x, y)
        return
    end
    if self.erasing then
        self:RemoveAt(x, y)
        return
    end
    local node = P.NodeAt(self.build, x, y, 11)
    if node then
        self.dragFrom = node
        self:HideForeman()
    else
        self:Hint(L.GBA_HINT_DRAG, x, y)
    end
end

function Module:OnFieldUp(button)
    if button ~= "LeftButton" or not self.dragFrom then return end
    local from = self.dragFrom
    self.dragFrom = nil
    local x, y = self:Cursor()
    if not x or self.sim then return end
    local ex, ey = P.EndPoint(self.build, from, x, y, self.material)
    local n = self.build.nodes[from]
    if ex == n.x and ey == n.y then return end
    local before = P.Serialize(self.build)
    local k, why = P.AddBeam(self.build, self.level, from, ex, ey, self.material)
    if k then
        local u = self.undo
        u[#u + 1] = before
        BA.UiSound(SOUNDKIT.IG_ABILITY_ICON_DROP or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        self:Changed()
    elseif why and why ~= "exists" then
        BA.UiSound(SOUNDKIT.IG_QUEST_LOG_ABANDON_QUEST)
        if L["GBA_WHY_" .. why] then self:Hint(L["GBA_WHY_" .. why], ex, ey) end
    end
end

function Module:RemoveAt(x, y)
    local k = P.BeamAt(self.build, x, y, 7)
    if not k then return end
    self:PushUndo()
    P.RemoveBeam(self.build, k)
    self.hoverBeam = nil
    BA.UiSound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
    self:Changed()
end

-- A short text at the cursor that fades.
function Module:Hint(text, x, y)
    local fs = self.hint
    if not fs then
        fs = self.hudLayer:CreateFontString(nil, "OVERLAY")
        fs:SetFont(Media.FontFile(), 12, "OUTLINE")
        fs:SetTextColor(1, 0.85, 0.5)
        self.hint = fs
    end
    fs:SetText(text)
    fs:ClearAllPoints()
    fs:SetPoint("BOTTOM", self.hudLayer, "TOPLEFT", math.max(140, math.min(FW - 140, x)), -(y - 14))
    fs:Show()
    self.hintTime = 0
end

-- Hover, the beam being drawn and its price.
function Module:UpdateEditor()
    local x, y = self:Cursor()
    local build = self.build
    local preview, label, joint = self.preview, self.label, self.previewJoint
    preview:Hide()
    label:Hide()
    joint:Hide()
    self.hoverRing:Hide()
    self.reach:Hide()
    local hoverBeam
    if x and not self.overlay.current then
        if self.dragFrom then
            local n = build.nodes[self.dragFrom]
            local ex, ey = P.EndPoint(build, self.dragFrom, x, y, self.material)
            local look = BEAM_LOOK[self.material]
            local len = math.sqrt((ex - n.x) ^ 2 + (ey - n.y) ^ 2)
            local ok = len >= GRID * 0.9 and (P.NodeAt(build, ex, ey, 1) or P.CanStand(self.level, ex, ey))
            preview:SetTexture(Tex(look.tex))
            preview:SetThickness(look.width)
            SetLine(preview, self.beamLayer, n.x, n.y, ex, ey)
            if ok then preview:SetVertexColor(0.75, 1, 0.75, 0.9) else preview:SetVertexColor(1, 0.35, 0.3, 0.9) end
            preview:Show()
            local reach = BA.MATERIALS[self.material].maxLen * GRID * 2
            self.reach:ClearAllPoints()
            self.reach:SetPoint("CENTER", self.beamLayer, "TOPLEFT", n.x, -n.y)
            self.reach:SetSize(reach, reach)
            self.reach:SetVertexColor(1, 0.9, 0.6, 0.35)
            self.reach:Show()
            joint:ClearAllPoints()
            joint:SetPoint("CENTER", self.beamLayer, "TOPLEFT", ex, -ey)
            joint:Show()
            label:SetText(L.GBA_LEN:format(len / GRID, math.floor(P.BeamCost(len, self.material) + 0.5)))
            label:ClearAllPoints()
            label:SetPoint("BOTTOM", self.fxLayer, "TOPLEFT", (n.x + ex) / 2, -((n.y + ey) / 2 - 10))
            label:SetTextColor(ok and 1 or 1, ok and 0.92 or 0.45, ok and 0.7 or 0.4)
            label:Show()
        else
            local node = not self.erasing and P.NodeAt(build, x, y, 11)
            if node then
                local n = build.nodes[node]
                self.hoverRing:ClearAllPoints()
                self.hoverRing:SetPoint("CENTER", self.beamLayer, "TOPLEFT", n.x, -n.y)
                self.hoverRing:SetVertexColor(1, 0.85, 0.4, 0.8)
                self.hoverRing:Show()
            else
                hoverBeam = P.BeamAt(build, x, y, 7)
                if hoverBeam then
                    local beam = build.beams[hoverBeam]
                    local len = P.BeamLength(build, beam)
                    label:SetText(L["GBA_MAT_" .. beam.mat] .. " · " .. L.GBA_LEN:format(len / GRID,
                        math.floor(P.BeamCost(len, beam.mat) + 0.5)) .. "\n" .. L.GBA_REMOVE_HINT)
                    label:ClearAllPoints()
                    label:SetPoint("BOTTOM", self.fxLayer, "TOPLEFT", x, -(y - 12))
                    label:SetTextColor(1, 0.75, 0.6)
                    label:Show()
                end
            end
        end
    end
    if hoverBeam ~= self.hoverBeam then
        self.hoverBeam = hoverBeam
        self:SyncBridge()
    end
end

-- Testing -------------------------------------------------------------------------------------------------

function Module:StartTest()
    if self.sim or not self.level or self.overlay.current then return end
    self:HideForeman()
    self.dragFrom = nil
    self.hoverBeam = nil
    self.sim = P.NewSim(self.build, self.level)
    self.simTime, self.acc = 0, 0
    self.cost = P.Cost(self.build)
    local store = self:Store()
    store.tests = (store.tests or 0) + 1
    self.grid:Hide()
    self.preview:Hide()
    self.label:Hide()
    self.previewJoint:Hide()
    self.hoverRing:Hide()
    BA.UiSound(SOUNDKIT.IG_QUEST_LIST_OPEN)
    self:SyncBridge()
    self:RefreshBars()
end

function Module:ToggleFast()
    self.fast = not self.fast
    BA.UiSound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    self:RefreshBars()
end

function Module:StopTest(silent)
    if not self.sim then return end
    self.sim = nil
    self:ClearEffects()
    self.grid:Show()
    self:HideResult()
    if self.level then
        self:VehicleAtStart()
        self:SyncBridge()
    end
    if not silent then BA.UiSound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF) end
    self:RefreshBars()
end

function Module:UpdateTest(dt)
    local s = self.sim
    self.acc = self.acc + dt * (self.fast and 2 or 1)
    local steps = 0
    while self.acc >= STEP and steps < 8 do
        P.Step(s, STEP)
        self.acc = self.acc - STEP
        steps = steps + 1
    end
    if self.acc > STEP then self.acc = 0 end
    for _, e in ipairs(s.events) do
        local handler = self["On_" .. e.type]
        if handler then handler(self, e) end
    end
    s.events = {}
    local x, y, tilt = P.VehiclePose(s)
    local r = s.vehicle.radius
    self:PlaceVehicle(x, y + r, tilt, not s.result and s.t > 0.6)
    self:SyncBridge()
end

function Module:On_break(e)
    local store = self:Store()
    store.broken = (store.broken or 0) + 1
    local color = BA.MATERIALS[e.mat].color
    for _ = 1, e.mat == "rope" and 3 or 6 do
        local t = self.fxPool.Acquire()
        t:SetTexture(Tex("splinter"))
        t:SetVertexColor(color[1], color[2], color[3])
        t:SetSize(10, 5)
        t:Show()
        local vx, vy = (math.random() - 0.5) * 160, -60 - math.random() * 120
        local px, py, spin, rot = e.x, e.y, (math.random() - 0.5) * 16, math.random() * 6
        self:AddEffect(1.1, function(p, dt)
            vy = vy + 420 * dt
            px, py, rot = px + vx * dt, py + vy * dt, rot + spin * dt
            t:ClearAllPoints()
            t:SetPoint("CENTER", self.fxLayer, "TOPLEFT", px, -py)
            if t.SetRotation then t:SetRotation(rot) end
            t:SetAlpha(1 - p * p)
        end, function() self.fxPool.Release(t) end)
    end
    self:Flash(e.x, e.y, 34, { 1, 0.85, 0.55 }, 0.25)
    BA.Play(e.mat == "steel" and "steel" or e.mat == "rope" and "rope" or "wood", 0.08)
end

function Module:On_won()
    local s = self.sim
    local x, y = P.VehiclePose(s)
    -- Gold coins pop out of the vehicle.
    for _ = 1, 14 do
        local t = self.fxPool.Acquire()
        t:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
        t:SetSize(12, 12)
        t:Show()
        local vx, vy = (math.random() - 0.5) * 220, -140 - math.random() * 160
        local px, py = x, y - 20
        self:AddEffect(1.4, function(p, dt)
            vy = vy + 380 * dt
            px, py = px + vx * dt, py + vy * dt
            t:ClearAllPoints()
            t:SetPoint("CENTER", self.fxLayer, "TOPLEFT", px, -py)
            t:SetAlpha(p < 0.7 and 1 or 1 - (p - 0.7) / 0.3)
        end, function() self.fxPool.Release(t) end)
    end
    BA.Play("cheer")
    self:Finish(true)
end

function Module:On_lost(e)
    if e.why == "water" then
        local s = self.sim
        local x = P.VehiclePose(s)
        local lava = BA.ZONES[self.level.zone].lava
        self:Splash(x, self.level.water, lava)
        BA.Play(lava and "lava" or "splash")
        if lava then e.why = "lava" end
    end
    self:Finish(false, e.why)
end

function Module:Splash(x, y, lava)
    for i = 1, 3 do
        local t = self.fxPool.Acquire()
        t:SetTexture(Media.Tex("glow"))
        t:SetBlendMode("ADD")
        if lava then t:SetVertexColor(1, 0.5, 0.1) else t:SetVertexColor(0.75, 0.9, 1) end
        t:Show()
        self:AddEffect(0.6 + i * 0.15, function(p)
            local s = 30 + 90 * p * i / 2
            t:ClearAllPoints()
            t:SetPoint("CENTER", self.fxLayer, "TOPLEFT", x, -(y - 6))
            t:SetSize(s, s * 0.45)
            t:SetAlpha(0.9 * (1 - p))
        end, function() self.fxPool.Release(t) end)
    end
end

function Module:Flash(x, y, size, color, duration)
    local t = self.fxPool.Acquire()
    t:SetTexture(Media.Tex("glow"))
    t:SetBlendMode("ADD")
    t:SetVertexColor(color[1], color[2], color[3])
    t:Show()
    self:AddEffect(duration, function(p)
        local s = size * (0.6 + 0.6 * p)
        t:ClearAllPoints()
        t:SetPoint("CENTER", self.fxLayer, "TOPLEFT", x, -y)
        t:SetSize(s, s)
        t:SetAlpha(1 - p)
    end, function() self.fxPool.Release(t) end)
end

function Module:AddEffect(duration, update, finish)
    self.effects[#self.effects + 1] = { t = 0, d = duration, update = update, finish = finish }
end

function Module:RunEffects(dt)
    for i = #self.effects, 1, -1 do
        local fx = self.effects[i]
        fx.t = fx.t + dt
        local p = fx.t / fx.d
        if p >= 1 then
            table.remove(self.effects, i)
            if fx.finish then fx.finish() end
        else
            fx.update(p, dt)
        end
    end
end

function Module:ClearEffects()
    for i = #self.effects, 1, -1 do
        local fx = table.remove(self.effects, i)
        if fx.finish then fx.finish() end
    end
end

-- A test ended: stars and records on success.
function Module:Finish(won, why)
    local level = self.level
    local store = self:Store()
    local info = { won = won, why = why, cost = self.cost, budget = level.budget, peak = self.sim and self.sim.peak or 0 }
    if won then
        local stars = P.Stars(level, self.cost)
        info.stars = stars
        if stars > 0 then
            local best = store.best[level.id]
            if not best or self.cost < best.cost then
                info.newBest = best ~= nil
                store.best[level.id] = { cost = self.cost, stars = math.max(stars, best and best.stars or 0) }
            end
        end
    end
    self.result = info
    -- The panel comes a moment later, so the end can be seen.
    self.resultAt = self.realClock + (won and 1.2 or 1.6)
end

-- The frame -----------------------------------------------------------------------------------------------

function Module:OnUpdate(dt)
    self.realClock = self.realClock + dt
    if not self.level then return end
    local paused = self.overlay.current ~= nil
    if self.sim then
        if not paused then self:UpdateTest(dt) end
        if self.result and self.resultAt and self.realClock >= self.resultAt then
            self.resultAt = nil
            self:ShowResult(self.result)
        end
    else
        self:UpdateEditor()
    end
    if not paused then self:RunEffects(dt) end
    self:UpdateAmbience(dt)
    -- The river moves.
    local o = (self.realClock * 0.04) % 1
    self.ripples:SetTexCoord(o, o + FW / 128, 0, (FH - self.level.water) / 64)
    local f = self.foreman
    if f and f:IsShown() and self.foremanAt and self.realClock - self.foremanAt > 14 then self:HideForeman() end
    if self.hintTime then
        self.hintTime = self.hintTime + dt
        self.hint:SetAlpha(math.max(0, 1 - math.max(0, self.hintTime - 1.2) / 0.5))
        if self.hintTime > 1.7 then
            self.hint:Hide()
            self.hintTime = nil
        end
    end
    self:UpdateBars(dt)
end

-- Window hooks ---------------------------------------------------------------------------------------------

function Module:Enter()
    if not self.level then self:ShowMenu() end
end

function Module:Leave()
    self:Pause()
end

function Module:Pause()
    if not self.overlay or not self.level then return end
    self.dragFrom = nil
    if not self.overlay.current then self.overlay:Show("pause") end
end

function Module:Resume()
    self.overlay:Hide()
    self.topBar:Show()
    self.toolBar:Show()
end

function Module:OnKey(key)
    if self.overlay.current then
        if key == "ESCAPE" and self.overlay.current == "pause" then
            self:Resume()
            return true
        end
        return false
    end
    if not self.level then return false end
    if key == "ESCAPE" then
        if self.dragFrom then
            self.dragFrom = nil
        elseif self.resultShown then
            self:StopTest()
        else
            self:Pause()
        end
        return true
    end
    if key == "SPACE" then
        if self.sim then self:StopTest() else self:StartTest() end
        return true
    end
    if key == "F" then
        self:ToggleFast()
        return true
    end
    if self.sim then return false end
    local n = tonumber(key)
    if n and self.level.materials[n] then
        self:SetMaterial(self.level.materials[n])
        return true
    end
    if key == "Z" then
        self:Undo()
        return true
    elseif key == "X" or key == "DELETE" then
        self:ToggleErase()
        return true
    end
    return false
end

function Module:RefreshTexts()
    if self.overlay then self.overlay:Refresh() end
    self:RefreshBars()
end

function Module:Stars()
    local total, done = 0, 0
    for _, b in pairs(self:Store().best) do
        total = total + (b.stars or 0)
        done = done + 1
    end
    return total, done
end

function Module:BestScore()
    local total = self:Stars()
    return total > 0 and total or nil
end

function Module:HubInfo()
    local stars, done = self:Stars()
    local n = #BA.LEVELS
    return {
        stats = {
            { value = stars .. "/" .. n * 3, label = L.GBA_HUB_STARS, share = stars / (n * 3) },
            { value = done .. "/" .. n, label = L.GBA_HUB_LEVELS, share = done / n },
        },
        status = done > 0 and L.GBA_HUB_AT:format(math.min(n, done + 1), n) or L.GBA_HUB_READY,
    }
end

function Module:StatLines()
    local store = self:Store()
    local stars, done = self:Stars()
    return {
        { L.GBA_STAT_STARS, tostring(stars) },
        { L.GBA_STAT_DONE, done .. "/" .. #BA.LEVELS },
        { L.GBA_STAT_TESTS, ns.FormatNumber(store.tests or 0) },
        { L.GBA_STAT_BROKEN, ns.FormatNumber(store.broken or 0) },
    }
end

function Module:ShowHelp()
    if self.overlay then
        self.helpBack = self.overlay.current or "game"
        self.overlay:Show("help")
    end
end

function Module:ShowAchievements()
    self:ShowHelp()
end

function Module:ResetProgress()
    local store = Arcade.Settings(self)
    for k in pairs(store) do store[k] = nil end
    Arcade.Settings(self)
    if self.overlay then
        self:StopTest(true)
        self.level = nil
        self:ShowMenu()
    end
end

-- Dev: /gba pitch flips the vehicle's tilt if it leans the wrong way.
SLASH_GOBLINBRIDGE1 = "/gba"
SlashCmdList.GOBLINBRIDGE = function(msg)
    if msg == "pitch" then
        PITCH_SIGN = -PITCH_SIGN
        print("Goblin Bridge Architect: pitch sign " .. PITCH_SIGN)
    end
end

-- The dev copy only, while it is a prototype.
if ADDON ~= "DarkmoonArcade" then Arcade.RegisterGame(Module) end
