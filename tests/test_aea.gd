extends SceneTree
const Core := preload("res://addons/android_export_audit/core/aea_audit.gd")
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


func has(result: Dictionary, kind: String, preset: String = "") -> bool:
    for issue in result["issues"]:
        if issue["kind"] == kind and (preset == "" or issue.get("preset", "") == preset):
            return true
    return false


func preset(options: String) -> String:
    return "[preset.0]\nname=\"Test\"\nplatform=\"Android\"\nexport_path=\"build/test.apk\"\n[preset.0.options]\npackage/unique_name=\"com.studio.game\"\n" + options + "\n"


func _init() -> void:
    var result: Dictionary = op.run("res://demo/android_dev/export_presets.cfg", {"history": "res://demo/android_dev/release_history.json"})
    check("only three Android presets selected", result["summary"]["android_presets"] == 3)
    check("32-bit ARM without arm64 detected", has(result, "arm32_without_arm64", "Problem Android"))
    check("no ABI detected", has(result, "no_architecture", "No ABI"))
    check("invalid and example package detected", has(result, "invalid_package", "No ABI") and has(result, "example_package", "Problem Android") and has(op.analyze(preset("").replace("com.studio.game", "com.example")), "example_package"))
    check("invalid and non-incremented version codes detected", has(result, "invalid_version_code", "No ABI") and has(result, "version_not_increased", "Problem Android"))
    check("AAB requires Gradle and matching extension", has(result, "bundle_requires_gradle") and has(result, "format_extension_mismatch"))
    check("AAB with APK expansion rejected", has(result, "bundle_with_expansion"))
    check("unsigned preset and stored password flagged", has(result, "unsigned_package") and has(result, "embedded_password"))
    check("ineffective SDK overrides and wrong order flagged", has(result, "sdk_override_without_gradle") and has(result, "sdk_order"))
    var ready_clean := true
    for issue in result["issues"]:
        if issue.get("preset", "") == "Ready Android":
            ready_clean = false
    check("ready preset has no findings", ready_clean)
    check("secret not printed in reports", not op.to_json(result).contains("DEMO_SECRET_NOT_REAL") and not op.to_markdown(result).contains("DEMO_SECRET_NOT_REAL"))
    var clean: Dictionary = op.analyze(preset("version/code=2"), {"com.studio.game": 1})
    check("default arm64 ABI and clean preset", clean["issues"].is_empty() and clean["presets"][0]["abis"] == ["arm64-v8a"])
    check("no history comparison unless supplied", not has(op.analyze(preset("version/code=1")), "history_missing"))
    check("unlisted history is reported", has(op.analyze(preset("version/code=1"), {}), "history_missing"))
    check("invalid history is rejected", has(op.analyze(preset(""), {"com.studio.game": -1}), "bad_input"))
    check("missing history is rejected", has(op.run("res://demo/android_dev/export_presets.cfg", {"history": "res://missing_history.json"}), "bad_input"))
    check("invalid ABI and booleans are not guessed", has(op.analyze(preset("architectures/arm64-v8a=\"false\"\ngradle_build/use_gradle_build=\"false\"")), "invalid_architecture") and has(op.analyze(preset("package/signed=\"true\"")), "invalid_option"))
    check("unknown export format detected", has(op.analyze(preset("gradle_build/export_format=8")), "invalid_format"))
    check("invalid SDK override detected", has(op.analyze(preset("gradle_build/min_sdk=\"not-a-number\"")), "invalid_sdk"))
    check("Godot 4.3 minimum SDK enforced", has(op.analyze(preset("gradle_build/use_gradle_build=true\ngradle_build/min_sdk=\"20\"")), "min_sdk_too_low"))
    check("target compared with default minimum", has(op.analyze(preset("gradle_build/use_gradle_build=true\ngradle_build/target_sdk=\"23\"")), "sdk_order"))
    check("placeholder package is accepted provisionally", not has(op.analyze(preset("").replace("com.studio.game", "com.studio.$genname")), "invalid_package"))
    check("non-Android configs are not errors", has(op.analyze("[preset.0]\nplatform=\"Linux\"\n"), "no_android_preset"))
    check("missing input reported", has(op.run("res://missing_android_preset.cfg"), "bad_input"))
    var binary := "user://aea_binary_test.cfg"
    var file := FileAccess.open(binary, FileAccess.WRITE)
    file.store_buffer(PackedByteArray([0, 1, 2]))
    file.close()
    check("binary presets and history are quarantined", has(op.run(binary), "bad_input") and has(op.run("res://demo/android_dev/export_clean.cfg", {"history": binary}), "bad_input"))
    file = FileAccess.open(binary, FileAccess.WRITE)
    file.store_string("{\"com.studio.game\":")
    file.close()
    check("malformed history JSON is rejected", has(op.run("res://demo/android_dev/export_clean.cfg", {"history": binary}), "bad_input"))
    var oversized := PackedByteArray()
    oversized.resize(2_000_001)
    file = FileAccess.open(binary, FileAccess.WRITE)
    file.store_buffer(oversized)
    file.close()
    var too_big: Dictionary = op.run(binary)
    check("oversize preset file is quarantined", has(too_big, "bad_input") and str(too_big["issues"][0]["message"]).contains("exceeds"))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(binary))
    check("JSON parses and Markdown renders", JSON.parse_string(op.to_json(result)) is Dictionary and op.to_markdown(result).begins_with("# "))
    print("Android Export Audit TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
