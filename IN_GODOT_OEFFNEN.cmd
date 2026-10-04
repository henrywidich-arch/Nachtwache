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
start "" "%GAME_EDITOR%" --editor --path "%~dp0."
