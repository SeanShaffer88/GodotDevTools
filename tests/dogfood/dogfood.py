#!/usr/bin/env python3
"""Print dogfood report summaries, finding kinds, and elapsed time.

Usage: python3 tests/dogfood/dogfood.py <reports-dir>
This does not adjudicate false positives or modify the false-positive log.
"""
import collections
import json
import pathlib
import sys


def main() -> int:
    root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "reports/dogfood")
    reports = sorted(p for p in root.rglob("*.json") if not p.name.endswith(".timing.json"))
    if not reports:
        print(f"No dogfood reports in {root}", file=sys.stderr)
        return 1
    failed = False
    for report in reports:
        try:
            data = json.loads(report.read_text(encoding="utf-8"))
            if not isinstance(data, dict) or not isinstance(data.get("summary"), dict):
                raise ValueError("missing summary object")
            issues = data.get("issues", [])
            if not isinstance(issues, list):
                raise ValueError("issues is not an array")
            kinds = collections.Counter(str(issue.get("kind", "unknown")) for issue in issues if isinstance(issue, dict))
            timing_file = report.with_name(report.stem + ".timing.json")
            timing = json.loads(timing_file.read_text(encoding="utf-8")) if timing_file.exists() else {}
            elapsed = timing.get("elapsed_ms", "unknown")
            print(f"{report.relative_to(root)}: elapsed_ms={elapsed} summary={json.dumps(data['summary'], sort_keys=True)} kinds={json.dumps(kinds, sort_keys=True)}")
            for issue in issues[:3]:
                if not isinstance(issue, dict):
                    continue
                location = str(issue.get("path", ""))
                line = issue.get("line", 0)
                message = " ".join(str(issue.get("message", "")).split())[:250]
                print(f"  sample {issue.get('kind', 'unknown')} {location}:{line}: {message}")
        except (OSError, ValueError, TypeError) as exc:
            failed = True
            print(f"{report}: unreadable ({exc})", file=sys.stderr)
    return int(failed)


if __name__ == "__main__":
    sys.exit(main())
