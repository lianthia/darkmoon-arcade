"""Refuses stable releases while a game is still marked `preview = true`, while the "What's new"
window does not start with this version, or while CHANGELOG.md (CurseForge) holds other notes.

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


def stale_texts(version):
    """The news and the changelog must be about the version being released."""
    problems = []
    news = (ROOT / "DarkmoonArcade" / "UI" / "News.lua").read_text(encoding="utf-8")
    first = re.search(r'version\s*=\s*"([^"]+)"', news)
    if not first or first.group(1) != version:
        problems.append(f"News.VERSIONS starts with {first.group(1) if first else '?'}, not {version}: add this release's news.")
    changelog = ROOT / "CHANGELOG.md"
    if not changelog.exists() or version not in changelog.read_text(encoding="utf-8").splitlines()[0]:
        problems.append(f"CHANGELOG.md does not start with the notes of {version}: copy dist/notes-{version}.md.")
    return problems


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
    problems = stale_texts(tag.lstrip("v"))
    for line in problems:
        print(f"Release {tag} blocked: {line}")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
