extends SceneTree
const Audit := preload("res://addons/subtitle_audit/core/sub_audit.gd")
var passes := 0
var failures := 0

func check(label: String, ok: bool) -> void:
    if ok:
        passes += 1
        print("PASS  ", label)
    else:
        failures += 1
        print("FAIL  ", label)

func kinds(result: Dictionary) -> Array:
    var out: Array = []
    for issue in result["issues"]:
        out.append(issue["kind"])
    return out

func _init() -> void:
    var audit = Audit.new()
    var result: Dictionary = audit.run("res://demo/subtitles/cues.json")
    check("fixture has two cues", result["summary"]["cues"] == 2)
    check("overlap detected", kinds(result).has("overlap"))
    check("short duration detected", kinds(result).has("short_duration"))
    check("reading speed detected", kinds(result).has("reading_speed"))
    check("long line detected", kinds(result).has("long_line"))
    var clean: Dictionary = audit.analyze({"cues": [{"start": 0, "end": 2, "text": "Hello", "speaker": "A"}]}, {"require_speaker": true})
    check("clean cue passes", clean["issues"].is_empty())
    var no_speaker: Dictionary = audit.analyze({"cues": [{"start": 0, "end": 2, "text": "Hello"}]}, {"require_speaker": true})
    check("required speaker detected", kinds(no_speaker).has("missing_speaker"))
    check("invalid timing reported", kinds(audit.analyze({"cues": [{"start": 2, "end": 1, "text": "x"}]})).has("invalid_timing"))
    check("invalid cue reported", kinds(audit.analyze({"cues": [{"start": "bad", "end": 1, "text": "x"}]})).has("invalid_cue"))
    check("empty text reported", kinds(audit.analyze({"cues": [{"start": 0, "end": 2, "text": ""}]})).has("empty_text"))
    check("invalid options reported", kinds(audit.analyze({"cues": []}, {"max_cps": 0})).has("invalid_options"))
    check("missing file reported", kinds(audit.run("res://missing_subtitle_test.json")).has("input_error"))
    var nested: Dictionary = audit.analyze({"cues": [{"start": 2, "end": 3, "text": "b"}, {"start": 0, "end": 5, "text": "a"}, {"start": 3, "end": 4, "text": "c"}]})
    check("unsorted nested overlaps detected", kinds(nested).count("overlap") == 2)
    var srt: Dictionary = audit.run("res://demo/subtitles/overlap.srt")
    check("SRT fixture has two cues and overlap", srt["summary"]["cues"] == 2 and kinds(srt).has("overlap"))
    var vtt: Dictionary = audit.run("res://demo/subtitles/overlap.vtt")
    check("VTT fixture has two cues and overlap", vtt["summary"]["cues"] == 2 and kinds(vtt).has("overlap"))
    var multiline: Dictionary = audit.parse_timed_text("\ufeff1\r\n00:01:02,250 --> 00:01:04,500\r\nFirst line\r\nSecond line\r\n", "srt")
    check("SRT handles BOM CRLF multiline and hours", multiline["ok"] and multiline["cues"][0]["text"] == "First line\nSecond line" and absf(multiline["cues"][0]["start"] - 62.25) < 0.001)
    var hours: Dictionary = audit.parse_timed_text("WEBVTT\n\n00:01:02.250 --> 00:01:04.500 align:start\nHello\n", "vtt")
    check("VTT accepts hours and cue settings", hours["ok"] and absf(hours["cues"][0]["end"] - 64.5) < 0.001)
    check("bad timestamp rejected", not audit.parse_timed_text("1\n00:00:99,000 --> 00:01:00,000\nHello\n", "srt")["ok"])
    check("malformed second cue rejects entire file", not audit.parse_timed_text("1\n00:00:00,000 --> 00:00:02,000\nHello\n\n2\nbad timing\n", "srt")["ok"])
    check("VTT header required", not audit.parse_timed_text("00:00.000 --> 00:02.000\nHello", "vtt")["ok"])
    check("missing cue separator rejected", not audit.parse_timed_text("1\n00:00:00,000 --> 00:00:02,000\nHello\n00:00:03,000 --> 00:00:04,000\nWorld", "srt")["ok"])
    check("empty timed text rejected", not audit.parse_timed_text("WEBVTT\n\nNOTE only a note\n", "vtt")["ok"])
    check("end before start remains audit error", kinds(audit.analyze({"cues": audit.parse_timed_text("1\n00:00:02,000 --> 00:00:01,000\nHello", "srt")["cues"]})).has("invalid_timing"))
    var short_cue := {"cues": [{"start": 0.0, "end": 3.0, "text": "Hello there."}]}
    check("layout off by default", not kinds(audit.analyze(short_cue)).has("layout_overflow"))
    var lay := {"font_size": 32, "layout_width": 1920, "safe_area": 0.9, "max_lines": 2}
    check("short cue fits the rendered box", kinds(audit.analyze(short_cue, lay)).filter(func(k): return str(k).begins_with("layout")).is_empty())
    var m: Dictionary = audit.measure("Hello there.", audit._layout(lay))
    check("real font metrics measured", int(m["lines"]) == 1 and float(m["widest_word"]) > 10.0)
    var long_text := "This line keeps going far past what any reasonable subtitle box could hold at this size and it really should wrap onto several lines"
    var narrow := {"font_size": 32, "layout_width": 640, "safe_area": 0.9, "max_lines": 2}
    check("long cue overflows a narrow safe area", kinds(audit.analyze({"cues": [{"start": 0.0, "end": 9.0, "text": long_text}]}, narrow)).has("layout_overflow"))
    check("same cue fits a wide box with more lines allowed", not kinds(audit.analyze({"cues": [{"start": 0.0, "end": 9.0, "text": long_text}]}, {"font_size": 32, "layout_width": 3840, "safe_area": 1.0, "max_lines": 4})).has("layout_overflow"))
    check("explicit line breaks count", kinds(audit.analyze({"cues": [{"start": 0.0, "end": 6.0, "text": "a\nb\nc"}]}, lay)).has("layout_overflow"))
    check("unbreakable word wider than the box is clipped", kinds(audit.analyze({"cues": [{"start": 0.0, "end": 6.0, "text": "Pneumonoultramicroscopicsilicovolcanoconiosis"}]}, {"font_size": 48, "layout_width": 400, "safe_area": 0.9})).has("layout_clipped"))
    check("invalid safe area rejected", kinds(audit.analyze(short_cue, {"safe_area": 1.5})).has("invalid_options"))
    check("missing font rejected", kinds(audit.analyze(short_cue, {"font": "res://missing_font.ttf"})).has("invalid_options"))
    check("narrow box wraps the long cue to several lines", int(audit.measure(long_text, audit._layout(narrow))["lines"]) >= 3)
    check("markdown renders findings", audit.to_markdown(result).contains("overlap"))
    check("json parses", JSON.parse_string(audit.to_json(result)).has("issues"))
    print("Subtitle audit TESTS: %d passed, %d failed" % [passes, failures])
    quit(1 if failures else 0)
