extends SceneTree
const Core := preload("res://addons/android_touch_audit/core/ata_audit.gd")
const Capture := preload("res://addons/android_touch_audit/runtime/ata_capture.gd")
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


func _initialize() -> void:
    _run_tests.call_deferred()


func _run_tests() -> void:
    var result: Dictionary = op.run("res://demo/android_dev/touch_snapshot.json")
    check("six targets and five comparable rectangles", result["summary"]["targets"] == 6 and result["summary"]["measured"] == 5)
    check("small logical-dp target found", count(result, "small_target") == 1 and str(result["issues"]).contains("35.0 x 35.0"))
    check("unsafe target found", count(result, "outside_safe_area") == 1)
    check("nearby and overlapping pairs distinguished", count(result, "close_targets") == 1 and count(result, "overlap") == 1)
    var pair_message := ""
    for issue in result["issues"]:
        if issue["kind"] == "overlap":
            pair_message = str(issue["message"])
    check("generic report consumers can identify both overlapping targets", pair_message.contains("/Game/Menu/Close") and pair_message.contains("/Game/Menu/Overlap"))
    check("rotated rectangle not treated as measured hit area", count(result, "unsupported_transform") == 1)
    var relaxed: Dictionary = op.run("res://demo/android_dev/touch_snapshot.json", {"min_dp": 20.0, "gap_dp": 0.0})
    check("thresholds are configurable and gap can be disabled", count(relaxed, "small_target") == 0 and count(relaxed, "close_targets") == 0 and count(relaxed, "overlap") == 1)
    var clean: Dictionary = op.run("res://demo/android_dev/touch_clean.json")
    check("clean fixture has no findings", clean["issues"].is_empty())
    var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://demo/android_dev/touch_clean.json"))
    data["targets"].reverse()
    check("findings deterministic regardless of input target order", op.to_json(op.analyze(data)) == op.to_json(clean))
    var edge := {"version": 1, "screen": {"size_px": [100, 100], "safe_area_px": [0, 0, 100, 100], "density_dpi": 160}, "targets": [{"path": "a", "rect_px": [0, 0, 48, 48]}, {"path": "b", "rect_px": [48, 0, 48, 48]}]}
    var boundary: Dictionary = op.analyze(edge)
    check("exact size and safe-area edges pass", count(boundary, "small_target") == 0 and count(boundary, "outside_safe_area") == 0)
    check("touching rectangles are close, not overlapping", count(boundary, "close_targets") == 1 and count(boundary, "overlap") == 0)
    edge["targets"][0]["axis_aligned"] = false
    edge["targets"][0]["rect_px"] = [-100, -100, 1, 1]
    var unknown: Dictionary = op.analyze(edge)
    check("unsupported transform suppresses misleading geometry findings", count(unknown, "unsupported_transform") == 1 and count(unknown, "outside_safe_area") == 0 and count(unknown, "small_target") == 0)
    check("unknown schema rejected", count(op.analyze({"version": 2, "screen": {}, "targets": []}), "bad_input") == 1)
    check("invalid density and thresholds rejected", count(op.analyze({"version": 1, "screen": {"size_px": [100, 100], "safe_area_px": [0, 0, 100, 100], "density_dpi": 0}, "targets": []}), "bad_input") == 1 and count(op.analyze(data, {"min_dp": -1}), "bad_input") == 1)
    var duplicate: Dictionary = data.duplicate(true)
    duplicate["targets"].append(duplicate["targets"][0].duplicate(true))
    check("duplicate paths rejected", count(op.analyze(duplicate), "bad_input") == 1)
    var outside: Dictionary = data.duplicate(true)
    outside["screen"]["safe_area_px"] = [0, 0, 500, 800]
    check("safe area outside screen rejected", count(op.analyze(outside), "bad_input") == 1)
    var empty: Dictionary = data.duplicate(true)
    empty["targets"] = []
    check("empty snapshot reports no targets", count(op.analyze(empty), "no_targets") == 1)
    empty["capture"] = {"skipped_other_viewport": 2}
    check("skipped viewport count is disclosed", count(op.analyze(empty), "viewport_targets_skipped") == 1)
    empty["capture"]["skipped_other_viewport"] = -1
    check("invalid capture metadata rejected", count(op.analyze(empty), "bad_input") == 1)
    var many: Dictionary = data.duplicate(true)
    many["targets"] = []
    for i in 65:
        many["targets"].append({"path": "target%03d" % i, "rect_px": [100, 100, 60, 60]})
    var limited: Dictionary = op.analyze(many)
    check("pair finding limit is disclosed", count(limited, "overlap") == 2000 and count(limited, "pair_findings_truncated") == 1)
    for i in range(65, 501):
        many["targets"].append({"path": "target%03d" % i, "rect_px": [100, 100, 60, 60]})
    check("oversize target list rejected rather than partially scanned", count(op.analyze(many), "bad_input") == 1)
    check("missing snapshot reported", count(op.run("res://missing_touch_snapshot.json"), "bad_input") == 1)
    var binary := "user://ata_binary_test.json"
    var file := FileAccess.open(binary, FileAccess.WRITE)
    file.store_buffer(PackedByteArray([0, 1, 2]))
    file.close()
    check("binary snapshots are quarantined", count(op.run(binary), "bad_input") == 1)
    file = FileAccess.open(binary, FileAccess.WRITE)
    file.store_string("{\"targets\":")
    file.close()
    check("malformed JSON snapshot rejected", count(op.run(binary), "bad_input") == 1)
    var oversized := PackedByteArray()
    oversized.resize(5_000_001)
    file = FileAccess.open(binary, FileAccess.WRITE)
    file.store_buffer(oversized)
    file.close()
    var too_big: Dictionary = op.run(binary)
    check("oversize snapshot file is quarantined", count(too_big, "bad_input") == 1 and str(too_big["issues"][0]["message"]).contains("exceeds"))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(binary))
    check("JSON and Markdown render", JSON.parse_string(op.to_json(result)) is Dictionary and op.to_markdown(result).begins_with("# "))
    _capture_tests()
    print("Android Touch Audit TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)


func _capture_tests() -> void:
    var capture = Capture.new()
    var box: Rect2 = capture._bounds(Transform2D(Vector2(2, 0), Vector2(0, 3), Vector2(10, 20)), Vector2(5, 6))
    check("capture transforms all corners with scale and translation", box == Rect2(10, 20, 10, 18))
    var scene := Node2D.new()
    scene.name = "TouchCaptureTest"
    root.add_child(scene)
    scene.position = Vector2(10, 20)
    scene.scale = Vector2(2, 2)
    var button := Button.new()
    button.name = "Go"
    scene.add_child(button)
    button.position = Vector2(20, 30)
    button.size = Vector2(60, 50)
    var custom := Control.new()
    custom.name = "Custom"
    custom.add_to_group("touch_target")
    scene.add_child(custom)
    custom.size = Vector2(60, 60)
    var rotated := Button.new()
    rotated.name = "Rotated"
    scene.add_child(rotated)
    rotated.rotation = PI / 4.0
    rotated.size = Vector2(70, 70)
    var disabled := Button.new()
    disabled.name = "Disabled"
    disabled.disabled = true
    scene.add_child(disabled)
    var hidden := Button.new()
    hidden.name = "Hidden"
    hidden.visible = false
    scene.add_child(hidden)
    var ignored := Button.new()
    ignored.name = "Ignored"
    ignored.mouse_filter = Control.MOUSE_FILTER_IGNORE
    scene.add_child(ignored)
    var sub := SubViewport.new()
    scene.add_child(sub)
    var sub_button := Button.new()
    sub_button.name = "SubButton"
    sub.add_child(sub_button)
    var metrics := {"screen": {"size_px": [1000, 1000], "safe_area_px": [0, 0, 1000, 1000], "density_dpi": 160}, "window_offset_px": [0, 0]}
    var snapshot: Dictionary = capture.capture(scene, metrics)
    if not snapshot.has("targets") or not snapshot.has("capture"):
        check("capture returns a valid snapshot for an active tree", false)
        scene.free()
        return
    var names: Array = []
    var rotated_marked := false
    var go_rect := Rect2()
    for target in snapshot["targets"]:
        names.append(str(target["path"]).get_file())
        if str(target["path"]).ends_with("/Rotated"):
            rotated_marked = not target["axis_aligned"]
        if str(target["path"]).ends_with("/Go"):
            var r: Array = target["rect_px"]
            go_rect = Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
    var expected: Rect2 = capture._bounds(root.get_screen_transform() * Transform2D(0.0, Vector2(50, 80)), Vector2(120, 100))
    check("capture applies parent translation and scale before viewport transform", go_rect.position.is_equal_approx(expected.position) and go_rect.size.is_equal_approx(expected.size))
    check("capture includes enabled buttons and opt-in controls", "Go" in names and "Custom" in names)
    check("capture excludes disabled, hidden and ignored controls", "Disabled" not in names and "Hidden" not in names and "Ignored" not in names)
    check("capture flags rotation and skips other viewports", rotated_marked and "SubButton" not in names and snapshot["capture"]["skipped_other_viewport"] == 1)
    var saved := "user://ata_test_snapshot.json"
    check("capture writes only on explicit request", capture.save_snapshot(snapshot, saved) == OK and JSON.parse_string(FileAccess.get_file_as_string(saved)) is Dictionary)
    DirAccess.remove_absolute(ProjectSettings.globalize_path(saved))
    scene.free()
