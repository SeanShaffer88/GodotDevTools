# Audio Import Settings Auditor

Check audio import settings against each clip's role and length: looping music, non-looping effects, long uncompressed WAVs. Enable the addon in Project Settings → Plugins and use **Audit audio imports** in the **Audio Import** dock.

It reads the `.import` file of every `.wav`, `.ogg` and `.mp3` under the folder (hidden folders, `addons/` and report folders skipped). A clip's role comes from its path: `--music-pattern` (default `/music/`) and `--sfx-pattern` (default `/sfx/`). WAV loop mode 0 ("Detect from WAV") counts as looping only when the WAV has loop points; WAV length is read from the source header.

| Finding | Meaning |
|---|---|
| `music_not_looping` | A music clip is imported without looping. |
| `sfx_looping` | A sound effect is imported looping. |
| `long_wav` | A WAV is longer than `--max-wav-seconds`; Ogg Vorbis is usually the better format. |

## Command line

```sh
godot --headless --path . --script res://addons/audio_import/cli/aia_cli.gd -- \
  --dir=res://demo/assets_audit --fail-on=music_not_looping
```

Options: `--dir=<path>` (default `res://`), `--out=<dir>` (default `res://reports/audio_import`), `--music-pattern` (path text marking music (default /music/)), `--sfx-pattern` (path text marking sound effects (default /sfx/)), `--max-wav-seconds` (WAV clips longer than this should be Ogg Vorbis (default 10)), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `audio_import.json` and `audio_import.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Roles come only from path patterns; stingers and one-shot jingles in a music folder will be flagged - move them or ignore.
- Loops set from code (`stream.loop = true`) or by AudioStreamPlayer settings are not seen.
- Ogg/MP3 durations are not read.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
