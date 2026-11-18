#!/usr/bin/env bash
# Runs every test under tests/ without opening the editor.
# Usage: scripts/run_tests.sh [filter]
#   GODOT=/path/to/godot scripts/run_tests.sh   to use a specific Godot binary.
set -euo pipefail

cd "$(dirname "$0")/.."

# shellcheck source=scripts/godot_env.sh
source "scripts/godot_env.sh"

if [ $# -gt 0 ]; then
	"$GODOT_BIN" --headless --path . --script res://tests/run_tests.gd -- "$1"
else
	"$GODOT_BIN" --headless --path . --script res://tests/run_tests.gd
fi
