#!/bin/bash
# Startet Nachtwache auf dem Mac.
# Sucht Godot 4.7.2 neben dem Spielordner, in den Programmen, in den Downloads und auf
# dem Schreibtisch, danach ueber die Spotlight-Suche. Liegt Godot woanders: vor dem Start
#   export GODOT="/Pfad/zu/Godot.app"
# eingeben oder den Pfad unten in die Liste PLACES eintragen.
# Beim ersten Start bereitet Godot die Spieldaten vor; das dauert ein paar Minuten.
# Nach einem Update (neue Dateien im Ordner) liest Godot beim Start nur das Neue ein.
#
# Laesst sich die Datei nicht per Doppelklick starten ("keine Zugriffsrechte" oder
# "nicht verifizierter Entwickler"): Terminal oeffnen und eingeben
#   bash "/Pfad/zum/Ordner/Nachtwache/SPIELEN.command"
# (den Pfad bekommst du, indem du die Datei ins Terminal-Fenster ziehst).
# Die 3D-Aufloesung nur fuer diesen Start: hinten  -- --scale=0.4  anhaengen.

WANTED="4.7.2"
cd "$(dirname "$0")" || exit 1
GAME_DIR="$(pwd)"

# Ein Ordner Godot.app oder direkt das Programm darin: gibt den Pfad des Programms aus.
binary_of() {
  if [ -d "$1" ] && [ -x "$1/Contents/MacOS/Godot" ]; then
    echo "$1/Contents/MacOS/Godot"
  elif [ -f "$1" ] && [ -x "$1" ]; then
    echo "$1"
  fi
}

PLACES=(
  "$GAME_DIR"
  "$GAME_DIR/.."
  "/Applications"
  "$HOME/Applications"
  "$HOME/Downloads"
  "$HOME/Desktop"
)

FOUND=""
OTHER=""
OTHER_VERSION=""
# Merkt sich das erste Godot mit der passenden Version, sonst das erste andere.
check() {
  local bin version
  bin="$(binary_of "$1")"
  if [ -z "$bin" ]; then
    return 0
  fi
  version="$("$bin" --version 2>/dev/null | head -n 1)"
  case "$version" in
    "$WANTED"*)
      if [ -z "$FOUND" ]; then FOUND="$bin"; fi
      ;;
    *)
      if [ -z "$OTHER" ]; then OTHER="$bin"; OTHER_VERSION="$version"; fi
      ;;
  esac
  return 0
}

if [ -n "$GODOT" ]; then
  check "$GODOT"
fi
for place in "${PLACES[@]}"; do
  for app in "$place"/Godot*.app; do
    if [ -e "$app" ]; then check "$app"; fi
  done
done
# Nirgends dort: die Spotlight-Suche kennt jedes Godot auf diesem Mac.
if [ -z "$FOUND" ] && command -v mdfind >/dev/null 2>&1; then
  while IFS= read -r app; do
    if [ -n "$app" ]; then check "$app"; fi
  done < <(mdfind "kMDItemCFBundleIdentifier == 'org.godotengine.godot'" 2>/dev/null)
fi

if [ -z "$FOUND" ]; then
  echo
  if [ -n "$OTHER" ]; then
    echo "Gefunden wurde nur Godot $OTHER_VERSION:"
    echo "  $OTHER"
    echo "Nachtwache braucht genau Godot $WANTED (dieselbe Version wie beim Mitspieler)."
  else
    echo "Godot wurde nicht gefunden."
  fi
  echo
  echo "So geht es weiter:"
  echo "  1. Auf godotengine.org Godot $WANTED fuer macOS laden (Standard-Version, nicht .NET)."
  echo "  2. Die geladene Datei entpacken, Godot.app in den Ordner Programme ziehen"
  echo "     und einmal per Doppelklick oeffnen (macOS fragt beim ersten Mal nach)."
  echo "  3. Diese Datei noch einmal starten."
  echo
  read -r -p "Eingabetaste zum Schliessen ... " _
  exit 1
fi

echo "Godot: $FOUND"

# Der Stand der Spieldaten: Groesse und Datum jeder Datei, die Godot einliest. Ist er ein
# anderer als beim letzten Start (ein Update wurde geladen), liest Godot die neuen und
# geaenderten Dateien vor dem Start ein - sonst fehlen sie im Spiel.
STAMP_FILE="$GAME_DIR/.godot/nachtwache_stand"
stamp() {
  ls -lR "$GAME_DIR/assets" "$GAME_DIR/scripts" "$GAME_DIR/scenes" "$GAME_DIR/project.godot" 2>/dev/null \
    | grep '^-' | grep -v '\.import$' | cksum
}
PREPARE=""
if [ ! -d "$GAME_DIR/.godot/imported" ]; then
  PREPARE="yes"
  echo
  echo "Erster Start: Die Spieldaten werden vorbereitet. Das dauert ein paar Minuten."
  echo "Bitte dieses Fenster offen lassen, das Spiel startet danach von selbst."
elif [ "$(stamp)" != "$(cat "$STAMP_FILE" 2>/dev/null)" ]; then
  PREPARE="yes"
  echo
  echo "Neue Spieldaten gefunden: Godot liest sie ein. Das dauert einen Moment."
  echo "Bitte dieses Fenster offen lassen, das Spiel startet danach von selbst."
fi
if [ -n "$PREPARE" ]; then
  # Der Stand wird erst danach gemerkt: Bricht das Einlesen ab, holt es der naechste Start nach.
  if "$FOUND" --headless --path "$GAME_DIR" --import; then
    stamp > "$STAMP_FILE"
  fi
fi

echo "Das Spiel startet. Dieses Fenster bleibt offen, solange du spielst."
"$FOUND" --path "$GAME_DIR" "$@"
