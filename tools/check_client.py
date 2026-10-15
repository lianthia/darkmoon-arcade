"""Checks every client asset the addon uses against an installed client:

    python tools/check_client.py [forever|retail] ...

The asset list comes from two sources: tests/smoke.lua run with ASSET_LOG (every texture, atlas,
model, display and sound the addon asks for while the whole UI is clicked through), plus the
Mercenaries data that a run never reaches in full (all maps, enemies, mercenaries and effects).

Each asset is looked up in the client's own storage (tools/casc_local.py) and, for atlases and
creature displays, in the client build's tables (wago.tools). A display that exists in both
clients but shows a different model is reported too: the same ID would show another creature.
Writes dist/client-check.md.
"""
import csv
import io
import pathlib
import re
import sys
import urllib.request

from lupa import luajit21 as lupa

ROOT = pathlib.Path(__file__).resolve().parent.parent
ADDON = ROOT / "DarkmoonArcade"
CACHE = ROOT / "tools" / ".cache"
sys.path.insert(0, str(ROOT / "tools"))
import casc_local  # noqa: E402

CLIENTS = {"forever": "wow_classic_beta", "retail": "wow"}
UA = {"User-Agent": "Mozilla/5.0"}


def table(name, build):
    CACHE.mkdir(exist_ok=True)
    path = CACHE / f"{name}-{build}.csv"
    if not path.exists():
        url = f"https://wago.tools/db2/{name}/csv?build={build}"
        path.write_bytes(urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=120).read())
    return list(csv.DictReader(io.StringIO(path.read_text(encoding="utf-8"))))


def collect():
    """Runs the smoke test with asset logging; returns {kind: set(values)} and where each came from."""
    toc = (ADDON / "DarkmoonArcade.toc").read_text(encoding="utf-8")
    files = [line.strip().replace("\\", "/") for line in toc.splitlines() if line.strip() and not line.startswith("#")]
    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    g = lua.globals()
    g.ADDON_FILES = lua.table_from(files)
    g.ADDON_SOURCES = lua.table_from({f: (ADDON / f).read_text(encoding="utf-8") for f in files})
    g.ASSET_LOG = lua.table()
    lua.execute((ROOT / "tests" / "smoke.lua").read_text(encoding="utf-8"))
    assets = {}

    def add(kind, value, source):
        assets.setdefault(kind, {}).setdefault(value, source)

    for i in range(1, len(g.ASSET_LOG) + 1):
        kind, value = g.ASSET_LOG[i].split("\t", 1)
        add(kind, value, "UI")
    mc = g.ADDON_NS.Mercenaries
    for name, art in mc.MapArt.items():
        for fid in art.files.values():
            add("texture", str(int(fid)), f"map {name}")
    for name, enemy in mc.Enemies.items():
        if enemy.display:
            add("display", str(int(enemy.display)), f"enemy {name}")
    for name, merc in mc.Mercs.items():
        if merc.display:
            add("display", str(int(merc.display)), f"mercenary {name}")
    for fx in mc.FX_LIST.values():
        if fx.file:
            add("model", str(int(fx.file)), f"effect {fx.name or fx.id}")
    return assets


def norm(value):
    """A number as int, a path without the .blp/.tga the client adds itself."""
    if re.fullmatch(r"\d+(\.0)?", value):
        return int(float(value))
    return value


class Check:
    def __init__(self, name):
        self.name = name
        self.client = casc_local.Client(CLIENTS[name])
        build = self.client.version
        self.atlases = {r["CommittedName"].lower() for r in table("UiTextureAtlasMember", build)}
        models = {r["ID"]: r["FileDataID"] for r in table("CreatureModelData", build)}
        self.displays = {}
        for r in table("CreatureDisplayInfo", build):
            self.displays[int(r["ID"])] = (models.get(r["ModelID"]), r.get("TextureVariationFileDataID_0"))

    def file(self, value):
        value = norm(value)
        if isinstance(value, str):
            if value.lower().startswith("interface\\addons") or value.lower().startswith("interface/addons"):
                return True
            fid = self.client.file_id(value)
            if fid is None:
                fid = self.client.file_id(value.rsplit(".", 1)[0] + ".blp") if "." in value else None
            if fid is None:
                return False
            value = fid
        return self.client.status(value) != "missing"

    def has(self, kind, value):
        if kind == "atlas":
            return value.lower() in self.atlases
        if kind == "display":
            return int(float(value)) in self.displays
        return self.file(value)


def main():
    names = sys.argv[1:] or ["forever", "retail"]
    assets = collect()
    checks = {name: Check(name) for name in names}
    lines = ["# Client check", ""]
    for name, check in checks.items():
        lines.append(f"- {name}: build {check.client.version}")
    lines.append("")
    summary = []
    for kind in ("texture", "atlas", "model", "display", "sound"):
        values = assets.get(kind, {})
        lines += [f"## {kind} ({len(values)})", ""]
        for name, check in checks.items():
            missing = sorted((v for v in values if not check.has(kind, v)), key=str)
            summary.append(f"{kind:8} {name:8} {len(values) - len(missing):5} ok {len(missing):5} missing")
            lines.append(f"### missing in {name}: {len(missing)}")
            for v in missing:
                lines.append(f"- `{v}` ({values[v]})")
            lines.append("")
    # Same display ID, different creature: the ID means something else in the other client.
    if "forever" in checks and "retail" in checks:
        f, r = checks["forever"], checks["retail"]
        changed = []
        for v, source in assets.get("display", {}).items():
            i = int(float(v))
            if i in f.displays and i in r.displays and f.displays[i][0] != r.displays[i][0]:
                changed.append(f"- `{i}` ({source}): model {f.displays[i][0]} on forever, {r.displays[i][0]} on retail")
        summary.append(f"display  same ID, other model on retail: {len(changed)}")
        lines += [f"## displays with another model on retail: {len(changed)}", ""] + changed + [""]
    out = ROOT / "dist" / "client-check.md"
    out.parent.mkdir(exist_ok=True)
    out.write_text("\n".join(lines), encoding="utf-8")
    print("\n".join(summary))
    print("details:", out)


if __name__ == "__main__":
    main()
