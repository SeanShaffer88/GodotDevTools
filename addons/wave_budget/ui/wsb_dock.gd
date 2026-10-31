@tool
extends VBoxContainer
## Wave Spawner Budget Planner dock. Thin shell over core/; results are read-only findings.
const Core := preload("res://addons/wave_budget/core/wsb_planner.gd")
var _input: LineEdit
var _output: RichTextLabel

func _init() -> void:
    name = "Wave Budget"
    custom_minimum_size = Vector2(320, 260)
    var row := HBoxContainer.new()
    var label := Label.new()
    label.text = "Data file"
    label.tooltip_text = "JSON with waves and enemy_lifetime (seconds)."
    _input = LineEdit.new()
    _input.text = "res://demo/balance/waves.json"
    _input.tooltip_text = label.tooltip_text
    _input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(label)
    row.add_child(_input)
    add_child(row)
    var button := Button.new()
    button.text = "Plan waves"
    button.tooltip_text = "Simulate each wave and compare peaks with budgets. Read-only."
    button.pressed.connect(_on_run)
    add_child(button)
    _output = RichTextLabel.new()
    _output.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _output.selection_enabled = true
    _output.tooltip_text = "Summary, then each finding with its suggested fix. See the addon README for scope and limits."
    _output.text = "Plan wave budgets."
    add_child(_output)

func _on_run() -> void:
    var result: Dictionary = Core.new().run(_input.text.strip_edges(), {})
    var lines: Array[String] = ["Summary: " + str(result["summary"])]
    for issue in result["issues"]:
        lines.append("[%s] %s:%s - %s Fix: %s" % [issue["kind"], issue.get("path", ""), issue.get("line", "-"), issue["message"], issue["fix"]])
    _output.text = "\n".join(lines)
