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
    check("markdown renders findings", audit.to_markdown(result).contains("overlap"))
    check("json parses", JSON.parse_string(audit.to_json(result)).has("issues"))
    print("Subtitle audit TESTS: %d passed, %d failed" % [passes, failures])
    quit(1 if failures else 0)
