extends SceneTree
const Core := preload("res://addons/audio_import/core/aia_auditor.gd")
var op = Core.new()
var passed := 0
var failed := 0

func check(label: String, ok: bool) -> void:
    if ok:
        passed += 1
        print("PASS  ", label)
    else:
        failed += 1
        print("FAIL  ", label)

func _has(result: Dictionary, kind: String, line: int) -> bool:
    for issue in result["issues"]:
        if issue["kind"] == kind and int(issue["line"]) == line:
            return true
    return false

func _init() -> void:
    var result: Dictionary = op.run("res://demo/assets_audit", {"max_wav_seconds": 1.0})
    check("five audio imports read", result["summary"]["clips"] == 5)
    check("theme music not looping", op._count(result, "music_not_looping") == 1)
    check("2 s theme is a long WAV at a 1 s limit", op._count(result, "long_wav") == 1)
    check("default 10 s limit quiet", op._count(op.run("res://demo/assets_audit"), "long_wav") == 0)
    var ogg: Dictionary = op.analyze({"res://a/sfx/wind.ogg.import": "[params]\nloop=true\n", "res://a/music/m.ogg.import": "[params]\nloop=true\n"})
    check("looping effect flagged, looping music fine", op._count(ogg, "sfx_looping") == 1 and op._count(ogg, "music_not_looping") == 0)
    var wav_loop: Dictionary = op.analyze({"res://a/music/x.wav.import": "[params]\nedit/loop_mode=0\n"}, {"sources": {"res://a/music/x.wav": {"seconds": 1.0, "has_loop": true}}})
    check("detect mode honours WAV loop points", op._count(wav_loop, "music_not_looping") == 0)
    check("missing input is reported", op.run("res://definitely_missing_dir_aia")["issues"][0]["kind"] in ["scan_error", "bad_input"])
    var r: Dictionary = op.run("res://demo/assets_audit")
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Audio Import Settings Auditor TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
