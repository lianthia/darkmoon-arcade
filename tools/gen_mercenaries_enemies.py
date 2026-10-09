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
    # Thousand Needles
    "galak_marauder": ("Galak Marauder", "fighter", "centaur", 1.0, ["e_strike", "e_trample"]),
    "galak_windchaser": ("Galak Windchaser", "caster", "centaur", 1.0, ["e_lightning", "e_net"]),
    "grimtotem_geomancer": ("Grimtotem Geomancer", "caster", "tauren", 1.0, ["e_firebolt", "e_chainlight"]),
    "grimtotem_stomper": ("Grimtotem Stomper", "protector", "tauren", 1.1, ["e_thunderclap", "e_guard"]),
    "crag_coyote": ("Crag Coyote", "fighter", "beast", 0.9, ["e_bite", "e_howl"]),
    "saltstone_basilisk": ("Saltstone Basilisk", "protector", "beast", 1.1, ["e_claw", "e_harden"]),
    # Alterac Mountains
    "syndicate_wizard": ("Syndicate Wizard", "caster", "human", 1.0, ["e_frostbolt", "e_fireball"]),
    "syndicate_sentry": ("Syndicate Sentry", "protector", "human", 1.0, ["e_strike", "e_guard"]),
    "crushridge_ogre": ("Crushridge Ogre", "fighter", "ogre", 1.2, ["e_slam", "e_enrage"]),
    "crushridge_mage": ("Crushridge Mage", "caster", "ogre", 1.0, ["e_fireball", "e_curse"]),
    "mountain_lion": ("Mountain Lion", "fighter", "beast", 0.9, ["e_bite", "e_claw"]),
    # Arathi Highlands
    "boulderfist_ogre": ("Boulderfist Ogre", "fighter", "ogre", 1.2, ["e_slam", "e_thunderclap"]),
    "witherbark_troll": ("Witherbark Troll", "fighter", "troll", 1.0, ["e_strike", "e_bloodlust"]),
    "witherbark_shadowcaster": ("Witherbark Shadowcaster", "caster", "troll", 1.0, ["e_shadowbolt", "e_shadowword"]),
    "highland_strider": ("Highland Strider", "fighter", "beast", 0.9, ["e_bite", "e_dive"]),
    "thundering_exile": ("Thundering Exile", "caster", "elemental", 1.0, ["e_chainlight", "e_lightning"]),
    "burning_exile": ("Burning Exile", "caster", "elemental", 1.0, ["e_fireball", "e_flamestrike"]),
    "cresting_exile": ("Cresting Exile", "protector", "elemental", 1.1, ["e_wave", "e_harden"]),
    # Desolace
    "gelkis_earthcaller": ("Gelkis Earthcaller", "caster", "centaur", 1.0, ["e_lightning", "e_renew"]),
    "magram_wrangler": ("Magram Wrangler", "fighter", "centaur", 1.0, ["e_strike", "e_net"]),
    "burning_blade_summoner": ("Burning Blade Summoner", "caster", "orc", 1.0, ["e_shadowbolt", "e_curse"]),
    "hatefury_felsworn": ("Hatefury Felsworn", "fighter", "satyr", 1.0, ["e_strike", "e_shadowword"]),
    "scorpashi_venomlash": ("Scorpashi Venomlash", "fighter", "beast", 0.9, ["e_poison", "e_claw"]),
    "primordial_behemoth": ("Primordial Behemoth", "protector", "elemental", 1.3, ["e_slam", "e_harden"]),
    "creeping_sludge": ("Creeping Sludge", "protector", "ooze", 1.1, ["e_poison", "e_guard"]),
    # Shen'dralas (WoW: Forever)
    "magram_necromancer": ("Magram Necromancer", "caster", "centaur", 1.0, ["e_shadowbolt", "e_drain"]),
    "magram_marauder": ("Magram Marauder", "fighter", "centaur", 1.0, ["e_strike", "e_trample"]),
    "decrepit_pylon_protector": ("Decrepit Pylon Protector", "protector", "construct", 1.2, ["e_slam", "e_guard"]),
    "bristleback_skullcrusher": ("Bristleback Skullcrusher", "fighter", "quilboar", 1.0, ["e_strike", "e_enrage"]),
    "blind_screecher": ("Blind Screecher", "fighter", "beast", 0.9, ["e_dive", "e_frenzy"]),
    "outcast_marauder": ("Outcast Marauder", "fighter", "elf", 1.0, ["e_strike", "e_cleave"]),
    "outcast_necrokhan": ("Outcast Necrokhan", "caster", "centaur", 1.1, ["e_volley", "e_drain"]),
    # Riverglades (WoW: Forever)
    "bolderok_brute": ("Bolder'ok Brute", "fighter", "ogre", 1.2, ["e_slam", "e_enrage"]),
    "twilight_fanatic": ("Twilight Fanatic", "caster", "human", 1.0, ["e_shadowbolt", "e_shadowword"]),
    "twilight_champion": ("Twilight Champion", "protector", "human", 1.1, ["e_strike", "e_guard"]),
    "eastsea_raider": ("Eastsea Raider", "fighter", "human", 1.0, ["e_strike", "e_cleave"]),
    "mudfin_oracle": ("Mudfin Oracle", "caster", "murloc", 0.9, ["e_frostbolt", "e_heal"]),
    "wildplains_patriarch": ("Wildplains Patriarch", "protector", "beast", 1.1, ["e_trample", "e_harden"]),
    # Stranglethorn Vale
    "bloodscalp_warrior": ("Bloodscalp Warrior", "fighter", "troll", 1.0, ["e_strike", "e_bloodlust"]),
    "bloodscalp_shaman": ("Bloodscalp Shaman", "caster", "troll", 1.0, ["e_lightning", "e_heal"]),
    "skullsplitter_hunter": ("Skullsplitter Hunter", "fighter", "troll", 1.0, ["e_strike", "e_net"]),
    "kurzen_jungle_fighter": ("Kurzen Jungle Fighter", "fighter", "human", 1.0, ["e_strike", "e_cleave"]),
    "stranglethorn_tigress": ("Stranglethorn Tigress", "fighter", "beast", 0.9, ["e_bite", "e_claw"]),
    "elder_stranglethorn_tiger": ("Elder Stranglethorn Tiger", "fighter", "beast", 1.0, ["e_bite", "e_frenzy"]),
    # Badlands
    "dustbelcher_ogre": ("Dustbelcher Ogre", "fighter", "ogre", 1.2, ["e_slam", "e_enrage"]),
    "dustbelcher_mystic": ("Dustbelcher Mystic", "caster", "ogre", 1.0, ["e_fireball", "e_heal"]),
    "ridge_huntress": ("Ridge Huntress", "fighter", "beast", 0.9, ["e_bite", "e_howl"]),
    "stonevault_seer": ("Stonevault Seer", "caster", "trogg", 1.0, ["e_lightning", "e_renew"]),
    "earthen_custodian": ("Earthen Custodian", "protector", "earthen", 1.3, ["e_thunderclap", "e_harden"]),
    "stone_keeper": ("Stone Keeper", "protector", "construct", 1.2, ["e_slam", "e_guard"]),
    # Swamp of Sorrows
    "marsh_inkspewer": ("Marsh Inkspewer", "caster", "murloc", 0.9, ["e_frostbolt", "e_wave"]),
    "marsh_flesheater": ("Marsh Flesheater", "fighter", "murloc", 0.9, ["e_bite", "e_frenzy"]),
    "sawtooth_crocolisk": ("Sawtooth Crocolisk", "protector", "beast", 1.1, ["e_bite", "e_harden"]),
    "fen_dweller": ("Fen Dweller", "caster", "elemental", 1.0, ["e_wave", "e_frostbolt"]),
    "atalai_priest": ("Atal'ai Priest", "caster", "troll", 1.0, ["e_shadowbolt", "e_heal"]),
    "nightmare_wanderer": ("Nightmare Wanderer", "fighter", "dragonkin", 1.0, ["e_shadowword", "e_claw"]),
    "atalai_warrior": ("Atal'ai Warrior", "fighter", "troll", 1.0, ["e_strike", "e_bloodlust"]),
    # Dustwallow Marsh
    "darkmist_spider": ("Darkmist Spider", "fighter", "beast", 0.9, ["e_poison", "e_web"]),
    "firemane_scalebane": ("Firemane Scalebane", "fighter", "dragonkin", 1.0, ["e_strike", "e_cleave"]),
    "firemane_ash_tail": ("Firemane Ash Tail", "caster", "dragonkin", 1.0, ["e_fireball", "e_flamestrike"]),
    "bloodfen_raptor": ("Bloodfen Raptor", "fighter", "beast", 0.9, ["e_bite", "e_claw"]),
    "drywallow_crocolisk": ("Drywallow Crocolisk", "protector", "beast", 1.1, ["e_bite", "e_harden"]),
    "onyxian_whelp": ("Onyxian Whelp", "fighter", "dragonkin", 0.8, ["e_fireball", "e_dive"]),
    "onyxian_warder": ("Onyxian Warder", "protector", "dragonkin", 1.2, ["e_cleave", "e_guard"]),
    # Feralas
    "gordunni_ogre": ("Gordunni Ogre", "fighter", "ogre", 1.2, ["e_slam", "e_enrage"]),
    "gordunni_shaman": ("Gordunni Shaman", "caster", "ogre", 1.0, ["e_lightning", "e_heal"]),
    "grimtotem_naturalist": ("Grimtotem Naturalist", "caster", "tauren", 1.0, ["e_renew", "e_lightning"]),
    "woodpaw_mystic": ("Woodpaw Mystic", "caster", "gnoll", 1.0, ["e_lightning", "e_renew"]),
    "feral_scar_yeti": ("Feral Scar Yeti", "protector", "beast", 1.1, ["e_claw", "e_thunderclap"]),
    "hatecrest_siren": ("Hatecrest Siren", "caster", "naga", 1.0, ["e_frostbolt", "e_curse"]),
    "gordok_brute": ("Gordok Brute", "fighter", "ogre", 1.2, ["e_slam", "e_cleave"]),
    "gordok_magelord": ("Gordok Mage-Lord", "caster", "ogre", 1.1, ["e_fireball", "e_volley"]),
    # Tanaris
    "wastewander_bandit": ("Wastewander Bandit", "fighter", "human", 1.0, ["e_strike", "e_net"]),
    "wastewander_shadow_mage": ("Wastewander Shadow Mage", "caster", "human", 1.0, ["e_shadowbolt", "e_volley"]),
    "sandfury_hideskinner": ("Sandfury Hideskinner", "fighter", "troll", 1.0, ["e_strike", "e_bloodlust"]),
    "sandfury_shadowcaster": ("Sandfury Shadowcaster", "caster", "troll", 1.0, ["e_shadowword", "e_drain"]),
    "dune_smasher": ("Dune Smasher", "protector", "elemental", 1.3, ["e_thunderclap", "e_harden"]),
    "southsea_pirate": ("Southsea Pirate", "fighter", "human", 1.0, ["e_strike", "e_cleave"]),
    "sandfury_soul_eater": ("Sandfury Soul Eater", "caster", "troll", 1.0, ["e_drain", "e_curse"]),
    "sandfury_blood_drinker": ("Sandfury Blood Drinker", "fighter", "troll", 1.0, ["e_strike", "e_enrage"]),
    # The Hinterlands
    "witherbark_scalper": ("Witherbark Scalper", "fighter", "troll", 1.0, ["e_strike", "e_cleave"]),
    "witherbark_witch_doctor": ("Witherbark Witch Doctor", "caster", "troll", 1.0, ["e_shadowbolt", "e_heal"]),
    "vilebranch_berserker": ("Vilebranch Berserker", "fighter", "troll", 1.0, ["e_strike", "e_enrage"]),
    "vilebranch_shadowcaster": ("Vilebranch Shadowcaster", "caster", "troll", 1.0, ["e_shadowbolt", "e_shadowword"]),
    "silvermane_stalker": ("Silvermane Stalker", "fighter", "beast", 0.9, ["e_bite", "e_claw"]),
    # Searing Gorge
    "dark_iron_taskmaster": ("Dark Iron Taskmaster", "fighter", "dwarf", 1.0, ["e_strike", "e_rally"]),
    "dark_iron_geologist": ("Dark Iron Geologist", "caster", "dwarf", 1.0, ["e_fireball", "e_harden"]),
    "glassweb_spider": ("Glassweb Spider", "fighter", "beast", 0.9, ["e_poison", "e_web"]),
    "heavy_war_golem": ("Heavy War Golem", "protector", "mechanical", 1.3, ["e_slam", "e_harden"]),
    "magma_elemental": ("Magma Elemental", "caster", "elemental", 1.0, ["e_flamestrike", "e_fireball"]),
    "anvilrage_guardsman": ("Anvilrage Guardsman", "protector", "dwarf", 1.1, ["e_strike", "e_guard"]),
    "shadowforge_flame_keeper": ("Shadowforge Flame Keeper", "caster", "dwarf", 1.0, ["e_fireball", "e_flamestrike"]),
    # Azshara
    "spitelash_warrior": ("Spitelash Warrior", "fighter", "naga", 1.0, ["e_strike", "e_cleave"]),
    "spitelash_siren": ("Spitelash Siren", "caster", "naga", 1.0, ["e_frostbolt", "e_wave"]),
    "highborne_apparition": ("Highborne Apparition", "caster", "undead", 1.0, ["e_volley", "e_curse"]),
    "thunderhead_hippogryph": ("Thunderhead Hippogryph", "fighter", "beast", 0.9, ["e_dive", "e_chainlight"]),
    "legashi_satyr": ("Legashi Satyr", "fighter", "satyr", 1.0, ["e_strike", "e_shadowword"]),
    # Blasted Lands
    "snickerfang_hyena": ("Snickerfang Hyena", "fighter", "beast", 0.9, ["e_bite", "e_howl"]),
    "redstone_basilisk": ("Redstone Basilisk", "protector", "beast", 1.1, ["e_claw", "e_harden"]),
    "felhound": ("Felhound", "fighter", "demon", 1.0, ["e_bite", "e_drain"]),
    "felguard_sentry": ("Felguard Sentry", "protector", "demon", 1.2, ["e_cleave", "e_guard"]),
    "shadowsworn_thug": ("Shadowsworn Thug", "fighter", "human", 1.0, ["e_strike", "e_net"]),
    "shadowsworn_cultist": ("Shadowsworn Cultist", "caster", "human", 1.0, ["e_shadowbolt", "e_volley"]),
    # Felwood
    "jaedenar_cultist": ("Jaedenar Cultist", "caster", "human", 1.0, ["e_shadowbolt", "e_curse"]),
    "jaedenar_adept": ("Jaedenar Adept", "caster", "human", 1.0, ["e_shadowword", "e_drain"]),
    "jaedenar_hound": ("Jaedenar Hound", "fighter", "demon", 1.0, ["e_bite", "e_frenzy"]),
    "deadwood_warrior": ("Deadwood Warrior", "fighter", "furbolg", 1.0, ["e_strike", "e_enrage"]),
    "deadwood_shaman": ("Deadwood Shaman", "caster", "furbolg", 1.0, ["e_lightning", "e_heal"]),
    "toxic_horror": ("Toxic Horror", "protector", "elemental", 1.2, ["e_poison", "e_plague"]),
    "jaedenar_darkweaver": ("Jaedenar Darkweaver", "caster", "satyr", 1.0, ["e_volley", "e_shadowbolt"]),
    "jaedenar_guardian": ("Jaedenar Guardian", "protector", "demon", 1.2, ["e_cleave", "e_guard"]),
    # Un'Goro Crater
    "stegodon": ("Stegodon", "protector", "beast", 1.3, ["e_trample", "e_harden"]),
    "ravasaur_hunter": ("Ravasaur Hunter", "fighter", "beast", 0.9, ["e_bite", "e_poison"]),
    "frenzied_pterrordax": ("Frenzied Pterrordax", "fighter", "beast", 0.9, ["e_dive", "e_frenzy"]),
    "ungoro_gorilla": ("Un'Goro Gorilla", "fighter", "beast", 1.1, ["e_slam", "e_enrage"]),
    "tar_creeper": ("Tar Creeper", "protector", "elemental", 1.2, ["e_slam", "e_web"]),
    "glutinous_ooze": ("Glutinous Ooze", "caster", "ooze", 1.0, ["e_poison", "e_plague"]),
    "devilsaur": ("Devilsaur", "fighter", "beast", 1.4, ["e_bite", "e_trample"]),
    # Burning Steppes
    "blackrock_soldier": ("Blackrock Soldier", "protector", "orc", 1.1, ["e_strike", "e_guard"]),
    "blackrock_warlock": ("Blackrock Warlock", "caster", "orc", 1.0, ["e_shadowbolt", "e_curse"]),
    "black_broodling": ("Black Broodling", "fighter", "dragonkin", 0.9, ["e_fireball", "e_bite"]),
    "firegut_ogre": ("Firegut Ogre", "fighter", "ogre", 1.2, ["e_slam", "e_enrage"]),
    "blackrock_worg": ("Blackrock Worg", "fighter", "beast", 0.9, ["e_bite", "e_howl"]),
    "blackhand_veteran": ("Blackhand Veteran", "fighter", "orc", 1.1, ["e_cleave", "e_rally"]),
    "blackhand_summoner": ("Blackhand Summoner", "caster", "orc", 1.0, ["e_fireball", "e_flamestrike"]),
    "chromatic_whelp": ("Chromatic Whelp", "fighter", "dragonkin", 0.8, ["e_fireball", "e_frostbolt"]),
    # Western Plaguelands
    "skeletal_flayer": ("Skeletal Flayer", "fighter", "undead", 1.0, ["e_strike", "e_frenzy"]),
    "diseased_wolf": ("Diseased Wolf", "fighter", "beast", 0.9, ["e_bite", "e_plague"]),
    "scarlet_mage": ("Scarlet Mage", "caster", "human", 1.0, ["e_fireball", "e_frostbolt"]),
    "scarlet_knight": ("Scarlet Knight", "protector", "human", 1.1, ["e_strike", "e_shieldbash"]),
    "rotting_ghoul": ("Rotting Ghoul", "fighter", "undead", 1.0, ["e_strike", "e_plague"]),
    "scholomance_necromancer": ("Scholomance Necromancer", "caster", "human", 1.0, ["e_shadowbolt", "e_drain"]),
    "risen_guard": ("Risen Guard", "protector", "undead", 1.2, ["e_strike", "e_guard"]),
    "scholomance_dark_summoner": ("Scholomance Dark Summoner", "caster", "human", 1.0, ["e_volley", "e_curse"]),
    # Eastern Plaguelands
    "plaguehound": ("Plaguehound", "fighter", "undead", 0.9, ["e_bite", "e_plague"]),
    "crypt_walker": ("Crypt Walker", "protector", "undead", 1.2, ["e_slam", "e_web"]),
    "cursed_mage": ("Cursed Mage", "caster", "undead", 1.0, ["e_frostbolt", "e_curse"]),
    "scourge_soldier": ("Scourge Soldier", "protector", "undead", 1.1, ["e_strike", "e_guard"]),
    "gibbering_ghoul": ("Gibbering Ghoul", "fighter", "undead", 1.0, ["e_strike", "e_frenzy"]),
    "blighted_horror": ("Blighted Horror", "protector", "undead", 1.2, ["e_plague", "e_slam"]),
    "skeletal_berserker": ("Skeletal Berserker", "fighter", "undead", 1.0, ["e_cleave", "e_enrage"]),
    "thuzadin_necromancer": ("Thuzadin Necromancer", "caster", "undead", 1.0, ["e_shadowbolt", "e_volley"]),
    # Winterspring
    "winterfall_ursa": ("Winterfall Ursa", "protector", "furbolg", 1.1, ["e_claw", "e_guard"]),
    "winterfall_shaman": ("Winterfall Shaman", "caster", "furbolg", 1.0, ["e_lightning", "e_heal"]),
    "frostsaber_huntress": ("Frostsaber Huntress", "fighter", "beast", 0.9, ["e_bite", "e_claw"]),
    "ice_thistle_yeti": ("Ice Thistle Yeti", "protector", "beast", 1.2, ["e_slam", "e_thunderclap"]),
    "winterspring_screecher": ("Winterspring Screecher", "fighter", "beast", 0.9, ["e_dive", "e_frenzy"]),
    "frostmaul_giant": ("Frostmaul Giant", "protector", "giant", 1.4, ["e_slam", "e_thunderclap"]),
    "winterfall_den_watcher": ("Winterfall Den Watcher", "fighter", "furbolg", 1.1, ["e_strike", "e_enrage"]),
    # Silithus
    "hiveashi_drone": ("Hive'Ashi Drone", "fighter", "silithid", 0.9, ["e_bite", "e_poison"]),
    "hivezora_wasp": ("Hive'Zora Wasp", "fighter", "silithid", 0.9, ["e_dive", "e_poison"]),
    "dust_stormer": ("Dust Stormer", "caster", "elemental", 1.0, ["e_chainlight", "e_wave"]),
    "twilight_geolord": ("Twilight Geolord", "caster", "human", 1.0, ["e_fireball", "e_volley"]),
    "stonelash_pincer": ("Stonelash Pincer", "protector", "beast", 1.1, ["e_claw", "e_harden"]),
    "anubisath_sentinel": ("Anubisath Sentinel", "protector", "construct", 1.4, ["e_slam", "e_thunderclap"]),
    "qiraji_mindslayer": ("Qiraji Mindslayer", "caster", "silithid", 1.0, ["e_shadowword", "e_drain"]),
    # Mount Hyjal (WoW: Forever) - the Legion's host from the battle of Mount Hyjal
    "doomguard_commander": ("Doomguard Commander", "fighter", "demon", 1.3, ["e_cleave", "e_shadowword"]),
    "felguard_elite": ("Felguard Elite", "protector", "demon", 1.2, ["e_cleave", "e_guard"]),
    "jaedenar_legionnaire": ("Jaedenar Legionnaire", "fighter", "satyr", 1.0, ["e_strike", "e_bloodlust"]),
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
    "arnak": ("Arnak Grimtotem", "protector", "tauren", 240, 9),
    "perenolde": ("Lord Aliden Perenolde", "caster", "human", 190, 6),
    "myzrael": ("Myzrael", "caster", "elemental", 200, 6),
    "theradras": ("Princess Theradras", "protector", "elemental", 260, 10),
    "necrokhan": ("Magram Necrokhan", "caster", "centaur", 200, 6),
    "clugfist": ("Clugfist", "fighter", "ogre", 230, 11),
    "bangalash": ("King Bangalash", "fighter", "beast", 215, 11),
    "archaedas": ("Archaedas", "protector", "construct", 270, 9),
    "eranikus": ("Shade of Eranikus", "caster", "dragonkin", 210, 7),
    "onyxia": ("Onyxia", "fighter", "dragonkin", 260, 11),
    "gordok": ("King Gordok", "fighter", "ogre", 250, 12),
    "gahzrilla": ("Gahz'rilla", "protector", "beast", 270, 10),
    "hexx": ("Vile Priestess Hexx", "caster", "troll", 205, 6),
    "thaurissan": ("Emperor Dagran Thaurissan", "caster", "dwarf", 230, 9),
    "azuregos": ("Azuregos", "caster", "dragonkin", 300, 9),
    "kazzak": ("Lord Kazzak", "fighter", "demon", 310, 13),
    "banehollow": ("Lord Banehollow", "caster", "demon", 230, 7),
    "mosh": ("King Mosh", "fighter", "beast", 300, 13),
    "rend": ("Warchief Rend Blackhand", "fighter", "orc", 260, 12),
    "gandling": ("Darkmaster Gandling", "caster", "human", 230, 8),
    "rivendare": ("Baron Rivendare", "fighter", "undead", 280, 12),
    "winterfall": ("High Chief Winterfall", "fighter", "furbolg", 240, 11),
    "cthun": ("C'Thun", "caster", "old god", 340, 10),
    "archimonde": ("Echo of Archimonde", "caster", "demon", 320, 10),
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
