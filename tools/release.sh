#!/bin/bash
# Exports Nachtwache for Windows, macOS and Linux and publishes it as a GitHub release.
# The Double W Launcher looks for the newest release and offers it as an install or update.
#
#   bash tools/release.sh            build and publish
#   bash tools/release.sh --dry-run  only build the ZIPs in build/release
#
# Before publishing: raise VERSION in scripts/net.gd, add the release to data/patch_notes.json,
# commit and push. The release is tagged v<VERSION> on the pushed commit.
# Also runs on GitHub: Actions > Release > Run workflow (.github/workflows/release.yml), which is
# the way to go when the upload from your own connection is too slow for the 1.5 GB files.
# Needs Godot 4.7.2 with its export templates (Editor > Manage Export Templates) and the
# GitHub CLI (gh auth login). Godot is looked for like in SPIELEN.command; or set GODOT.
#
# What the launcher expects (keep it when changing this script):
#   Nachtwache-windows.zip  Nachtwache.exe + Nachtwache.pck + music/
#   Nachtwache-macos.zip    Nachtwache.app (music inside Contents/Resources)
#   Nachtwache-linux.zip    Nachtwache.x86_64 + Nachtwache.pck + music/
#   changelog.json          data/patch_notes.json, every version's notes for the launcher
set -euo pipefail
cd "$(dirname "$0")/.."

NAME="Nachtwache"
VERSION="$(sed -nE 's/^const VERSION := "([0-9.]+)".*/\1/p' scripts/net.gd)"
NOTES="data/patch_notes.json"
MUSIC="assets/music"
TAG="v$VERSION"
DRY=0
[ "${1:-}" = "--dry-run" ] && DRY=1

find_godot() {
	for place in "${GODOT:-}" /Applications/Godot.app "$HOME/Applications/Godot.app" "$HOME/Downloads/Godot.app" "$HOME/Desktop/Godot.app"; do
		[ -z "$place" ] && continue
		[ -d "$place" ] && place="$place/Contents/MacOS/Godot"
		[ -x "$place" ] && { echo "$place"; return; }
	done
	command -v godot && return
	local found
	found="$(mdfind 'kMDItemCFBundleIdentifier == "org.godotengine.godot"' 2>/dev/null | head -1)"
	[ -n "$found" ] && { echo "$found/Contents/MacOS/Godot"; return; }
	return 1
}
GODOT_BIN="$(find_godot)" || { echo "Godot nicht gefunden. GODOT=/Pfad/zu/Godot.app setzen."; exit 1; }
echo "$NAME $VERSION mit $("$GODOT_BIN" --version | tail -1)"

if [ $DRY = 0 ]; then
	gh auth status >/dev/null 2>&1 || { echo "Erst bei GitHub anmelden: gh auth login"; exit 1; }
	if gh release view "$TAG" >/dev/null 2>&1; then
		echo "Release $TAG gibt es schon. Erst VERSION in scripts/net.gd erhöhen."; exit 1
	fi
	if [ -z "$(git branch -r --contains HEAD 2>/dev/null)" ]; then
		echo "Der aktuelle Commit ist noch nicht gepusht. Erst committen und pushen."; exit 1
	fi
	[ -n "$(git status --porcelain --untracked-files=no)" ] && echo "Achtung: Es gibt nicht committete Änderungen; sie kommen mit ins Spiel."
fi

# The macOS app carries the same version as the game.
sed -i '' -E "s#^(application/(short_version|version))=.*#\1=\"$VERSION\"#" export_presets.cfg

rm -rf build/windows build/macos build/linux build/release build/macos_template.zip
mkdir -p build/windows build/macos build/linux build/release
touch build/.gdignore

# Godot only exports universal (Apple Silicon) apps when the project also imports every texture
# as ETC2/ASTC. Apple Silicon reads the desktop formats (S3TC/BPTC) just as well, so the macOS
# preset says "x86_64" and uses this copy of the official template, in which the universal
# program also carries the x86_64 name.
TEMPLATES="$HOME/Library/Application Support/Godot/export_templates/$("$GODOT_BIN" --version | tail -1 | cut -d. -f1-4)"
python3 - "$TEMPLATES/macos.zip" build/macos_template.zip <<'EOF2'
import shutil, sys, zipfile
src, dst = sys.argv[1:]
shutil.copy(src, dst)
with zipfile.ZipFile(dst, "a") as z:
    for kind in ("release", "debug"):
        info = z.getinfo(f"macos_template.app/Contents/MacOS/godot_macos_{kind}.universal")
        alias = zipfile.ZipInfo(info.filename.replace(".universal", ".x86_64"), info.date_time)
        alias.external_attr = info.external_attr
        z.writestr(alias, z.read(info), zipfile.ZIP_DEFLATED)
EOF2

export_one() { # preset, output
	echo "Exportiere $1 ..."
	"$GODOT_BIN" --headless --path . --export-release "$1" "$2" >build/export-"$1".log 2>&1 || { tail -20 build/export-"$1".log; exit 1; }
	[ -e "$2" ] || { echo "Export $1 hat nichts erzeugt (build/export-$1.log)"; exit 1; }
}
copy_music() { mkdir -p "$1"; rsync -a --exclude .gdignore --exclude .DS_Store "$MUSIC"/ "$1"/; }

# One system after the other, and what is packed is deleted at once: all three exports side by
# side would need about 5 GB more than a GitHub runner has to spare.
export_one Windows build/windows/$NAME.exe
echo "Packe Windows ..."
copy_music build/windows/music
(cd build/windows && zip -qr -X ../release/$NAME-windows.zip . -x '*.DS_Store')
rm -rf build/windows

export_one Linux build/linux/$NAME.x86_64
echo "Packe Linux ..."
copy_music build/linux/music
(cd build/linux && zip -qr -X ../release/$NAME-linux.zip . -x '*.DS_Store')
rm -rf build/linux

# macOS: the music goes into the app; then it is signed again (ad hoc), or the changed bundle
# would not start on Apple Silicon.
export_one macOS build/macos/$NAME.zip
echo "Packe macOS ..."
(cd build/macos && ditto -x -k $NAME.zip . && rm $NAME.zip)
copy_music "build/macos/$NAME.app/Contents/Resources/music"
codesign --force --deep --sign - "build/macos/$NAME.app"
ditto -c -k --keepParent "build/macos/$NAME.app" build/release/$NAME-macos.zip
rm -rf build/macos build/macos_template.zip

cp "$NOTES" build/release/changelog.json
python3 - "$NOTES" "$VERSION" >build/release/notes.md <<'EOF'
import json, sys
releases = json.load(open(sys.argv[1]))
release = next((r for r in releases if r["version"] == sys.argv[2]), releases[0])
for section in release.get("sections", []):
    print(f"### {section['title']}")
    for item in section["items"]:
        print(f"- {item}")
    print()
EOF
TITLE="$(python3 -c 'import json,sys; r=json.load(open(sys.argv[1])); print(next((x for x in r if x["version"]==sys.argv[2]), r[0]).get("title",""))' "$NOTES" "$VERSION")"

ls -lh build/release
if [ $DRY = 1 ]; then echo "Probelauf fertig: build/release"; exit 0; fi

echo "Veröffentliche $TAG ..."
gh release create "$TAG" --target "$(git rev-parse HEAD)" --title "$VERSION · $TITLE" --notes-file build/release/notes.md \
	build/release/$NAME-windows.zip build/release/$NAME-macos.zip build/release/$NAME-linux.zip build/release/changelog.json
echo "Fertig. Der Launcher bietet $NAME $VERSION ab sofort als Update an."
