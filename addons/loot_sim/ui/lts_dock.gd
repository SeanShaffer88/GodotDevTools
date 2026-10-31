@tool
extends VBoxContainer
## Loot Table and Economy Simulator dock. Thin shell over core/; results are read-only findings.
const Core := preload("res://addons/loot_sim/core/lts_simulator.gd")
var _input: LineEdit
var _output: RichTextLabel

func _init() -> void:
    name = "Loot Simulator"
    custom_minimum_size = Vector2(320, 260)
    var row := HBoxContainer.new()
    var label := Label.new()
    label.text = "Data file"
    label.tooltip_text = "JSON with a tables object (see README)."
    _input = LineEdit.new()
    _input.text = "res://demo/balance/loot.json"
    _input.tooltip_text = label.tooltip_text
    _input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(label)
    row.add_child(_input)
    add_child(row)
    var button := Button.new()
    button.text = "Simulate loot"
    button.tooltip_text = "Compute odds and run a seeded simulation of every table. Read-only."
    button.pressed.connect(_on_run)
    add_child(button)
    _output = RichTextLabel.new()
    _output.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _output.selection_enabled = true
    _output.tooltip_text = "Summary, then each finding with its suggested fix. See the addon README for scope and limits."
    _output.text = "Simulate loot tables; same seed, same result."
    add_child(_output)

func _on_run() -> void:
    var result: Dictionary = Core.new().run(_input.text.strip_edges(), {})
    var lines: Array[String] = ["Summary: " + str(result["summary"])]
    for issue in result["issues"]:
        lines.append("[%s] %s:%s - %s Fix: %s" % [issue["kind"], issue.get("path", ""), issue.get("line", "-"), issue["message"], issue["fix"]])
    _output.text = "\n".join(lines)
