#!/usr/bin/env python3
"""Append a coverage_gate report to docs/coverage_trend.csv + badge JSON.
Usage: python3 tools/coverage/coverage_trend.py reports/coverage_gate/coverage_gate.json
Stdlib only. Run in CI on main (see .github/workflows/coverage-trend.yml).
"""
import csv, json, pathlib, sys, datetime
ROOT = pathlib.Path(__file__).resolve().parents[2]
def main():
    report = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "reports/coverage_gate/coverage_gate.json")
    data = json.loads(report.read_text())
    s = data.get("summary", {})
    csv_path = ROOT / "docs" / "coverage_trend.csv"
    date = datetime.date.today().isoformat()
    row = {"date": date, "percent": s.get("percent", ""), "functions": s.get("functions", ""), "covered": s.get("covered", "")}
    exists = csv_path.exists()
    with csv_path.open("a", newline="") as f:
        wtr = csv.DictWriter(f, fieldnames=["date", "percent", "functions", "covered"])
        if not exists:
            wtr.writeheader()
        wtr.writerow(row)
    badge = {"schemaVersion": 1, "label": "coverage (estimate)", "message": f"{row['percent']}%", "color": "green" if float(row["percent"] or 0) >= 50 else "yellow"}
    (ROOT / "docs" / "coverage_badge.json").write_text(json.dumps(badge, indent=2) + "\n")
    print(f"trend: {row} -> docs/coverage_trend.csv, docs/coverage_badge.json")
if __name__ == "__main__":
    main()
