-- The sound of each ability in battle: the client's own spell and weapon sounds. The ability's icon
-- is the real spell's icon, so its name picks the sound; otherwise the school decides. An ability
-- can name its own with `sound = "key"`.

local _, ns = ...
local MC = ns.Mercenaries

-- Client sound files (FileDataIDs); one of each list is played at random.
local SOUNDS = {
    fireball = { 568461, 568429, 569449 },        -- sound/spells/fireballimpacta-c
    firebomb = { 568315, 568733, 569576 },        -- sound/spells/firebombimpact1-3
    frost = { 1631383, 1631384, 1631385, 1631386 }, -- sound/spells/spell_ma_revamp_frostbolt_impact_01-04
    frostnova = { 569378 },                       -- sound/spells/frostnova
    shadow = { 569474, 569471 },                  -- shadowfury_impact_base, shadowstrike_impact_chest
    curse = { 569079, 567957 },                   -- curse, curseoftounges
    pain = { 569138 },                            -- shadowwordpaintarget
    fear = { 567950 },                            -- fear
    lightning = { 568516 },                       -- lightningboltimpact
    earthquake = { 568874 },                      -- earthquakecamerashake
    acid = { 568594 },                            -- acidbreath
    nature = { 569708 },                          -- natureimpact
    rejuvenation = { 569594 },                    -- rejuvenation
    renew = { 569376 },                           -- renew
    heal = { 569570, 569419 },                    -- heal_low_base, flashheal_low_base
    holy = { 569402, 567966 },                    -- holybolt, holy_impactdd_uber_chest
    ward = { 569408 },                            -- holyward
    arcane = { 569631, 569565, 569554 },          -- arcanemissileimpact1a-c
    starfire = { 568008 },                        -- starfireimpact
    shout = { 568028 },                           -- battleshouttarget
    thunderclap = { 569222 },                     -- thunderclap
    whirlwind = { 568519 },                       -- whirlwindshort
    cleave = { 568227 },                          -- cleavetarget
    taunt = { 568268 },                           -- taunt
    stealth = { 569423 },                         -- stealth
    backstab = { 569555, 569273 },                -- backstab_impact_chest(dru)
    arrow = { 567672, 567681, 567671 },           -- item/weapons/bow/arrowhita-c
    shieldwall = { 569473 },                      -- shieldwalltarget
    weapon = {                                    -- 1h sword, axe and mace hits on flesh
        567880, 567881, 567883, 567621, 567620, 567632, 567738, 567741,
    },
}

-- Fragments of the icon's name (lower case) and their sound; the first match wins.
local BY_ICON = {
    { "fireball", "fireball" }, { "flamebolt", "fireball" }, { "firebolt", "fireball" }, { "fire_fire", "fireball" },
    { "selfdestruct", "firebomb" }, { "gizmo", "firebomb" },
    { "icestorm", "frostnova" }, { "frostward", "frostnova" },
    { "psychicscream", "fear" }, { "shadowwordpain", "pain" },
    { "curse", "curse" }, { "possession", "curse" }, { "charm", "curse" },
    { "shadowbolt", "shadow" }, { "deathcoil", "shadow" }, { "lifedrain", "shadow" }, { "abomination", "shadow" },
    { "callofbone", "shadow" }, { "raisedead", "shadow" },
    { "earthquake", "earthquake" }, { "acid", "acid" }, { "poison", "acid" },
    { "lightning", "lightning" }, { "callstorm", "lightning" }, { "stormreach", "lightning" }, { "earthshock", "lightning" },
    { "rejuvenation", "rejuvenation" }, { "regeneration", "rejuvenation" }, { "renew", "renew" },
    { "heal", "heal" }, { "layonhands", "heal" }, { "resurrection", "heal" }, { "holynova", "heal" },
    { "powerwordshield", "ward" }, { "divineintervention", "ward" }, { "sealofprotection", "ward" },
    { "devotionaura", "ward" }, { "innerfire", "ward" },
    { "starfire", "starfire" }, { "starfall", "starfire" },
    { "battleshout", "shout" }, { "rallyingcry", "shout" }, { "warcry", "shout" }, { "bannerpvp", "shout" },
    { "unholyfrenzy", "shout" }, { "bloodlust", "shout" }, { "frenzy", "shout" }, { "rampage", "shout" },
    { "thunderclap", "thunderclap" }, { "warstomp", "thunderclap" },
    { "whirlwind", "whirlwind" }, { "cleave", "cleave" },
    { "challange", "taunt" }, { "taunt", "taunt" },
    { "vanish", "stealth" }, { "stealth", "stealth" },
    { "backstab", "backstab" }, { "ambush", "backstab" }, { "kidneyshot", "backstab" }, { "gouge", "backstab" },
    { "weapon_bow", "arrow" }, { "snipershot", "arrow" }, { "marksmanship", "arrow" }, { "impalingbolt", "arrow" },
    { "spear", "arrow" }, { "moonglaive", "arrow" },
    { "shieldwall", "shieldwall" }, { "defend", "shieldwall" }, { "defensivestance", "shieldwall" },
}
local BY_SCHOOL = {
    fire = "fireball", frost = "frost", shadow = "shadow", nature = "nature", holy = "holy", arcane = "arcane",
    physical = "weapon",
}

local cache = {}

-- The sound key of an ability (also used by the tests).
function MC.AbilitySoundKey(abilityId)
    if cache[abilityId] then return cache[abilityId] end
    local def = MC.Abilities[abilityId]
    if not def then return nil end
    local key = def.sound
    if not key then
        local icon = def.icon:lower()
        for _, pair in ipairs(BY_ICON) do
            if icon:find(pair[1], 1, true) then
                key = pair[2]
                break
            end
        end
    end
    key = key or BY_SCHOOL[def.school] or "weapon"
    cache[abilityId] = key
    return key
end

MC.ABILITY_SOUNDS = SOUNDS

-- Plays the ability's sound; returns true when a sound was played.
function MC.AbilitySound(abilityId)
    if ns.db and not ns.db.sound then return false end
    local ids = SOUNDS[MC.AbilitySoundKey(abilityId)]
    if not ids then return false end
    PlaySoundFile(ids[math.random(#ids)], "SFX")
    return true
end
