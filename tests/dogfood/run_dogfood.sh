#!/bin/sh
# Dogfood run: copy addons into a real project and run a scanner subset.
# Usage: sh tests/dogfood/run_dogfood.sh <godot-binary> <project-dir>
set -e
GODOT="${1:?godot binary}"
PROJECT="${2:?project dir}"
SRC="$(cd "$(dirname "$0")/../.." && pwd)"
mkdir -p "$PROJECT/addons"
cp -r "$SRC/addons/"* "$PROJECT/addons/"
"$GODOT" --headless --path "$PROJECT" --import --quit-after 5 >/dev/null 2>&1 || true
for cli in naming_conventions/nc_cli.gd a11y_options/aoc_cli.gd duplicate_code/dup_cli.gd script_complexity/scx_cli.gd; do
  echo "== dogfood: $cli =="
  "$GODOT" --headless --path "$PROJECT" --script "res://addons/$cli" -- --dir=res:// --out=res://reports/dogfood || true
done
test -s "$PROJECT/reports/dogfood/naming_conventions.json" || test -s "$PROJECT/reports/dogfood/a11y_options.json"
echo "Dogfood reports: $PROJECT/reports/dogfood/"
