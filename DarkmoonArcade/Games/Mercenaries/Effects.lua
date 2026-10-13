-- Spell effects: the client's own spell models (missiles, impacts, auras) played over the board.
-- Each model needs its own size, place and turn in the frame; the effect gallery of the dev copy
-- (FxGallery.lua) tunes them in the game and keeps the values in DarkmoonArcadeDB.fxGallery.

local _, ns = ...
local MC = ns.Mercenaries
local Media = ns.Media
local Module = MC.Module

-- kind: missile (flies from the caster to the target, then plays `impact`), impact (on the
-- target) or aura (on the caster or an ally). file: the model's FileDataID (spells/*.m2).
local function E(id, kind, file, name, extra)
    local e = { id = id, kind = kind, file = file, name = name }
    for k, v in pairs(extra or {}) do e[k] = v end
    return e
end

MC.FX_LIST = {
    -- Missiles
    E("fire_missile", "missile", 166128, "fireball_missile_high", { impact = "fire_hit" }),
    E("fel_missile", "missile", 166074, "fel_fireball_missile_high", { impact = "fire_hit2" }),
    E("frost_missile", "missile", 166214, "frostbolt", { impact = "frost_hit" }),
    E("frost_missile2", "missile", 1598570, "cfx_mage_frostbolt_missile", { impact = "frost_hit" }),
    E("blue_missile", "missile", 166127, "fireball_blue_missile_high", { impact = "frost_hit" }),
    E("lightning_missile", "missile", 166497, "lightningbolt_missile", { impact = "lightning_hit" }),
    E("arcane_missile", "missile", 165569, "arcane_missile", { impact = "arcane_hit" }),
    E("arcane_orb", "missile", 963808, "arcane_missile_orb", { impact = "arcane_hit" }),
    E("shadow_missile", "missile", 382336, "fireball_missile_shadow_high", { impact = "shadow_hit" }),
    E("twilight_missile", "missile", 367434, "twilight_fireball_missile_high", { impact = "shadow_hit2" }),
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
    E("holy_hit2", "impact", 916379, "explosion_holy_impact"),
    E("arcane_hit", "impact", 165578, "arcaneexplosion_impact_chest"),
    E("arcane_burst", "impact", 165576, "arcaneexplosion_base"),
    E("blood_hit", "impact", 426040, "bloodyexplosionblack"),
    E("blood_hit2", "impact", 165738, "bloodyexplosiongreen"),
    E("thunderclap", "impact", 167120, "thunderclap_cast_base"),
    E("shadow_dot", "impact", 166800, "shadow_impactdot_med_chest"),
    E("stun", "impact", 166988, "stunswirl_state_head"),
    -- Auras on the caster or an ally
    E("heal", "aura", 166327, "holy_impactdd_med_chest"),
    E("renew", "aura", 166697, "renew_chest"),
    E("holy_cast", "aura", 166339, "holy_precast_uber_hand"),
    E("nature_cast", "aura", 166604, "nature_precast_chest"),
    E("shield", "aura", 588344, "divineshield_v2_chest"),
    E("shield2", "aura", 165962, "divineshield_low_chest"),
    E("taunt", "aura", 167093, "taunt_head"),
    E("taunt_cast", "aura", 167092, "taunt_cast"),
    E("battleshout", "aura", 165658, "battleshout_cast_base"),
    E("levelup", "aura", 166464, "levelup"),
    E("resurrect", "aura", 166704, "resurrection_low_base"),
}
MC.FX = {}
for i, e in ipairs(MC.FX_LIST) do
    e.index = i
    MC.FX[e.id] = e
end

-- Starting values for every effect; the gallery changes them per effect.
-- size: the model frame in pixels; scale, x, y, z: the model in its frame; rx, ry, rz: turn in
-- degrees; dur: seconds (a missile's flight); aim: the axis a missile turns on to face its target.
MC.FX_DEFAULTS = { size = 160, scale = 1, x = 0, y = 0, z = 0, rx = 0, ry = 0, rz = 0, dur = 0.8, aim = 0 }
MC.FX_API = { "transform", "position" }

function MC.FxStore()
    local db = ns.db
    if not db then return {} end
    db.fxGallery = db.fxGallery or {}
    return db.fxGallery
end

-- An effect's values: the tuned ones from the gallery over the defaults.
function MC.FxTuning(id)
    local def = MC.FX[id]
    local saved = MC.FxStore()[id]
    local t = {}
    for k, v in pairs(MC.FX_DEFAULTS) do
        local own = def and def[k]
        if saved and saved[k] ~= nil then t[k] = saved[k] elseif own ~= nil then t[k] = own else t[k] = v end
    end
    return t
end

local function Vector(x, y, z)
    if CreateVector3D then return CreateVector3D(x, y, z) end
end

-- Places the model in its frame. "transform" uses SetTransform (frame-relative, the camera stays
-- put); "position" the older SetPosition / SetModelScale / SetFacing.
local function Pose(m, t, extraAngle)
    local api = MC.FxStore().api or "transform"
    local rx, ry, rz = math.rad(t.rx), math.rad(t.ry), math.rad(t.rz)
    if extraAngle then
        if t.aim == 1 then rx = rx + extraAngle elseif t.aim == 2 then ry = ry + extraAngle elseif t.aim == 3 then rz = rz + extraAngle end
    end
    if api == "transform" and m.SetTransform and CreateVector3D then
        pcall(m.SetTransform, m, Vector(t.x, t.y, t.z), Vector(rx, ry, rz), t.scale)
    else
        if m.ClearTransform then pcall(m.ClearTransform, m) end
        pcall(m.SetPosition, m, t.z, t.x, t.y)
        pcall(m.SetModelScale, m, t.scale)
        pcall(m.SetFacing, m, rz)
    end
end

function Module:FxPool()
    if not self.fxModels then
        self.fxModels = Media.Pool(function()
            local m = CreateFrame("PlayerModel", nil, self.fxLayer)
            m:SetFrameLevel(self.fxLayer:GetFrameLevel() + 2)
            -- The pose only holds once the model has loaded; set it again then.
            m:SetScript("OnModelLoaded", function(model)
                if model.pose then model.pose() end
            end)
            return m
        end, function(m)
            m.pose = nil
            pcall(m.ClearModel, m)
            m:Hide()
        end)
    end
    return self.fxModels
end

-- Plays effect `id` at x, y (board coordinates, y downwards). A missile flies to toX, toY and
-- then plays its impact there. Returns the effect's length in seconds (0 if unknown).
function Module:PlayFx(id, x, y, toX, toY, onDone)
    local def = MC.FX[id]
    if not def or not self.fxLayer then return 0 end
    local t = MC.FxTuning(id)
    local pool = self:FxPool()
    local m = pool.Acquire()
    m:SetSize(t.size, t.size)
    m:SetAlpha(1)
    m:Show()
    local ok = pcall(m.SetModel, m, def.file)
    local store = MC.FxStore()
    if MC.DEV then
        local loaded = m.GetModelFileID and m:GetModelFileID()
        store.loaded = store.loaded or {}
        store.loaded[id] = ok and (loaded == nil and "unknown" or loaded == def.file) or false
        store.info = { setTransform = m.SetTransform ~= nil, vector = CreateVector3D ~= nil }
    end
    local missile = def.kind == "missile" and toX ~= nil
    local angle = missile and math.atan2(-(toY - y), toX - x) or nil
    m.pose = function() Pose(m, t, angle) end
    m.pose()
    local function Place(px, py)
        m:ClearAllPoints()
        m:SetPoint("CENTER", self.fxLayer, "TOPLEFT", px, -py)
    end
    Place(x, y)
    local dur = math.max(0.1, t.dur)
    self.effects[#self.effects + 1] = {
        t = 0,
        update = function(e)
            local p = e.t / dur
            if p >= 1 then return false end
            if missile then
                Place(x + (toX - x) * p, y + (toY - y) * p - math.sin(p * math.pi) * 24)
            elseif p > 0.75 then
                m:SetAlpha(1 - (p - 0.75) / 0.25)
            end
            return true
        end,
        finish = function()
            pool.Release(m)
            if missile and def.impact and not self.clearingEffects then self:PlayFx(def.impact, toX, toY) end
            if onDone then onDone() end
        end,
    }
    return dur + (missile and def.impact and MC.FxTuning(def.impact).dur or 0)
end
