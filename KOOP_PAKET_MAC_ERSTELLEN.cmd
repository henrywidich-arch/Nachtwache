@echo off
setlocal
rem Packt das Spiel fuer einen Mitspieler mit Mac in eine ZIP-Datei neben den Projektordner:
rem nur das Projekt, ohne Zwischenspeicher, ohne die Windows-Startdateien und ohne Godot.
rem Godot 4.7.2 fuer macOS laedt der Mitspieler selbst von godotengine.org.
rem Auf dem Mac: ZIP entpacken, im Ordner des Spiels SPIELEN.command starten (siehe README,
rem Abschnitt "Auf dem Mac").
for %%I in ("%~dp0.") do set "GAME_FOLDER=%%~nxI"
for %%I in ("%~dp0..") do set "PARENT=%%~fI"
set "PACKAGE=%PARENT%\%GAME_FOLDER%-Koop-Paket-Mac.zip"
echo Packe %GAME_FOLDER% fuer den Mac nach:
echo   %PACKAGE%
echo Das dauert ein bis zwei Minuten ...
where node >nul 2>nul
if errorlevel 1 goto plain
node "%~dp0tools\make_mac_package.js" "%PACKAGE%"
if errorlevel 1 goto failed
goto done

:plain
rem Ohne Node.js packt Windows selbst. Die ZIP ist dann genauso gut, nur ist SPIELEN.command
rem auf dem Mac nicht direkt startbar: der Mitspieler nimmt den Weg ueber Godot (README).
echo Node.js wurde nicht gefunden, es wird mit dem Windows-Packer gepackt.
if exist "%PACKAGE%" del "%PACKAGE%"
"%SystemRoot%\System32\tar.exe" -a -c -f "%PACKAGE%" --exclude=".godot" --exclude=".git" --exclude="*.cmd" -C "%PARENT%" "%GAME_FOLDER%"
if errorlevel 1 goto failed
echo Hinweis: SPIELEN.command ist in dieser ZIP auf dem Mac nicht direkt startbar.
echo Der Mitspieler oeffnet das Spiel ueber Godot: Importieren, project.godot, F5.

:done
echo.
echo Fertig. Schicke die ZIP-Datei deinem Mitspieler. Er braucht dazu Godot 4.7.2 fuer macOS.
if not defined NACHTWACHE_NO_PAUSE pause
exit /b 0

:failed
echo Das Packen ist fehlgeschlagen.
if not defined NACHTWACHE_NO_PAUSE pause
exit /b 1
