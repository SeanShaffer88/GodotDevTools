#!/usr/bin/env python3
"""Print dogfood process timings, report summaries, and sample findings.

Usage: python3 tests/dogfood/dogfood.py <reports-dir>
This does not adjudicate false positives or modify the false-positive log.
"""
import collections
import json
import pathlib
import sys


def timing_text(data: object) -> str:
    if not isinstance(data, dict):
        raise ValueError("timing must be an object")
    fields = ("elapsed_ms", "exit_code", "timed_out", "timeout_seconds")
    return " ".join(
        f"{key}={json.dumps(data.get(key, 'unknown'), sort_keys=True, ensure_ascii=True)}"
        for key in fields
    )


def sample(issue: dict) -> str:
    kind = " ".join(str(issue.get("kind", "unknown")).split())
    location = " ".join(str(issue.get("path", "")).split()) or "(no path)"
    line = issue.get("line")
    if isinstance(line, (int, float)) and not isinstance(line, bool) and line > 0 and int(line) == line:
        location += f":{int(line)}"
    message = " ".join(str(issue.get("message", "")).split())[:250]
    return f"  sample {kind} {location}: {message}"


def main() -> int:
    root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "reports/dogfood")
    timing_files = sorted(root.rglob("*.timing.json"))
    reports = sorted(p for p in root.rglob("*.json") if not p.name.endswith(".timing.json"))
    failed = False
    for timing_file in timing_files:
        try:
            data = json.loads(timing_file.read_text(encoding="utf-8"))
            name = timing_file.relative_to(root).as_posix()[:-len(".timing.json")]
            print(f"process {name}: {timing_text(data)}")
        except (OSError, ValueError, TypeError) as exc:
            failed = True
            print(f"{timing_file}: unreadable timing ({exc})", file=sys.stderr)
    if not reports:
        print(f"No dogfood reports in {root}", file=sys.stderr)
        return 1
    if not timing_files:
        print("process timings: not recorded")
    for report in reports:
        try:
            data = json.loads(report.read_text(encoding="utf-8"))
            if not isinstance(data, dict) or not isinstance(data.get("summary"), dict):
                raise ValueError("missing summary object")
            issues = data.get("issues", [])
            if not isinstance(issues, list) or any(not isinstance(issue, dict) for issue in issues):
                raise ValueError("issues must be an array of objects")
            kinds = collections.Counter(str(issue.get("kind", "unknown")) for issue in issues)
            timing = report.with_name(report.stem + ".timing.json")
            timing_status = "recorded" if timing.is_file() else "not_recorded"
            print(f"report {report.relative_to(root)}: timing={timing_status} summary={json.dumps(data['summary'], sort_keys=True)} kinds={json.dumps(kinds, sort_keys=True)}")
            for issue in issues[:3]:
                print(sample(issue))
        except (OSError, ValueError, TypeError, OverflowError) as exc:
            failed = True
            print(f"{report}: unreadable ({exc})", file=sys.stderr)
    return int(failed)


if __name__ == "__main__":
    sys.exit(main())
