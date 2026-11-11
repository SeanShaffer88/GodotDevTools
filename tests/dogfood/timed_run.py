#!/usr/bin/env python3
"""Run a dogfood command with a monotonic timer and bounded runtime.

Usage: timed_run.py TIMING_JSON SECONDS COMMAND [ARG ...]
Output and errors are inherited; the JSON includes elapsed milliseconds and
exit status, even on timeout or a missing executable.
"""
import json
import pathlib
import subprocess
import sys
import time


def main() -> int:
    if len(sys.argv) < 4:
        print(__doc__, file=sys.stderr)
        return 1
    path = pathlib.Path(sys.argv[1])
    try:
        timeout = float(sys.argv[2])
        if timeout <= 0:
            raise ValueError("timeout must be positive")
    except ValueError as exc:
        print(f"Invalid timeout: {exc}", file=sys.stderr)
        return 1
    started = time.monotonic()
    try:
        result = subprocess.run(sys.argv[3:], timeout=timeout, check=False)
        status = result.returncode if result.returncode >= 0 else 128 - result.returncode
    except subprocess.TimeoutExpired:
        print(f"Command timed out after {timeout:g} seconds", file=sys.stderr)
        status = 124
    except OSError as exc:
        print(f"Could not start command: {exc}", file=sys.stderr)
        status = 127
    elapsed_ms = round((time.monotonic() - started) * 1000)
    path.write_text(json.dumps({"elapsed_ms": elapsed_ms, "exit_code": status, "timeout_seconds": timeout}) + "\n", encoding="utf-8")
    return status


if __name__ == "__main__":
    sys.exit(main())
