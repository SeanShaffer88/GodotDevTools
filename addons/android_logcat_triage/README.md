# Android Logcat Crash Triage

Group a local Android `logcat -v threadtime` capture into supported Java fatal exceptions, libc fatal signals and ActivityManager ANR records. This complements the generic Godot log grouper and crash packager; it does not connect to a device, collect a dump or upload anything.

## Capture and inspect

On a machine with the Android SDK, collect a log using your own authorized device connection:

```sh
adb logcat -d -v threadtime > android_logcat.txt
```

The tool never invokes `adb` or clears the device buffer. Raw logs can contain account data, tokens and personal information: store them securely and do not commit them. Copy `addons/android_logcat_triage` into your project, enable **Android Logcat Crash Triage**, select the UTF-8 file in the **Android Logcat Triage** dock, optionally enter an exact application ID, and press **Triage logcat**.

The analyzer recognizes `AndroidRuntime: FATAL EXCEPTION:` headers followed by `Process:`, exception/cause classes and up to three `at` methods from the same PID within 120 lines; `libc: Fatal signal ... (SIG...)` headers; and `ActivityManager: ANR in ...` headers. Java groups use process, exception, last recognized cause and the first three recognized method names; source filenames, line numbers and exception messages do not affect grouping. Native groups use process and signal; ANRs use process. Counts are **recognized log records**, not deduplicated real-world incident counts. Hints are starting points, not diagnoses.

A package filter includes the exact process name and `package:subprocess` names. Crash headers whose process cannot be recognized are excluded by the filter and counted as `unattributed_crashes`. Other packages are excluded. Android may truncate native process names; verify attribution in the original log.

## Command line

```sh
godot --headless --path . --script res://addons/android_logcat_triage/cli/alt_cli.gd -- \
  --log=/absolute/path/android_logcat.txt --package=com.studio.game \
  --fail-on=java_crash,native_crash,anr
```

`--log` defaults to `user://android_logcat.txt`; `--package` is optional; `--out` defaults to `res://reports/android_logcat_triage`. Reports are `android_logcat_triage.json` and `.md`. `--fail-on` accepts comma-separated kinds below, `errors`, or `issues`. Exit **0** on success without selected findings, **2** for selected findings, and **1** on bad arguments, malformed/unreadable input or report-write errors. `--help` lists options.

| Finding | Meaning |
|---|---|
| `java_crash`, `native_crash`, `anr` | A matching group of recognized crash/ANR records. |
| `incomplete_java_trace` | A selected Java record lacked a recognized exception class or frames. |
| `unattributed_crashes` | Records missing a recognized process were excluded by the package filter. |
| `unsupported_lines` | Nonempty lines were not threadtime records and were ignored. |
| `no_matching_crashes` | No supported records matched; this does **not** mean the app is crash-free. |
| `event_limit` | Crash headers beyond 5,000 were skipped; split the log. |
| `bad_input` | Invalid filter, missing/binary/non-UTF-8 file, log over 10 MB, or no recognized threadtime lines; always exits 1. |

## Limits and privacy

- Only the described threadtime forms are recognized. Other logcat formats, unprefixed multiline stack lines, tombstone-only traces, native backtraces, application-specific crash reporters, ANR variants and silent crashes can be missed. See `unsupported_lines` and inspect the original capture. Symbolicate native crashes separately using matching unstripped libraries.
- Interleaved Java traces are tracked by logcat PID with a 120-line bound; incomplete, unusual or reused-PID logs may still be misgrouped. Filtering requires recognized process attribution; missing process lines and truncated names can hide records from filtered results.
- The reports deliberately omit raw message text, source paths and addresses. They still contain the input path, package/process names, class and method names, counts and line numbers. These may themselves be sensitive, and this is **not a general-purpose redactor**. Review both reports and raw logs before sharing.
- Input is read-only; the CLI writes reports locally. No network use. Headless synthetic log fixtures are provided; no actual Android device or crash dump has been verified by this addon.
