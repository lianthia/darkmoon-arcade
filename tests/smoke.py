"""Runs tests/smoke.lua: the full addon against a mocked WoW API."""
import pathlib
import re
import sys

from lupa import luajit21 as lupa

ROOT = pathlib.Path(__file__).resolve().parent.parent
ADDON = ROOT / "MurlocBlast"


def main() -> int:
    toc = (ADDON / "MurlocBlast.toc").read_text(encoding="utf-8")
    files = [line.strip().replace("\\", "/") for line in toc.splitlines() if line.strip() and not line.startswith("#")]
    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    g = lua.globals()
    g.ADDON_FILES = lua.table_from(files)
    g.ADDON_SOURCES = lua.table_from({f: (ADDON / f).read_text(encoding="utf-8") for f in files})
    clears, overs, clicks, chats = lua.execute((ROOT / "tests" / "smoke.lua").read_text(encoding="utf-8"))
    print(f"smoke: ok ({clears} levels cleared, {overs} games over, {clicks} button clicks, {chats} chat shares)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
