-- Every ability in Mercenaries: the mercenaries' own and those of the creatures they face.
-- Values are for a level 60 user at rank I; Combat scales them. Effects are listed in order:
--   { "damage", v, to, hits, school }  { "attack", v, to, noRetaliate }  { "heal", v, to }
--   { "shield", to }  { "absorb", v, to }  { "taunt", turns, to }  { "stealth" }  { "stun", to }
--   { "dot", v, turns, to, school }  { "hot", v, turns, to }  { "buff", k, v, turns, to }
--   { "maxhp", v, to }  { "cleanse", to }
-- `to` defaults to the chosen target: target, self, all, allies, others, adjacent, random, lowest.

local _, ns = ...
ns.Mercenaries = ns.Mercenaries or {}
local MC = ns.Mercenaries

local A = {}
MC.Abilities = A

-- Positional fields are easier to read in the tables; Combat reads them by name.
local function E(kind, ...)
    local args = { ... }
    local e = { kind }
    if kind == "damage" then
        e.v, e.to, e.hits, e.school = args[1], args[2], args[3], args[4]
    elseif kind == "attack" then
        e.v, e.to, e.noRetaliate = args[1], args[2], args[3]
    elseif kind == "heal" or kind == "absorb" or kind == "maxhp" then
        e.v, e.to = args[1], args[2]
    elseif kind == "shield" or kind == "stun" or kind == "stealth" or kind == "cleanse" then
        e.to = args[1]
    elseif kind == "taunt" then
        e.turns, e.to = args[1], args[2]
    elseif kind == "dot" then
        e.v, e.turns, e.to, e.school = args[1], args[2], args[3], args[4]
    elseif kind == "hot" then
        e.v, e.turns, e.to = args[1], args[2], args[3]
    elseif kind == "buff" then
        e.k, e.v, e.turns, e.to = args[1], args[2], args[3], args[4]
    end
    return e
end

local function Define(id, icon, school, speed, cd, target, effects, extra)
    local def = {
        id = id, icon = "Interface\\Icons\\" .. icon, school = school, speed = speed, cd = cd,
        target = target, effects = effects,
    }
    for k, v in pairs(extra or {}) do def[k] = v end
    A[id] = def
end

-- Protectors -----------------------------------------------------------------------------

Define("cairne_1", "Ability_Warrior_Sunder", "physical", 5, 0, "enemy", { E("attack", 4) })
Define("cairne_2", "Ability_WarStomp", "physical", 7, 2, "none", { E("damage", 5, "all"), E("buff", "speed", 2, 2, "all") }, { harmful = true })
Define("cairne_3", "Spell_Nature_StoneSkinTotem", "nature", 2, 2, "none", { E("taunt", 2), E("maxhp", 14, "self") })

Define("bolvar_1", "Spell_Holy_RighteousFury", "holy", 5, 0, "enemy", { E("attack", 3), E("heal", 4, "self") })
Define("bolvar_2", "Spell_Holy_DivineIntervention", "holy", 3, 2, "ally", { E("shield") })
Define("bolvar_3", "Ability_Warrior_BattleShout", "physical", 6, 2, "none", { E("buff", "atk", 3, nil, "allies"), E("taunt", 1) })

Define("magni_1", "Ability_ThunderClap", "physical", 6, 0, "enemy", { E("attack", 5) })
Define("magni_2", "Spell_Shadow_UnholyStrength", "physical", 2, 3, "none", { E("cleanse", "self"), E("buff", "taken", -0.5, 2, "self") })
Define("magni_3", "Ability_Warrior_Challange", "physical", 4, 2, "none", { E("taunt", 2), E("absorb", 16, "self"), E("damage", 3, "all") }, { harmful = true })

Define("tirion_1", "Spell_Holy_SealOfWrath", "holy", 5, 0, "enemy", { E("attack", 4) })
Define("tirion_2", "Spell_Holy_SealOfMight", "holy", 3, 3, "enemy", { E("damage", 5), E("stun") })
Define("tirion_3", "Spell_Holy_LayOnHands", "holy", 8, 3, "ally", { E("heal", 45) })

Define("eitrigg_1", "Ability_Warrior_SavageBlow", "physical", 6, 0, "enemy", { E("attack", 6) })
Define("eitrigg_2", "Ability_Warrior_ShieldWall", "physical", 1, 3, "none", { E("taunt", 2), E("buff", "taken", -0.5, 2, "self") })
Define("eitrigg_3", "Ability_Warrior_Cleave", "physical", 7, 1, "enemy", { E("attack", 1), E("damage", 6, "adjacent") })

Define("taelan_1", "Spell_Holy_HolyBolt", "holy", 5, 0, "enemy", { E("attack", 2), E("heal", 6, "lowest") })
Define("taelan_2", "Spell_Holy_InnerFire", "holy", 6, 2, "none", { E("damage", 5, "all") }, { harmful = true })
Define("taelan_3", "Spell_Holy_DevotionAura", "holy", 3, 3, "none", { E("buff", "taken", -0.25, 3, "allies") })

Define("saurfang_1", "Ability_Warrior_Revenge", "physical", 5, 0, "enemy", { E("attack", 5) })
Define("saurfang_2", "Ability_Warrior_RallyingCry", "physical", 3, 2, "none", { E("maxhp", 8, "allies"), E("buff", "atk", 2, nil, "allies") })
Define("saurfang_3", "Ability_Warrior_DefensiveStance", "physical", 2, 3, "none", { E("taunt", 2), E("heal", 20, "self") })

Define("windsor_1", "INV_Shield_05", "physical", 4, 0, "enemy", { E("attack", 3), E("buff", "dmg", -0.2, 2) })
Define("windsor_2", "INV_BannerPVP_02", "holy", 3, 2, "none", { E("absorb", 8, "allies") })
Define("windsor_3", "Ability_Defend", "physical", 1, 3, "none", { E("taunt", 2), E("buff", "taken", -0.3, 2, "self") })

-- Fighters -------------------------------------------------------------------------------

Define("rexxar_1", "Ability_Druid_Maul", "physical", 5, 0, "enemy", { E("attack", 4) })
Define("rexxar_2", "Ability_Hunter_Pet_Bear", "physical", 2, 3, "none", { E("buff", "atkPct", 0.6, 3, "self"), E("taunt", 1) })
Define("rexxar_3", "Ability_UpgradeMoonGlaive", "physical", 6, 1, "enemy", { E("damage", 7), E("damage", 5, "adjacent") })

Define("sylvanas_1", "INV_Spear_07", "physical", 7, 0, "enemy", { E("damage", 11) })
Define("sylvanas_2", "Ability_ImpalingBolt", "shadow", 4, 1, "enemy", { E("damage", 4), E("dot", 4, 3) })
Define("sylvanas_3", "Spell_Shadow_PsychicScream", "shadow", 8, 2, "none", { E("damage", 6, "all"), E("buff", "dmg", -0.3, 2, "all") }, { harmful = true })

Define("voljin_1", "INV_Spear_04", "physical", 4, 0, "enemy", { E("damage", 9) })
Define("voljin_2", "Spell_Shadow_Charm", "shadow", 3, 3, "enemy", { E("stun"), E("buff", "taken", 0.3, 2) })
Define("voljin_3", "Spell_Nature_MagicImmunity", "nature", 5, 1, "ally", { E("heal", 14), E("hot", 4, 2) })

Define("shandris_1", "INV_Weapon_Bow_07", "physical", 3, 0, "enemy", { E("damage", 9) })
Define("shandris_2", "Ability_Hunter_SniperShot", "physical", 2, 2, "enemy", { E("buff", "taken", 0.35, 3) })
Define("shandris_3", "Ability_Marksmanship", "physical", 7, 2, "none", { E("damage", 6, "all") }, { harmful = true })

Define("mankrik_1", "Ability_Warrior_DecisiveStrike", "physical", 4, 0, "enemy", { E("attack", 3) })
Define("mankrik_2", "Spell_Shadow_UnholyFrenzy", "physical", 2, 1, "none", { E("buff", "atk", 4, nil, "self"), E("buff", "taken", 0.1, nil, "self") })
Define("mankrik_3", "Ability_Whirlwind", "physical", 7, 2, "none", { E("attack", 0, "all", true) }, { harmful = true })

Define("renzik_1", "Spell_Shadow_RitualOfSacrifice", "physical", 3, 0, "enemy", { E("damage", 9) })
Define("renzik_2", "Ability_Gouge", "physical", 2, 3, "enemy", { E("damage", 4), E("stun") })
Define("renzik_3", "Ability_Vanish", "shadow", 1, 2, "none", { E("stealth"), E("buff", "ambush", 1.0, nil, "self") })

Define("jorach_1", "Ability_BackStab", "physical", 3, 0, "enemy", { E("damage", 10) })
Define("jorach_2", "Ability_Rogue_KidneyShot", "physical", 2, 3, "enemy", { E("damage", 3), E("stun") })
Define("jorach_3", "Ability_Warrior_PunishingBlow", "physical", 5, 2, "enemy", { E("damage", 7), E("damage", 5, "adjacent") })

Define("natpagle_1", "INV_Spear_02", "physical", 5, 0, "enemy", { E("damage", 9) })
Define("natpagle_2", "INV_Misc_Fish_14", "nature", 4, 1, "ally", { E("heal", 12) })
Define("natpagle_3", "Ability_Ensnare", "physical", 3, 2, "none", { E("damage", 2, "all"), E("buff", "speed", 4, 2, "all") }, { harmful = true })

-- Casters --------------------------------------------------------------------------------

Define("jaina_1", "Spell_Fire_FlameBolt", "fire", 6, 0, "enemy", { E("damage", 10), E("dot", 2, 2) })
Define("jaina_2", "Spell_Frost_FrostBolt02", "frost", 4, 1, "enemy", { E("damage", 8), E("buff", "speed", 3, 2) })
Define("jaina_3", "Spell_Frost_IceStorm", "frost", 8, 2, "none", { E("damage", 6, "all") }, { harmful = true })

Define("thrall_1", "Spell_Nature_ChainLightning", "nature", 6, 0, "enemy", { E("damage", 9), E("damage", 5, "adjacent") })
Define("thrall_2", "Spell_Nature_LightningShield", "nature", 3, 1, "ally", { E("buff", "thorns", 5, 3), E("absorb", 8) })
Define("thrall_3", "Spell_Nature_Windfury", "nature", 1, 3, "none", { E("buff", "speed", -3, 3, "allies"), E("buff", "dmg", 0.2, 3, "allies") })

Define("tyrande_1", "Spell_Arcane_StarFire", "arcane", 5, 0, "enemy", { E("damage", 10) })
Define("tyrande_2", "Spell_Holy_Heal", "holy", 4, 0, "ally", { E("heal", 15) })
Define("tyrande_3", "Spell_Holy_PrayerOfHealing02", "holy", 7, 2, "none", { E("heal", 10, "allies") })

Define("magatha_1", "Spell_Nature_Lightning", "nature", 5, 0, "enemy", { E("damage", 10) })
Define("magatha_2", "Spell_Shadow_CurseOfMannoroth", "shadow", 3, 2, "enemy", { E("buff", "dmg", -0.4, 2), E("damage", 4) })
Define("magatha_3", "Spell_Fire_SearingTotem", "fire", 6, 2, "none", { E("dot", 4, 3, "all") }, { harmful = true })

Define("benedictus_1", "Spell_Holy_HolySmite", "holy", 5, 0, "enemy", { E("damage", 9) })
Define("benedictus_2", "Spell_Holy_PowerWordShield", "holy", 2, 1, "ally", { E("absorb", 16) })
Define("benedictus_3", "Spell_Holy_HolyNova", "holy", 6, 1, "none", { E("damage", 4, "all"), E("heal", 5, "allies") }, { harmful = true })

Define("hamuul_1", "Spell_Nature_AbolishMagic", "nature", 4, 0, "enemy", { E("damage", 9) })
Define("hamuul_2", "Spell_Nature_Rejuvenation", "nature", 3, 0, "ally", { E("hot", 6, 3) })
Define("hamuul_3", "Spell_Nature_StrangleVines", "nature", 5, 3, "enemy", { E("stun"), E("dot", 4, 2) })

Define("fandral_1", "Spell_Nature_StarFall", "arcane", 5, 0, "enemy", { E("damage", 7), E("dot", 3, 2) })
Define("fandral_2", "Spell_Nature_Thorns", "nature", 2, 1, "ally", { E("buff", "thorns", 5, 3) })
Define("fandral_3", "Spell_Nature_Cyclone", "nature", 7, 2, "none", { E("damage", 5, "all"), E("buff", "speed", 2, 2, "all") }, { harmful = true })

Define("drekthar_1", "Spell_Frost_FrostShock", "frost", 4, 0, "enemy", { E("damage", 8), E("buff", "speed", 2, 2) })
Define("drekthar_2", "Spell_Nature_HealingWaveGreater", "nature", 5, 1, "ally", { E("heal", 14) })
Define("drekthar_3", "Spell_Frost_FrostWard", "frost", 6, 2, "none", { E("damage", 5, "all"), E("buff", "dmg", -0.2, 2, "all") }, { harmful = true })

-- Creatures --------------------------------------------------------------------------------
-- Shared by the zone foes; `ai` weights how often the enemy picks it.

Define("e_strike", "Ability_MeleeDamage", "physical", 5, 0, "enemy", { E("attack", 2) })
Define("e_bite", "Ability_Druid_Rake", "physical", 4, 0, "enemy", { E("attack", 3) })
Define("e_claw", "Ability_Druid_Swipe", "physical", 5, 1, "enemy", { E("damage", 5), E("dot", 3, 2) })
Define("e_slam", "Ability_Warrior_PunishingBlow", "physical", 7, 1, "enemy", { E("damage", 10) })
Define("e_cleave", "Ability_Warrior_Cleave", "physical", 7, 2, "enemy", { E("attack", 0), E("damage", 4, "adjacent") })
Define("e_frenzy", "Ability_GhoulFrenzy", "physical", 6, 1, "none", { E("damage", 5, "random", 2) }, { harmful = true })
Define("e_shieldbash", "Ability_Warrior_ShieldBash", "physical", 3, 3, "enemy", { E("damage", 4), E("stun") }, { ai = 0.7 })
Define("e_enrage", "Spell_Shadow_UnholyFrenzy", "physical", 2, 2, "none", { E("buff", "atkPct", 0.4, 2, "self") }, { ai = 0.6 })
Define("e_rally", "Ability_Warrior_BattleShout", "physical", 6, 2, "none", { E("buff", "atk", 3, nil, "allies") }, { ai = 0.6 })
Define("e_guard", "Ability_Defend", "physical", 2, 2, "none", { E("taunt", 1), E("absorb", 8, "self") }, { ai = 0.7 })
Define("e_harden", "Spell_Nature_StoneClawTotem", "physical", 1, 2, "none", { E("buff", "taken", -0.4, 1, "self") }, { ai = 0.5 })
Define("e_web", "Spell_Nature_Web", "nature", 2, 3, "enemy", { E("stun") }, { ai = 0.6 })
Define("e_poison", "Ability_PoisonSting", "nature", 4, 1, "enemy", { E("dot", 4, 3) })
Define("e_firebolt", "Spell_Fire_FireBolt", "fire", 5, 0, "enemy", { E("damage", 8) })
Define("e_frostbolt", "Spell_Frost_FrostBolt", "frost", 4, 1, "enemy", { E("damage", 6), E("buff", "speed", 2, 2) })
Define("e_shadowbolt", "Spell_Shadow_ShadowBolt", "shadow", 5, 0, "enemy", { E("damage", 8) })
Define("e_lightning", "Spell_Nature_Lightning", "nature", 5, 0, "enemy", { E("damage", 8) })
Define("e_holyfire", "Spell_Holy_SearingLight", "holy", 6, 1, "enemy", { E("damage", 6), E("dot", 3, 2) })
Define("e_drain", "Spell_Shadow_LifeDrain02", "shadow", 5, 1, "enemy", { E("damage", 6), E("heal", 5, "self") })
Define("e_curse", "Spell_Shadow_CurseOfSargeras", "shadow", 3, 2, "enemy", { E("buff", "dmg", -0.3, 2) }, { ai = 0.6 })
Define("e_heal", "Spell_Holy_FlashHeal", "holy", 6, 1, "ally", { E("heal", 12) })
Define("e_renew", "Spell_Nature_Rejuvenation", "nature", 3, 1, "ally", { E("hot", 5, 2) })
Define("e_dive", "Ability_Hunter_Pet_Bat", "physical", 3, 0, "enemy", { E("damage", 6) })
Define("e_howl", "Ability_Hunter_Pet_Wolf", "physical", 3, 2, "none", { E("buff", "dmg", 0.3, 2, "allies") }, { ai = 0.6 })
Define("e_trample", "Ability_Hunter_Pet_Boar", "physical", 6, 1, "enemy", { E("attack", 4) })
Define("e_explode", "Spell_Fire_SelfDestruct", "fire", 8, 3, "none", { E("damage", 7, "all") }, { harmful = true, ai = 0.5 })
Define("e_net", "Ability_Ensnare", "physical", 2, 3, "enemy", { E("buff", "speed", 4, 2), E("damage", 3) }, { ai = 0.6 })
Define("e_plague", "Spell_Shadow_CallofBone", "shadow", 6, 2, "none", { E("dot", 3, 3, "all") }, { harmful = true, ai = 0.7 })
Define("e_wave", "Spell_Frost_SummonWaterElemental", "frost", 6, 2, "none", { E("damage", 4, "all") }, { harmful = true, ai = 0.7 })

Define("e_fireball", "Spell_Fire_FlameBolt", "fire", 6, 1, "enemy", { E("damage", 8), E("dot", 2, 2) })
Define("e_volley", "Spell_Shadow_ShadowBolt", "shadow", 7, 2, "none", { E("damage", 4, "all") }, { harmful = true, ai = 0.7 })
Define("e_thunderclap", "Ability_ThunderClap", "physical", 6, 2, "none", { E("damage", 4, "all"), E("buff", "speed", 2, 2, "all") }, { harmful = true, ai = 0.7 })
Define("e_chainlight", "Spell_Nature_ChainLightning", "nature", 6, 1, "enemy", { E("damage", 6), E("damage", 3, "adjacent") })
Define("e_sunder", "Ability_Warrior_Sunder", "physical", 4, 2, "enemy", { E("attack", 1), E("buff", "taken", 0.25, 2) }, { ai = 0.7 })
Define("e_bloodlust", "Spell_Nature_BloodLust", "nature", 2, 3, "none", { E("buff", "speed", -2, 2, "allies"), E("buff", "dmg", 0.15, 2, "allies") }, { ai = 0.6 })
Define("e_shadowword", "Spell_Shadow_ShadowWordPain", "shadow", 4, 1, "enemy", { E("dot", 5, 3) })
Define("e_flamestrike", "Spell_Fire_SelfDestruct", "fire", 8, 2, "none", { E("damage", 3, "all"), E("dot", 2, 2, "all") }, { harmful = true, ai = 0.7 })

-- Bosses ----------------------------------------------------------------------------------------
-- Every boss has three abilities; heroic adds the fourth.

Define("hogger_1", "Ability_Druid_Maul", "physical", 5, 0, "enemy", { E("attack", 5) })
Define("hogger_2", "Ability_Hunter_Pet_Hyena", "physical", 3, 2, "none", { E("buff", "atk", 3, nil, "allies"), E("taunt", 1) }, { ai = 0.7 })
Define("hogger_3", "Ability_Whirlwind", "physical", 7, 2, "none", { E("attack", 0, "all", true) }, { harmful = true })
Define("hogger_h", "Spell_Nature_Regeneration", "nature", 1, 3, "none", { E("heal", 25, "self"), E("absorb", 12, "self") })

Define("thermaplugg_1", "INV_Gizmo_02", "fire", 5, 0, "enemy", { E("damage", 9) })
Define("thermaplugg_2", "Spell_Fire_SelfDestruct", "fire", 8, 2, "none", { E("damage", 6, "all") }, { harmful = true })
Define("thermaplugg_3", "INV_Gizmo_01", "physical", 2, 3, "none", { E("absorb", 20, "self"), E("taunt", 1) }, { ai = 0.6 })
Define("thermaplugg_h", "Spell_Nature_Lightning", "nature", 3, 2, "enemy", { E("damage", 6), E("stun") })

Define("whitemane_1", "Spell_Holy_HolySmite", "holy", 5, 0, "enemy", { E("damage", 9) })
Define("whitemane_2", "Spell_Holy_FlashHeal", "holy", 6, 1, "ally", { E("heal", 18) })
Define("whitemane_3", "Spell_Shadow_PsychicScream", "shadow", 3, 3, "none", { E("damage", 3, "all"), E("buff", "speed", 3, 2, "all") }, { harmful = true })
Define("whitemane_h", "Spell_Holy_Resurrection", "holy", 9, 4, "none", { E("heal", 20, "allies") })

Define("melenas_1", "Spell_Shadow_ShadowBolt", "shadow", 5, 0, "enemy", { E("damage", 9) })
Define("melenas_2", "Spell_Shadow_AbominationExplosion", "shadow", 4, 2, "enemy", { E("dot", 5, 3) })
Define("melenas_3", "Spell_Shadow_DeathCoil", "shadow", 6, 2, "enemy", { E("damage", 7), E("heal", 7, "self") })
Define("melenas_h", "Spell_Shadow_CurseOfMannoroth", "shadow", 2, 3, "none", { E("buff", "dmg", -0.25, 2, "all") }, { harmful = true })

Define("zalazane_1", "Spell_Shadow_ShadowWordPain", "shadow", 5, 0, "enemy", { E("damage", 8), E("dot", 2, 2) })
Define("zalazane_2", "Spell_Shadow_Charm", "shadow", 3, 3, "enemy", { E("stun"), E("damage", 3) })
Define("zalazane_3", "Spell_Nature_HealingWaveGreater", "nature", 6, 1, "ally", { E("heal", 14) })
Define("zalazane_h", "Spell_Shadow_UnholyFrenzy", "shadow", 2, 3, "none", { E("buff", "atkPct", 0.5, 3, "allies") })

Define("arrachea_1", "Ability_Hunter_Pet_Boar", "physical", 6, 0, "enemy", { E("attack", 5) })
Define("arrachea_2", "Ability_WarStomp", "physical", 7, 2, "none", { E("damage", 5, "all"), E("buff", "speed", 2, 2, "all") }, { harmful = true })
Define("arrachea_3", "Ability_Druid_Bash", "physical", 3, 3, "enemy", { E("damage", 5), E("stun") })
Define("arrachea_h", "Ability_Racial_Avatar", "physical", 2, 3, "none", { E("buff", "atkPct", 0.5, 2, "self"), E("absorb", 15, "self") })

Define("lorthuna_1", "Spell_Nature_CallStorm", "nature", 5, 0, "enemy", { E("damage", 9) })
Define("lorthuna_2", "Spell_Nature_Cyclone", "nature", 4, 3, "enemy", { E("stun"), E("damage", 4) })
Define("lorthuna_3", "Spell_Holy_Renew", "holy", 6, 1, "ally", { E("heal", 12), E("hot", 4, 2) })
Define("lorthuna_h", "Spell_Nature_StormReach", "nature", 8, 2, "none", { E("damage", 5, "all") }, { harmful = true })

Define("vancleef_1", "Ability_Warrior_Disarm", "physical", 4, 0, "enemy", { E("attack", 4) })
Define("vancleef_2", "Ability_Rogue_Ambush", "physical", 3, 2, "enemy", { E("damage", 12) })
Define("vancleef_3", "Ability_Warrior_BattleShout", "physical", 6, 2, "none", { E("buff", "atk", 3, nil, "allies") }, { ai = 0.7 })
Define("vancleef_h", "Ability_Rogue_Sprint", "physical", 1, 3, "none", { E("buff", "speed", -3, 2, "allies") })

Define("galgosh_1", "Ability_Warrior_PunishingBlow", "physical", 6, 0, "enemy", { E("attack", 5) })
Define("galgosh_2", "Spell_Nature_EarthBind", "nature", 4, 2, "enemy", { E("buff", "speed", 4, 2), E("damage", 5) })
Define("galgosh_3", "Ability_Warrior_Challange", "physical", 2, 2, "none", { E("taunt", 1), E("absorb", 14, "self") }, { ai = 0.7 })
Define("galgosh_h", "Spell_Nature_Earthquake", "nature", 7, 2, "none", { E("damage", 6, "all") }, { harmful = true })

Define("arugal_1", "Spell_Shadow_ShadowBolt", "shadow", 5, 0, "enemy", { E("damage", 10) })
Define("arugal_2", "Spell_Shadow_Teleport", "arcane", 2, 3, "none", { E("stealth"), E("heal", 10, "self") }, { ai = 0.5 })
Define("arugal_3", "Spell_Shadow_ShadowWordPain", "shadow", 7, 2, "none", { E("dot", 4, 2, "all") }, { harmful = true })
Define("arugal_h", "Spell_Shadow_Curse", "shadow", 3, 2, "enemy", { E("buff", "taken", 0.5, 2), E("damage", 4) })

Define("murkdeep_1", "INV_Spear_04", "physical", 5, 0, "enemy", { E("attack", 4) })
Define("murkdeep_2", "Spell_Frost_SummonWaterElemental", "frost", 6, 2, "none", { E("damage", 5, "all") }, { harmful = true })
Define("murkdeep_3", "Ability_Ensnare", "physical", 2, 3, "enemy", { E("buff", "speed", 4, 2), E("damage", 4) })
Define("murkdeep_h", "Spell_Shadow_UnholyFrenzy", "physical", 3, 2, "none", { E("buff", "dmg", 0.4, 2, "allies") })

Define("kodobane_1", "Ability_Warrior_DecisiveStrike", "physical", 5, 0, "enemy", { E("attack", 5) })
Define("kodobane_2", "Ability_Hunter_Pet_Boar", "physical", 7, 1, "enemy", { E("damage", 7), E("damage", 4, "adjacent") })
Define("kodobane_3", "Spell_Nature_Lightning", "nature", 4, 2, "enemy", { E("damage", 6), E("stun") })
Define("kodobane_h", "Ability_Warrior_Rampage", "physical", 2, 3, "none", { E("buff", "atkPct", 0.5, 3, "self") })

Define("gathilzogg_1", "Ability_Warrior_Cleave", "physical", 6, 0, "enemy", { E("attack", 3), E("damage", 4, "adjacent") })
Define("gathilzogg_2", "Ability_Warrior_BattleShout", "physical", 5, 2, "none", { E("buff", "atk", 4, nil, "allies") }, { ai = 0.7 })
Define("gathilzogg_3", "Ability_Warrior_Charge", "physical", 2, 2, "enemy", { E("damage", 6), E("stun") })
Define("gathilzogg_h", "Ability_Warrior_ShieldWall", "physical", 1, 3, "none", { E("buff", "taken", -0.5, 2, "self"), E("taunt", 2) })

Define("gerenzo_1", "INV_Gizmo_02", "fire", 5, 0, "enemy", { E("damage", 9) })
Define("gerenzo_2", "Spell_Fire_SelfDestruct", "fire", 7, 2, "none", { E("damage", 6, "all") }, { harmful = true })
Define("gerenzo_3", "INV_Misc_Wrench_01", "physical", 3, 1, "ally", { E("heal", 12), E("absorb", 6) })
Define("gerenzo_h", "INV_Gizmo_01", "fire", 2, 3, "none", { E("buff", "speed", -3, 2, "allies"), E("buff", "dmg", 0.3, 2, "allies") })

Define("akumai_1", "Ability_Druid_Rake", "physical", 5, 0, "enemy", { E("attack", 5) })
Define("akumai_2", "Spell_Nature_Acid_01", "nature", 6, 2, "none", { E("dot", 4, 3, "all") }, { harmful = true })
Define("akumai_3", "Ability_Hunter_Pet_Turtle", "physical", 2, 3, "none", { E("buff", "taken", -0.5, 2, "self"), E("heal", 15, "self") }, { ai = 0.6 })
Define("akumai_h", "Spell_Frost_FrostShock", "frost", 3, 2, "enemy", { E("damage", 8), E("buff", "speed", 4, 2) })

Define("stitches_1", "Ability_Warrior_PunishingBlow", "physical", 6, 0, "enemy", { E("attack", 6) })
Define("stitches_2", "Spell_Shadow_CallofBone", "shadow", 5, 2, "none", { E("dot", 4, 3, "all") }, { harmful = true })
Define("stitches_3", "Spell_Shadow_UnholyFrenzy", "physical", 2, 2, "none", { E("buff", "atkPct", 0.5, 2, "self") })
Define("stitches_h", "Spell_Shadow_AntiShadow", "shadow", 1, 3, "none", { E("absorb", 25, "self"), E("taunt", 1) })

Define("nekrosh_1", "Ability_Warrior_Cleave", "physical", 6, 0, "enemy", { E("attack", 4), E("damage", 4, "adjacent") })
Define("nekrosh_2", "Spell_Fire_Fireball02", "fire", 5, 1, "enemy", { E("damage", 10) })
Define("nekrosh_3", "Ability_Warrior_WarCry", "physical", 3, 2, "none", { E("buff", "dmg", 0.3, 2, "allies") }, { ai = 0.7 })
Define("nekrosh_h", "Spell_Fire_Fire", "fire", 7, 2, "none", { E("damage", 5, "all"), E("dot", 2, 2, "all") }, { harmful = true })

Define("burnside_1", "Spell_Holy_HolySmite", "holy", 5, 0, "enemy", { E("damage", 9) })
Define("burnside_2", "Spell_Holy_SealOfProtection", "holy", 2, 2, "ally", { E("shield") }, { ai = 0.8 })
Define("burnside_3", "Spell_Holy_PrayerOfHealing02", "holy", 7, 2, "none", { E("heal", 10, "allies") }, { ai = 0.8 })
Define("burnside_h", "Spell_Holy_SealOfMight", "holy", 3, 3, "enemy", { E("damage", 5), E("stun") })

Define("arnak_1", "Ability_WarStomp", "physical", 6, 0, "enemy", { E("attack", 5) })
Define("arnak_2", "Spell_Nature_EarthBindTotem", "nature", 3, 2, "none", { E("damage", 4, "all"), E("buff", "speed", 2, 2, "all") }, { harmful = true })
Define("arnak_3", "Spell_Nature_StoneSkinTotem", "nature", 2, 3, "none", { E("taunt", 2), E("absorb", 18, "self") }, { ai = 0.7 })
Define("arnak_h", "Spell_Fire_SearingTotem", "fire", 5, 2, "none", { E("dot", 4, 3, "all") }, { harmful = true })

Define("perenolde_1", "Spell_Shadow_ShadowBolt", "shadow", 5, 0, "enemy", { E("damage", 9) })
Define("perenolde_2", "Ability_Warrior_BattleShout", "physical", 4, 2, "none", { E("buff", "atk", 3, nil, "allies"), E("heal", 10, "self") }, { ai = 0.7 })
Define("perenolde_3", "Spell_Shadow_CurseOfTounges", "shadow", 3, 2, "none", { E("buff", "dmg", -0.3, 2, "all") }, { harmful = true, ai = 0.7 })
Define("perenolde_h", "Spell_Shadow_Possession", "shadow", 2, 3, "enemy", { E("stun"), E("damage", 5) })

Define("myzrael_1", "Spell_Nature_EarthShock", "nature", 5, 0, "enemy", { E("damage", 9) })
Define("myzrael_2", "Spell_Nature_Earthquake", "nature", 7, 2, "none", { E("damage", 6, "all") }, { harmful = true })
Define("myzrael_3", "Spell_Holy_PowerWordShield", "arcane", 3, 3, "none", { E("absorb", 10, "allies") }, { ai = 0.7 })
Define("myzrael_h", "Spell_Nature_StoneClawTotem", "nature", 4, 3, "none", { E("damage", 4, "all"), E("stun", "random") }, { harmful = true })

Define("theradras_1", "Spell_Nature_Earthquake", "physical", 6, 0, "enemy", { E("attack", 6) })
Define("theradras_2", "Spell_Nature_Acid_01", "nature", 5, 2, "none", { E("damage", 5, "all"), E("buff", "dmg", -0.2, 2, "all") }, { harmful = true })
Define("theradras_3", "Spell_Shadow_Charm", "nature", 3, 3, "enemy", { E("stun"), E("taunt", 1, "self") }, { ai = 0.7 })
Define("theradras_h", "Spell_Nature_Regeneration", "nature", 1, 3, "none", { E("heal", 28, "self") })

Define("necrokhan_1", "Spell_Shadow_ShadowBolt", "shadow", 5, 0, "enemy", { E("damage", 8), E("heal", 4, "self") })
Define("necrokhan_2", "Spell_Shadow_RaiseDead", "shadow", 3, 3, "none", { E("absorb", 10, "allies") }, { ai = 0.7 })
Define("necrokhan_3", "Spell_Shadow_CallofBone", "shadow", 6, 2, "none", { E("dot", 4, 3, "all") }, { harmful = true })
Define("necrokhan_h", "Spell_Shadow_DeathCoil", "shadow", 4, 3, "enemy", { E("damage", 7), E("stun") })

Define("clugfist_1", "INV_Mace_01", "physical", 6, 0, "enemy", { E("attack", 6) })
Define("clugfist_2", "Ability_WarStomp", "physical", 7, 2, "none", { E("damage", 6, "all") }, { harmful = true })
Define("clugfist_3", "Spell_Shadow_UnholyFrenzy", "physical", 2, 2, "none", { E("buff", "atkPct", 0.5, 2, "self"), E("taunt", 1) }, { ai = 0.7 })
Define("clugfist_h", "Ability_Warrior_PunishingBlow", "physical", 4, 3, "enemy", { E("damage", 6), E("stun") })

Define("bangalash_1", "Ability_Druid_Rake", "physical", 4, 0, "enemy", { E("attack", 6) })
Define("bangalash_2", "Ability_Druid_Ravage", "physical", 5, 1, "enemy", { E("dot", 5, 3) })
Define("bangalash_3", "Ability_Hunter_Pet_Cat", "physical", 3, 2, "none", { E("buff", "dmg", 0.3, 2, "allies") }, { ai = 0.7 })
Define("bangalash_h", "Ability_Druid_SupriseAttack", "physical", 2, 3, "enemy", { E("damage", 6), E("stun") })

Define("archaedas_1", "Spell_Nature_Earthquake", "physical", 6, 0, "enemy", { E("attack", 5) })
Define("archaedas_2", "Spell_Nature_StoneClawTotem", "nature", 3, 3, "none", { E("absorb", 12, "allies") }, { ai = 0.7 })
Define("archaedas_3", "Ability_Warrior_DefensiveStance", "physical", 2, 2, "none", { E("taunt", 2), E("buff", "taken", -0.4, 2, "self") }, { ai = 0.7 })
Define("archaedas_h", "Spell_Nature_EarthShock", "nature", 7, 3, "none", { E("damage", 6, "all"), E("stun", "random") }, { harmful = true })

Define("eranikus_1", "Spell_Shadow_ShadowBolt", "shadow", 5, 0, "enemy", { E("damage", 10) })
Define("eranikus_2", "Spell_Nature_Acid_01", "nature", 7, 2, "none", { E("damage", 6, "all") }, { harmful = true })
Define("eranikus_3", "Spell_Nature_Sleep", "nature", 3, 3, "none", { E("stun", "random"), E("damage", 3, "all") }, { harmful = true })
Define("eranikus_h", "Spell_Shadow_ShadowWordPain", "shadow", 4, 2, "none", { E("dot", 4, 3, "all") }, { harmful = true })

Define("onyxia_1", "Spell_Fire_Fire", "fire", 5, 0, "enemy", { E("damage", 10) })
Define("onyxia_2", "Ability_Warrior_PunishingBlow", "physical", 6, 2, "none", { E("damage", 5, "all") }, { harmful = true })
Define("onyxia_3", "Spell_Fire_SelfDestruct", "fire", 9, 3, "none", { E("damage", 9, "all") }, { harmful = true })
Define("onyxia_h", "Spell_Shadow_UnholyFrenzy", "physical", 3, 3, "none", { E("damage", 4, "all"), E("stun", "random") }, { harmful = true })

Define("gordok_1", "Ability_Warrior_SavageBlow", "physical", 5, 0, "enemy", { E("attack", 7) })
Define("gordok_2", "Ability_WarStomp", "physical", 6, 2, "none", { E("damage", 5, "all"), E("buff", "speed", 2, 2, "all") }, { harmful = true })
Define("gordok_3", "Ability_Warrior_Sunder", "physical", 3, 2, "enemy", { E("attack", 2), E("buff", "taken", 0.3, 3) }, { ai = 0.7 })
Define("gordok_h", "Spell_Shadow_UnholyFrenzy", "physical", 2, 3, "none", { E("buff", "atkPct", 0.5, 3, "allies") })

Define("gahzrilla_1", "Spell_Frost_FrostBolt02", "frost", 5, 0, "enemy", { E("damage", 9), E("buff", "speed", 2, 2) })
Define("gahzrilla_2", "Spell_Frost_Glacier", "frost", 3, 3, "enemy", { E("stun"), E("damage", 4) })
Define("gahzrilla_3", "Ability_Warrior_PunishingBlow", "physical", 7, 2, "none", { E("damage", 7, "all") }, { harmful = true })
Define("gahzrilla_h", "Spell_Nature_Regeneration", "nature", 1, 3, "none", { E("heal", 30, "self") })

Define("hexx_1", "Spell_Shadow_ShadowBolt", "shadow", 5, 0, "enemy", { E("damage", 10) })
Define("hexx_2", "Spell_Nature_Drowsy", "nature", 3, 3, "enemy", { E("stun"), E("buff", "dmg", -0.3, 2) })
Define("hexx_3", "Spell_Holy_FlashHeal", "holy", 6, 1, "none", { E("heal", 18, "lowest") }, { ai = 0.8 })
Define("hexx_h", "Spell_Shadow_ShadowWordPain", "shadow", 4, 2, "none", { E("dot", 4, 3, "all") }, { harmful = true })

Define("thaurissan_1", "Spell_Fire_FlameShock", "fire", 5, 0, "enemy", { E("damage", 10) })
Define("thaurissan_2", "Spell_Fire_Immolation", "fire", 7, 2, "none", { E("damage", 5, "all"), E("dot", 2, 2, "all") }, { harmful = true })
Define("thaurissan_3", "Spell_Fire_FireArmor", "fire", 3, 2, "none", { E("buff", "dmg", 0.3, 2, "allies") }, { ai = 0.7 })
Define("thaurissan_h", "Spell_Fire_SealOfFire", "fire", 8, 3, "none", { E("damage", 8, "all") }, { harmful = true })

Define("azuregos_1", "Spell_Frost_FrostNova", "frost", 5, 0, "enemy", { E("damage", 9), E("buff", "speed", 2, 2) })
Define("azuregos_2", "Spell_Arcane_PortalUnderCity", "arcane", 6, 2, "none", { E("damage", 6, "all") }, { harmful = true })
Define("azuregos_3", "Spell_Nature_StormReach", "arcane", 4, 2, "none", { E("dot", 4, 3, "all") }, { harmful = true })
Define("azuregos_h", "Spell_Arcane_Blink", "arcane", 1, 3, "none", { E("absorb", 25, "self") })

Define("kazzak_1", "Ability_Warrior_Cleave", "physical", 6, 0, "enemy", { E("attack", 5), E("damage", 5, "adjacent") })
Define("kazzak_2", "Spell_Shadow_ShadowBolt", "shadow", 7, 2, "none", { E("damage", 7, "all") }, { harmful = true })
Define("kazzak_3", "Spell_Shadow_AntiShadow", "shadow", 3, 2, "enemy", { E("dot", 6, 3) })
Define("kazzak_h", "Spell_Shadow_SoulLeech_3", "shadow", 2, 3, "none", { E("heal", 30, "self") })

Define("banehollow_1", "Spell_Shadow_ShadowBolt", "shadow", 5, 0, "enemy", { E("damage", 11) })
Define("banehollow_2", "Spell_Nature_Sleep", "shadow", 3, 3, "none", { E("stun", "random") }, { harmful = true })
Define("banehollow_3", "Spell_Shadow_CarrionSwarm", "shadow", 6, 2, "none", { E("damage", 6, "all"), E("buff", "dmg", -0.2, 2, "all") }, { harmful = true })
Define("banehollow_h", "Spell_Shadow_SiphonMana", "shadow", 4, 2, "enemy", { E("damage", 8), E("heal", 10, "self") })

Define("mosh_1", "Ability_Hunter_Pet_Raptor", "physical", 4, 0, "enemy", { E("attack", 8) })
Define("mosh_2", "Ability_WarStomp", "physical", 7, 2, "none", { E("damage", 7, "all") }, { harmful = true })
Define("mosh_3", "Ability_Warrior_WarCry", "physical", 3, 2, "none", { E("buff", "dmg", -0.3, 2, "all") }, { harmful = true, ai = 0.7 })
Define("mosh_h", "Spell_Shadow_UnholyFrenzy", "physical", 2, 3, "none", { E("buff", "atkPct", 0.6, 3, "self") })

Define("rend_1", "Ability_Warrior_Cleave", "physical", 6, 0, "enemy", { E("attack", 5), E("damage", 4, "adjacent") })
Define("rend_2", "Ability_Whirlwind", "physical", 7, 2, "none", { E("attack", 0, "all", true) }, { harmful = true })
Define("rend_3", "Ability_Warrior_BattleShout", "physical", 3, 2, "none", { E("buff", "atk", 4, nil, "allies") }, { ai = 0.7 })
Define("rend_h", "Ability_Warrior_DecisiveStrike", "physical", 5, 3, "enemy", { E("damage", 14) })

Define("gandling_1", "Spell_Arcane_StarFire", "arcane", 5, 0, "enemy", { E("damage", 10) })
Define("gandling_2", "Spell_Shadow_AntiShadow", "shadow", 2, 3, "none", { E("absorb", 25, "self") }, { ai = 0.7 })
Define("gandling_3", "Spell_Shadow_CurseOfMannoroth", "shadow", 4, 2, "none", { E("dot", 5, 3, "all") }, { harmful = true })
Define("gandling_h", "Spell_Shadow_SealOfKings", "shadow", 3, 3, "enemy", { E("stun"), E("damage", 6) })

Define("rivendare_1", "Ability_Warrior_SavageBlow", "physical", 5, 0, "enemy", { E("attack", 7) })
Define("rivendare_2", "Spell_Shadow_DeathPact", "shadow", 6, 2, "none", { E("dot", 3, 3, "all") }, { harmful = true })
Define("rivendare_3", "Spell_Shadow_RaiseDead", "shadow", 3, 3, "none", { E("absorb", 12, "allies"), E("taunt", 1) }, { ai = 0.7 })
Define("rivendare_h", "Spell_Shadow_UnholyFrenzy", "shadow", 1, 3, "none", { E("heal", 30, "self") })

Define("winterfall_1", "Ability_Druid_Rake", "physical", 5, 0, "enemy", { E("attack", 6) })
Define("winterfall_2", "Spell_Frost_FrostShock", "frost", 6, 2, "none", { E("damage", 5, "all"), E("buff", "speed", 2, 2, "all") }, { harmful = true })
Define("winterfall_3", "Spell_Nature_Purge", "nature", 3, 2, "none", { E("buff", "atk", 4, nil, "allies") }, { ai = 0.7 })
Define("winterfall_h", "Spell_Shadow_UnholyFrenzy", "physical", 2, 3, "none", { E("buff", "atkPct", 0.5, 3, "self"), E("heal", 15, "self") })

Define("cthun_1", "INV_Misc_Eye_01", "shadow", 5, 0, "enemy", { E("damage", 11), E("damage", 5, "adjacent") })
Define("cthun_2", "Spell_Shadow_Charm", "shadow", 9, 3, "none", { E("damage", 9, "all") }, { harmful = true })
Define("cthun_3", "Spell_Shadow_MindFlay", "shadow", 3, 2, "enemy", { E("stun"), E("dot", 4, 2) })
Define("cthun_h", "Spell_Shadow_GatherShadows", "shadow", 2, 3, "none", { E("absorb", 15, "allies"), E("damage", 4, "all") }, { harmful = true })

Define("archimonde_1", "Spell_Shadow_Teleport", "shadow", 8, 0, "enemy", { E("damage", 14) })
Define("archimonde_2", "Spell_Fire_Incinerate", "fire", 5, 2, "none", { E("dot", 5, 3, "all") }, { harmful = true })
Define("archimonde_3", "Spell_Shadow_Shadowfury", "shadow", 6, 2, "none", { E("damage", 6, "all"), E("stun", "random") }, { harmful = true })
Define("archimonde_h", "Spell_Shadow_CurseOfAchimonde", "shadow", 3, 3, "none", { E("buff", "dmg", -0.4, 2, "all"), E("dot", 3, 2, "all") }, { harmful = true })
