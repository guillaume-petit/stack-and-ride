#!/usr/bin/env bash
# Runs every test under tests/ without opening the editor.
# Usage: scripts/run_tests.sh [filter]
#   GODOT=/path/to/godot scripts/run_tests.sh   to use a specific Godot binary.
set -euo pipefail

GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."

# On a fresh clone the class cache (.godot/) does not exist yet:
# importing once lets the tests resolve class_name declarations.
if [ ! -d .godot ]; then
	"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
fi

if [ $# -gt 0 ]; then
	"$GODOT" --headless --path . --script res://tests/run_tests.gd -- "$1"
else
	"$GODOT" --headless --path . --script res://tests/run_tests.gd
fi
