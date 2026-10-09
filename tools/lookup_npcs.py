"""Looks up NPC and display IDs for WoW: Forever on Wowhead.

python tools/lookup_npcs.py "Hogger" "Riverpaw Gnoll" ...   (or no names: everything in NAMES)
Results are cached in tools/npc_ids.json; names already there are skipped.
"""
import html
import json
import pathlib
import re
import sys
import time
import urllib.parse
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent
CACHE = ROOT / "npc_ids.json"
UA = {"User-Agent": "Mozilla/5.0"}

NAMES = [
    # Mercenaries
    "Highlord Bolvar Fordragon", "Cairne Bloodhoof", "King Magni Bronzebeard", "Tirion Fordring", "Eitrigg",
    "Highlord Taelan Fordring", "Rexxar", "Lady Sylvanas Windrunner", "Vol'jin", "Shandris Feathermoon",
    "Mankrik", "Renzik \"The Shiv\"", "Lady Jaina Proudmoore", "Thrall", "Tyrande Whisperwind",
    "Magatha Grimtotem", "Archbishop Benedictus", "Arch Druid Hamuul Runetotem",
    # Bosses
    "Hogger", "Mekgineer Thermaplugg", "High Inquisitor Whitemane", "Lord Melenas", "Zalazane", "Arra'chea",
    "High Priestess Lorthuna", "Edwin VanCleef", "Boss Galgosh", "Archmage Arugal", "Murkdeep", "Barak Kodobane",
    "Gath'Ilzogg", "Gerenzo Wrenchwhistle", "Aku'mai", "Stitches", "Chieftain Nek'rosh", "Magistrate Burnside",
    # Zone enemies
    "Kobold Vermin", "Kobold Tunneler", "Riverpaw Outrunner", "Defias Thug", "Murloc Streamrunner", "Prowler",
    "Frostmane Troll Whelp", "Frostmane Seer", "Rockjaw Trogg", "Leper Gnome", "Ice Claw Bear",
    "Rattlecage Skeleton", "Mindless Zombie", "Scarlet Convert", "Scarlet Missionary", "Darkhound", "Scarlet Monk",
    "Grellkin", "Timberling", "Gnarlpine Ursa", "Webwood Spider", "Nightsaber", "Fel Rock Grell",
    "Vile Familiar", "Mottled Boar", "Scorpid Worker", "Kul Tiras Sailor", "Durotar Tiger", "Voodoo Troll",
    "Plainstrider", "Bristleback Quilboar", "Palemane Tanner", "Venture Co. Laborer", "Prairie Wolf",
    "Defias Pillager", "Defias Trapper", "Harvest Golem", "Riverpaw Gnoll", "Fleshripper", "Defias Blackguard",
    "Stonesplinter Trogg", "Stonesplinter Seer", "Mo'grosh Ogre", "Tunnel Rat Kobold", "Dark Iron Dwarf",
    "Mountain Buzzard",
    "Moonrage Whitescalp", "Dalaran Apprentice", "Rot Hide Gnoll", "Shadowfang Moonwalker", "Son of Arugal",
    "Greymist Coastrunner", "Blackwood Pathfinder", "Darkshore Thresher", "Greymist Seer", "Moonstalker",
    "Razormane Thornweaver", "Kolkar Wrangler", "Witchwing Harpy", "Venture Co. Peon", "Savannah Huntress",
    "Kolkar Stormer",
    "Redridge Mongrel", "Redridge Mystic", "Blackrock Grunt", "Blackrock Shadowcaster", "Shadowhide Brute",
    "Venture Co. Logger", "Venture Co. Operator", "Deepmoss Webspinner", "Bloodfury Harpy", "Grimtotem Ruffian",
    "Foulweald Warrior", "Bleakheart Satyr", "Blackfathom Tide Priestess", "Blackfathom Myrmidon",
    "Twilight Acolyte", "Raging Agam'ar",
    "Skeletal Warrior", "Rotting Horror", "Nightbane Shadow Weaver", "Venom Web Spider", "Bone Chewer",
    "Plague Spreader",
    "Dragonmaw Grunt", "Dragonmaw Shadowwarder", "Mottled Raptor", "Mosshide Gnoll", "Bluegill Murloc",
    "Hillsbrad Footman", "Hillsbrad Farmer", "Syndicate Thief", "Torn Fin Tidehunter", "Gray Bear",
    "Hillsbrad Councilman",
]


def fetch(url):
    for attempt in range(3):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=30) as r:
                raw = r.read()
            # Pages are UTF-8 with the odd broken byte; replacing those keeps the umlauts intact.
            return raw.decode("utf-8", "replace")
        except OSError as exc:  # network hiccups and rate limits are retried
            if attempt == 2:
                raise
            print("  retry", url, exc)
            time.sleep(90 if "403" in str(exc) else 3)


def lookup(name):
    q = urllib.parse.quote(name)
    data = json.loads(fetch(f"https://www.wowhead.com/forever/search/suggestions-template?q={q}"))
    npcs = [r for r in data.get("results", []) if r.get("type") == 1]
    exact = [r for r in npcs if r["name"].lower() == name.lower()] or npcs
    if not exact:
        return None
    hit = exact[0]
    html = fetch(f"https://www.wowhead.com/forever/npc={hit['id']}")
    display = re.search(r"displayId = (\d+)", html)
    de_name = german_name(hit["id"])
    return {
        "id": hit["id"],
        "name": hit["name"],
        "de": de_name,
        "info": hit.get("pinDescription", ""),
        "display": int(display.group(1)) if display else None,
    }


def german_name(npc_id):
    page = fetch(f"https://www.wowhead.com/forever/de/npc={npc_id}")
    match = re.search(r'<h1 class="heading-size-1">([^<]+)', page)
    if not match:
        return None
    # The heading carries the title in angle brackets after the name.
    return html.unescape(match.group(1)).split("<")[0].strip()


def main():
    if sys.argv[1:] == ["--refresh-de"]:
        cache = json.loads(CACHE.read_text(encoding="utf-8"))
        for name, entry in cache.items():
            de = entry and entry.get("de") or ""
            if entry and ("�" in de or "&" in de or "<" in de):
                entry["de"] = german_name(entry["id"])
                print(name, "->", entry["de"])
                time.sleep(1.5)
        CACHE.write_text(json.dumps(cache, indent=1, ensure_ascii=False, sort_keys=True), encoding="utf-8")
        return

    cache = json.loads(CACHE.read_text(encoding="utf-8")) if CACHE.exists() else {}
    names = sys.argv[1:] or NAMES
    for name in names:
        if name in cache:
            continue
        try:
            cache[name] = lookup(name)
        except Exception as exc:  # noqa: BLE001
            print("failed", name, exc)
            continue
        print(name, "->", cache[name])
        CACHE.write_text(json.dumps(cache, indent=1, ensure_ascii=False, sort_keys=True), encoding="utf-8")
        time.sleep(1.5)


if __name__ == "__main__":
    main()
