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

## Rendered layout (opt-in)

Add `--font-size=32 --layout-width=1920 --safe-area=0.9 --max-lines=2` (and optionally `--font=res://fonts/ui.ttf`; the engine fallback font is used otherwise) to lay every cue out with Godot's own line breaker: `TextParagraph`, which is the TextServer path `Label` uses. The box is the safe-area fraction of the layout width. Two findings can result:
- `layout_overflow`: a cue wraps to more lines than allowed.
- `layout_clipped`: a single word is wider than the box.

Explicit line breaks always count. The line counts match a `Label` rendered in a real window (checked in `tests/game/live_game.gd`). The check does not cover your own subtitle panel's padding, outline, theme or scaling, so set the width and safe area to match it.

This is not a full SRT or WebVTT implementation. It does not interpret styling, markup, layout metadata, audio or speaker identity. Character-per-second counts are heuristics, not measured comprehension. Localization conventions and sync to media are not checked. The tool never modifies the source.
