"""Writes DarkmoonArcade/Games/Mercenaries/ItemData.lua: python tools/gen_mercenaries_items.py

Mercenaries' items are the real Classic loot of its dungeons:
- which boss drops what, and how often: AtlasLoot Classic's data (github.com/Hoizame/AtlasLootClassic,
  data.lua and droprate.lua; facts only, nothing of its code),
- names in the six languages, icon, quality and stats: Wowhead's tooltips (Classic).

Our bonuses follow each item's WoW stats, bought from the point budget of its rarity (MC.ITEM_BUDGET,
Games/Mercenaries/Items.lua): Strength and attack power -> attack, Agility -> critical strikes, Stamina ->
health, Intellect -> spell damage, Spirit -> experience (comfort), a resistance -> that resistance,
defense -> less damage taken, health over time -> regeneration, a proc of a school's damage (or a
wand's) -> that school's damage. Rings, necks and
trinkets put half their points into coins per bounty (comfort). Bags, quest items and pets are left out.
Everything fetched is cached in tools/.cache.
"""
import json
import pathlib
import re
import time
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
CACHE = ROOT / "tools" / ".cache"
OUT = ROOT / "DarkmoonArcade" / "Games" / "Mercenaries" / "ItemData.lua"
UA = {"User-Agent": "Mozilla/5.0"}
ATLASLOOT = "https://raw.githubusercontent.com/Hoizame/AtlasLootClassic/master/AtlasLootClassic_DungeonsAndRaids/"

# Our dungeons and their AtlasLoot keys, bosses in the order of the dungeon.
DUNGEONS = {
    "deadmines": "TheDeadmines",
    "wailing": "WailingCaverns",
}
# Wowhead's locale numbers.
LOCALES = {"enUS": 0, "deDE": 3, "frFR": 2, "esES": 6, "ruRU": 7, "zhCN": 4}
BUDGET = {"common": 2, "uncommon": 4, "rare": 6, "epic": 8, "legendary": 10}
QUALITY = {1: "common", 2: "uncommon", 3: "rare", 4: "epic", 5: "legendary"}
STAT_BONUS = {"Strength": "atkPct", "Agility": "critChance", "Stamina": "hpPct", "Intellect": "spellPct",
              "Spirit": "xpPct"}
RESISTANCES = {"Fire": "fire", "Frost": "frost", "Nature": "nature", "Shadow": "shadow", "Holy": "holy",
               "Arcane": "arcane"}
WEAPON_SLOTS = {"One-Hand", "Two-Hand", "Main Hand", "Off Hand", "Ranged", "Thrown", "Ranged Right",
                "Held In Off-hand"}
ARMOR_SLOTS = {"Head", "Shoulder", "Chest", "Robe", "Waist", "Legs", "Feet", "Wrist", "Hands", "Back",
               "Shirt", "Tabard"}
JEWELRY_SLOTS = {"Finger", "Neck", "Trinket"}


def fetch(url, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    if not path.exists():
        path.write_bytes(urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=60).read())
        time.sleep(0.3)
    return path.read_text(encoding="utf-8")


def atlasloot():
    data = fetch(ATLASLOOT + "data.lua", CACHE / "atlasloot" / "data.lua")
    rates_src = fetch(ATLASLOOT + "droprate.lua", CACHE / "atlasloot" / "droprate.lua")
    rates = {}
    for npc, body in re.findall(r"\[(\d+)\] = \{([^{}]*)\}", rates_src):
        rates[int(npc)] = {int(i): float(r) for i, r in re.findall(r"\[(\d+)\] = ([\d.]+)", body)}
    dungeons = {}
    for key, al_key in DUNGEONS.items():
        start = data.index(f'data["{al_key}"]')
        end = data.index('\ndata["', start + 10)
        section = data[start:end]
        bosses = []
        for block in re.split(r"\n\t\t\{\s*--", section)[1:]:
            npc = re.search(r"npcID = (\d+)", block)
            if not npc:
                continue
            items = [int(i) for i in re.findall(r"\{ *\d+, *(\d+) *\}", block)]
            special = re.search(r'specialType = "(\w+)"', block)
            bosses.append({"npc": int(npc.group(1)), "items": items, "special": special and special.group(1)})
        dungeons[key] = bosses
    return dungeons, rates


def tooltip(kind, wid, locale):
    url = f"https://nether.wowhead.com/tooltip/{kind}/{wid}?dataEnv=4&locale={LOCALES[locale]}"
    return json.loads(fetch(url, CACHE / "wowhead" / f"{kind}-{wid}-{locale}.json"))


def stats_of(html):
    """WoW stats, slot and kind from a tooltip."""
    text = re.sub(r"<[^>]+>", "\n", html)
    lines = [line.strip() for line in text.split("\n") if line.strip()]
    stats = {}
    for line in lines:
        m = re.match(r"\+(\d+) (Strength|Agility|Stamina|Intellect|Spirit)$", line)
        if m:
            stats[STAT_BONUS[m.group(2)]] = stats.get(STAT_BONUS[m.group(2)], 0) + int(m.group(1))
        m = re.match(r"\+(\d+) (\w+) Resistance$", line)
        if m and m.group(2) in RESISTANCES:
            key = "resist_" + RESISTANCES[m.group(2)]
            stats[key] = stats.get(key, 0) + int(m.group(1))
        m = re.match(r"\+(\d+) Attack Power", line)
        if m:
            stats["atkPct"] = stats.get("atkPct", 0) + int(m.group(1))
        m = re.match(r"Restores (\d+) health", line)
        if m:
            stats["regenPct"] = stats.get("regenPct", 0) + int(m.group(1))
        m = re.match(r"Increased Defense \+(\d+)", line)
        if m:
            stats["takenPct"] = stats.get("takenPct", 0) + int(m.group(1))
        # A proc or an equip effect of a school's damage: that school's damage, worth a fair share.
        m = re.search(r"(Fire|Frost|Nature|Shadow|Holy|Arcane) [Dd]amage", line)
        if m:
            key = "school_" + RESISTANCES[m.group(1)]
            stats[key] = max(stats.get(key, 0), 6)
    slot = next((line for line in lines if line in WEAPON_SLOTS | ARMOR_SLOTS | JEWELRY_SLOTS), None)
    if slot is None and "Shield" in lines:
        slot = "Off Hand"
    kind = "weapon" if slot in WEAPON_SLOTS else "armor" if slot in ARMOR_SLOTS else "jewelry" if slot else None
    if "Shield" in lines:
        kind = "armor"
    return stats, slot, kind


def allocate(shares, budget):
    """Splits `budget` points over the keys in proportion to `shares` (largest remainder)."""
    total = sum(shares.values())
    if total <= 0 or budget <= 0:
        return {}
    raw = {k: budget * v / total for k, v in shares.items()}
    points = {k: int(v) for k, v in raw.items()}
    left = budget - sum(points.values())
    for k in sorted(raw, key=lambda k: raw[k] - points[k], reverse=True)[:left]:
        points[k] += 1
    return {k: v for k, v in points.items() if v > 0}


def item_points(stats, kind, budget):
    if kind == "jewelry":
        comfort = budget // 2
        points = allocate(stats, budget - comfort) or {}
        points["coinPct"] = points.get("coinPct", 0) + comfort + (budget - comfort - sum(points.values()))
        return points
    if not stats:
        # No stats on the item: its kind's plain bonus.
        stats = {"atkPct": 1} if kind == "weapon" else {"hpPct": 1}
    return allocate(stats, budget)


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def main():
    dungeons, rates = atlasloot()
    items, names, boss_names, skipped = {}, {loc: {} for loc in LOCALES}, {loc: {} for loc in LOCALES}, []
    loot = {}
    for dungeon, bosses in dungeons.items():
        loot[dungeon] = []
        for boss in bosses:
            npc = boss["npc"]
            for loc in LOCALES:
                boss_names[loc][npc] = tooltip("npc", npc, loc)["name"]
            drops = []
            for wid in boss["items"]:
                en = tooltip("item", wid, "enUS")
                rarity = QUALITY.get(en.get("quality"))
                stats, slot, kind = stats_of(en["tooltip"])
                if not rarity or not kind:
                    skipped.append(f"{wid} {en['name']} ({slot or 'no slot'})")
                    continue
                if wid not in items:
                    items[wid] = {"rarity": rarity, "kind": kind, "slot": slot, "icon": en["icon"],
                                  "points": item_points(stats, kind, BUDGET[rarity]), "stats": stats}
                    for loc in LOCALES:
                        names[loc][wid] = tooltip("item", wid, loc)["name"]
                drops.append((wid, rates.get(npc, {}).get(wid)))
            loot[dungeon].append({"npc": npc, "special": boss["special"], "drops": drops})

    lines = [
        "-- Generated by tools/gen_mercenaries_items.py (AtlasLoot Classic's loot and drop rates, Wowhead's",
        "-- names, icons and stats); do not edit. Item bonuses: Games/Mercenaries/Items.lua.",
        "",
        "local _, ns = ...",
        "ns.Mercenaries = ns.Mercenaries or {}",
        "local MC = ns.Mercenaries",
        "",
        "-- kind: weapon, armor or jewelry; points: what the item's budget buys (MC.ITEM_POINT).",
        "MC.Items = {",
    ]
    for wid in sorted(items):
        it = items[wid]
        points = ", ".join(f"{k} = {v}" for k, v in sorted(it["points"].items()))
        lines.append(f'    [{wid}] = {{ rarity = "{it["rarity"]}", kind = "{it["kind"]}", '
                     f'icon = "Interface\\\\Icons\\\\{it["icon"]}", points = {{ {points} }} }},')
    lines += ["}", "", "-- Per dungeon, its bosses in order with their loot: item and chance in % (Classic's).",
              "MC.DungeonLoot = {"]
    for dungeon, bosses in loot.items():
        lines.append(f"    {dungeon} = {{")
        for boss in bosses:
            drops = ", ".join(f"{{ {wid}, {rate if rate is not None else 'nil'} }}" for wid, rate in boss["drops"])
            special = f', special = "{boss["special"]}"' if boss["special"] else ""
            lines.append(f"        {{ npc = {boss['npc']}{special}, drops = {{ {drops} }} }},")
        lines.append("    },")
    lines += ["}", ""]
    for loc in LOCALES:
        lines.append(f'ns.AddStrings("{loc}", {{')
        for wid in sorted(names[loc]):
            lines.append(f"    MC_I_{wid} = {lua_str(names[loc][wid])},")
        for npc in sorted(boss_names[loc]):
            lines.append(f"    MC_B_{npc} = {lua_str(boss_names[loc][npc])},")
        lines.append("})")
    lines.append("")
    OUT.write_text("\n".join(lines), encoding="utf-8", newline="\n")
    print("wrote", OUT, len(items), "items")
    for wid in sorted(items):
        it = items[wid]
        print(f"  {wid:6} {it['rarity']:9} {it['kind']:8} {str(it['slot']):12} {names['enUS'][wid]:32} "
              f"stats {it['stats']} -> {it['points']}")
    for s in skipped:
        print("  skipped", s)


if __name__ == "__main__":
    main()
