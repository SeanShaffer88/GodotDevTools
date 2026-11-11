#!/usr/bin/env python3
"""Print summaries from dogfood reports; false-positive review is manual.
Usage: python3 tests/dogfood/dogfood.py <reports-dir>
Stdlib only. This does not modify the false-positive log.
"""
import json, pathlib, sys
def main():
    root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "reports/dogfood")
    for jf in sorted(root.rglob("*.json")):
        try:
            data = json.loads(jf.read_text())
            print(f"{jf.parent.name}: {data.get('summary', {})}")
        except Exception as e:
            print(f"{jf}: unreadable ({e})")
if __name__ == "__main__":
    main()
