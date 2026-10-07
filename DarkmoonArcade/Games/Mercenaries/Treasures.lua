-- Treasures: run-only bonuses for a single mercenary, offered three at a time after each won
-- fight. They stack. `needs` limits an offer to mercenaries it actually helps.

local _, ns = ...
ns.Mercenaries = ns.Mercenaries or {}
local MC = ns.Mercenaries

local function T(id, icon, mods, extra)
    local t = { id = id, icon = "Interface\\Icons\\" .. icon, mods = mods }
    for k, v in pairs(extra or {}) do t[k] = v end
    return t
end

MC.Treasures = {
    might = T("might", "Spell_Nature_Strength", { atkPct = 0.3 }, { needs = "attack" }),
    vigor = T("vigor", "Spell_Holy_WordFortitude", { hpPct = 0.3 }),
    haste = T("haste", "Spell_Nature_Invisibilty", { speed = -1 }),
    aegis = T("aegis", "Spell_Holy_DivineIntervention", { startShield = true }),
    leech = T("leech", "Spell_Shadow_LifeDrain", { lifesteal = 0.3 }, { needs = "damage" }),
    thorns = T("thorns", "Spell_Nature_Thorns", { thorns = 5 }),
    renewal = T("renewal", "Spell_Nature_Rejuvenation", { regenPct = 0.07 }),
    readiness = T("readiness", "Ability_Hunter_Readiness", { readyStart = true }, { needs = "cooldown" }),
    precision = T("precision", "Ability_CriticalStrike", { critChance = 0.25 }, { needs = "damage" }),
    bulwark = T("bulwark", "Spell_Holy_DevotionAura", { takenPct = -0.2 }),
    execution = T("execution", "Ability_Warrior_Decisivestrike", { executePct = 0.8 }, { needs = "damage" }),
    vengeance = T("vengeance", "Spell_Holy_SealOfVengeance", { vengeance = 0.5 }),
    devotion = T("devotion", "Spell_Holy_HolyBolt", { healPct = 0.4 }, { needs = "heal" }),
    focus1 = T("focus1", "Spell_Holy_MindVision", { abil1_value = 0.5 }),
    focus2 = T("focus2", "Spell_Holy_MindVision", { abil2_value = 0.5 }, { needs = 2 }),
    focus3 = T("focus3", "Spell_Holy_MindVision", { abil3_value = 0.5 }, { needs = 3 }),
    quick1 = T("quick1", "Spell_Nature_Invisibilty", { abil1_speed = -2 }),
    quick2 = T("quick2", "Spell_Nature_Invisibilty", { abil2_speed = -2 }, { needs = 2 }),
    quick3 = T("quick3", "Spell_Nature_Invisibilty", { abil3_speed = -2 }, { needs = 3 }),
    fire = T("fire", "Spell_Fire_Fire", { school_fire = 0.4 }, { needs = "fire" }),
    frost = T("frost", "Spell_Frost_FrostBolt02", { school_frost = 0.4 }, { needs = "frost" }),
    nature = T("nature", "Spell_Nature_Lightning", { school_nature = 0.4 }, { needs = "nature" }),
    shadow = T("shadow", "Spell_Shadow_ShadowBolt", { school_shadow = 0.4 }, { needs = "shadow" }),
    holy = T("holy", "Spell_Holy_HolySmite", { school_holy = 0.4 }, { needs = "holy" }),
    arcane = T("arcane", "Spell_Holy_MagicalSentry", { school_arcane = 0.4 }, { needs = "arcane" }),
    physical = T("physical", "Ability_MeleeDamage", { school_physical = 0.3 }, { needs = "physical" }),
    -- Elite fights offer from this richer pool.
    titan = T("titan", "Spell_Holy_PrayerOfFortitude", { atkPct = 0.5, hpPct = 0.3 }, { elite = true }),
    zeal = T("zeal", "Spell_Holy_Excorcism_02", { speed = -2, dmgPct = 0.2 }, { elite = true }),
    overflow = T("overflow", "Spell_Nature_TimeStop", { abil2_cd = -1, abil3_cd = -1 }, { elite = true, needs = 3 }),
    champion = T("champion", "INV_Misc_Head_Dragon_01", { dmgPct = 0.35, takenPct = -0.15 }, { elite = true }),
    lifebloom = T("lifebloom", "Spell_Nature_ResistNature", { regenPct = 0.12, hpPct = 0.2 }, { elite = true }),
    -- Cursed treasures: offered by a mystery, they weaken the whole party for the rest of the run.
    cursedblade = T("cursedblade", "INV_Sword_48", { dmgPct = 0.7 }, { cursed = true }),
    cursedmail = T("cursedmail", "INV_Chest_Chain_15", { takenPct = -0.4 }, { cursed = true }),
    cursedrelic = T("cursedrelic", "INV_Misc_Bone_ElfSkull_01", { speed = -3 }, { cursed = true }),
}

MC.TREASURE_ORDER = {
    "might", "vigor", "haste", "aegis", "leech", "thorns", "renewal", "readiness", "precision", "bulwark",
    "execution", "vengeance", "devotion", "focus1", "focus2", "focus3", "quick1", "quick2", "quick3",
    "fire", "frost", "nature", "shadow", "holy", "arcane", "physical",
    "titan", "zeal", "overflow", "champion", "lifebloom",
    "cursedblade", "cursedmail", "cursedrelic",
}
-- A curse costs every party member this share of their health.
MC.CURSE_HEALTH = 0.15
