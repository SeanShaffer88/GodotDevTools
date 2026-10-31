# Subtitle Timing and Readability Auditor

Review timed subtitles before shipping. Enable the plugin and enter a JSON path in the dock, or run:

```sh
godot --headless --path . --script res://addons/subtitle_audit/cli/sub_cli.gd -- \
  --input=res://demo/subtitles/cues.json --require-speaker --fail-on=overlap,reading_speed
```

Input is a JSON object containing `cues`, an array of objects with numeric `start` and `end` in seconds, string `text`, and optional `speaker`. Literal newline characters in text separate lines. Cues need not be sorted. Example:

```json
{"cues":[{"start":0,"end":2,"text":"Hello!","speaker":"Guide"}]}
```

The scanner checks malformed cues and timing, empty text, duration below one second, reading speed over 20 characters per second (excluding newlines), lines over 42 characters, and overlapping cues. Speaker checks are opt-in (`--require-speaker`). Overlaps are candidates for review: simultaneous dialogue can be intentional. The pure core `analyze(data, options)` accepts `min_seconds`, `max_cps`, `max_line` and `require_speaker`; the first three use defaults in the dock and CLI.

The CLI writes JSON and Markdown to `res://reports/subtitle_audit` (`--out` overrides it). `--fail-on` accepts comma-separated finding kinds or `issues`; a selected warning exits 2. Invalid input, invalid timings/options or report-write failures exit 1; otherwise exit 0. The default `--input` is the demo fixture.

This first version only reads the documented JSON format, not SRT/VTT or audio. Character counts are heuristics, not measured reading comprehension or rendered width; it does not check font, wrapping, safe areas, localization conventions, speaker identity, or sync to media. It never modifies the source. Godot execution and a hands-on dock session remain to be verified.
