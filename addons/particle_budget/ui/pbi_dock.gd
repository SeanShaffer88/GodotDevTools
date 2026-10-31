@tool
extends VBoxContainer
const Core := preload("res://addons/particle_budget/core/pbi_scanner.gd")
var _scene_budget: SpinBox
var _emitter_budget: SpinBox
var _output: RichTextLabel

func _init() -> void:
    name = "Particle Budget"
    custom_minimum_size = Vector2(320, 260)
    _scene_budget = _row("Scene budget", Core.DEFAULT_BUDGET["max_scene"], "Maximum particles a scene may hold at once if every emitter (including instanced children) is active.")
    _emitter_budget = _row("Emitter budget", Core.DEFAULT_BUDGET["max_emitter"], "Maximum particles a single emitter may hold.")
    var button := Button.new()
    button.text = "Scan particle budgets"
    button.tooltip_text = "Read every .tscn under res:// (addons and reports skipped) and total emitter capacity. Read-only; numbers are scene-property capacities, not live counts."
    button.pressed.connect(_on_run)
    add_child(button)
    _output = RichTextLabel.new()
    _output.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _output.selection_enabled = true
    _output.tooltip_text = "Per-scene worst case and always-on capacity, then findings with a suggested fix."
    _output.text = "Scan to total particle capacity per scene. See the addon README for scope."
    add_child(_output)

func _row(label_text: String, value: int, tip: String) -> SpinBox:
    var row := HBoxContainer.new()
    var label := Label.new()
    label.text = label_text
    label.tooltip_text = tip
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var spin := SpinBox.new()
    spin.min_value = 1
    spin.max_value = 10000000
    spin.value = value
    spin.tooltip_text = tip
    row.add_child(label)
    row.add_child(spin)
    add_child(row)
    return spin

func _on_run() -> void:
    var budget := {"max_scene": int(_scene_budget.value), "max_emitter": int(_emitter_budget.value)}
    var result: Dictionary = Core.new().run("res://", budget)
    var lines: Array[String] = ["Summary: " + str(result["summary"])]
    for scene in result["scenes"]:
        lines.append("%s - worst case %d, always on %d (%d emitters)" % [scene["path"], scene["worst_case"], scene["always_on"], scene["emitters"].size()])
    for issue in result["issues"]:
        lines.append("[%s] %s %s - %s Fix: %s" % [issue["kind"], issue["path"], issue["node"], issue["message"], issue["fix"]])
    _output.text = "\n".join(lines)
