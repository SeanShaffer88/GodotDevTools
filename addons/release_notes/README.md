# Release Notes Generator

Group conventional-commit subjects into a draft changelog section: breaking changes, features, fixes, performance and other. Enable the addon in Project Settings → Plugins and use **Draft release notes** in the **Release Notes** dock.

Produce the input with `git log --format=%s v1.0.0..HEAD > commits.txt`. Each subject in conventional-commit form, `type(scope)!: summary`, is sorted: `feat` → Added, `fix` → Fixed, `perf` → Performance, `!` or `BREAKING CHANGE` → Breaking, other types → Other (shown with `--include-other`). Merge commits are skipped; other lines go to Unsorted. The draft section (heading `--version`, default `Unreleased`) is in both reports, ready to edit into `CHANGELOG.md`.

| Finding | Meaning |
|---|---|
| `breaking_change` | A breaking change needs a call-out and migration notes. |
| `nonconventional_commit` | A subject is not in conventional form; place it by hand. |

## Command line

```sh
godot --headless --path . --script res://addons/release_notes/cli/rln_cli.gd -- \
  --commits=res://demo/shipping/commits.txt --fail-on=breaking_change
```

Options: `--commits=<path>` (default `res://demo/shipping/commits.txt`), `--out=<dir>` (default `res://reports/release_notes`), `--version` (heading for the draft (default Unreleased)), `--include-other` (list docs/refactor/test/chore commits too (default false)), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `release_notes.json` and `release_notes.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Subjects only; commit bodies (where BREAKING CHANGE footers usually live) are not read unless included in the file.
- The draft is for a human to edit: commit subjects are written for developers, release notes for players.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
