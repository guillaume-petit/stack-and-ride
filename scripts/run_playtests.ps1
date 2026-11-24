# Gathers the runs played by people into docs/playtest-report.md (Windows).
# Usage: scripts\run_playtests.ps1 [folder] [version]
#   Without a folder: the runs played on this computer (the folder "runs" of the game's data).
#   With a version (e.g. 0.0.2): only the runs played with that version.
#   $env:GODOT = "C:\path\to\Godot_v4.x-stable_win64_console.exe" to use a specific Godot binary.
param([string]$Folder = "", [string]$Version = "")

$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

. (Join-Path $PSScriptRoot "godot_env.ps1")

if ($Folder -ne "") {
	$Folder = (Resolve-Path $Folder).Path
}
& $godot --headless --path . --script res://sim/run_playtests.gd -- $Folder $Version
exit $LASTEXITCODE
