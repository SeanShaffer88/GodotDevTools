# Android tool fixtures

These files are **synthetic**, not device captures or credentials:

- `export_presets.cfg` contains invalid and clean Android presets and a deliberately fake password marker. `release_history.json` supplies manually invented prior codes. `export_clean.cfg` is a separate clean example.
- `touch_snapshot.json` has small, unsafe, close, overlapping and rotated-target examples. `touch_clean.json` is a clean snapshot. Coordinates and density are invented.
- `logcat.txt` contains repeated Java crashes, a fatal signal, an ANR, unrelated and unattributed records, and fake secret markers to check report omission. `logcat_clean.txt` has one supported non-crash line.

Fixtures validate the documented checks; they do not establish Android device, export, store or privacy-redaction coverage.
