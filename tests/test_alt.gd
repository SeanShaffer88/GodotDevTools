extends SceneTree
const Core := preload("res://addons/android_logcat_triage/core/alt_triage.gd")
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


func count(result: Dictionary, kind: String) -> int:
    var n := 0
    for issue in result["issues"]:
        if issue["kind"] == kind:
            n += 1
    return n


func group_for(result: Dictionary, type: String, process: String = "") -> Dictionary:
    for group in result["groups"]:
        if group["type"] == type and (process == "" or group["process"] == process):
            return group
    return {}


func _init() -> void:
    var result: Dictionary = op.run("res://demo/android_dev/logcat.txt", {"package": "com.studio.game"})
    check("four matching records grouped into three signatures", result["summary"]["matched_records"] == 4 and result["summary"]["groups"] == 3)
    check("Java, native and ANR findings", count(result, "java_crash") == 1 and count(result, "native_crash") == 1 and count(result, "anr") == 1)
    var java: Dictionary = group_for(result, "java")
    check("Java messages and line-number changes group together", not java.is_empty() and java["count"] == 2 and java["exception"] == "java.lang.RuntimeException")
    check("cause and normalized frames retained", java.get("cause", "") == "java.lang.NullPointerException" and java.get("frames", []) == ["com.studio.game.MainActivity.resume", "com.studio.game.Player.load"])
    check("root-cause hint is actionable but provisional", str(java.get("hint", "")).contains("null"))
    var native: Dictionary = group_for(result, "native")
    check("native signal and process captured", native.get("signal", "") == "SIGSEGV" and native.get("process", "") == "com.studio.game")
    var anr: Dictionary = group_for(result, "anr")
    check("package filter includes colon-suffixed app processes", anr.get("process", "") == "com.studio.game:remote")
    check("unattributed and unsupported lines disclosed", count(result, "unattributed_crashes") == 1 and count(result, "unsupported_lines") == 1)
    check("raw log messages, paths and secrets excluded", not op.to_json(result).contains("DO_NOT_COPY_THIS") and not op.to_markdown(result).contains("ANOTHER_PRIVATE_VALUE") and not op.to_json(result).contains("MainActivity.java"))
    var all: Dictionary = op.run("res://demo/android_dev/logcat.txt")
    check("unfiltered records include unrelated and unattributed processes", all["summary"]["matched_records"] == 6 and all["summary"]["groups"] == 5)
    check("incomplete Java traces disclosed", count(all, "incomplete_java_trace") == 1)
    var missing: Dictionary = op.run("res://demo/android_dev/logcat.txt", {"package": "com.studio.game2"})
    check("package matching does not use a loose prefix", missing["summary"]["matched_records"] == 0 and count(missing, "no_matching_crashes") == 1)
    check("invalid package filter rejected", count(op.analyze("", {"package": "bad package"}), "bad_input") == 1)
    check("unsupported log format and missing input rejected", count(op.analyze("E/AndroidRuntime: FATAL EXCEPTION: main\n"), "bad_input") == 1 and count(op.run("res://missing_logcat.txt"), "bad_input") == 1)
    var empty_log := "11-11 13:00:00.000  120  120 I Godot: Application started\n"
    check("no recognized crash is informational, not proof of safety", count(op.analyze(empty_log), "no_matching_crashes") == 1)
    var interleaved := "\n".join([
        "11-11 13:00:00.000  100  100 E AndroidRuntime: FATAL EXCEPTION: main",
        "11-11 13:00:00.001  200  200 E AndroidRuntime: FATAL EXCEPTION: main",
        "11-11 13:00:00.002  100  100 E AndroidRuntime: Process: com.example.first, PID: 100",
        "11-11 13:00:00.003  200  200 E AndroidRuntime: Process: com.example.second, PID: 200",
        "11-11 13:00:00.004  100  100 E AndroidRuntime: java.lang.OutOfMemoryError: a",
        "11-11 13:00:00.005  200  200 E AndroidRuntime: java.lang.UnsatisfiedLinkError: b",
        "11-11 13:00:00.006  100  100 E AndroidRuntime:     at com.example.first.Main.run(Main.java:1)",
        "11-11 13:00:00.007  200  200 E AndroidRuntime:     at com.example.second.Main.run(Main.java:1)",
    ])
    var separate: Dictionary = op.analyze(interleaved)
    var first: Dictionary = group_for(separate, "java", "com.example.first")
    var second: Dictionary = group_for(separate, "java", "com.example.second")
    check("interleaved PIDs remain separate", first.get("exception", "") == "java.lang.OutOfMemoryError" and second.get("exception", "") == "java.lang.UnsatisfiedLinkError")
    check("OOM and missing native library hints differ", str(first.get("hint", "")).contains("memory") and str(second.get("hint", "")).contains("ABIs"))
    var generic: Dictionary = op.analyze(interleaved.replace("java.lang.OutOfMemoryError", "java.lang.Exception"))
    check("generic Exception class is recognized", group_for(generic, "java", "com.example.first").get("exception", "") == "java.lang.Exception")
    var long_log: Array[String] = ["11-11 13:00:00.000  100  100 E AndroidRuntime: FATAL EXCEPTION: main"]
    for i in 121:
        long_log.append("11-11 13:00:00.001  101  101 I Godot: unrelated")
    long_log.append("11-11 13:00:00.002  100  100 E AndroidRuntime: java.lang.SecurityException: too late")
    var bounded: Dictionary = op.analyze("\n".join(long_log))
    check("stale Java headers cannot absorb arbitrarily distant exception lines", str(group_for(bounded, "java").get("exception", "")) == "")
    var repeated: Array[String] = []
    for i in 5001:
        repeated.append("11-11 13:00:00.000  100  100 E AndroidRuntime: FATAL EXCEPTION: main")
    check("event limit is disclosed", count(op.analyze("\n".join(repeated)), "event_limit") == 1)
    var binary := "user://alt_binary_test.log"
    var file := FileAccess.open(binary, FileAccess.WRITE)
    file.store_buffer(PackedByteArray([0, 1, 2]))
    file.close()
    check("binary data quarantined", count(op.run(binary), "bad_input") == 1)
    var oversized := PackedByteArray()
    oversized.resize(10_000_001)
    file = FileAccess.open(binary, FileAccess.WRITE)
    file.store_buffer(oversized)
    file.close()
    var too_big: Dictionary = op.run(binary)
    check("oversize log is quarantined", count(too_big, "bad_input") == 1 and str(too_big["issues"][0]["message"]).contains("exceeds"))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(binary))
    check("JSON and Markdown render", JSON.parse_string(op.to_json(result)) is Dictionary and op.to_markdown(result).begins_with("# "))
    print("Android Logcat Triage TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
