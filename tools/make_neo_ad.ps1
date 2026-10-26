# Renders one loop of the video wall's advertisement (scripts/neo_ad.gd) with Godot's Movie
# Maker in the background (tools/godot_bg.ps1 -Render) and makes two films of it with ffmpeg:
#   assets/tokyo/neo_ad_claude.ogv   Ogg Theora, 1280 x 720, 30 fps - what Godot plays
#   <Preview>                        H.264 MP4, to look at
#   powershell -ExecutionPolicy Bypass -File tools\make_neo_ad.ps1 [-Preview <file.mp4>]
param(
    [string]$Preview = "",
    [string]$Ffmpeg = ""
)
$project = Split-Path -Parent $PSScriptRoot
if (-not $Ffmpeg) {
    $found = Get-Command ffmpeg -ErrorAction SilentlyContinue
    if ($found) { $Ffmpeg = $found.Source }
    else { $Ffmpeg = (Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Recurse -Filter ffmpeg.exe -ErrorAction SilentlyContinue | Select-Object -First 1).FullName }
}
if (-not $Ffmpeg) { Write-Error "ffmpeg not found"; exit 1 }
$frames = Join-Path $env:TEMP "neo_ad_frames"
if (Test-Path $frames) { Remove-Item $frames -Recurse -Force }
New-Item -ItemType Directory $frames | Out-Null
# 15 seconds at 30 frames: 450 frames, one whole loop (NeoAd.LENGTH).
$movie = (Join-Path $frames "neo.png").Replace("\", "/")
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "godot_bg.ps1") -Render -Resolution 1280x720 -Seconds 600 -GodotArgs "--write-movie `"$movie`" --fixed-fps 30 --quit-after 451 res://tools/neo_ad_movie.tscn" | Out-Null
$count = (Get-ChildItem $frames -Filter "neo*.png").Count
Write-Output "frames: $count"
if ($count -lt 450) { Write-Error "too few frames"; exit 1 }
$pattern = Join-Path $frames "neo%08d.png"
& $Ffmpeg -hide_banner -loglevel error -y -framerate 30 -i $pattern -frames:v 450 -c:v libtheora -q:v 6 -pix_fmt yuv420p (Join-Path $project "assets\tokyo\neo_ad_claude.ogv")
if ($Preview) {
    & $Ffmpeg -hide_banner -loglevel error -y -framerate 30 -i $pattern -frames:v 450 -c:v libx264 -crf 18 -pix_fmt yuv420p -movflags +faststart $Preview
}
Remove-Item $frames -Recurse -Force
Write-Output "done"
