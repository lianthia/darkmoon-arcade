"""Writes DarkmoonArcade/Games/Mercenaries/Retail.lua: python tools/gen_mercenaries_retail.py

Mercenaries plays the same on WoW: Forever and retail; only the pictures come from each client.
This reads retail's tables (via wago.tools, for the installed retail build) and stores what retail
shows instead of Forever's files:

- maps: retail's art tiles per map and every zone's rectangle on retail's continent maps. Zones retail
  lacks (Forever's own, and Alterac, which retail merged into Hillsbrad) are placed by their world
  coordinates from Forever. Forever's own zones use the map pictures in art/maps (tools/import_art.py
  turns them into media/maps/<zone>.tga).
- creature displays: Forever's old (classic) display IDs mostly exist on retail as the same creature
  with its newer model and stay. Forever's own, high IDs may mean another creature on retail, and some
  old ones are gone: those are looked up by the NPC, then by the creature's English name, then by a
  display with the same model and skin. A creature retail does not have at all borrows the look of
  another enemy of its race.
"""
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import casc_local  # noqa: E402
import check_client  # noqa: E402

OUT = ROOT / "DarkmoonArcade" / "Games" / "Mercenaries" / "Retail.lua"
FOREVER = casc_local.build_info("wow_classic_beta")["Version"]
RETAIL = casc_local.build_info("wow")["Version"]

CONTINENTS = {"ek": (13, 1415), "kal": (12, 1414)}
# key: retail uiMapID, Forever uiMapID (for world bounds), continent; a retail ID of None uses art/maps.
ZONES = {
    "elwynn": (37, 1429, "ek"), "dunmorogh": (27, 1426, "ek"), "tirisfal": (18, 1420, "ek"), "westfall": (52, 1436, "ek"),
    "lochmodan": (48, 1432, "ek"), "silverpine": (21, 1421, "ek"), "redridge": (49, 1433, "ek"), "duskwood": (47, 1431, "ek"),
    "wetlands": (56, 1437, "ek"), "hillsbrad": (25, 1424, "ek"), "riverglades": (None, 2548, "ek"),
    "teldrassil": (57, 1438, "kal"), "durotar": (1, 1411, "kal"), "mulgore": (7, 1412, "kal"), "darkshore": (62, 1439, "kal"),
    "barrens": (10, 1413, "kal"), "stonetalon": (65, 1442, "kal"), "ashenvale": (63, 1440, "kal"), "hyjal": (None, 2482, "kal"),
    "shendralas": (None, 2652, "kal"), "zephras": (None, 2521, None),
    "thousandneedles": (64, 1441, "kal"), "desolace": (66, 1443, "kal"), "dustwallow": (70, 1445, "kal"), "feralas": (69, 1444, "kal"),
    "tanaris": (71, 1446, "kal"), "azshara": (76, 1447, "kal"), "felwood": (77, 1448, "kal"), "ungoro": (78, 1449, "kal"),
    "silithus": (81, 1451, "kal"), "winterspring": (83, 1452, "kal"),
    # Retail merged Alterac into Hillsbrad: its art, Alterac's own place.
    "alterac": (25, 1416, "ek"), "arathi": (14, 1417, "ek"), "badlands": (15, 1418, "ek"), "blastedlands": (17, 1419, "ek"),
    "westernplaguelands": (22, 1422, "ek"), "easternplaguelands": (23, 1423, "ek"), "hinterlands": (26, 1425, "ek"),
    "searinggorge": (32, 1427, "ek"), "burningsteppes": (36, 1428, "ek"), "stranglethorn": (224, 1434, "ek"),
    "swampofsorrows": (51, 1435, "ek"),
}


def bounds(build):
    """World bounds per map: the assignment covering the whole map (OrderIndex 0); retail adds rows for
    insets such as Outland's islands on the continents."""
    out = {}
    for r in check_client.table("UiMapAssignment", build):
        if r["UiMapID"] != "947" and r["OrderIndex"] == "0":
            out[int(r["UiMapID"])] = tuple(float(r[k]) for k in ("Region_0", "Region_1", "Region_3", "Region_4"))
    return out


def art_tables(build):
    t = check_client.table
    x_art = {r["UiMapID"]: r["UiMapArtID"] for r in t("UiMapXMapArt", build) if r["PhaseID"] == "0"}
    art = {r["ID"]: r for r in t("UiMapArt", build)}
    styles = {r["UiMapArtStyleID"]: r for r in t("UiMapArtStyleLayer", build) if r["LayerIndex"] == "0"}
    tiles = {}
    for r in t("UiMapArtTile", build):
        if r["LayerIndex"] == "0":
            tiles.setdefault(r["UiMapArtID"], []).append((int(r["RowIndex"]), int(r["ColIndex"]), int(r["FileDataID"])))

    def art_of(map_id):
        art_id = x_art[str(map_id)]
        style = styles[art[art_id]["UiMapArtStyleID"]]
        tl = sorted(tiles[art_id])
        return {"w": int(style["LayerWidth"]), "h": int(style["LayerHeight"]), "tw": int(style["TileWidth"]),
                "th": int(style["TileHeight"]), "cols": max(c for _, c, _ in tl) + 1, "files": [f for _, _, f in tl]}
    return art_of


def displays(build):
    models = {r["ID"]: r["FileDataID"] for r in check_client.table("CreatureModelData", build)}
    out = {}
    for r in check_client.table("CreatureDisplayInfo", build):
        out[int(r["ID"])] = (models.get(r["ModelID"]), r["TextureVariationFileDataID_0"])
    return out


def main():
    g = check_client.run_addon()
    mc = g.ADDON_NS.Mercenaries

    # Maps.
    art_of = art_tables(RETAIL)
    retail_bounds, forever_bounds = bounds(RETAIL), bounds(FOREVER)
    lines = [
        "-- Generated by tools/gen_mercenaries_retail.py from retail's tables; do not edit.",
        "-- On retail, Mercenaries shows retail's map art and creature displays: the game stays the same.",
        "",
        "local _, ns = ...",
        "if not ns.IS_RETAIL then return end",
        "local MC = ns.Mercenaries",
        "local Tex = ns.Media.Tex",
        "",
        "MC.MapArt = {",
    ]
    for key, (retail_id, _) in CONTINENTS.items():
        m = art_of(retail_id)
        lines.append(f"    {key} = {{ w = {m['w']}, h = {m['h']}, tw = {m['tw']}, th = {m['th']}, cols = {m['cols']}, "
                     f"files = {{ {', '.join(map(str, m['files']))} }} }},")
    for key, (retail_id, _, _) in ZONES.items():
        if retail_id is None:
            # A picture of its own (media/maps), tiled like the client's maps.
            files = ", ".join(f'Tex("maps/{key}_{i}")' for i in range(1, 13))
            lines.append(f"    {key} = {{ w = 1002, h = 668, tw = 256, th = 256, cols = 4, files = {{ {files} }} }},")
        else:
            m = art_of(retail_id)
            lines.append(f"    {key} = {{ w = {m['w']}, h = {m['h']}, tw = {m['tw']}, th = {m['th']}, cols = {m['cols']}, "
                         f"files = {{ {', '.join(map(str, m['files']))} }} }},")
    lines += ["}", "", "MC.ZoneMaps = {"]
    for key, (retail_id, forever_id, cont) in ZONES.items():
        if cont:
            # World coordinates are the same in both clients: zones retail lacks keep Forever's place.
            zone = retail_bounds.get(retail_id) if retail_id and key != "alterac" else forever_bounds[forever_id]
            zx0, zy0, zx1, zy1 = zone
            cx0, cy0, cx1, cy1 = retail_bounds[CONTINENTS[cont][0]]
            # Map x runs against world y, map y against world x.
            rect = ((cy1 - zy1) / (cy1 - cy0), (cy1 - zy0) / (cy1 - cy0), (cx1 - zx1) / (cx1 - cx0), (cx1 - zx0) / (cx1 - cx0))
        else:
            rect, cont = (0.0, 1.0, 0.0, 1.0), key
        lines.append(f'    {key} = {{ map = {retail_id or forever_id}, continent = "{cont}", '
                     f'rect = {{ {rect[0]:.4f}, {rect[1]:.4f}, {rect[2]:.4f}, {rect[3]:.4f} }} }},')
    lines += ["}", ""]

    # Creature displays: retail's own display of the NPC, else one with the same model and skin.
    creatures, by_name = {}, {}
    for r in check_client.table("Creature", RETAIL):
        display = int(r["DisplayID_0"] or 0)
        if display:
            creatures[int(r["ID"])] = display
            by_name.setdefault(r["Name_lang"].strip().lower(), display)
    forever, retail = displays(FOREVER), displays(RETAIL)
    by_look = {}
    for i, look in sorted(retail.items()):
        by_look.setdefault(look, i)
    unresolved = []
    L = g.ADDON_NS.L
    # Forever's own display IDs start here; below it they are the classic ones retail keeps.
    FOREVER_IDS = 100000

    def resolve(npc, display, name):
        if display in retail and (display < FOREVER_IDS or retail[display] == forever.get(display)):
            return display, "same"
        if npc and creatures.get(npc):
            return creatures[npc], "npc"
        if name and by_name.get(name.lower()):
            return by_name[name.lower()], "name"
        look = forever.get(display)
        if look and look in by_look:
            return by_look[look], "model"
        return None, None

    for table_name, source, prefix in (("Enemies", mc.Enemies, "MC_E_"), ("Mercs", mc.Mercs, "MC_M_")):
        found_by_key, races = {}, {}
        for key in sorted(source.keys()):
            entry = source[key]
            display = int(entry.display) if entry.display else None
            if not display:
                continue
            found, how = resolve(int(entry.npc) if entry.npc else None, display, L[prefix + key])
            found_by_key[key] = (display, found, how)
            if found and how in ("same", "npc", "name"):
                races.setdefault(entry.race, found)
        lines.append(f"local {table_name.upper()} = {{")
        for key, (display, found, how) in found_by_key.items():
            if found is None and races.get(source[key].race):
                found, how = races[source[key].race], f"another {source[key].race}"
            if found is None:
                unresolved.append(f"{table_name} {key} (npc {source[key].npc}, display {display})")
                lines.append(f"    {key} = false, -- not on retail")
            elif found != display:
                lines.append(f"    {key} = {found}, -- {how}")
        lines.append("}")
    lines += [
        "",
        "for key, display in pairs(ENEMIES) do MC.Enemies[key].display = display or nil end",
        "for key, display in pairs(MERCS) do MC.Mercs[key].display = display or nil end",
        "",
    ]
    OUT.write_text("\n".join(lines), encoding="utf-8", newline="\n")
    print("wrote", OUT)
    print("unresolved:", len(unresolved))
    for u in unresolved:
        print(" ", u)


if __name__ == "__main__":
    main()
