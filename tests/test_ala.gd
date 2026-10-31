extends SceneTree
const Core := preload("res://addons/audio_levels/core/ala_auditor.gd")
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

func _count_path(result: Dictionary, kind: String, file: String) -> int:
    return result["issues"].filter(func(i): return i["kind"] == kind and str(i["path"]).ends_with(file)).size()

func _wav16(data: PackedByteArray) -> PackedByteArray:
    var b := PackedByteArray()
    b.append_array("RIFF".to_ascii_buffer())
    b.resize(8)
    b.encode_u32(4, 36 + data.size())
    b.append_array("WAVEfmt ".to_ascii_buffer())
    var f := PackedByteArray()
    f.resize(20)
    f.encode_u32(0, 16)
    f.encode_u16(4, 1)
    f.encode_u16(6, 1)
    f.encode_u32(8, 22050)
    f.encode_u32(12, 44100)
    f.encode_u16(16, 2)
    f.encode_u16(18, 16)
    b.append_array(f)
    b.append_array("data".to_ascii_buffer())
    var s := PackedByteArray()
    s.resize(4)
    s.encode_u32(0, data.size())
    b.append_array(s)
    b.append_array(data)
    return b

func _init() -> void:
    var result: Dictionary = op.run("res://demo/assets_audit")
    var click: Dictionary = result["files"]["res://demo/assets_audit/sfx/click.wav"]
    check("five WAVs decoded", result["summary"]["files"] == 5)
    check("half-scale tone peaks near -6 dBFS", absf(float(click["peak_db"]) + 6.02) < 0.1)
    check("sine RMS is 3 dB under peak", absf(float(click["rms_db"]) - float(click["peak_db"]) + 3.01) < 0.1)
    check("clipped file flagged", _count_path(result, "clipping", "boom_clipped.wav") == 1)
    check("whisper flagged as too quiet", _count_path(result, "too_quiet", "whisper.wav") == 1)
    check("rate outliers vs majority 22050", op._count(result, "rate_mismatch") == 2)
    check("non-WAV bytes reported", op.analyze({"res://x.wav": "hello".to_utf8_buffer()})["issues"][0]["kind"] == "unsupported_wav")
    var dc := PackedByteArray()
    for i in range(100):
        dc.append_array([0, 64])
    check("DC offset detected", op.analyze({"res://dc.wav": _wav16(dc)})["issues"].any(func(i): return i["kind"] == "dc_offset"))
    check("missing input is reported", op.run("res://definitely_missing_dir_ala")["issues"][0]["kind"] in ["scan_error", "bad_input"])
    var r: Dictionary = op.run("res://demo/assets_audit")
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Audio Loudness and Clipping Auditor TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
