# Runs every test under tests/ without opening the editor (Windows).
# Usage: scripts\run_tests.ps1 [filter]
#   $env:GODOT = "C:\path\to\Godot_v4.x-stable_win64_console.exe" to use a specific Godot binary.
# Use the *_console.exe build: the other one does not print to the terminal.
param([string]$Filter = "")

$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

function Find-Godot {
	if ($env:GODOT) { return $env:GODOT }
	# Official downloads keep their versioned name: look for the console build in the PATH first.
	foreach ($name in @("Godot_v4*_win64_console.exe", "godot", "godot4")) {
		$cmd = Get-Command $name -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
		if ($cmd) { return $cmd.Source }
	}
	$folders = @(
		(Join-Path $HOME "Downloads"),
		(Join-Path $HOME "Desktop"),
		(Join-Path $HOME "Godot")
	)
	foreach ($folder in $folders) {
		if (Test-Path $folder) {
			$found = Get-ChildItem -Path $folder -Filter "Godot_v4*_win64_console.exe" -ErrorAction SilentlyContinue |
				Sort-Object Name -Descending | Select-Object -First 1
			if ($found) { return $found.FullName }
		}
	}
	return $null
}

$godot = Find-Godot
if (-not $godot) {
	Write-Host "Godot introuvable."
	Write-Host "Indique le chemin du programme Godot console, par exemple :"
	Write-Host '  $env:GODOT = "C:\Users\toi\Downloads\Godot_v4.7.2-stable_win64_console.exe"; scripts\run_tests.ps1'
	exit 2
}

# Godot keeps a cache of the class_name declarations in .godot/. It does not exist on a
# fresh clone and is stale after a pull that adds classes: import again in both cases.
$classCache = ".godot/global_script_class_cache.cfg"
$stale = -not (Test-Path $classCache)
if (-not $stale) {
	$cacheTime = (Get-Item $classCache).LastWriteTime
	$stale = [bool](Get-ChildItem -Recurse -Filter *.gd -File |
		Where-Object { $_.FullName -notmatch '[\\/]\.godot[\\/]' -and $_.LastWriteTime -gt $cacheTime } |
		Select-Object -First 1)
}
if ($stale) {
	& $godot --headless --path . --import | Out-Null
}

if ($Filter) {
	& $godot --headless --path . --script res://tests/run_tests.gd -- $Filter
} else {
	& $godot --headless --path . --script res://tests/run_tests.gd
}
exit $LASTEXITCODE
