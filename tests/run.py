"""Runs the Lua tests on LuaJIT (Lua 5.1 semantics like WoW): python tests/run.py"""
import pathlib
import sys

from lupa import luajit21 as lupa

ROOT = pathlib.Path(__file__).resolve().parent.parent
ADDON = ROOT / "DarkmoonArcade"


def main() -> int:
    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    lua.execute("ns = {}")
    loader = lua.eval(
        "function(code, name) local f, err = loadstring(code, name); if not f then error(err) end; f('DarkmoonArcade', ns) end"
    )
    for rel in (
        "Games/MurlocBlast/Grid.lua",
        "Games/MurlocBlast/Levels.lua",
        "Games/MurlocBlast/Game.lua",
        "Games/FlappyGriffin/Game.lua",
        "Games/JewelsOfUldum/Game.lua",
        "Games/GoblinSlots/Game.lua",
        "Games/Spellbounce/Maps.lua",
        "Games/Spellbounce/Talents.lua",
        "Games/Spellbounce/Game.lua",
        "Games/DarkmoonDeck/Game.lua",
    ):
        loader((ADDON / rel).read_text(encoding="utf-8"), "@" + rel)

    failures = 0
    for test_file in sorted((ROOT / "tests").glob("test_*.lua")):
        result = lua.execute(test_file.read_text(encoding="utf-8"))
        passed, failed = result
        failures += failed
        print(f"{test_file.name}: {passed} passed, {failed} failed")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
