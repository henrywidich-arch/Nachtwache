# Runs Godot for this project in the background, so that nothing opens on the screen.
#   Checks without pictures:
#     powershell -ExecutionPolicy Bypass -File tools\godot_bg.ps1 "-s res://tools/tokyo_check.gd"
#   Runs that draw (screenshots, frame rates, Movie Maker):
#     powershell -ExecutionPolicy Bypass -File tools\godot_bg.ps1 -Render "-s res://tools/tokyo_shots.gd -- --out=C:/shots"
# Without -Render Godot runs --headless. With -Render it gets a real window, but on a second,
# invisible Windows desktop (tools/run_hidden.ps1), off the screen there too, without sound:
# no window appears, nothing loses the keyboard. Its output is printed when it is done; the
# exit code is Godot's (124: stopped after -Seconds). NACHTWACHE_GODOT names another Godot.
param(
    [Parameter(Position = 0)][string]$GodotArgs = "",
    [switch]$Render,
    [int]$Seconds = 900,
    [string]$Resolution = "1600x900"
)
$project = Split-Path -Parent $PSScriptRoot
$godot = $env:NACHTWACHE_GODOT
if (-not $godot) {
    foreach ($candidate in @("$project\Godot_v4.7.2-stable_win64.exe", "$project\..\Godot_v4.7.2-stable_win64.exe", "D:\Games\AI Games\Godot_v4.7.2-stable_win64.exe", "$env:USERPROFILE\Downloads\Godot_v4.7.2-stable_win64.exe", "$env:USERPROFILE\Desktop\Godot_v4.7.2-stable_win64.exe")) {
        if (Test-Path $candidate -PathType Leaf) { $godot = $candidate; break }
    }
}
if (-not $godot) { Write-Error "Godot not found: set NACHTWACHE_GODOT"; exit 1 }
$log = Join-Path $env:TEMP ("godot_bg_" + [guid]::NewGuid().ToString("N") + ".log")
if ($Render) {
    $line = "--path `"$project`" --audio-driver Dummy --position -20000,-20000 --resolution $Resolution --log-file `"$log`" $GodotArgs"
} else {
    $line = "--headless --path `"$project`" --audio-driver Dummy $GodotArgs"
}
if ($Render) {
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "run_hidden.ps1") -Program $godot -Arguments $line -Folder $project -Seconds $Seconds
    $code = $LASTEXITCODE
} else {
    $run = Start-Process -FilePath $godot -ArgumentList $line -WorkingDirectory $project -NoNewWindow -PassThru
    if (-not $run.WaitForExit($Seconds * 1000)) { $run.Kill(); $code = 124 } else { $code = $run.ExitCode }
}
if (Test-Path $log) { Get-Content $log -Encoding UTF8; Remove-Item $log -ErrorAction SilentlyContinue }
exit $code
