#!/usr/bin/env bash
# Run the repository's committed gate inside an already-built Docker image.
# Linux host requirements: Docker, git, tar, timeout and bash.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd -P)"
image="${1:-godot-dev-tools}"
docker="${GDT_DOCKER:-docker}"
limit="${GDT_DOCKER_GATE_TIMEOUT:-600s}"
scratch="$(mktemp -d "${TMPDIR:-/tmp}/gdt-docker-gate.XXXXXXXX")"
project="$scratch/project"
log="$scratch/gate.log"
container="gdt-gate-$$-$RANDOM-$RANDOM"
started=0
status=1

cleanup() {
  # --rm removes successful containers; also remove a container whose client
  # timed out or was interrupted. The checkout is always disposable.
  if [ "$started" -eq 1 ] && ! timeout --kill-after=5s 15s "$docker" rm --force "$container" >/dev/null 2>&1; then
    if [ "$status" -ne 0 ]; then
      echo "WARNING: check whether container $container needs removal (it may already be gone)." >&2
    fi
  fi
  rm -rf -- "$scratch"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

mkdir -p "$project"
# Archive HEAD, rather than copying .git, caches or local untracked files.
# On PRs actions/checkout supplies the tested merge commit as HEAD.
git -C "$root" archive --format=tar HEAD > "$scratch/project.tar"
tar -xf "$scratch/project.tar" -C "$project"
# Never accept stale outputs as evidence, even if a future commit tracks them.
rm -rf -- "$project/reports" "$project/visual_reports" "$project/.godot"

printf 'Running committed gate in image %s (limit %s)\n' "$image" "$limit"
started=1
set +e
timeout --kill-after=15s "$limit" "$docker" run --rm --pull=never --name "$container" \
  --network=none --user "$(id -u):$(id -g)" --env HOME=/tmp \
  --volume "$project:/work" "$image" gate 2>&1 | tee "$log"
statuses=("${PIPESTATUS[@]}")
set -e
status="${statuses[0]}"
if [ "${statuses[1]}" -ne 0 ] && [ "$status" -eq 0 ]; then
  echo 'FAIL: could not save the Docker gate log' >&2
  status=1
fi
if [ "$status" -eq 0 ] && ! grep -qx 'ALL GATE CHECKS PASSED' "$log"; then
  echo 'FAIL: the gate success marker is missing' | tee -a "$log" >&2
  status=1
fi
if [ "$status" -eq 0 ] && {
  [ ! -s "$project/reports/android_export_audit/android_export_audit.json" ] ||
  [ ! -s "$project/visual_reports/menu__320x240.highlight.png" ];
}; then
  echo 'FAIL: expected gate reports were not written to the mounted project' | tee -a "$log" >&2
  status=1
fi
if [ "$status" -ne 0 ]; then
  echo "Docker gate failed with exit $status" >&2
  if [ "${GITHUB_ACTIONS:-}" = true ]; then
    if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
      if {
        echo '### Mounted Docker gate failure (last 80 lines, up to 20 KB)'
        echo '```'
        { tail -80 "$log" 2>/dev/null || echo '(gate log unavailable)'; } | tail -c 20000
        echo '```'
      } >> "$GITHUB_STEP_SUMMARY"; then
        :
      else
        echo 'WARNING: could not write the GitHub step summary' >&2
      fi
    fi
    message="$( { tail -60 "$log" 2>/dev/null || echo '(gate log unavailable)'; } | tail -c 12000 )" || message='(gate log unavailable)'
    message=${message//'%'/'%25'}
    message=${message//$'\n'/'%0A'}
    message=${message//$'\r'/'%0D'}
    echo "::error title=Mounted Docker gate failed (exit $status)::$message" || :
  fi
  exit "$status"
fi
printf '%s\n' 'Mounted Docker gate passed.'
