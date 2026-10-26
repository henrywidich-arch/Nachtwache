#!/usr/bin/env bash
# Builds every facade part of the simulation hall (assets/tokyo/kit) from Henry's models in
# the source folder (which is only read). For each part a version reduced in Meshy itself
# ("<name>_low.glb", its pictures baked anew there) is taken first: then nothing is reduced
# here, only repaired, sized, given its origin. Without one the original is reduced here,
# gently (tools/blender_kit_fix.py). Afterwards: Godot --import (via tools/godot_bg.ps1).
# Run from the project folder:  bash tools/build_tokyo_kit.sh [part ...]
set -u
SRC="${KIT_SRC:-D:/Games/AI Games/Nachtwache/tokyo}"
BLENDER="${BLENDER:-/c/Program Files/Blender Foundation/Blender 5.1/blender.exe}"
HERE="$(pwd)"
#   part            source (without .glb)                                              triangles width depth texture
PARTS="
window_a        Meshy_AI_SciFi_Window_Frame_1024151034_image-to-3d-texture         16000  2.3  0.22  2048
window_b        fensteralt                                                         16000  1.6  0.25  2048
window_shutter  Meshy_AI_Industrial_Rolling_Sh_1024152806_texture                  16000  1.8  0.22  2048
door_frame      Meshy_AI_Industrial_Portal_Fra_1024152640_texture                  16000  1.7  0.25  2048
shop_facade     japanese_shop_facade                                               30000  5.4  1.2   2048
shop_window     storefront                                                         30000  5.2  0.5   2048
balcony         Meshy_AI_Tokyo_Balcony_Module_1024175402_image-to-3d-texture       40000  3.0  0     2048
vending         Meshy_AI_Tokyo_Vending_Machine_1025043334_image-to-3d-texture      40000  1.1  0     4096
fence           zaun                                                               16000  2.4  0     2048
"
echo "$PARTS" | while read -r part source tris width depth texture; do
	[ -z "$part" ] && continue
	if [ $# -gt 0 ] && [[ " $* " != *" $part "* ]]; then
		continue
	fi
	from="$SRC/$source.glb"
	# (Parts Henry sent in the chat lie in the project: assets/tokyo/source.)
	for dir in "$SRC" "$HERE/assets/tokyo/source"; do
		[ -f "$dir/$source.glb" ] && from="$dir/$source.glb"
		[ -f "$dir/${source}_low.glb" ] && from="$dir/${source}_low.glb" && tris=0
	done
	if [ ! -f "$from" ]; then
		echo "MISSING $part: $from"
		continue
	fi
	"$BLENDER" --background --factory-startup --python "$HERE/tools/blender_kit_fix.py" -- "$from" "$HERE/assets/tokyo/kit/$part.glb" "$tris" "$width" "$depth" "$texture" 2>&1 | grep -E "FIXED|Error" | sed "s/^/$part: /"
done
