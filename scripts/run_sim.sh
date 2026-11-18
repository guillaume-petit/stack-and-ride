#!/usr/bin/env bash
# Plays many runs with the bot and writes docs/balance-report.md.
# Usage: scripts/run_sim.sh [runs per profile, default 200] [first seed, default 1]
#   GODOT=/path/to/godot scripts/run_sim.sh   to use a specific Godot binary.
set -euo pipefail

cd "$(dirname "$0")/.."

# shellcheck source=scripts/godot_env.sh
source "scripts/godot_env.sh"

"$GODOT_BIN" --headless --path . --script res://sim/run_simulation.gd -- "$@"
