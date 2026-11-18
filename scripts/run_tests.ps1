# Runs every test under tests/ without opening the editor (Windows).
# Usage: scripts\run_tests.ps1 [filter]
#   $env:GODOT = "C:\path\to\Godot_v4.x-stable_win64_console.exe" to use a specific Godot binary.
# Use the *_console.exe build: the other one does not print to the terminal.
param([string]$Filter = "")

$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

. (Join-Path $PSScriptRoot "godot_env.ps1")

if ($Filter) {
	& $godot --headless --path . --script res://tests/run_tests.gd -- $Filter
} else {
	& $godot --headless --path . --script res://tests/run_tests.gd
}
exit $LASTEXITCODE
