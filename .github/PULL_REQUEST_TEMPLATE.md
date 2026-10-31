## What does this change

<!-- One or two sentences: which tool, and what it now does that it did not before. -->

## Where does the logic live

<!-- The one rule from CONTRIBUTING.md: new checking logic goes in core/; docks, CLIs and tests stay thin shells. Point at the file. If this touches ui/ only (a button, a pane), say what core function it calls. -->

## Evidence

<!-- Required by the coverage floor:
- New/changed check: the demo/ fixture case that contains the problem + the tests/test_*.gd check that catches it.
- New CLI behaviour: the run_tests.sh line that exercises it, including exit-code-2 where it has one.
- Docs-only change: which status labels moved (PARITY.md / QUALITY.md) and what evidence backs them.
CI runs the full gate on 4.3-stable (must pass) and 4.5-stable (informational). -->

## Checklist

- [ ] `sh tests/run_tests.sh /path/to/godot` passes locally (or CI is green)
- [ ] CHANGELOG.md has an entry under [Unreleased]
- [ ] Tool README / root README limitations updated if user-visible behaviour or a known limit changed
- [ ] No network use, no cross-tool dependency, no checking logic outside core/
