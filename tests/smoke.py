"""Runs tests/smoke.lua: the full addon against a mocked WoW API."""
import pathlib
import re
import sys

from lupa import luajit21 as lupa

ROOT = pathlib.Path(__file__).resolve().parent.parent
ADDON = ROOT / "DarkmoonArcade"


def main() -> int:
    toc = (ADDON / "DarkmoonArcade.toc").read_text(encoding="utf-8")
    files = [line.strip().replace("\\", "/") for line in toc.splitlines() if line.strip() and not line.startswith("#")]
    # WoW runs Lua 5.1; LuaJIT (used here) also knows goto and labels, so catch them before the client does.
    for f in files:
        if f.endswith(".lua"):
            for n, line in enumerate((ADDON / f).read_text(encoding="utf-8").splitlines(), 1):
                code = line.split("--", 1)[0]
                if re.search(r"\bgoto\b|::\w+::", code):
                    print(f"{f}:{n}: goto/labels are not Lua 5.1")
                    return 1
    # The dev copy in the client loads its own generated TOC; it must list the same files.
    dev = ADDON / "DarkmoonArcade_Dev.toc"
    if dev.exists():
        dev_files = [line.strip().replace("\\", "/") for line in dev.read_text(encoding="utf-8").splitlines()
                     if line.strip() and not line.startswith("#")]
        if dev_files != files:
            print("DarkmoonArcade_Dev.toc is out of date: run tools/deploy.ps1")
            return 1
    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    g = lua.globals()
    g.ADDON_FILES = lua.table_from(files)
    g.ADDON_SOURCES = lua.table_from({f: (ADDON / f).read_text(encoding="utf-8") for f in files})
    try:
        murloc, flappy, clicks, best = lua.execute((ROOT / "tests" / "smoke.lua").read_text(encoding="utf-8"))
    except lupa.LuaError:
        # Errors caught inside the addon explain most failures; show them first.
        errors = g.DarkmoonArcadeDB and g.DarkmoonArcadeDB.errors
        if errors:
            for i in range(1, len(errors) + 1):
                print("captured:", errors[i].message)
        raise
    print(f"smoke: ok ({murloc} murloc shots, {flappy} flappy frames, best flappy score {best}, {clicks} button clicks)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
