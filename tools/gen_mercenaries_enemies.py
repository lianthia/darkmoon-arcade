"""Writes DarkmoonArcade/Games/Mercenaries/Enemies.lua: python tools/gen_mercenaries_enemies.py

Creature stats and abilities live here; NPC and display IDs come from tools/npc_ids.json
(fill it with tools/lookup_npcs.py). Stats are for level 60, like the mercenaries'.
"""
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
IDS = json.loads((ROOT / "tools" / "npc_ids.json").read_text(encoding="utf-8"))
OUT = ROOT / "DarkmoonArcade" / "Games" / "Mercenaries" / "Enemies.lua"
NAMES_OUT = ROOT / "DarkmoonArcade" / "Games" / "Mercenaries" / "EnemyNames.lua"

# Base stats per role; individual creatures scale them.
BASE = {"protector": (72, 6), "fighter": (60, 8), "caster": (52, 4), "neutral": (62, 7)}

# key: (Wowhead name, role, race, hp scale, abilities)
ENEMIES = {
    # Elwynn Forest
    "kobold_vermin": ("Kobold Vermin", "fighter", "kobold", 0.9, ["e_strike", "e_frenzy"]),
    "kobold_tunneler": ("Kobold Tunneler", "protector", "kobold", 1.0, ["e_strike", "e_guard"]),
    "riverpaw_outrunner": ("Riverpaw Outrunner", "fighter", "gnoll", 1.0, ["e_strike", "e_net"]),
    "riverpaw_gnoll": ("Riverpaw Gnoll", "protector", "gnoll", 1.0, ["e_strike", "e_guard"]),
    "defias_thug": ("Defias Thug", "fighter", "human", 1.0, ["e_strike", "e_cleave"]),
    "murloc_streamrunner": ("Murloc Streamrunner", "caster", "murloc", 0.9, ["e_frostbolt", "e_wave"]),
    "prowler": ("Prowler", "fighter", "beast", 0.9, ["e_bite", "e_howl"]),
    # Dun Morogh
    "frostmane_whelp": ("Frostmane Troll Whelp", "fighter", "troll", 0.9, ["e_strike", "e_enrage"]),
    "frostmane_seer": ("Frostmane Seer", "caster", "troll", 1.0, ["e_frostbolt", "e_renew"]),
    "rockjaw_trogg": ("Rockjaw Trogg", "protector", "trogg", 1.0, ["e_strike", "e_guard"]),
    "leper_gnome": ("Leper Gnome", "fighter", "gnome", 0.9, ["e_strike", "e_explode"]),
    "ice_claw_bear": ("Ice Claw Bear", "protector", "beast", 1.1, ["e_claw", "e_enrage"]),
    # Tirisfal Glades
    "rattlecage_skeleton": ("Rattlecage Skeleton", "protector", "undead", 1.0, ["e_strike", "e_guard"]),
    "mindless_zombie": ("Mindless Zombie", "fighter", "undead", 1.0, ["e_strike", "e_plague"]),
    "scarlet_convert": ("Scarlet Convert", "fighter", "human", 1.0, ["e_strike", "e_rally"]),
    "scarlet_missionary": ("Scarlet Missionary", "caster", "human", 1.0, ["e_holyfire", "e_heal"]),
    "darkhound": ("Darkhound", "fighter", "beast", 0.9, ["e_bite", "e_howl"]),
    "scarlet_monk": ("Scarlet Monk", "fighter", "human", 1.1, ["e_strike", "e_shieldbash"]),
    # Teldrassil
    "grellkin": ("Grellkin", "caster", "demon", 0.9, ["e_shadowbolt", "e_curse"]),
    "timberling": ("Timberling", "protector", "elemental", 1.1, ["e_strike", "e_harden"]),
    "gnarlpine_ursa": ("Gnarlpine Ursa", "protector", "furbolg", 1.0, ["e_claw", "e_guard"]),
    "webwood_spider": ("Webwood Spider", "fighter", "beast", 0.9, ["e_poison", "e_web"]),
    "nightsaber": ("Nightsaber", "fighter", "beast", 0.9, ["e_bite", "e_claw"]),
    # Durotar
    "vile_familiar": ("Vile Familiar", "caster", "demon", 0.8, ["e_firebolt", "e_curse"]),
    "mottled_boar": ("Mottled Boar", "protector", "beast", 1.0, ["e_trample", "e_harden"]),
    "scorpid_worker": ("Scorpid Worker", "fighter", "beast", 0.9, ["e_poison", "e_bite"]),
    "kul_tiras_sailor": ("Kul Tiras Sailor", "fighter", "human", 1.0, ["e_strike", "e_rally"]),
    "durotar_tiger": ("Durotar Tiger", "fighter", "beast", 0.9, ["e_bite", "e_claw"]),
    "voodoo_troll": ("Voodoo Troll", "caster", "troll", 1.0, ["e_shadowbolt", "e_heal"]),
    # Mulgore
    "plainstrider": ("Plainstrider", "fighter", "beast", 0.9, ["e_bite", "e_dive"]),
    "bristleback_quilboar": ("Bristleback Quilboar", "protector", "quilboar", 1.0, ["e_strike", "e_guard"]),
    "palemane_tanner": ("Palemane Tanner", "fighter", "gnoll", 1.0, ["e_strike", "e_net"]),
    "venture_laborer": ("Venture Co. Laborer", "fighter", "goblin", 1.0, ["e_strike", "e_explode"]),
    "prairie_wolf": ("Prairie Wolf", "fighter", "beast", 0.9, ["e_bite", "e_howl"]),
    # Zephras Isle (WoW: Forever)
    "shadowgale_shrieker": ("Shadowgale Shrieker", "fighter", "beast", 0.9, ["e_dive", "e_frenzy"]),
    "shadowgale_shriekling": ("Shadowgale Shriekling", "fighter", "beast", 0.8, ["e_dive", "e_bite"]),
    "shadowgale_ursera": ("Shadowgale Ursera", "protector", "beast", 1.1, ["e_claw", "e_guard"]),
    "shadowgale_manticore": ("Shadowgale Manticore", "fighter", "beast", 1.1, ["e_poison", "e_bite"]),
    "drowned_skyborne": ("Drowned Skyborne", "caster", "undead", 1.0, ["e_frostbolt", "e_drain"]),
    # Westfall
    "defias_pillager": ("Defias Pillager", "caster", "human", 1.0, ["e_firebolt", "e_curse"]),
    "defias_trapper": ("Defias Trapper", "fighter", "human", 1.0, ["e_strike", "e_net"]),
    "harvest_golem": ("Harvest Golem", "protector", "mechanical", 1.2, ["e_slam", "e_harden"]),
    "fleshripper": ("Fleshripper", "fighter", "beast", 0.9, ["e_dive", "e_claw"]),
    "defias_blackguard": ("Defias Blackguard", "fighter", "human", 1.1, ["e_strike", "e_shieldbash"]),
    # Loch Modan
    "stonesplinter_trogg": ("Stonesplinter Trogg", "protector", "trogg", 1.0, ["e_strike", "e_guard"]),
    "stonesplinter_seer": ("Stonesplinter Seer", "caster", "trogg", 1.0, ["e_lightning", "e_renew"]),
    "mogrosh_ogre": ("Mo'grosh Ogre", "fighter", "ogre", 1.2, ["e_slam", "e_enrage"]),
    "tunnel_rat": ("Tunnel Rat Kobold", "fighter", "kobold", 0.9, ["e_strike", "e_explode"]),
    "dark_iron_dwarf": ("Dark Iron Dwarf", "fighter", "dwarf", 1.0, ["e_strike", "e_shieldbash"]),
    "mountain_buzzard": ("Mountain Buzzard", "fighter", "beast", 0.9, ["e_dive", "e_bite"]),
    # Silverpine Forest
    "moonrage_whitescalp": ("Moonrage Whitescalp", "fighter", "worgen", 1.0, ["e_bite", "e_frenzy"]),
    "dalaran_apprentice": ("Dalaran Apprentice", "caster", "human", 1.0, ["e_frostbolt", "e_firebolt"]),
    "rot_hide_gnoll": ("Rot Hide Gnoll", "protector", "gnoll", 1.0, ["e_strike", "e_plague"]),
    "shadowfang_moonwalker": ("Shadowfang Moonwalker", "caster", "worgen", 1.0, ["e_shadowbolt", "e_drain"]),
    "son_of_arugal": ("Son of Arugal", "fighter", "worgen", 1.2, ["e_bite", "e_enrage"]),
    # Darkshore
    "greymist_coastrunner": ("Greymist Coastrunner", "fighter", "murloc", 0.9, ["e_strike", "e_net"]),
    "greymist_seer": ("Greymist Seer", "caster", "murloc", 0.9, ["e_lightning", "e_renew"]),
    "blackwood_pathfinder": ("Blackwood Pathfinder", "protector", "furbolg", 1.0, ["e_claw", "e_guard"]),
    "darkshore_thresher": ("Darkshore Thresher", "fighter", "beast", 1.1, ["e_bite", "e_wave"]),
    "moonstalker": ("Moonstalker", "fighter", "beast", 0.9, ["e_bite", "e_claw"]),
    # The Barrens
    "razormane_thornweaver": ("Razormane Thornweaver", "caster", "quilboar", 1.0, ["e_lightning", "e_poison"]),
    "kolkar_wrangler": ("Kolkar Wrangler", "fighter", "centaur", 1.0, ["e_strike", "e_net"]),
    "kolkar_stormer": ("Kolkar Stormer", "caster", "centaur", 1.0, ["e_lightning", "e_wave"]),
    "witchwing_harpy": ("Witchwing Harpy", "fighter", "harpy", 0.9, ["e_dive", "e_claw"]),
    "venture_peon": ("Venture Co. Peon", "fighter", "goblin", 1.0, ["e_strike", "e_explode"]),
    "savannah_huntress": ("Savannah Huntress", "fighter", "beast", 0.9, ["e_bite", "e_howl"]),
    # Redridge Mountains
    "redridge_mongrel": ("Redridge Mongrel", "fighter", "gnoll", 1.0, ["e_strike", "e_frenzy"]),
    "redridge_mystic": ("Redridge Mystic", "caster", "gnoll", 1.0, ["e_lightning", "e_heal"]),
    "blackrock_grunt": ("Blackrock Grunt", "protector", "orc", 1.1, ["e_strike", "e_guard"]),
    "blackrock_shadowcaster": ("Blackrock Shadowcaster", "caster", "orc", 1.0, ["e_shadowbolt", "e_curse"]),
    "shadowhide_brute": ("Shadowhide Brute", "fighter", "gnoll", 1.1, ["e_slam", "e_enrage"]),
    # Stonetalon Mountains
    "venture_logger": ("Venture Co. Logger", "fighter", "goblin", 1.0, ["e_strike", "e_cleave"]),
    "venture_operator": ("Venture Co. Operator", "protector", "goblin", 1.1, ["e_slam", "e_guard"]),
    "deepmoss_webspinner": ("Deepmoss Webspinner", "fighter", "beast", 0.9, ["e_poison", "e_web"]),
    "bloodfury_harpy": ("Bloodfury Harpy", "fighter", "harpy", 0.9, ["e_dive", "e_frenzy"]),
    "grimtotem_ruffian": ("Grimtotem Ruffian", "protector", "tauren", 1.2, ["e_trample", "e_guard"]),
    # Ashenvale
    "foulweald_warrior": ("Foulweald Warrior", "protector", "furbolg", 1.1, ["e_claw", "e_guard"]),
    "bleakheart_satyr": ("Bleakheart Satyr", "caster", "demon", 1.0, ["e_shadowbolt", "e_drain"]),
    "blackfathom_tide_priestess": ("Blackfathom Tide Priestess", "caster", "naga", 1.0, ["e_frostbolt", "e_heal"]),
    "blackfathom_myrmidon": ("Blackfathom Myrmidon", "fighter", "naga", 1.1, ["e_strike", "e_cleave"]),
    "twilight_acolyte": ("Twilight Acolyte", "caster", "human", 1.0, ["e_shadowbolt", "e_renew"]),
    # Duskwood
    "skeletal_warrior": ("Skeletal Warrior", "protector", "undead", 1.1, ["e_strike", "e_guard"]),
    "nightbane_shadow_weaver": ("Nightbane Shadow Weaver", "caster", "worgen", 1.0, ["e_shadowbolt", "e_curse"]),
    "venom_web_spider": ("Venom Web Spider", "fighter", "beast", 0.9, ["e_poison", "e_web"]),
    "bone_chewer": ("Bone Chewer", "fighter", "undead", 1.1, ["e_bite", "e_plague"]),
    "plague_spreader": ("Plague Spreader", "caster", "undead", 1.0, ["e_plague", "e_drain"]),
    # Wetlands
    "dragonmaw_grunt": ("Dragonmaw Grunt", "protector", "orc", 1.1, ["e_strike", "e_guard"]),
    "dragonmaw_shadowwarder": ("Dragonmaw Shadowwarder", "caster", "orc", 1.0, ["e_shadowbolt", "e_drain"]),
    "mottled_raptor": ("Mottled Raptor", "fighter", "beast", 1.0, ["e_bite", "e_claw"]),
    "mosshide_gnoll": ("Mosshide Gnoll", "fighter", "gnoll", 1.0, ["e_strike", "e_frenzy"]),
    "bluegill_murloc": ("Bluegill Murloc", "caster", "murloc", 0.9, ["e_frostbolt", "e_wave"]),
    # Hillsbrad Foothills
    "hillsbrad_footman": ("Hillsbrad Footman", "protector", "human", 1.1, ["e_strike", "e_shieldbash"]),
    "hillsbrad_farmer": ("Hillsbrad Farmer", "fighter", "human", 1.0, ["e_strike", "e_rally"]),
    "hillsbrad_councilman": ("Hillsbrad Councilman", "caster", "human", 1.0, ["e_holyfire", "e_heal"]),
    "syndicate_thief": ("Syndicate Thief", "fighter", "human", 0.9, ["e_strike", "e_poison"]),
    "torn_fin_tidehunter": ("Torn Fin Tidehunter", "caster", "murloc", 0.9, ["e_frostbolt", "e_net"]),
    "gray_bear": ("Gray Bear", "protector", "beast", 1.1, ["e_claw", "e_enrage"]),
}

# key: (Wowhead name, role, race, hp, atk, abilities, heroic ability)
BOSSES = {
    "hogger": ("Hogger", "fighter", "gnoll", 210, 10),
    "thermaplugg": ("Mekgineer Thermaplugg", "caster", "gnome", 190, 6),
    "whitemane": ("High Inquisitor Whitemane", "caster", "human", 185, 5),
    "melenas": ("Lord Melenas", "caster", "nightelf", 185, 5),
    "zalazane": ("Zalazane", "caster", "troll", 185, 6),
    "arrachea": ("Arra'chea", "protector", "beast", 230, 9),
    "lorthuna": ("High Priestess Lorthuna", "caster", "elf", 190, 5),
    "vancleef": ("Edwin VanCleef", "fighter", "human", 210, 10),
    "galgosh": ("Boss Galgosh", "protector", "trogg", 235, 8),
    "arugal": ("Archmage Arugal", "caster", "human", 190, 5),
    "murkdeep": ("Murkdeep", "fighter", "murloc", 205, 9),
    "kodobane": ("Barak Kodobane", "fighter", "centaur", 215, 10),
    "gathilzogg": ("Gath'Ilzogg", "protector", "orc", 240, 9),
    "gerenzo": ("Gerenzo Wrenchwhistle", "caster", "goblin", 190, 6),
    "akumai": ("Aku'mai", "protector", "beast", 250, 9),
    "stitches": ("Stitches", "protector", "undead", 255, 10),
    "nekrosh": ("Chieftain Nek'rosh", "fighter", "orc", 220, 10),
    "burnside": ("Magistrate Burnside", "caster", "human", 195, 5),
}

# Creatures Wowhead does not list under this name borrow a look-alike's model.
FALLBACK = {"Fel Rock Grell": "Grellkin", "Rotting Horror": "Bone Chewer"}


def ids(name):
    entry = IDS.get(name) or IDS.get(FALLBACK.get(name, ""))
    if not entry or not entry.get("display"):
        print("missing model:", name)
        return 0, 0
    return entry["id"], entry["display"]


def lua_list(items):
    return "{ " + ", ".join(f'"{i}"' for i in items) + " }"


def main():
    lines = [
        "-- Generated by tools/gen_mercenaries_enemies.py; edit the script, not this file.",
        "-- The creatures of the bounties. Stats are for level 60, like the mercenaries'.",
        "",
        "local _, ns = ...",
        "ns.Mercenaries = ns.Mercenaries or {}",
        "local MC = ns.Mercenaries",
        "",
        "MC.Enemies = {",
    ]
    for key, (name, role, race, scale, abilities) in ENEMIES.items():
        npc, display = ids(name)
        hp, atk = BASE[role]
        lines.append(
            f'    {key} = {{ npc = {npc}, display = {display}, role = "{role}", race = "{race}", '
            f"hp = {round(hp * scale)}, atk = {atk}, abilities = {lua_list(abilities)} }},"
        )
    for key, (name, role, race, hp, atk) in BOSSES.items():
        npc, display = ids(name)
        abilities = [f"{key}_{i}" for i in (1, 2, 3)]
        lines.append(
            f'    {key} = {{ npc = {npc}, display = {display}, role = "{role}", race = "{race}", '
            f'hp = {hp}, atk = {atk}, boss = true, abilities = {lua_list(abilities)}, heroic = "{key}_h" }},'
        )
    lines.append("}")
    lines.append("")
    OUT.write_text("\n".join(lines), encoding="utf-8", newline="\n")
    print("wrote", OUT)
    write_names()


def lua_string(text):
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


def write_names():
    """English and German names of every creature, as the client shows them (from Wowhead)."""
    rows = {"enUS": [], "deDE": []}
    for key, spec in list(ENEMIES.items()) + list(BOSSES.items()):
        name = spec[0]
        entry = IDS.get(name) or IDS.get(FALLBACK.get(name, "")) or {}
        rows["enUS"].append(f"    MC_E_{key} = {lua_string(name)},")
        rows["deDE"].append(f"    MC_E_{key} = {lua_string(entry.get('de') or name)},")
    lines = [
        "-- Generated by tools/gen_mercenaries_enemies.py from tools/npc_ids.json; edit the script, not this file.",
        "",
        "local _, ns = ...",
        "",
    ]
    for lang, entries in rows.items():
        lines.append(f'ns.AddStrings("{lang}", {{')
        lines.extend(entries)
        lines.append("})")
        lines.append("")
    NAMES_OUT.write_text("\n".join(lines), encoding="utf-8", newline="\n")
    print("wrote", NAMES_OUT)


if __name__ == "__main__":
    main()
