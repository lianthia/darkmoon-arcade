-- The mercenaries: figures from Classic and Forever. Stats are for level 60; abilities unlock at
-- levels 1, 10 and 30. Equipment changes how a mercenary plays rather than making it stronger.
-- NPC and display IDs come from tools/npc_ids.json (Wowhead, WoW: Forever).

local _, ns = ...
ns.Mercenaries = ns.Mercenaries or {}
local MC = ns.Mercenaries

MC.ABILITY_LEVELS = { 1, 10, 30 }
MC.MAX_LEVEL = 60
-- The first party before any recruiting: two of each role.
MC.STARTERS = { "cairne", "bolvar", "mankrik", "shandris", "benedictus", "hamuul" }

local function Merc(id, role, race, npc, display, hp, atk, gear)
    local abilities = {}
    for i = 1, 3 do abilities[i] = id .. "_" .. i end
    return {
        id = id, role = role, race = race, npc = npc, display = display, hp = hp, atk = atk,
        abilities = abilities, gear = gear,
    }
end

-- Gear: { icon, mods }; the first piece is owned from the start.
local function G(icon, mods)
    return { icon = "Interface\\Icons\\" .. icon, mods = mods }
end

MC.Mercs = {
    -- Protectors
    cairne = Merc("cairne", "protector", "tauren", 3057, 4307, 95, 8, {
        G("INV_Misc_Bone_TaurenSkull_01", { abil3_cd = -1 }),
        G("INV_Chest_Plate06", { hpPct = 0.25 }),
        G("INV_Spear_06", { abil1_value = 0.5 }),
    }),
    bolvar = Merc("bolvar", "protector", "human", 1748, 5566, 88, 8, {
        G("INV_Shield_06", { startShield = true }),
        G("INV_Shirt_GuildTabard_01", { abil3_value = 0.6 }),
        G("INV_Sword_39", { atkPct = 0.3 }),
    }),
    magni = Merc("magni", "protector", "dwarf", 2784, 3597, 92, 8, {
        G("INV_Jewelry_Ring_03", { abil2_cd = -1 }),
        G("INV_Hammer_09", { abil1_value = 0.5 }),
        G("INV_Crown_01", { takenPct = -0.15 }),
    }),
    tirion = Merc("tirion", "protector", "human", 1855, 9477, 85, 7, {
        G("INV_Relics_LibramofHope", { healPct = 0.3 }),
        G("INV_Hammer_05", { abil2_speed = -2 }),
        G("INV_Chest_Plate03", { abil3_cd = -1 }),
    }),
    eitrigg = Merc("eitrigg", "protector", "orc", 3144, 1619, 86, 9, {
        G("INV_Axe_09", { abil1_value = 0.4 }),
        G("INV_Shield_05", { thorns = 4 }),
        G("INV_Misc_Bandana_03", { vengeance = 0.4 }),
    }),
    taelan = Merc("taelan", "protector", "human", 1842, 10341, 84, 7, {
        G("INV_Jewelry_Ring_15", { abil2_speed = -2 }),
        G("INV_Shield_04", { startShield = true }),
        G("INV_Relics_LibramofTruth", { healPct = 0.4 }),
    }),
    saurfang = Merc("saurfang", "protector", "orc", 14720, 14732, 90, 9, {
        G("INV_Axe_12", { thorns = 5 }),
        G("INV_Chest_Plate10", { abil2_cd = -1 }),
        G("INV_Misc_Head_Orc_01", { atkPct = 0.25 }),
    }),
    windsor = Merc("windsor", "protector", "human", 9682, 9052, 86, 7, {
        G("INV_Shield_10", { startShield = true }),
        G("INV_BannerPVP_02", { abil2_value = 0.5 }),
        G("INV_Helmet_05", { hpPct = 0.2 }),
    }),
    -- Fighters
    rexxar = Merc("rexxar", "fighter", "orc", 10182, 11660, 75, 10, {
        G("INV_Misc_Pelt_Bear_03", { abil2_cd = -1 }),
        G("INV_Axe_05", { atkPct = 0.25 }),
        G("INV_Misc_Quiver_06", { abil3_value = 0.5 }),
    }),
    sylvanas = Merc("sylvanas", "fighter", "undead", 10181, 11657, 62, 7, {
        G("INV_Weapon_Bow_02", { abil1_speed = -2 }),
        G("INV_Misc_Cape_18", { critChance = 0.2 }),
        G("INV_Misc_Quiver_03", { school_shadow = 0.4 }),
    }),
    voljin = Merc("voljin", "fighter", "troll", 10540, 10357, 66, 8, {
        G("INV_Spear_04", { abil1_value = 0.4 }),
        G("INV_Misc_Head_Troll_01", { abil2_cd = -1 }),
        G("INV_Jewelry_Talisman_04", { healPct = 0.4 }),
    }),
    shandris = Merc("shandris", "fighter", "nightelf", 3936, 2035, 64, 7, {
        G("INV_Weapon_Bow_04", { abil1_value = 0.3 }),
        G("INV_Misc_Cape_06", { speed = -1 }),
        G("INV_Weapon_Glave_01", { executePct = 0.6 }),
    }),
    mankrik = Merc("mankrik", "fighter", "orc", 3432, 3855, 72, 10, {
        G("INV_Axe_02", { vengeance = 0.5 }),
        G("INV_Chest_Chain_04", { hpPct = 0.25 }),
        G("INV_Jewelry_Necklace_04", { lifesteal = 0.25 }),
    }),
    renzik = Merc("renzik", "fighter", "human", 6946, 7613, 60, 9, {
        G("INV_Weapon_ShortBlade_05", { critChance = 0.2 }),
        G("INV_Potion_19", { abil1_value = 0.4 }),
        G("INV_Misc_Cape_11", { abil3_cd = -1 }),
    }),
    jorach = Merc("jorach", "fighter", "human", 6768, 6572, 60, 9, {
        G("INV_Weapon_ShortBlade_14", { critChance = 0.2 }),
        G("INV_Sword_23", { executePct = 0.5 }),
        G("INV_Misc_Cape_20", { abil2_cd = -1 }),
    }),
    natpagle = Merc("natpagle", "fighter", "human", 12919, 13099, 68, 8, {
        G("INV_Fishingpole_02", { abil1_value = 0.4 }),
        G("INV_Misc_Food_06", { abil2_value = 0.5 }),
        G("INV_Misc_Fish_03", { regenPct = 0.06 }),
    }),
    -- Casters
    jaina = Merc("jaina", "caster", "human", 4968, 2970, 56, 4, {
        G("INV_Staff_13", { school_fire = 0.3 }),
        G("INV_Jewelry_Necklace_07", { school_frost = 0.3 }),
        G("INV_Misc_Orb_01", { abil3_cd = -1 }),
    }),
    thrall = Merc("thrall", "caster", "orc", 4949, 4527, 68, 6, {
        G("INV_Hammer_04", { abil1_value = 0.35 }),
        G("INV_Jewelry_Talisman_02", { abil2_cd = -1 }),
        G("INV_Shoulder_29", { abil3_cd = -1 }),
    }),
    tyrande = Merc("tyrande", "caster", "nightelf", 7999, 7274, 58, 4, {
        G("INV_Crown_02", { healPct = 0.3 }),
        G("INV_Misc_Gem_Pearl_04", { abil3_cd = -1 }),
        G("INV_Weapon_Glave_01", { school_arcane = 0.5 }),
    }),
    magatha = Merc("magatha", "caster", "tauren", 4046, 4510, 60, 4, {
        G("INV_Staff_07", { school_nature = 0.3 }),
        G("INV_Misc_Bone_ElfSkull_01", { abil2_speed = -2 }),
        G("Spell_Fire_SearingTotem", { school_fire = 0.5 }),
    }),
    benedictus = Merc("benedictus", "caster", "human", 1284, 5072, 58, 4, {
        G("INV_Misc_Lantern_01", { abil2_value = 0.5 }),
        G("INV_Chest_Cloth_11", { regenPct = 0.06 }),
        G("INV_Helmet_29", { abil3_cd = -1 }),
    }),
    fandral = Merc("fandral", "caster", "nightelf", 15382, 15421, 60, 4, {
        G("INV_Staff_17", { school_arcane = 0.3 }),
        G("INV_Misc_Branch_01", { abil2_cd = -1 }),
        G("INV_Misc_Orb_02", { abil3_cd = -1 }),
    }),
    drekthar = Merc("drekthar", "caster", "orc", 11946, 11894, 64, 5, {
        G("INV_Staff_20", { school_frost = 0.3 }),
        G("INV_Jewelry_Ring_14", { healPct = 0.3 }),
        G("INV_Jewelry_Talisman_08", { abil3_cd = -1 }),
    }),
    hamuul = Merc("hamuul", "caster", "tauren", 5769, 4519, 62, 5, {
        G("INV_Staff_06", { abil2_value = 0.5 }),
        G("INV_Misc_Horn_01", { abil3_cd = -1 }),
        G("INV_Misc_Herb_09", { healPct = 0.3 }),
    }),
}

-- Collection order: by role, then as listed here.
MC.MERC_ORDER = {
    "cairne", "bolvar", "magni", "tirion", "eitrigg", "taelan", "saurfang", "windsor",
    "rexxar", "sylvanas", "voljin", "shandris", "mankrik", "renzik", "jorach", "natpagle",
    "jaina", "thrall", "tyrande", "magatha", "benedictus", "hamuul", "fandral", "drekthar",
}
