#!/bin/sh
# The editor harness must refuse destructive scratch destinations.
set -eu
SRC="$(cd "$(dirname "$0")/../.." && pwd -P)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/gdt-editor-safety.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
trap 'exit 1' HUP INT TERM
FAKE="$TMP/fake-repository"
mkdir -p "$FAKE/tests/editor" "$TMP/existing"
cp "$SRC/tests/editor/run_editor_session.sh" "$FAKE/tests/editor/run_editor_session.sh"
printf 'keep\n' > "$FAKE/sentinel"
printf 'keep\n' > "$TMP/existing/sentinel"
if sh "$FAKE/tests/editor/run_editor_session.sh" false "$TMP/existing" >/dev/null 2>&1; then
  echo "FAIL: existing scratch directory accepted" >&2
  exit 1
fi
test "$(cat "$TMP/existing/sentinel")" = keep
if sh "$FAKE/tests/editor/run_editor_session.sh" false "$FAKE" >/dev/null 2>&1; then
  echo "FAIL: source repository accepted as scratch" >&2
  exit 1
fi
test "$(cat "$FAKE/sentinel")" = keep
if sh "$FAKE/tests/editor/run_editor_session.sh" false "$FAKE/new-scratch" >/dev/null 2>&1; then
  echo "FAIL: scratch path inside repository accepted" >&2
  exit 1
fi
test ! -e "$FAKE/new-scratch"
echo "Editor scratch safety tests passed"
