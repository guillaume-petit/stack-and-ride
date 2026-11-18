# Plays many runs with the bot and writes docs/balance-report.md (Windows).
# Usage: scripts\run_sim.ps1 [runs per profile, default 200] [first seed, default 1]
#   $env:GODOT = "C:\path\to\Godot_v4.x-stable_win64_console.exe" to use a specific Godot binary.
param([string]$Runs = "200", [string]$FirstSeed = "1")

$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

. (Join-Path $PSScriptRoot "godot_env.ps1")

& $godot --headless --path . --script res://sim/run_simulation.gd -- $Runs $FirstSeed
exit $LASTEXITCODE
