#!/usr/bin/env bash
# Writes the provisional sounds to assets/sounds/ and imports them.
# Usage: scripts/make_sounds.sh
#   GODOT=/path/to/godot scripts/make_sounds.sh   to use a specific Godot binary.
set -euo pipefail

cd "$(dirname "$0")/.."

# shellcheck source=scripts/godot_env.sh
source "scripts/godot_env.sh"

"$GODOT_BIN" --headless --path . --script res://scripts/make_sounds.gd
"$GODOT_BIN" --headless --path . --import >/dev/null 2>&1 || true
