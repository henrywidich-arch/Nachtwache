@echo off
setlocal
rem Packt das Spiel fuer den Koop-Mitspieler in eine ZIP-Datei neben den Projektordner:
rem das Projekt ohne Zwischenspeicher, dazu Godot selbst. Der Mitspieler entpackt die ZIP
rem und startet im Ordner des Spiels SPIELEN.cmd.
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
for %%I in ("%~dp0.") do set "GAME_FOLDER=%%~nxI"
for %%I in ("%~dp0..") do set "PARENT=%%~fI"
for %%I in ("%GAME_EDITOR%") do (
  set "EDITOR_DIR=%%~dpI"
  set "EDITOR_FILE=%%~nxI"
)
set "PACKAGE=%PARENT%\%GAME_FOLDER%-Koop-Paket.zip"
echo Packe %GAME_FOLDER% und Godot nach:
echo   %PACKAGE%
echo Das dauert ein bis zwei Minuten ...
"%SystemRoot%\System32\tar.exe" -a -c -f "%PACKAGE%" --exclude=".godot" --exclude=".git" -C "%PARENT%" "%GAME_FOLDER%" -C "%EDITOR_DIR%." "%EDITOR_FILE%"
if errorlevel 1 (
  echo Das Packen ist fehlgeschlagen.
  if not defined NACHTWACHE_NO_PAUSE pause
  exit /b 1
)
echo.
echo Fertig. Schicke die ZIP-Datei deinem Mitspieler. Er entpackt sie komplett und
echo startet im Ordner %GAME_FOLDER% die Datei SPIELEN.cmd.
if not defined NACHTWACHE_NO_PAUSE pause
