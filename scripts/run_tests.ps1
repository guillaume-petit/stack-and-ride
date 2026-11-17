# Runs every test under tests/ without opening the editor (Windows).
# Usage: scripts\run_tests.ps1 [filter]
#   $env:GODOT = "C:\path\to\Godot.exe" to use a specific Godot binary.
param([string]$Filter = "")

$ErrorActionPreference = "Stop"
$godot = if ($env:GODOT) { $env:GODOT } else { "godot" }
Set-Location (Join-Path $PSScriptRoot "..")

# On a fresh clone the class cache (.godot/) does not exist yet:
# importing once lets the tests resolve class_name declarations.
if (-not (Test-Path ".godot")) {
	& $godot --headless --path . --import | Out-Null
}

if ($Filter) {
	& $godot --headless --path . --script res://tests/run_tests.gd -- $Filter
} else {
	& $godot --headless --path . --script res://tests/run_tests.gd
}
exit $LASTEXITCODE
