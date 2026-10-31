@tool
extends VBoxContainer
## Log Warning Budget Gate dock. Thin shell over core/; results are read-only findings.
const Core := preload("res://addons/log_budget/core/lbg_gate.gd")
var _input: LineEdit
var _output: RichTextLabel

func _init() -> void:
    name = "Log Budget"
    custom_minimum_size = Vector2(320, 260)
    var row := HBoxContainer.new()
    var label := Label.new()
    label.text = "Log file"
    label.tooltip_text = "A captured Godot output log."
    _input = LineEdit.new()
    _input.text = "res://demo/ci/logs/run.log"
    _input.tooltip_text = label.tooltip_text
    _input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(label)
    row.add_child(_input)
    add_child(row)
    var button := Button.new()
    button.text = "Check log budget"
    button.tooltip_text = "Compare error/warning counts and signatures with the baseline. Read-only."
    button.pressed.connect(_on_run)
    add_child(button)
    _output = RichTextLabel.new()
    _output.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _output.selection_enabled = true
    _output.tooltip_text = "Summary, then each finding with its suggested fix. See the addon README for scope and limits."
    _output.text = "Check a log against its baseline (dock baseline: res://log_baseline.json)."
    add_child(_output)

func _on_run() -> void:
    var result: Dictionary = Core.new().run(_input.text.strip_edges(), {})
    var lines: Array[String] = ["Summary: " + str(result["summary"])]
    for issue in result["issues"]:
        lines.append("[%s] %s:%s - %s Fix: %s" % [issue["kind"], issue.get("path", ""), issue.get("line", "-"), issue["message"], issue["fix"]])
    _output.text = "\n".join(lines)
