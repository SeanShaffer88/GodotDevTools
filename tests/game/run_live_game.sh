#!/bin/sh
# Live game session for the runtime nodes (windowed, not headless).
# Usage: sh tests/game/run_live_game.sh <godot-binary>
# Exits non-zero if any runtime check fails. Results: reports/live_game/.
set -e
GODOT="${1:?godot binary}"
cd "$(dirname "$0")/../.."
"$GODOT" --headless --path . --import --quit-after 5 >/dev/null 2>&1 || true
if command -v xvfb-run >/dev/null 2>&1; then
  timeout 600 xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . --rendering-driver opengl3 res://tests/game/live_game.tscn
else
  timeout 600 "$GODOT" --path . --rendering-driver opengl3 res://tests/game/live_game.tscn
fi
test -s reports/live_game/live_game.json
