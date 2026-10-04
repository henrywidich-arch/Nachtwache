@echo off
setlocal
rem Sucht Godot an den bekannten Orten. Eigener Pfad: als erste Zeile in die Liste eintragen.
set "GAME_EDITOR="
for %%G in (
  "%~dp0Godot_v4.7.2-stable_win64.exe"
  "%~dp0..\Godot_v4.7.2-stable_win64.exe"
  "D:\Games\AI Games\Godot_v4.7.2-stable_win64.exe"
  "%USERPROFILE%\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe"
  "%USERPROFILE%\Downloads\Godot_v4.7.2-stable_win64.exe"
  "%USERPROFILE%\Desktop\Godot_v4.7.2-stable_win64.exe"
) do (
  if not defined GAME_EDITOR if exist "%%~G" if not exist "%%~G\" set "GAME_EDITOR=%%~G"
)
if not defined GAME_EDITOR (
  echo Godot wurde nicht gefunden.
  echo Lege Godot_v4.7.2-stable_win64.exe neben den Ordner des Spiels
  echo oder trage den Pfad zu Godot oben in dieser Datei ein.
  pause
  exit /b 1
)
rem Erster Start auf diesem PC: Godot bereitet Modelle, Texturen und Sounds einmalig vor.
if not exist "%~dp0.godot\imported" (
  echo Erster Start: Die Spieldaten werden vorbereitet. Das dauert einige Minuten.
  echo Bitte dieses Fenster offen lassen, das Spiel startet danach von selbst.
  "%GAME_EDITOR%" --headless --path "%~dp0." --import
)
start "" "%GAME_EDITOR%" --path "%~dp0."
