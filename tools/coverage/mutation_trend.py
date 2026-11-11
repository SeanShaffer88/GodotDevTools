#!/usr/bin/env python3
"""Append mutation_tester results to docs/mutation_trend.csv.
Usage: python3 tools/coverage/mutation_trend.py <mutation-report.json> [score]
Stdlib only. The score is read from the report summary if present, else argv[2].
"""
import csv, json, pathlib, sys, datetime
ROOT = pathlib.Path(__file__).resolve().parents[2]
def main():
    report = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "reports/mutation_tester/mutation_tester.json")
    score = sys.argv[2] if len(sys.argv) > 2 else ""
    if report.exists() and not score:
        try:
            s = json.loads(report.read_text()).get("summary", {})
            score = str(s.get("mutation_score", s.get("killed", "")))
        except Exception:
            pass
    csv_path = ROOT / "docs" / "mutation_trend.csv"
    exists = csv_path.exists()
    with csv_path.open("a", newline="") as f:
        wtr = csv.DictWriter(f, fieldnames=["date", "mutation_score"])
        if not exists:
            wtr.writeheader()
        wtr.writerow({"date": datetime.date.today().isoformat(), "mutation_score": score})
    print(f"mutation trend: score={score} -> docs/mutation_trend.csv")
if __name__ == "__main__":
    main()
