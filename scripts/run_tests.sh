#!/usr/bin/env bash
# Runs every test under tests/ without opening the editor.
# Usage: scripts/run_tests.sh [filter]
#   GODOT=/path/to/godot scripts/run_tests.sh   to use a specific Godot binary.
set -euo pipefail

cd "$(dirname "$0")/.."

find_godot() {
	if [ -n "${GODOT:-}" ]; then
		echo "$GODOT"
		return
	fi
	for name in godot godot4 Godot; do
		if command -v "$name" >/dev/null 2>&1; then
			command -v "$name"
			return
		fi
	done
	# Official downloads keep their versioned name (Godot_v4.x-stable_...):
	# look for them in every PATH folder, console build first on Windows.
	local dir
	IFS=: read -r -a path_dirs <<< "${PATH:-}"
	for pattern in "Godot_v4*_win64_console.exe" "Godot_v4*_linux.x86_64"; do
		for dir in "${path_dirs[@]}"; do
			for candidate in "$dir"/$pattern; do
				if [ -x "$candidate" ]; then
					echo "$candidate"
					return
				fi
			done
		done
	done
	# Usual install locations (macOS app bundle, Linux and Windows downloads).
	# On Windows, prefer the *_console.exe build: the other one does not print to the terminal.
	for candidate in \
		"/Applications/Godot.app/Contents/MacOS/Godot" \
		"$HOME/Applications/Godot.app/Contents/MacOS/Godot" \
		"$HOME"/Downloads/Godot_v4*_win64_console.exe \
		"$HOME"/Desktop/Godot_v4*_win64_console.exe \
		"$HOME"/Godot/Godot_v4*_win64_console.exe \
		"$HOME"/Downloads/Godot_v4*_linux.x86_64 \
		"$HOME"/Godot/Godot_v4*_linux.x86_64; do
		if [ -x "$candidate" ]; then
			echo "$candidate"
			return
		fi
	done
}

GODOT_BIN="$(find_godot)"
if [ -z "$GODOT_BIN" ]; then
	echo "Godot introuvable." >&2
	echo "Indique le chemin de l'exécutable, par exemple :" >&2
	echo "  GODOT=/Applications/Godot.app/Contents/MacOS/Godot scripts/run_tests.sh" >&2
	exit 2
fi

# On a fresh clone the class cache (.godot/) does not exist yet:
# importing once lets the tests resolve class_name declarations.
if [ ! -d .godot ]; then
	"$GODOT_BIN" --headless --path . --import >/dev/null 2>&1 || true
fi

if [ $# -gt 0 ]; then
	"$GODOT_BIN" --headless --path . --script res://tests/run_tests.gd -- "$1"
else
	"$GODOT_BIN" --headless --path . --script res://tests/run_tests.gd
fi
