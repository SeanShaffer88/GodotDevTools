#!/bin/sh
# Filesystem-safety and CLI-path regression test using a mock Godot process.
set -eu
SRC="$(cd "$(dirname "$0")/../.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/gdt-dogfood-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
trap 'exit 1' HUP INT TERM
PROJECT="$TMP/game"
mkdir -p "$PROJECT/addons/naming_conventions"
printf '[application]\nconfig/name="Fixture"\n' > "$PROJECT/project.godot"
printf 'original addon\n' > "$PROJECT/addons/naming_conventions/keep.txt"
MOCK="$TMP/mock-godot"
cat > "$MOCK" <<'MOCK_SCRIPT'
#!/bin/sh
set -eu
work=""
script=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --path) work="$2"; shift 2 ;;
    --script) script="$2"; shift 2 ;;
    *) shift ;;
  esac
done
[ -f "$work/project.godot" ]
[ "$work" != "$ORIGINAL_PROJECT" ]
if [ -z "$script" ]; then
  [ "${MOCK_IMPORT_FAIL:-}" != 1 ] || exit 11
  exit 0
fi
relative="${script#res://}"
[ -f "$work/$relative" ] || { echo "missing script: $script" >&2; exit 1; }
addon="${relative#addons/}"
addon="${addon%%/*}"
case "$relative" in "addons/$addon/cli/"*_cli.gd) : ;; *) exit 1 ;; esac
[ "${MOCK_FAIL:-}" != "$addon" ] || exit 7
mkdir -p "$work/reports/dogfood"
printf '{"summary":{"issues":0}}\n' > "$work/reports/dogfood/$addon.json"
MOCK_SCRIPT
chmod +x "$MOCK"
ORIGINAL_PROJECT="$PROJECT" sh "$SRC/tests/dogfood/run_dogfood.sh" "$MOCK" "$PROJECT" "$TMP/results"
for addon in naming_conventions a11y_options duplicate_code script_complexity; do
  test -s "$TMP/results/$addon.json"
  test -s "$TMP/results/$addon.timing.json"
  test -f "$TMP/results/$addon.log"
done
python3 "$SRC/tests/dogfood/dogfood.py" "$TMP/results" > "$TMP/summary"
grep -q 'process import: elapsed_ms=.*exit_code=0 timed_out=false' "$TMP/summary"
grep -q 'report naming_conventions.json: timing=recorded' "$TMP/summary"
if python3 "$SRC/tests/dogfood/timed_run.py" "$TMP/timeout.timing.json" 0.05 python3 -c 'import time; time.sleep(2)' >/dev/null 2>&1; then
  echo "FAIL: timed command did not time out" >&2
  exit 1
else
  status=$?
  [ "$status" -eq 124 ] || { echo "FAIL: expected timeout exit 124" >&2; exit 1; }
fi
python3 - "$TMP/timeout.timing.json" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    timing = json.load(f)
assert timing["exit_code"] == 124 and timing["timed_out"] is True and timing["elapsed_ms"] >= 0
PY
test "$(cat "$PROJECT/addons/naming_conventions/keep.txt")" = "original addon"
test ! -e "$PROJECT/addons/naming_conventions/core/nc_audit.gd"
test ! -e "$PROJECT/reports"

mkdir "$TMP/existing"
printf 'keep me\n' > "$TMP/existing/sentinel"
if ORIGINAL_PROJECT="$PROJECT" sh "$SRC/tests/dogfood/run_dogfood.sh" "$MOCK" "$PROJECT" "$TMP/existing" >/dev/null 2>&1; then
  echo "FAIL: existing output directory was accepted" >&2
  exit 1
fi
test "$(cat "$TMP/existing/sentinel")" = "keep me"
if ORIGINAL_PROJECT="$PROJECT" MOCK_FAIL=duplicate_code sh "$SRC/tests/dogfood/run_dogfood.sh" "$MOCK" "$PROJECT" "$TMP/failing" >/dev/null 2>&1; then
  echo "FAIL: scanner error was ignored" >&2
  exit 1
fi
test -f "$TMP/failing/duplicate_code.log"
python3 "$SRC/tests/dogfood/dogfood.py" "$TMP/failing" > "$TMP/failing-summary"
grep -q 'process duplicate_code: elapsed_ms=.*exit_code=7 timed_out=false' "$TMP/failing-summary"
if ORIGINAL_PROJECT="$PROJECT" MOCK_IMPORT_FAIL=1 sh "$SRC/tests/dogfood/run_dogfood.sh" "$MOCK" "$PROJECT" "$TMP/import-failing" >/dev/null 2>&1; then
  echo "FAIL: import error was ignored" >&2
  exit 1
fi
if python3 "$SRC/tests/dogfood/dogfood.py" "$TMP/import-failing" > "$TMP/import-summary" 2>&1; then
  echo "FAIL: summary without reports was accepted" >&2
  exit 1
fi
grep -q 'process import: elapsed_ms=.*exit_code=11 timed_out=false' "$TMP/import-summary"
grep -q 'No dogfood reports' "$TMP/import-summary"
if ORIGINAL_PROJECT="$PROJECT" sh "$SRC/tests/dogfood/run_dogfood.sh" "$MOCK" "$PROJECT" "$PROJECT/results" >/dev/null 2>&1; then
  echo "FAIL: output inside source project was accepted" >&2
  exit 1
fi
test ! -e "$PROJECT/results"

# A copied addon symlink must never cause writes through to its target.
mkdir -p "$TMP/external" "$TMP/symlink-game/addons"
printf 'external file\n' > "$TMP/external/sentinel"
printf '[application]\nconfig/name="Links"\n' > "$TMP/symlink-game/project.godot"
ln -s "$TMP/external" "$TMP/symlink-game/addons/naming_conventions"
ORIGINAL_PROJECT="$TMP/symlink-game" sh "$SRC/tests/dogfood/run_dogfood.sh" "$MOCK" "$TMP/symlink-game" "$TMP/link-results" >/dev/null
test "$(cat "$TMP/external/sentinel")" = "external file"
test ! -e "$TMP/external/cli"

mkdir "$TMP/root-link-game"
printf '[application]\nconfig/name="Links"\n' > "$TMP/root-link-game/project.godot"
ln -s "$TMP/external" "$TMP/root-link-game/addons"
if ORIGINAL_PROJECT="$TMP/root-link-game" sh "$SRC/tests/dogfood/run_dogfood.sh" "$MOCK" "$TMP/root-link-game" "$TMP/root-link-results" >/dev/null 2>&1; then
  echo "FAIL: symlinked addons directory was accepted" >&2
  exit 1
fi
test ! -e "$TMP/external/naming_conventions"
echo "Dogfood harness safety tests passed"
