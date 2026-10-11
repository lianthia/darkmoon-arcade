-- Treasures: run-only bonuses for a single mercenary, offered three at a time after each won
-- fight. They stack. `needs` limits an offer to mercenaries it actually helps. Each has a rarity as
-- in WoW: common, uncommon, rare, epic and legendary, rolled by the fight's weights below.

local _, ns = ...
ns.Mercenaries = ns.Mercenaries or {}
local MC = ns.Mercenaries

local function T(id, rarity, icon, mods, extra)
    local t = { id = id, rarity = rarity, icon = "Interface\\Icons\\" .. icon, mods = mods }
    for k, v in pairs(extra or {}) do t[k] = v end
    return t
end

MC.RARITIES = { "common", "uncommon", "rare", "epic", "legendary" }
-- WoW's item quality colours (for dark backgrounds) and darker inks for the parchment cards.
MC.RARITY_COLORS = {
    common = { 1, 1, 1 }, uncommon = { 0.12, 1, 0 }, rare = { 0, 0.44, 0.87 },
    epic = { 0.64, 0.21, 0.93 }, legendary = { 1, 0.5, 0 },
}
MC.RARITY_INKS = {
    common = { 0.3, 0.26, 0.22 }, uncommon = { 0.05, 0.42, 0 }, rare = { 0, 0.28, 0.62 },
    epic = { 0.42, 0.1, 0.62 }, legendary = { 0.72, 0.3, 0 },
}
-- Chances per rarity (in %): regular fights, elite fights, and both in heroic mode.
MC.RARITY_WEIGHTS = {
    fight = { common = 55, uncommon = 30, rare = 12, epic = 3, legendary = 0 },
    elite = { common = 25, uncommon = 35, rare = 25, epic = 12, legendary = 3 },
    heroicFight = { common = 35, uncommon = 35, rare = 20, epic = 8, legendary = 2 },
    heroicElite = { common = 10, uncommon = 25, rare = 35, epic = 22, legendary = 8 },
}

MC.Treasures = {
    -- Common: one plain bonus.
    might = T("might", "common", "Spell_Nature_Strength", { atkPct = 0.2 }, { needs = "attack" }),
    vigor = T("vigor", "common", "Spell_Holy_WordFortitude", { hpPct = 0.2 }),
    bulwark = T("bulwark", "common", "Spell_Holy_DevotionAura", { takenPct = -0.12 }),
    renewal = T("renewal", "common", "Spell_Nature_Rejuvenation", { regenPct = 0.05 }),
    thorns = T("thorns", "common", "Spell_Nature_Thorns", { thorns = 4 }),
    whetstone = T("whetstone", "common", "INV_Stone_SharpeningStone_01", { dmgPct = 0.1 }),
    focus1 = T("focus1", "common", "Spell_Holy_MindVision", { abil1_value = 0.3 }),
    fire = T("fire", "common", "Spell_Fire_Fire", { school_fire = 0.25 }, { needs = "fire" }),
    frost = T("frost", "common", "Spell_Frost_FrostBolt02", { school_frost = 0.25 }, { needs = "frost" }),
    nature = T("nature", "common", "Spell_Nature_Lightning", { school_nature = 0.25 }, { needs = "nature" }),
    shadow = T("shadow", "common", "Spell_Shadow_ShadowBolt", { school_shadow = 0.25 }, { needs = "shadow" }),
    holy = T("holy", "common", "Spell_Holy_HolySmite", { school_holy = 0.25 }, { needs = "holy" }),
    arcane = T("arcane", "common", "Spell_Holy_MagicalSentry", { school_arcane = 0.25 }, { needs = "arcane" }),
    physical = T("physical", "common", "Ability_MeleeDamage", { school_physical = 0.2 }, { needs = "physical" }),
    -- Uncommon: stronger, or a second ability.
    haste = T("haste", "uncommon", "Spell_Nature_Invisibilty", { speed = -1 }),
    leech = T("leech", "uncommon", "Spell_Shadow_LifeDrain", { lifesteal = 0.25 }, { needs = "damage" }),
    precision = T("precision", "uncommon", "Ability_CriticalStrike", { critChance = 0.2 }, { needs = "damage" }),
    devotion = T("devotion", "uncommon", "Spell_Holy_HolyBolt", { healPct = 0.35 }, { needs = "heal" }),
    quick1 = T("quick1", "uncommon", "Spell_Nature_Invisibilty", { abil1_speed = -2 }),
    focus2 = T("focus2", "uncommon", "Spell_Holy_MindVision", { abil2_value = 0.4 }, { needs = 2 }),
    quick2 = T("quick2", "uncommon", "Spell_Nature_Invisibilty", { abil2_speed = -2 }, { needs = 2 }),
    guardian = T("guardian", "uncommon", "INV_Shield_04", { takenPct = -0.15, hpPct = 0.1 }),
    battlefocus = T("battlefocus", "uncommon", "Ability_Warrior_InnerRage", { dmgPct = 0.18 }),
    -- Rare: effects that change how a fight goes.
    aegis = T("aegis", "rare", "Spell_Holy_DivineIntervention", { startShield = true }),
    readiness = T("readiness", "rare", "Ability_Hunter_Readiness", { readyStart = true }, { needs = "cooldown" }),
    execution = T("execution", "rare", "Ability_Warrior_Decisivestrike", { executePct = 0.8 }, { needs = "damage" }),
    vengeance = T("vengeance", "rare", "Spell_Holy_SealOfVengeance", { vengeance = 0.5 }),
    focus3 = T("focus3", "rare", "Spell_Holy_MindVision", { abil3_value = 0.5 }, { needs = 3 }),
    quick3 = T("quick3", "rare", "Spell_Nature_Invisibilty", { abil3_speed = -2 }, { needs = 3 }),
    bloodthirst = T("bloodthirst", "rare", "Spell_Nature_BloodLust", { lifesteal = 0.2, atkPct = 0.15 }, { needs = "attack" }),
    stoneskin = T("stoneskin", "rare", "Spell_Nature_StoneSkinTotem", { takenPct = -0.2, regenPct = 0.04 }),
    insight = T("insight", "rare", "Spell_Holy_MindSooth", { abil1_value = 0.25, abil2_value = 0.25 }, { needs = 2 }),
    -- Epic: two strong bonuses at once.
    titan = T("titan", "epic", "Spell_Holy_PrayerOfFortitude", { atkPct = 0.5, hpPct = 0.3 }),
    zeal = T("zeal", "epic", "Spell_Holy_Excorcism_02", { speed = -2, dmgPct = 0.2 }),
    overflow = T("overflow", "epic", "Spell_Nature_TimeStop", { abil2_cd = -1, abil3_cd = -1 }, { needs = 3 }),
    champion = T("champion", "epic", "INV_Misc_Head_Dragon_01", { dmgPct = 0.35, takenPct = -0.15 }),
    lifebloom = T("lifebloom", "epic", "Spell_Nature_ResistNature", { regenPct = 0.12, hpPct = 0.2 }),
    assassin = T("assassin", "epic", "Ability_Rogue_Eviscerate", { critChance = 0.35, executePct = 0.5 }, { needs = "damage" }),
    -- Legendary: echoes of the old world's famous weapons.
    ashbringer = T("ashbringer", "legendary", "INV_Sword_62", { dmgPct = 0.4, lifesteal = 0.25, school_holy = 0.3 }),
    thunderfury = T("thunderfury", "legendary", "INV_Sword_39", { speed = -2, critChance = 0.3, dmgPct = 0.25 }),
    atiesh = T("atiesh", "legendary", "INV_Staff_Medivh", { abil1_value = 0.35, abil2_value = 0.35, abil3_value = 0.35, healPct = 0.3 }),
    sulfuras = T("sulfuras", "legendary", "INV_Hammer_Unique_Sulfuras", { atkPct = 0.6, hpPct = 0.4, startShield = true }),
    -- Cursed treasures: offered by a mystery, they weaken the whole party for the rest of the run.
    cursedblade = T("cursedblade", "epic", "INV_Sword_48", { dmgPct = 0.7 }, { cursed = true }),
    cursedmail = T("cursedmail", "epic", "INV_Chest_Chain_15", { takenPct = -0.4 }, { cursed = true }),
    cursedrelic = T("cursedrelic", "epic", "INV_Misc_Bone_ElfSkull_01", { speed = -3 }, { cursed = true }),
}

MC.TREASURE_ORDER = {
    "might", "vigor", "bulwark", "renewal", "thorns", "whetstone", "focus1",
    "fire", "frost", "nature", "shadow", "holy", "arcane", "physical",
    "haste", "leech", "precision", "devotion", "quick1", "focus2", "quick2", "guardian", "battlefocus",
    "aegis", "readiness", "execution", "vengeance", "focus3", "quick3", "bloodthirst", "stoneskin", "insight",
    "titan", "zeal", "overflow", "champion", "lifebloom", "assassin",
    "ashbringer", "thunderfury", "atiesh", "sulfuras",
    "cursedblade", "cursedmail", "cursedrelic",
}
-- A curse costs every party member this share of their health.
MC.CURSE_HEALTH = 0.15
