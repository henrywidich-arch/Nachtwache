#!/usr/bin/env python3
"""Check the menu's release data; optionally enforce a new release against a Git base."""
import argparse
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
NOTES = "data/patch_notes.json"
VERSION_FILE = "scripts/net.gd"


def version(source):
    return re.search(r'const VERSION\s*:=\s*"([0-9.]+)"', source).group(1)


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True)


def check(base=None):
    releases = json.loads((ROOT / NOTES).read_text())
    current = version((ROOT / VERSION_FILE).read_text())
    assert isinstance(releases, list) and releases, "Patch notes must contain releases."
    seen = set()
    previous = None
    for release in releases:
        number = release["version"]
        assert re.fullmatch(r"\d+\.\d+(?:\.\d+)?", number), f"Invalid version: {number}"
        assert number not in seen, f"Duplicate release: {number}"
        numeric = tuple(map(int, number.split(".")))
        assert previous is None or numeric < previous, "Newest versions must come first."
        previous = numeric
        seen.add(number)
        assert isinstance(release["title"], str) and release["title"].strip(), f"Missing title: {number}"
        assert release["sections"], f"Missing sections: {number}"
        for section in release["sections"]:
            assert isinstance(section["title"], str), f"Invalid section title: {number}"
            assert section["items"] and all(isinstance(item, str) and item.strip() for item in section["items"]), f"Missing changes: {number}"
    assert releases[0]["version"] == current, f"Newest patch notes must match NetLink.VERSION ({current})."
    if base and set(base) != {"0"}:
        changed = git("diff", "--name-only", base, "HEAD").splitlines()
        gameplay = any((name.startswith("scripts/") and name != "scripts/verification.gd") or name.startswith(("scenes/", "assets/")) for name in changed)
        if gameplay:
            old = version(git("show", f"{base}:{VERSION_FILE}"))
            assert tuple(map(int, current.split("."))) > tuple(map(int, old.split("."))), "Player-facing changes require a new NetLink.VERSION."
            assert NOTES in changed, "Add the important changes to data/patch_notes.json."
        # Existing notes describe published releases; a new batch must not rewrite them.
        exists = subprocess.run(["git", "cat-file", "-e", f"{base}:{NOTES}"], cwd=ROOT, capture_output=True).returncode == 0
        if exists:
            by_version = {release["version"]: release for release in releases}
            for old in json.loads(git("show", f"{base}:{NOTES}")):
                assert by_version.get(old["version"]) == old, f"Keep published notes for v{old['version']} unchanged."
    print(f"PATCH_NOTES_OK: v{current}, {len(releases)} documented versions")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", help="Previous main commit or PR base SHA")
    try:
        check(parser.parse_args().base)
    except (AssertionError, KeyError, TypeError, ValueError, AttributeError, OSError, subprocess.CalledProcessError) as error:
        sys.exit(f"PATCH_NOTES_ERROR: {error}")
