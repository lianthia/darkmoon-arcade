-- Goblin Bridge Architect: life in the gorge. Drifting clouds, the moon at night, weather (snow, rain,
-- embers over lava, fireflies, blowing dust) and now and then a creature flying past in the distance
-- (a client model in its own scene behind the bridge). Nothing here touches the game; it only looks.

local _, ns = ...
local BA = ns.BridgeArchitect
local P = BA.Physics
local Media = ns.Media

local Module = BA.Module
local FW, FH = P.W, P.H
local PPY = 20

-- Creatures that fly past: display, model length (yards), animation while flying.
BA.FLYERS = {
    wyvern = { display = 295, len = 6.34, anim = 5 },
    gryphon = { display = 1149, len = 4.48, anim = 5 },
    hippogryph = { display = 479, len = 5.05, anim = 5 },
    carrion = { display = 1192, len = 3.85, anim = 5 },
    bat = { display = 9074, len = 5.33, anim = 5, flutter = true },
    whelp = { display = 497, len = 1.39, anim = 5, flutter = true },
    pterrordax = { display = 8411, len = 5.59, anim = 5 },
}

-- Each zone's sky and weather.
--   clouds   how many, cloud colour (nil: white mixed into the horizon), alpha
--   weather  "snow", "rain", "embers", "fireflies", "dust" and how many
--   flyers   who may fly past
BA.AMBIENCE = {
    barrens = { clouds = 3, weather = "dust", count = 12, flyers = { "wyvern", "carrion" } },
    needles = { clouds = 4, flyers = { "carrion", "wyvern" } },
    desolace = { clouds = 6, cloudColor = { 0.72, 0.72, 0.74 }, weather = "dust", count = 18, dust = { 0.75, 0.75, 0.72 },
        flyers = { "carrion" } },
    stranglethorn = { clouds = 5, cloudColor = { 0.7, 0.74, 0.76 }, weather = "rain", count = 70, flyers = { "gryphon" } },
    duskwood = { clouds = 2, cloudColor = { 0.22, 0.24, 0.38 }, cloudAlpha = 0.6, moon = true, weather = "fireflies", count = 16,
        flyers = { "bat" } },
    steppes = { clouds = 4, cloudColor = { 0.3, 0.17, 0.13 }, cloudAlpha = 0.8, weather = "embers", count = 44, flyers = { "whelp" } },
    winterspring = { clouds = 3, weather = "snow", count = 80, flyers = { "hippogryph" } },
    tanaris = { clouds = 1, weather = "dust", count = 26, dust = { 1, 0.85, 0.6 }, flyers = { "carrion", "wyvern" } },
    ungoro = { clouds = 3, weather = "fireflies", count = 9, flyers = { "pterrordax" } },
    feralas = { clouds = 6, cloudColor = { 0.66, 0.7, 0.72 }, weather = "rain", count = 90, flyers = { "hippogryph" } },
}

local function Tex(name) return Media.Tex("bridge/" .. name) end
local rand = math.random
local function Range(a, b) return a + (b - a) * rand() end

-- Building --------------------------------------------------------------------------------------------------

-- back: the layer with the sky (textures between its stars and hills); weather: a layer in front of the
-- bridge; base: the field's frame level.
function Module:BuildAmbience(field, back, weather, base)
    self.moon = back:CreateTexture(nil, "BACKGROUND", nil, -5)
    self.moon:SetTexture(Tex("moon"))
    self.moon:SetSize(96, 96)
    self.moon:SetPoint("CENTER", back, "TOPLEFT", 770, -70)
    self.moon:Hide()
    self.cloudPool = Media.Pool(function()
        local t = back:CreateTexture(nil, "BACKGROUND", nil, -4)
        t:SetTexture(Tex("cloud"))
        return t
    end, function(t) t:Hide() end)
    self.weatherPool = Media.Pool(function() return weather:CreateTexture(nil, "ARTWORK") end, function(t)
        t:Hide()
        t:SetBlendMode("BLEND")
        if t.SetRotation then t:SetRotation(0) end
    end)
    self.clouds, self.particles, self.flyers = {}, {}, {}
    -- Flyers: their own scene behind the bridge, with the same camera as the vehicle's.
    local ok, scene = pcall(CreateFrame, "ModelScene", nil, field)
    if ok and scene and scene.CreateActor then
        scene:SetAllPoints()
        scene:SetFrameLevel(base + 2)
        if scene.EnableMouse then scene:EnableMouse(false) end
        self:SetupCamera(scene)
        for i = 1, 2 do
            local a = scene:CreateActor()
            a:Hide()
            self.flyers[i] = { actor = a }
        end
        self.skyScene = scene
    end
end

-- The scene's camera: side on, PPY pixels per yard at the depth of the actors.
function Module:SetupCamera(scene)
    local diag = math.sqrt(FW * FW + FH * FH) / 2
    local fov = 0.3
    local dist = diag / math.tan(fov / 2) / PPY
    pcall(scene.SetCameraFieldOfView, scene, fov)
    pcall(scene.SetCameraNearClip, scene, 1)
    pcall(scene.SetCameraFarClip, scene, dist * 3)
    pcall(scene.SetCameraPosition, scene, -dist, 0, 0)
    pcall(scene.SetCameraOrientationByYawPitchRoll, scene, 0, 0, 0)
    pcall(scene.SetLightVisible, scene, true)
    pcall(scene.SetLightType, scene, 0)
    pcall(scene.SetLightDirection, scene, 0.6, -0.3, -0.6)
    pcall(scene.SetLightAmbientColor, scene, 0.6, 0.58, 0.55)
    pcall(scene.SetLightDiffuseColor, scene, 0.95, 0.88, 0.78)
end

-- Setting up a zone ------------------------------------------------------------------------------------------

function Module:ClearAmbience()
    for _, c in ipairs(self.clouds) do self.cloudPool.Release(c.t) end
    for _, p in ipairs(self.particles) do self.weatherPool.Release(p.t) end
    self.clouds, self.particles = {}, {}
    for _, f in ipairs(self.flyers) do
        f.active = nil
        f.actor:Hide()
    end
    self.moon:Hide()
end

function Module:SetAmbience(zoneId)
    self:ClearAmbience()
    local amb = BA.AMBIENCE[zoneId]
    local zone = BA.ZONES[zoneId]
    if not amb or not zone then return end
    self.ambience = amb
    self.moon:SetShown(amb.moon and true or false)
    -- Clouds: white, lit by the sky's horizon colour, unless the zone has its own.
    local hz = zone.sky[1]
    local cc = amb.cloudColor or { (1 + hz[1]) / 2, (1 + hz[2]) / 2, (1 + hz[3]) / 2 }
    for i = 1, amb.clouds or 0 do
        local t = self.cloudPool.Acquire()
        local w = Range(170, 300)
        t:SetSize(w, w / 2)
        t:SetVertexColor(cc[1], cc[2], cc[3], (amb.cloudAlpha or 0.8) * Range(0.75, 1))
        -- Some mirrored, so the same cloud does not repeat.
        if rand() < 0.5 then t:SetTexCoord(1, 0, 0, 1) else t:SetTexCoord(0, 1, 0, 1) end
        t:Show()
        self.clouds[i] = { t = t, w = w, x = Range(-w / 2, FW + w / 2), y = Range(10, 150), speed = Range(4, 11) }
    end
    for i = 1, amb.count or 0 do
        local p = { t = self.weatherPool.Acquire(), kind = amb.weather }
        self:SpawnParticle(p, true)
        self.particles[i] = p
    end
    self.nextFlyer = Range(2, 6)
end

-- (Re)starts a weather particle; `anywhere`: scattered over the field instead of entering at an edge.
function Module:SpawnParticle(p, anywhere)
    local t, kind = p.t, p.kind
    p.phase = Range(0, 6.28)
    if kind == "snow" then
        t:SetTexture(Tex("flake"))
        p.size = Range(4, 10)
        p.x, p.y = Range(-20, FW + 20), anywhere and Range(0, FH) or -10
        p.vx, p.vy = Range(4, 14), Range(22, 48) * (0.5 + p.size / 14)
        t:SetVertexColor(1, 1, 1, Range(0.6, 0.95))
        t:SetSize(p.size, p.size)
    elseif kind == "rain" then
        t:SetTexture(Tex("rain"))
        p.vy = Range(520, 640)
        p.vx = -p.vy * 0.16
        p.x, p.y = Range(0, FW + 100), anywhere and Range(0, FH) or Range(-60, -10)
        local len = Range(14, 22)
        t:SetSize(2, len)
        t:SetVertexColor(0.78, 0.86, 0.95, Range(0.3, 0.5))
        if t.SetRotation then t:SetRotation(math.atan2(-p.vx, p.vy)) end
    elseif kind == "embers" then
        t:SetTexture(Media.Tex("glow"))
        t:SetBlendMode("ADD")
        local level = self.level
        local water = level and level.water or 440
        p.size = Range(4, 9)
        p.x = Range(0, FW)
        p.y = anywhere and Range(water - 260, water) or water + Range(-4, 14)
        p.vx, p.vy = Range(-8, 8), -Range(26, 64)
        p.life, p.age = Range(3, 6), anywhere and Range(0, 3) or 0
        p.g = Range(0.35, 0.75)
        t:SetSize(p.size, p.size)
    elseif kind == "fireflies" then
        t:SetTexture(Media.Tex("glow"))
        t:SetBlendMode("ADD")
        local water = self.level and self.level.water or 440
        p.size = Range(7, 11)
        p.x, p.y = Range(20, FW - 20), Range(water - 220, water - 20)
        p.cx, p.cy = p.x, p.y
        p.rx, p.ry = Range(20, 60), Range(10, 30)
        p.speed = Range(0.15, 0.4)
        p.pulse = Range(0.8, 1.6)
        t:SetSize(p.size, p.size)
        t:SetVertexColor(0.75, 1, 0.4)
    else -- dust
        t:SetTexture(Tex("mote"))
        local c = self.ambience and self.ambience.dust or { 0.95, 0.85, 0.65 }
        p.size = Range(4, 10)
        p.x, p.y = anywhere and Range(0, FW) or -12, Range(60, FH - 40)
        p.vx, p.vy = Range(18, 42), Range(-3, 3)
        t:SetVertexColor(c[1], c[2], c[3], Range(0.18, 0.35))
        t:SetSize(p.size, p.size)
    end
    t:Show()
end

-- Every frame ----------------------------------------------------------------------------------------------

function Module:UpdateAmbience(dt)
    if not self.ambience then return end
    local back = self.backLayer
    local clock = self.realClock
    for _, c in ipairs(self.clouds) do
        c.x = c.x + c.speed * dt
        if c.x - c.w / 2 > FW then
            c.x = -c.w / 2
            c.y = Range(10, 150)
        end
        c.t:ClearAllPoints()
        c.t:SetPoint("CENTER", back, "TOPLEFT", c.x, -c.y)
    end
    local layer = self.weatherLayer
    for _, p in ipairs(self.particles) do
        local kind, t = p.kind, p.t
        if kind == "snow" then
            p.x = p.x + (p.vx + math.sin(clock * 1.3 + p.phase) * 14) * dt
            p.y = p.y + p.vy * dt
            if p.y > FH + 10 then self:SpawnParticle(p) end
        elseif kind == "rain" then
            p.x, p.y = p.x + p.vx * dt, p.y + p.vy * dt
            if p.y > FH + 20 then self:SpawnParticle(p) end
        elseif kind == "embers" then
            p.age = p.age + dt
            p.x = p.x + (p.vx + math.sin(clock * 2 + p.phase) * 10) * dt
            p.y = p.y + p.vy * dt
            local f = p.age / p.life
            if f >= 1 then
                self:SpawnParticle(p)
            else
                local flick = 0.75 + 0.25 * math.sin(clock * 9 + p.phase)
                t:SetVertexColor(1, p.g * flick, 0.15, (1 - f) * flick)
            end
        elseif kind == "fireflies" then
            local a = clock * p.speed + p.phase
            p.x = p.cx + math.sin(a) * p.rx + math.sin(a * 2.3) * 8
            p.y = p.cy + math.sin(a * 1.7) * p.ry
            local glow = math.max(0, math.sin(clock * p.pulse + p.phase))
            t:SetAlpha(glow * glow)
        else
            p.x = p.x + p.vx * dt
            p.y = p.y + (p.vy + math.sin(clock * 0.8 + p.phase) * 6) * dt
            if p.x > FW + 12 then self:SpawnParticle(p) end
        end
        t:ClearAllPoints()
        t:SetPoint("CENTER", layer, "TOPLEFT", p.x, -p.y)
    end
    self:UpdateFlyers(dt)
end

-- A creature crossing the sky far away; at most two at a time.
function Module:UpdateFlyers(dt)
    if not self.skyScene then return end
    local amb = self.ambience
    if amb.flyers and #amb.flyers > 0 then
        self.nextFlyer = (self.nextFlyer or 5) - dt
        if self.nextFlyer <= 0 then
            self.nextFlyer = Range(9, 20)
            for _, f in ipairs(self.flyers) do
                if not f.active then
                    self:LaunchFlyer(f, BA.FLYERS[amb.flyers[rand(#amb.flyers)]])
                    break
                end
            end
        end
    end
    for _, f in ipairs(self.flyers) do
        if f.active then
            f.x = f.x + f.vx * dt
            f.t = f.t + dt
            local bob = math.sin(f.t * (f.def.flutter and 5 or 1.6)) * (f.def.flutter and 6 or 9)
            local y = f.y + bob
            local s = f.scale
            pcall(f.actor.SetPosition, f.actor, 0, -(f.x - FW / 2) / PPY / s, -(y - FH / 2) / PPY / s)
            if (f.vx > 0 and f.x > FW + 80) or (f.vx < 0 and f.x < -80) then
                f.active = nil
                f.actor:Hide()
            end
        end
    end
end

function Module:LaunchFlyer(f, def)
    if not def then return end
    local a = f.actor
    if not pcall(a.SetModelByCreatureDisplayID, a, def.display) then return end
    -- Far away: small, and smaller still the higher up it flies.
    local px = Range(30, 46)
    f.scale = px / PPY / def.len
    pcall(a.SetScale, a, f.scale)
    local right = rand() < 0.5
    f.vx = (right and 1 or -1) * Range(45, 75) * (def.flutter and 1.2 or 1)
    f.x = right and -70 or FW + 70
    f.y = Range(50, 160)
    f.t = Range(0, 6)
    f.def = def
    pcall(a.SetYaw, a, right and -math.pi / 2 or math.pi / 2)
    pcall(a.SetAnimation, a, def.anim or 5, 0, 1)
    pcall(a.SetAlpha, a, 0.92)
    a:Show()
    f.active = true
end
