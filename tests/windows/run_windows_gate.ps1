# Windows gate wrapper. Usage: .\tests\windows\run_windows_gate.ps1 -Godot "C:\path\godot.exe"
# Runs the same tests/run_tests.sh the Linux CI runs, via Git Bash if present,
# otherwise falls back to a clear error. See docs/WINDOWS_GPU.md.
param([string]$Godot = "godot")
$ErrorActionPreference = "Stop"
$bash = Get-Command bash -ErrorAction SilentlyContinue
if (-not $bash) {
  Write-Error "Git Bash (bash.exe) is required on Windows. Install Git for Windows, then re-run."
  exit 1
}
$root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Push-Location $root
try {
  & bash -c "sh tests/run_tests.sh '$($Godot -replace '\\','/')'"
  exit $LASTEXITCODE
} finally { Pop-Location }
