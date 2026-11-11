# Windows verification

`.github/workflows/windows-gpu.yml` runs a headless gate and windowed editor/live-game sessions on `windows-latest` with Godot 4.3. `tests/windows/run_windows_gate.ps1` provides a local wrapper for the gate (requires Git Bash).

## Verification status

The Windows workflow is under development and has not yet passed. GitHub-hosted Windows runners do not guarantee a hardware GPU, so even a green run is not evidence of hands-on use with a physical GPU. Record the renderer/adapter and test on real Windows hardware before claiming that gap is closed. See `QUALITY.md`.

## Run the gate locally on Windows

```powershell
.\tests\windows\run_windows_gate.ps1 -Godot "C:\Godot\Godot_v4.3-stable_win64_console.exe"
```

The gate imports the project, runs the test suites, and exercises the CLIs, including exit-code-2 checks.
