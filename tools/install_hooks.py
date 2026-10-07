"""Installs the local git hooks: python tools/install_hooks.py

pre-push: a pushed tag that is not -alpha/-beta is refused while any game is still a preview
(see tools/release_check.py), so no stable release ships an unfinished game.
"""
import pathlib
import stat

ROOT = pathlib.Path(__file__).resolve().parent.parent
HOOK = ROOT / ".git" / "hooks" / "pre-push"

SCRIPT = """#!/bin/sh
# Installed by tools/install_hooks.py.
while read local_ref local_sha remote_ref remote_sha; do
    case "$remote_ref" in
        refs/tags/*)
            python tools/release_check.py "${remote_ref#refs/tags/}" || exit 1
            ;;
    esac
done
exit 0
"""

HOOK.write_text(SCRIPT, encoding="utf-8", newline="\n")
HOOK.chmod(HOOK.stat().st_mode | stat.S_IEXEC)
print("installed", HOOK)
