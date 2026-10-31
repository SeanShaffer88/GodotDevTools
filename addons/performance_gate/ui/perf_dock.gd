@tool
extends VBoxContainer
const Compare := preload("res://addons/performance_gate/core/perf_compare.gd")
var _baseline: LineEdit
var _current: LineEdit
var _output: RichTextLabel

func _init() -> void:
    name = "Performance Gate"
    custom_minimum_size = Vector2(320, 250)
    _baseline = LineEdit.new()
    _baseline.text = "res://demo/performance/baseline.json"
    _baseline.tooltip_text = "Reviewed benchmark baseline JSON path."
    add_child(_baseline)
    _current = LineEdit.new()
    _current.text = "res://demo/performance/current.json"
    _current.tooltip_text = "Current benchmark measurement JSON path."
    add_child(_current)
    var button := Button.new()
    button.text = "Compare benchmarks"
    button.tooltip_text = "Compare supplied measurements; this does not run benchmarks."
    button.pressed.connect(_on_run)
    add_child(button)
    _output = RichTextLabel.new()
    _output.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _output.text = "Choose baseline and current measurements to compare."
    add_child(_output)

func _on_run() -> void:
    var result: Dictionary = Compare.new().run(_baseline.text, _current.text)
    var lines: Array[String] = ["Summary: " + str(result["summary"])]
    for row in result["comparisons"]:
        lines.append("%s: %s → %s %s (allowance %s)" % [row["metric"], row["baseline"], row["current"], row["unit"], row["allowance"]])
    for issue in result["issues"]:
        lines.append("[%s] %s — %s" % [issue["kind"], issue["path"], issue["message"]])
    _output.text = "\n".join(lines)
