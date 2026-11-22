# Writes the provisional sounds to assets/sounds/ and imports them (Windows).
# Usage: scripts\make_sounds.ps1
#   $env:GODOT = "C:\path\to\Godot_v4.x-stable_win64_console.exe" to use a specific Godot binary.
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

. (Join-Path $PSScriptRoot "godot_env.ps1")

& $godot --headless --path . --script res://scripts/make_sounds.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $godot --headless --path . --import | Out-Null
exit 0
