# Windows + GPU verification

Closes the main *Unverified* item in `QUALITY.md`: *"hands-on use on Windows with a GPU"*.

## What was added

- `.github/workflows/windows-gpu.yml` — two jobs on `windows-latest`:
  - **Gate on Windows (Godot 4.3)**: downloads Godot 4.3-stable Windows, runs `sh tests/run_tests.sh`.
  - **Editor and live-game sessions on Windows (GPU)**: runs `tests/game/run_live_game.sh` logic and `tests/editor/run_editor_session.sh` with `--rendering-driver opengl3` on a real GPU (no Xvfb needed on Windows).
- `tests/windows/run_windows_gate.ps1` — local wrapper for developers on Windows (requires Git Bash).

## Status (honest)

**CI-ready, pending first green run.** Per `PROJECT_RULES.md` ("never claim a version/platform works without a test run"), Windows/GPU stays *Unverified* in `QUALITY.md` until this workflow passes on `main`. After the first green run, update `QUALITY.md`, `docs/PARITY.md` and the README limitations list in the same PR.

## Run locally on Windows

```powershell
.\tests\windows\run_windows_gate.ps1 -Godot "C:\Godot\Godot_v4.3-stable_win64_console.exe"
```

Requires Git for Windows (for `bash.exe`). The gate imports the project, runs every `tests/test_*.gd`, and exercises every CLI including exit-code-2 gates — identical to Linux CI.
