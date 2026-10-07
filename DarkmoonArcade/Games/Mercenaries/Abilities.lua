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
