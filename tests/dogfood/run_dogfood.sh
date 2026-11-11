#!/bin/sh
# Dogfood a trusted Godot project without modifying its source directory.
# Usage: sh tests/dogfood/run_dogfood.sh <godot-binary> <project-dir> [new-output-dir]
set -eu
GODOT="${1:?godot binary}"
PROJECT="${2:?project dir}"
SRC="$(cd "$(dirname "$0")/../.." && pwd -P)"
if [ ! -f "$PROJECT/project.godot" ]; then
  echo "Not a Godot project: $PROJECT" >&2
  exit 1
fi
PROJECT="$(cd "$PROJECT" && pwd -P)"
if [ "$PROJECT" = / ]; then
  echo "The filesystem root is not a supported project directory." >&2
  exit 1
fi

# Never write reports or scratch files inside the source project. An explicit
# output's parent must already exist so it can be resolved before creating it.
if [ "${3:-}" ]; then
  parent="$(cd "$(dirname "$3")" && pwd -P)" || { echo "Output parent must exist: $3" >&2; exit 1; }
  OUTPUT="$parent/$(basename "$3")"
  case "$OUTPUT/" in "$PROJECT/"*) echo "Output must be outside the source project." >&2; exit 1 ;; esac
  if [ -e "$OUTPUT" ] || [ -L "$OUTPUT" ]; then
    echo "Output path already exists; choose a new directory: $OUTPUT" >&2
    exit 1
  fi
  mkdir "$OUTPUT"
else
  case "$SRC/reports/dogfood/" in "$PROJECT/"*) echo "Choose an output directory outside the source project." >&2; exit 1 ;; esac
  if [ -L "$SRC/reports" ] || [ -L "$SRC/reports/dogfood" ]; then
    echo "Default reports path must not be a symbolic link." >&2
    exit 1
  fi
  mkdir -p "$SRC/reports/dogfood"
  OUTPUT="$(mktemp -d "$SRC/reports/dogfood/run.XXXXXX")"
fi

TEMP_BASE="$(cd "${TMPDIR:-/tmp}" && pwd -P)"
case "$TEMP_BASE/" in "$PROJECT/"*) echo "TMPDIR must be outside the source project." >&2; exit 1 ;; esac
WORK="$(mktemp -d "$TEMP_BASE/gdt-dogfood.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
trap 'exit 1' HUP INT TERM
# Exclude transient outputs and the Git database from the disposable copy.
tar -C "$PROJECT" --exclude=./.git --exclude=./.godot --exclude=./reports --exclude=./visual_reports -cf "$WORK/project.tar" .
tar -C "$WORK" -xf "$WORK/project.tar"
rm "$WORK/project.tar"
# Do not follow project-provided links while installing the suite in the copy.
if [ -L "$WORK/addons" ]; then
  echo "A symlinked addons directory is not supported." >&2
  exit 1
fi
mkdir -p "$WORK/addons"
for addon_source in "$SRC"/addons/*; do
  [ -d "$addon_source" ] || continue
  destination="$WORK/addons/$(basename "$addon_source")"
  rm -rf "$destination"
  cp -R "$addon_source" "$destination"
done

# Importing a Godot project can execute its code/plugins: use trusted projects.
# Timing covers process startup and is evidence, not a controlled benchmark.
TIMER="$SRC/tests/dogfood/timed_run.py"
if ! python3 "$TIMER" "$OUTPUT/import.timing.json" "${GDT_DOGFOOD_TIMEOUT:-180}" "$GODOT" --headless --path "$WORK" --import --quit-after 5 >"$OUTPUT/import.log" 2>&1; then
  echo "Project import failed; see $OUTPUT/import.log" >&2
  exit 1
fi

failed=0
for entry in naming_conventions/nc_cli.gd a11y_options/aoc_cli.gd duplicate_code/dup_cli.gd script_complexity/scx_cli.gd; do
  addon="${entry%%/*}"
  script="${entry#*/}"
  echo "== dogfood: $addon =="
  if python3 "$TIMER" "$OUTPUT/$addon.timing.json" "${GDT_DOGFOOD_TIMEOUT:-180}" "$GODOT" --headless --path "$WORK" --script "res://addons/$addon/cli/$script" -- --dir=res:// --out=res://reports/dogfood >"$OUTPUT/$addon.log" 2>&1; then
    :
  else
    status=$?
    if [ "$status" -ne 2 ]; then
      echo "$addon failed with exit $status; see $OUTPUT/$addon.log" >&2
      failed=1
    fi
  fi
  if [ ! -s "$WORK/reports/dogfood/$addon.json" ]; then
    echo "$addon did not produce a report" >&2
    failed=1
  fi
done
if [ -d "$WORK/reports/dogfood" ]; then
  cp -R "$WORK/reports/dogfood/." "$OUTPUT/"
fi
echo "Dogfood reports: $OUTPUT"
[ "$failed" -eq 0 ]
