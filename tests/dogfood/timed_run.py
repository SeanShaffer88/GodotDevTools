#!/usr/bin/env python3
"""Run a dogfood command with a monotonic timer and bounded runtime.

Usage: timed_run.py TIMING_JSON SECONDS COMMAND [ARG ...]
Output and errors are inherited; the JSON includes elapsed milliseconds, exit
status and whether the watchdog fired, even on timeout or a missing executable.
"""
import json
import math
import pathlib
import subprocess
import sys
import threading
import time


def main() -> int:
    if len(sys.argv) < 4:
        print(__doc__, file=sys.stderr)
        return 1
    path = pathlib.Path(sys.argv[1])
    try:
        timeout = float(sys.argv[2])
        if not math.isfinite(timeout) or not 0 < timeout <= threading.TIMEOUT_MAX:
            raise ValueError("timeout must be finite, positive, and within the platform limit")
    except ValueError as exc:
        print(f"Invalid timeout: {exc}", file=sys.stderr)
        return 1

    started = time.monotonic()
    timed_out = threading.Event()
    try:
        process = subprocess.Popen(sys.argv[3:])
    except OSError as exc:
        print(f"Could not start command: {exc}", file=sys.stderr)
        status = 127
    else:
        def expire() -> None:
            # wait() below is blocking, not timeout-polling: fast commands do
            # not acquire Python's exponential polling-delay floor.
            if process.poll() is None:
                timed_out.set()
                try:
                    process.kill()
                except ProcessLookupError:
                    pass

        remaining = max(0.0, timeout - (time.monotonic() - started))
        watchdog = threading.Timer(remaining, expire)
        watchdog.daemon = True
        watchdog.start()
        try:
            returncode = process.wait()
        except BaseException:
            process.kill()
            process.wait()
            raise
        finally:
            watchdog.cancel()
            watchdog.join()
        if timed_out.is_set():
            print(f"Command timed out after {timeout:g} seconds", file=sys.stderr)
            status = 124
        else:
            status = returncode if returncode >= 0 else 128 - returncode

    elapsed_ms = round((time.monotonic() - started) * 1000)
    timing = {
        "elapsed_ms": elapsed_ms,
        "exit_code": status,
        "timeout_seconds": timeout,
        "timed_out": timed_out.is_set(),
    }
    path.write_text(json.dumps(timing) + "\n", encoding="utf-8")
    return status


if __name__ == "__main__":
    sys.exit(main())
