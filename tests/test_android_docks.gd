extends SceneTree
## Exercise the new docks with real fixture inputs, not only their default error state.
const ExportDock := preload("res://addons/android_export_audit/ui/aea_dock.gd")
const TouchDock := preload("res://addons/android_touch_audit/ui/ata_dock.gd")
const LogDock := preload("res://addons/android_logcat_triage/ui/alt_dock.gd")
var passed := 0
var failed := 0


func check(label: String, ok: bool) -> void:
    if ok:
        passed += 1
        print("PASS  ", label)
    else:
        failed += 1
        print("FAIL  ", label)


func _initialize() -> void:
    _run.call_deferred()


func _run() -> void:
    var export_dock = ExportDock.new()
    root.add_child(export_dock)
    check("export dock controls have tooltips and keyboard focus", _untipped(export_dock).is_empty() and _unfocusable(export_dock).is_empty())
    var export_input: LineEdit = export_dock.get("_input")
    var history: LineEdit = export_dock.get("_history")
    var export_output: RichTextLabel = export_dock.get("_output")
    export_input.text = "res://demo/android_dev/export_presets.cfg"
    history.text = "res://demo/android_dev/release_history.json"
    export_dock.call("_on_run")
    check("export dock passes history to core", export_output.text.contains("version_not_increased") and export_output.text.contains("bundle_requires_gradle"))
    check("export dock does not display stored password", not export_output.text.contains("DEMO_SECRET_NOT_REAL"))
    export_input.text = "res://demo/android_dev/export_clean.cfg"
    history.text = ""
    export_dock.call("_on_run")
    check("export dock refreshes on clean input", not export_output.text.contains("version_not_increased") and export_output.text.contains("Clean Android"))
    root.remove_child(export_dock)
    export_dock.free()

    var touch_dock = TouchDock.new()
    root.add_child(touch_dock)
    check("touch dock controls have tooltips and keyboard focus", _untipped(touch_dock).is_empty() and _unfocusable(touch_dock).is_empty())
    var touch_input: LineEdit = touch_dock.get("_input")
    var min_dp: SpinBox = touch_dock.get("_min_dp")
    var gap_dp: SpinBox = touch_dock.get("_gap_dp")
    var touch_output: RichTextLabel = touch_dock.get("_output")
    touch_input.text = "res://demo/android_dev/touch_snapshot.json"
    min_dp.value = 20
    gap_dp.value = 0
    touch_dock.call("_on_run")
    check("touch dock applies relaxed thresholds", not touch_output.text.contains("small_target") and not touch_output.text.contains("close_targets") and touch_output.text.contains("overlap"))
    min_dp.value = 48
    gap_dp.value = 8
    touch_dock.call("_on_run")
    check("touch dock refreshes size, gap and safe-area findings", touch_output.text.contains("small_target") and touch_output.text.contains("close_targets") and touch_output.text.contains("outside_safe_area"))
    root.remove_child(touch_dock)
    touch_dock.free()

    var log_dock = LogDock.new()
    root.add_child(log_dock)
    check("logcat dock controls have tooltips and keyboard focus", _untipped(log_dock).is_empty() and _unfocusable(log_dock).is_empty())
    var log_input: LineEdit = log_dock.get("_input")
    var package: LineEdit = log_dock.get("_package")
    var log_output: RichTextLabel = log_dock.get("_output")
    log_input.text = "res://demo/android_dev/logcat.txt"
    package.text = "com.studio.game"
    log_dock.call("_on_run")
    check("logcat dock filters and displays groups", log_output.text.contains("java_crash") and log_output.text.contains("native_crash") and log_output.text.contains("anr") and not log_output.text.contains("com.other.app"))
    check("logcat dock omits raw fixture secrets", not log_output.text.contains("DO_NOT_COPY_THIS") and not log_output.text.contains("ANOTHER_PRIVATE_VALUE"))
    log_input.text = "res://demo/android_dev/logcat_clean.txt"
    package.text = ""
    log_dock.call("_on_run")
    check("logcat dock refreshes on a clean supported log", log_output.text.contains("no_matching_crashes") and not log_output.text.contains("java_crash"))
    root.remove_child(log_dock)
    log_dock.free()
    print("Android Dock TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)


func _untipped(node: Node) -> Array:
    var missing: Array = []
    if node is BaseButton or node is LineEdit or node is Range or node is TextEdit or node is ItemList or node is Tree:
        if node is Control and (node as Control).tooltip_text.strip_edges() == "" and not (node is ScrollBar):
            missing.append(node.name)
    for child in node.get_children():
        missing.append_array(_untipped(child))
    return missing


func _unfocusable(node: Node) -> Array:
    var missing: Array = []
    if node is SpinBox:
        if (node as SpinBox).get_line_edit().focus_mode == Control.FOCUS_NONE:
            missing.append(node.name)
    elif (node is BaseButton or node is LineEdit or node is Range or node is TextEdit or node is ItemList or node is Tree) and node is Control and (node as Control).focus_mode == Control.FOCUS_NONE:
        missing.append(node.name)
    for child in node.get_children():
        missing.append_array(_unfocusable(child))
    return missing
