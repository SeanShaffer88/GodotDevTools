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
    check("markdown renders findings", audit.to_markdown(result).contains("overlap"))
    check("json parses", JSON.parse_string(audit.to_json(result)).has("issues"))
    print("Subtitle audit TESTS: %d passed, %d failed" % [passes, failures])
    quit(1 if failures else 0)
