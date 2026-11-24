#!/usr/bin/env bash
# Gathers the runs played by people into docs/playtest-report.md.
# Usage: scripts/run_playtests.sh [folder] [version]
#   Without a folder: the runs played on this computer (the folder "runs" of the game's data).
#   With a version (e.g. 0.0.2): only the runs played with that version.
#   GODOT=/path/to/godot scripts/run_playtests.sh   to use a specific Godot binary.
set -euo pipefail

cd "$(dirname "$0")/.."

# shellcheck source=scripts/godot_env.sh
source "scripts/godot_env.sh"

folder="${1:-}"
# Godot runs from the project: a relative folder is made absolute first.
if [ -n "$folder" ] && [ -d "$folder" ]; then
	folder="$(cd "$folder" && pwd)"
fi
"$GODOT_BIN" --headless --path . --script res://sim/run_playtests.gd -- "$folder" "${2:-}"
