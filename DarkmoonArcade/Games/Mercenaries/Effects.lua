-- Spell effects: the client's own spell models (missiles, impacts, auras) played over the board.
--
-- All effects are actors in one ModelScene that covers the whole board, with a fixed camera: a
-- model keeps its real size (no camera that fits each model on its own) and nothing is cut off at
-- the edge of a small model frame. Clients without ModelScene fall back to one PlayerModel per
-- effect. The effect gallery of the dev copy (FxGallery.lua) tunes and rates every effect; the
-- values are kept in DarkmoonArcadeDB.fxGallery.v3 to be moved into FX_LIST. The values in
-- FX_LIST come from Ben's second round in the gallery (`unused`: rated bad).

local _, ns = ...
local MC = ns.Mercenaries
local Media = ns.Media
local Module = MC.Module
local W, H = MC.W, MC.H

-- kind: missile (flies from the caster to the target, then plays `impact`), impact (on the
-- target) or aura (on the caster or an ally). file: the model's FileDataID (spells/*.m2).
local function E(id, kind, file, name, extra)
    local e = { id = id, kind = kind, file = file, name = name }
    for k, v in pairs(extra or {}) do e[k] = v end
    return e
end

MC.FX_LIST = {
    -- Missiles
    E("fire_missile", "missile", 166128, "fireball_missile_high", { impact = "fire_hit", scale = 0.76 }),
    E("fel_missile", "missile", 166074, "fel_fireball_missile_high", { impact = "fire_hit2", scale = 0.76 }),
    E("frost_missile", "missile", 166214, "frostbolt", { impact = "frost_hit", scale = 0.76 }),
    E("frost_missile2", "missile", 1598570, "cfx_mage_frostbolt_missile", { impact = "frost_hit", scale = 0.76 }),
    E("blue_missile", "missile", 166127, "fireball_blue_missile_high", { impact = "frost_hit", scale = 0.76 }),
    E("lightning_missile", "missile", 166497, "lightningbolt_missile", { impact = "lightning_hit", scale = 0.76 }),
    E("arcane_missile", "missile", 165569, "arcane_missile", { impact = "arcane_hit", scale = 0.76 }),
    E("arcane_orb", "missile", 963808, "arcane_missile_orb", { impact = "arcane_hit", scale = 0.76 }),
    E("shadow_missile", "missile", 382336, "fireball_missile_shadow_high", { impact = "shadow_hit", scale = 0.76 }),
    E("twilight_missile", "missile", 367434, "twilight_fireball_missile_high", { impact = "shadow_hit2", scale = 0.76 }),
    -- Impacts on the target
    E("fire_hit", "impact", 166115, "fire_impactdd_high_chest"),
    E("fire_hit2", "impact", 166119, "fire_impactdd_uber_chest"),
    E("frost_hit", "impact", 1599028, "cfx_mage_frostbolt_impactchest"),
    E("lightning_hit", "impact", 166496, "lightningbolt_impact_chest"),
    E("lightning_call", "impact", 165768, "calllightning_impact"),
    E("shadow_hit", "impact", 166814, "shadowbolt_chest_impact"),
    E("shadow_hit2", "impact", 166795, "shadow_impactdd_high_chest"),
    E("shadow_hit3", "impact", 166799, "shadow_impactdd_uber_chest"),
    E("holy_hit", "impact", 166329, "holy_impactdd_uber_chest"),
    E("holy_hit2", "impact", 916379, "explosion_holy_impact", { y = 39 }),
    E("arcane_hit", "impact", 165578, "arcaneexplosion_impact_chest"),
    E("arcane_burst", "impact", 165576, "arcaneexplosion_base", { scale = 0.66, x = -14, y = -62 }),
    E("blood_hit", "impact", 426040, "bloodyexplosionblack"),
    E("blood_hit2", "impact", 165738, "bloodyexplosiongreen"),
    E("thunderclap", "impact", 167120, "thunderclap_cast_base", { scale = 0.76, y = 49 }),
    E("shadow_dot", "impact", 166800, "shadow_impactdot_med_chest"),
    E("stun", "impact", 166988, "stunswirl_state_head", { scale = 1.32 }),
    -- Auras on the caster or an ally
    E("heal", "aura", 166327, "holy_impactdd_med_chest"),
    E("renew", "aura", 166697, "renew_chest"),
    E("holy_cast", "aura", 166339, "holy_precast_uber_hand"),
    E("nature_cast", "aura", 166604, "nature_precast_chest"),
    E("shield", "aura", 588344, "divineshield_v2_chest"),
    E("shield2", "aura", 165962, "divineshield_low_chest"),
    E("taunt", "aura", 167093, "taunt_head", { scale = 1.15, x = 36, y = -60 }),
    E("taunt_cast", "aura", 167092, "taunt_cast", { unused = true }),
    E("battleshout", "aura", 165658, "battleshout_cast_base"),
    E("levelup", "aura", 166464, "levelup", { scale = 1.15, x = 36, y = 56 }),
    E("resurrect", "aura", 166704, "resurrection_low_base"),
}
MC.FX = {}
for i, e in ipairs(MC.FX_LIST) do
    e.index = i
    MC.FX[e.id] = e
end

-- Starting values of every effect; the gallery changes them per effect. scale: the model's size;
-- x, y: shift in pixels; rx, ry, rz: turn in degrees (roll, pitch, yaw); dur: seconds (a
-- missile's flight).
MC.FX_DEFAULTS = { scale = 1, x = 0, y = 0, rx = 0, ry = 0, rz = 0, dur = 0.8 }
-- The camera: how many pixels one yard in the scene covers, and its field of view. The client's
-- field of view spans the scene's diagonal (found in the gallery: with it every effect sat on its
-- mark without being shifted).
MC.FX_CAMERA = { ppy = 48, fov = 0.6, fovAxis = "diagonal" }

function MC.FxStore()
    local db = ns.db
    if not db then return { v3 = {}, cam = {} } end
    db.fxGallery = db.fxGallery or {}
    db.fxGallery.v3 = db.fxGallery.v3 or {}
    db.fxGallery.cam = db.fxGallery.cam or {}
    return db.fxGallery
end

-- An effect's values: the tuned ones from the gallery over the effect's own and the defaults.
function MC.FxTuning(id)
    local def = MC.FX[id]
    local saved = MC.FxStore().v3[id]
    local t = {}
    for k, v in pairs(MC.FX_DEFAULTS) do
        local own = def and def[k]
        if saved and saved[k] ~= nil then t[k] = saved[k] elseif own ~= nil then t[k] = own else t[k] = v end
    end
    return t
end

-- Camera settings the gallery can change for all effects at once.
function MC.FxCamera()
    local cam = MC.FxStore().cam
    return {
        ppy = cam.ppy or MC.FX_CAMERA.ppy,
        fov = MC.FX_CAMERA.fov,
        fovAxis = cam.fovAxis or MC.FX_CAMERA.fovAxis,
        mirror = cam.mirror and -1 or 1,
        pitchSign = cam.pitchSign or -1,
    }
end

-- Blizzard's own UI effects (missiles and bursts between frames), where the client has them.
function MC.ScriptedFxAvailable()
    return C_ScriptedAnimations ~= nil and C_ScriptedAnimations.GetAllScriptedAnimationEffects ~= nil
        and C_XMLUtil ~= nil and C_XMLUtil.GetTemplateInfo ~= nil
        and C_XMLUtil.GetTemplateInfo("ScriptAnimatedModelSceneTemplate") ~= nil
end

-- Adds Blizzard's UI effects to the list (kind "scripted", id "s<number>"); dev copy only.
function MC.AddScriptedFx()
    if MC.scriptedAdded or not MC.ScriptedFxAvailable() then return 0 end
    MC.scriptedAdded = true
    local ok, list = pcall(C_ScriptedAnimations.GetAllScriptedAnimationEffects)
    if not ok or type(list) ~= "table" then return 0 end
    table.sort(list, function(a, b) return (a.id or 0) < (b.id or 0) end)
    local dump, added = {}, 0
    for _, e in ipairs(list) do
        if e.id and e.visual and e.visual ~= 0 then
            local def = E("s" .. e.id, "scripted", e.visual, "blizzard ui effect " .. e.id, { scripted = e.id })
            MC.FX_LIST[#MC.FX_LIST + 1] = def
            def.index = #MC.FX_LIST
            MC.FX[def.id] = def
            added = added + 1
            dump[#dump + 1] = table.concat({ e.id, e.visual, e.visualScale or 1, e.duration or 0,
                e.trajectory or 0, e.startBehavior or 0, e.finishBehavior or 0, e.finishEffectID or 0 }, ",")
        end
    end
    -- id, visual, visualScale, duration, trajectory, startBehavior, finishBehavior, finishEffectID
    MC.FxStore().scripted = dump
    return added
end

-- In battle -----------------------------------------------------------------------------------------

-- Per school: the missile of a single-target spell, the hit on a target and the burst of an
-- ability that strikes several. Holy has no missile; physical hits show no missile either.
MC.SCHOOL_FX = {
    fire = { missile = "fire_missile", hit = "fire_hit", big = "fire_hit2" },
    frost = { missile = "frost_missile", hit = "frost_hit", big = "frost_hit" },
    nature = { missile = "lightning_missile", hit = "lightning_hit", big = "lightning_call" },
    shadow = { missile = "shadow_missile", hit = "shadow_hit", big = "shadow_hit3" },
    arcane = { missile = "arcane_missile", hit = "arcane_hit", big = "arcane_burst" },
    holy = { hit = "holy_hit", big = "holy_hit2" },
    physical = { hit = "blood_hit", big = "thunderclap" },
}
local SPREAD = { all = true, others = true, adjacent = true }

-- How an ability looks: its school, whether it strikes several, and the missile it flies with.
local abilityFx = {}
function MC.AbilityFx(abilityId)
    if abilityFx[abilityId] then return abilityFx[abilityId] end
    local def = MC.Abilities[abilityId]
    if not def then return nil end
    local school = MC.SCHOOL_FX[def.school] and def.school or "physical"
    local info = { school = school, big = false }
    for _, eff in ipairs(def.effects) do
        if eff[1] == "damage" then
            local to = eff.to or "target"
            info.big = SPREAD[to] or false
            local own = MC.SCHOOL_FX[eff.school or school]
            if not info.big and def.target == "enemy" and to == "target" and own then
                info.missile = own.missile
            end
            break
        end
    end
    abilityFx[abilityId] = info
    return info
end

-- Spell effects in battle: the option, and a client that can show them.
function Module:BattleFxOn()
    return ns.Arcade.Settings(self).effects ~= false and self:FxScene() ~= false
end

-- Scene ---------------------------------------------------------------------------------------------

function Module:FxScene()
    if self.fxScene == nil then
        self.fxScene = false
        local ok, scene = pcall(CreateFrame, "ModelScene", nil, self.fxLayer)
        if ok and scene and scene.CreateActor then
            scene:SetAllPoints(self.fxLayer)
            scene:SetFrameLevel(self.fxLayer:GetFrameLevel() + 2)
            if scene.EnableMouse then scene:EnableMouse(false) end
            self.fxScene = scene
            self.fxActors = Media.Pool(function() return scene:CreateActor() end, function(a)
                if a.ClearModel then pcall(a.ClearModel, a) end
                if a.Hide then a:Hide() end
            end)
            self:AimFxCamera()
        end
        if MC.DEV then
            MC.FxStore().info = {
                modelScene = self.fxScene ~= false, scripted = MC.ScriptedFxAvailable(),
            }
        end
    end
    return self.fxScene
end

-- Camera at (-D, 0, 0) looking along +X: screen right is -Y, screen up is +Z. D is chosen so that
-- `ppy` pixels show one yard at the plane X = 0, where the effects play.
function Module:AimFxCamera()
    local scene = self.fxScene
    if not scene then return end
    local cam = MC.FxCamera()
    local span = cam.fovAxis == "vertical" and H or (cam.fovAxis == "horizontal" and W or math.sqrt(W * W + H * H))
    local half = span / 2 / cam.ppy
    local distance = half / math.tan(cam.fov / 2)
    pcall(scene.SetCameraFieldOfView, scene, cam.fov)
    pcall(scene.SetCameraNearClip, scene, 0.1)
    pcall(scene.SetCameraFarClip, scene, distance * 4)
    pcall(scene.SetCameraPosition, scene, -distance, 0, 0)
    pcall(scene.SetCameraOrientationByYawPitchRoll, scene, 0, 0, 0)
end

-- Board pixels (x right, y down from the top left) to the scene's Y and Z.
function Module:FxWorld(px, py)
    local cam = MC.FxCamera()
    return -(px - W / 2) / cam.ppy * cam.mirror, -(py - H / 2) / cam.ppy
end

-- Turns a missile, which points along +X, to fly along the board direction dx, dy.
local function Aim(dx, dy, cam)
    local sx, sy = dx * cam.mirror, -dy
    local len = math.max(0.001, math.sqrt(sx * sx + sy * sy))
    local yaw = math.atan2(-sx, 0)
    local pitch = cam.pitchSign * math.asin(sy / len)
    return yaw, pitch
end

-- Plays effect `id` at x, y (board pixels). A missile flies to toX, toY and then plays its
-- impact there. Returns the effect's length in seconds (0 if it cannot play).
function Module:PlayFx(id, x, y, toX, toY, onDone, duration)
    local def = MC.FX[id]
    if not def or def.kind == "scripted" or not self.fxLayer then return 0 end
    local scene = self:FxScene()
    if not scene then return self:PlayFxModel(def, x, y, toX, toY, onDone) end
    local t, cam = MC.FxTuning(id), MC.FxCamera()
    local a = self.fxActors.Acquire()
    local ok = pcall(a.SetModelByFileID, a, def.file)
    if MC.DEV then
        local store = MC.FxStore()
        store.loaded = store.loaded or {}
        store.loaded[id] = ok
    end
    pcall(a.SetScale, a, t.scale)
    pcall(a.SetAlpha, a, 1)
    local missile = def.kind == "missile" and toX ~= nil
    local yaw, pitch = math.rad(t.rz), math.rad(t.ry)
    if missile then
        local aimYaw, aimPitch = Aim(toX - x, toY - y, cam)
        yaw, pitch = yaw + aimYaw, pitch + aimPitch
    end
    pcall(a.SetYaw, a, yaw)
    pcall(a.SetPitch, a, pitch)
    pcall(a.SetRoll, a, math.rad(t.rx))
    local function Put(px, py)
        local wy, wz = self:FxWorld(px + t.x, py + t.y)
        pcall(a.SetPosition, a, 0, wy, wz)
    end
    Put(x, y)
    if a.Show then a:Show() end
    local dur = math.max(0.1, duration or t.dur)
    self.effects[#self.effects + 1] = {
        t = 0,
        update = function(e)
            local p = e.t / dur
            if p >= 1 then return false end
            if missile then
                Put(x + (toX - x) * p, y + (toY - y) * p - math.sin(p * math.pi) * 24)
            elseif p > 0.75 then
                pcall(a.SetAlpha, a, 1 - (p - 0.75) / 0.25)
            end
            return true
        end,
        finish = function()
            self.fxActors.Release(a)
            if missile and def.impact and not self.clearingEffects then self:PlayFx(def.impact, toX, toY) end
            if onDone then onDone() end
        end,
    }
    return dur + (missile and def.impact and MC.FxTuning(def.impact).dur or 0)
end

-- Fallback without ModelScene: one PlayerModel per effect, a large frame round the spot so the
-- effect's edges are not cut off.
local PAD = 4
function Module:PlayFxModel(def, x, y, toX, toY, onDone)
    local t = MC.FxTuning(def.id)
    if not self.fxModels then
        self.fxModels = Media.Pool(function()
            local m = CreateFrame("PlayerModel", nil, self.fxLayer)
            m:SetFrameLevel(self.fxLayer:GetFrameLevel() + 2)
            return m
        end, function(m)
            pcall(m.ClearModel, m)
            m:Hide()
        end)
    end
    local m = self.fxModels.Acquire()
    local size = 120 * PAD
    m:SetSize(size, size)
    m:SetAlpha(1)
    m:Show()
    pcall(m.SetModel, m, def.file)
    pcall(m.SetModelScale, m, t.scale / PAD)
    local missile = def.kind == "missile" and toX ~= nil
    local function Put(px, py)
        m:ClearAllPoints()
        m:SetPoint("CENTER", self.fxLayer, "TOPLEFT", px + t.x, -(py + t.y))
    end
    Put(x, y)
    local dur = math.max(0.1, t.dur)
    self.effects[#self.effects + 1] = {
        t = 0,
        update = function(e)
            local p = e.t / dur
            if p >= 1 then return false end
            if missile then
                Put(x + (toX - x) * p, y + (toY - y) * p - math.sin(p * math.pi) * 24)
            elseif p > 0.75 then
                m:SetAlpha(1 - (p - 0.75) / 0.25)
            end
            return true
        end,
        finish = function()
            self.fxModels.Release(m)
            if missile and def.impact and not self.clearingEffects then self:PlayFx(def.impact, toX, toY) end
            if onDone then onDone() end
        end,
    }
    return dur
end

-- Blizzard's UI effects play between two frames in a scene of their own.
function Module:PlayScriptedFx(id, source, target)
    local def = MC.FX[id]
    if not def or not def.scripted then return 0 end
    if not self.fxScripted then
        local ok, scene = pcall(CreateFrame, "ModelScene", nil, self.fxLayer, "ScriptAnimatedModelSceneTemplate")
        if not ok or not scene then return 0 end
        scene:SetAllPoints(self.fxLayer)
        scene:SetFrameLevel(self.fxLayer:GetFrameLevel() + 3)
        self.fxScripted = scene
    end
    local ok = pcall(self.fxScripted.AddEffect, self.fxScripted, def.scripted, source, target)
    if MC.DEV then
        local store = MC.FxStore()
        store.loaded = store.loaded or {}
        store.loaded[id] = ok
    end
    return 1.5
end

function Module:ClearScriptedFx()
    if self.fxScripted and self.fxScripted.RemoveAllEffects then
        pcall(self.fxScripted.RemoveAllEffects, self.fxScripted)
    end
end
