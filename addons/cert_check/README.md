# Platform Certification Checklist Runner

Compare a **user-maintained** requirements profile against recorded review results. This tool does not provide official platform requirements, execute compliance tests, verify evidence, or certify a game.

Profile: `{"requirements":[{"id":"save_recovery","evidence_required":true}]}`. Results: `{"checks":{"save_recovery":{"status":"pass","evidence":"test log"}}}`. Status is `pass`, `fail`, or `skip`. Missing, failed, skipped, unknown, and passing-without-required-evidence checks are reported. Duplicate or malformed requirements/results are errors. Evidence text is not checked for authenticity.

Enable the dock, or run `godot --headless --path . --script res://addons/cert_check/cli/cert_cli.gd -- --first=res://demo/cert_check/profile.json --second=res://demo/cert_check/results.json --fail-on=failed_check`. `--out` changes the report directory. JSON and Markdown reports are written under `res://reports/cert_check` by default. Selected warning kinds or `issues` exit 2; malformed input and I/O errors exit 1; otherwise exit 0. The tool is offline and never edits inputs. Godot and hands-on editor verification are pending.
