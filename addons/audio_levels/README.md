# Audio Loudness and Clipping Auditor

Read WAV files sample by sample: peak and RMS level in dBFS, clipped samples, DC offset and sample-rate mismatches. Enable the addon in Project Settings → Plugins and use **Measure audio levels** in the **Audio Levels** dock.

It decodes every `.wav` under the folder (hidden folders, `addons/` and report folders skipped): 8/16/24/32-bit PCM and 32-bit float, mono or multichannel (channels are pooled). For each file it reports sample rate, length, peak and RMS in dBFS, clipped samples (at or beyond full scale) and mean sample value.

| Finding | Meaning |
|---|---|
| `clipping` | Samples at full scale: distortion is baked into the file. |
| `peak_hot` | Peak above -1 dBFS without clipping: no headroom. |
| `too_quiet` | RMS below `--quiet-db` (default -40 dBFS). |
| `dc_offset` | Mean sample value beyond ±0.02. |
| `rate_mismatch` | Sample rate differs from `--expected-rate`, or from the most common rate in the folder. |
| `unsupported_wav` | Not a PCM/float WAV (compressed WAV, broken header). |

## Command line

```sh
godot --headless --path . --script res://addons/audio_levels/cli/ala_cli.gd -- \
  --dir=res://demo/assets_audit --fail-on=clipping
```

Options: `--dir=<path>` (default `res://`), `--out=<dir>` (default `res://reports/audio_levels`), `--expected-rate` (sample rate every file should use (default 0 = the most common rate)), `--quiet-db` (RMS below this dBFS is too quiet (default -40)), `--max-samples` (samples read per file (default 2000000)), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `audio_levels.json` and `audio_levels.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- RMS is not perceived loudness (LUFS/LKFS); it ranks files and catches outliers but is not a broadcast measurement.
- Ogg Vorbis and MP3 are not decoded.
- Files longer than `--max-samples` are measured on their first samples only (the report shows samples read).
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
