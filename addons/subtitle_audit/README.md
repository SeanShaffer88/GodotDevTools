# Subtitle Timing and Readability Auditor

Review timed subtitles before shipping. Enable the plugin and enter a subtitle path in the dock, or run:

```sh
godot --headless --path . --script res://addons/subtitle_audit/cli/sub_cli.gd -- \
  --input=res://demo/subtitles/overlap.srt --fail-on=overlap,reading_speed
```

Inputs are selected by extension: `.srt`, `.vtt` (WebVTT), or otherwise a JSON object containing `cues`, an array of objects with numeric `start`/`end` in seconds, string `text`, and optional `speaker`. JSON example: `{"cues":[{"start":0,"end":2,"text":"Hello!","speaker":"Guide"}]}`. Cues need not be sorted.

The SRT subset accepts numbered or unnumbered cues with `HH:MM:SS,mmm` timestamps. WebVTT accepts a `WEBVTT` header, optional identifiers, `MM:SS.mmm` or `HH:MM:SS.mmm` timestamps, and cue settings. Blocks require blank-line separation. UTF-8 BOM and CRLF are supported. WebVTT NOTE, STYLE and REGION blocks and cue settings are ignored; inline tags and entities are retained as literal text and counted. Speaker labels are not inferred from SRT/VTT tags. Unsupported or malformed timing and missing cue separators fail the entire import rather than silently returning partial coverage.

The scanner checks malformed cues and timing, empty text, duration below one second, reading speed over 20 characters per second (excluding newlines), lines over 42 characters, and overlapping cues. Speaker checks are opt-in (`--require-speaker`); for SRT/VTT they will flag all cues unless data is converted to JSON with speaker fields. Overlaps are review candidates: simultaneous dialogue can be intentional. The pure core `analyze(data, options)` accepts `min_seconds`, `max_cps`, `max_line` and `require_speaker`; the dock and CLI use defaults.

The CLI writes JSON and Markdown to `res://reports/subtitle_audit` (`--out` overrides it). `--fail-on` accepts comma-separated finding kinds or `issues`; a selected warning exits 2. Invalid input, invalid timings/options or report-write failures exit 1; otherwise exit 0. The default `--input` is the demo JSON fixture.

This is not a full SRT or WebVTT implementation: it does not interpret styling, markup, layout metadata, audio or speaker identity. Character counts are heuristics, not measured comprehension or rendered width. It does not check font, wrapping, safe areas, localization conventions, or sync to media. It never modifies the source. The previous JSON audit passed Godot 4.3/4.5 CI; the new timed-text import and hands-on dock session still need verification.
