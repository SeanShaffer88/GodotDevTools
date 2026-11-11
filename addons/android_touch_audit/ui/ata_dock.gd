@tool
extends VBoxContainer
## Snapshot viewer; geometry and checking live in core/ and runtime/.
const Core := preload("res://addons/android_touch_audit/core/ata_audit.gd")
var _input: LineEdit
var _min_dp: SpinBox
var _gap_dp: SpinBox
var _output: RichTextLabel


func _init() -> void:
    name = "Android Touch Audit"
    custom_minimum_size = Vector2(320, 260)
    var input_row := HBoxContainer.new()
    var input_label := Label.new()
    input_label.text = "Snapshot"
    _input = LineEdit.new()
    _input.text = "user://touch_snapshot.json"
    _input.tooltip_text = "A version 1 JSON snapshot captured by the runtime helper or measured manually."
    _input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    input_row.add_child(input_label)
    input_row.add_child(_input)
    add_child(input_row)
    _min_dp = _number_field("Minimum size (dp)", 48.0, 1.0, "Configurable minimum target width and height in logical dp; not a compliance guarantee.")
    _gap_dp = _number_field("Minimum gap (dp)", 8.0, 0.0, "Configurable minimum distance between target rectangles in dp; zero disables gap checks.")
    var button := Button.new()
    button.text = "Check touch snapshot"
    button.tooltip_text = "Compare resolved control rectangles with the captured safe area and dp thresholds."
    button.pressed.connect(_on_run)
    add_child(button)
    _output = RichTextLabel.new()
    _output.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _output.selection_enabled = true
    _output.tooltip_text = "Touch and safe-area findings. A snapshot is not a substitute for on-device testing."
    _output.text = "Capture or select a touch snapshot, then check it."
    add_child(_output)


func _number_field(label_text: String, value: float, minimum: float, tip: String) -> SpinBox:
    var row := HBoxContainer.new()
    var label := Label.new()
    label.text = label_text
    var spin := SpinBox.new()
    spin.min_value = minimum
    spin.max_value = 10000
    spin.step = 1
    spin.value = value
    spin.tooltip_text = tip
    spin.get_line_edit().tooltip_text = tip
    spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(label)
    row.add_child(spin)
    add_child(row)
    return spin


func _on_run() -> void:
    var result: Dictionary = Core.new().run(_input.text.strip_edges(), {"min_dp": _min_dp.value, "gap_dp": _gap_dp.value})
    var lines: Array[String] = ["Summary: " + str(result["summary"])]
    for issue in result["issues"]:
        lines.append("[%s] %s Fix: %s" % [issue["kind"], issue["message"], issue["fix"]])
    _output.text = "\n".join(lines)
