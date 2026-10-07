"""Refuses stable releases while a game is still marked `preview = true`.

python tools/release_check.py v1.3.0          -> exit 1 if any game module is a preview
python tools/release_check.py v1.3.0-alpha    -> always fine (alpha and beta may ship previews)

Used by the release flow and the local pre-push hook (tools/install_hooks.py).
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
GAMES = ROOT / "DarkmoonArcade" / "Games"


def previews():
    found = []
    for path in GAMES.glob("*/*.lua"):
        text = path.read_text(encoding="utf-8")
        # Only the module table's own flag counts, not saved settings with the same name.
        if re.search(r"^\s*preview\s*=\s*true\s*,", text, re.M) and "Arcade.RegisterGame" in text:
            found.append(path.parent.name)
    return sorted(found)


def main(argv):
    if len(argv) != 2:
        print(__doc__)
        return 2
    tag = argv[1]
    if re.search(r"-(alpha|beta)\d*$", tag):
        return 0
    blocked = previews()
    if blocked:
        print(f"Release {tag} blocked: still in preview -> {', '.join(blocked)}.")
        print("Ship it as -alpha/-beta, or finish the game and remove `preview = true` first.")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
