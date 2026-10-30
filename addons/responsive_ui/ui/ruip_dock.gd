## Responsive UI Previewer - editor dock.
@tool
extends VBoxContainer

const Evaluator := preload("res://addons/responsive_ui/core/ruip_evaluator.gd")

var _results: RichTextLabel


func _init() -> void:
    name = "Responsive UI Previewer"
    custom_minimum_size = Vector2(320, 200)
    var title := Label.new()
    title.text = "Responsive UI Previewer"
    title.tooltip_text = "Preview a UI across common screen sizes, aspect ratios, safe areas and stretch settings, directly inside the editor."
    add_child(title)
    var run_btn := Button.new()
    run_btn.text = "Run check"
    run_btn.tooltip_text = "Run the Responsive UI Previewer check on this project and list the results below."
    run_btn.pressed.connect(_on_run)
    add_child(run_btn)
    var help_btn := Button.new()
    help_btn.text = "?"
    help_btn.tooltip_text = "Show plain-words help for this tool."
    help_btn.pressed.connect(func() -> void: _results.text = HELP_TEXT)
    add_child(help_btn)
    _results = RichTextLabel.new()
    _results.fit_content = true
    _results.custom_minimum_size = Vector2(320, 300)
    _results.tooltip_text = "Results of the last run. Run the check to fill this in."
    add_child(_results)
    _results.text = "Press Run check."


const HELP_TEXT := "Run replays every UI scene in the project against 9 screen sizes (desktop, laptop, phones with notch safe areas, tablet, ultrawide, Steam Deck) using the project's real stretch settings from project.godot. Controls that land outside a safe area or shrink below 24 px are listed with the screen size that breaks them."


func _on_run() -> void:
    var result: Dictionary = _run_check()
    var lines: Array[String] = []
    var s: Dictionary = result.get("summary", {})
    lines.append("Summary: " + str(s))
    var issues: Array = result.get("issues", [])
    if issues.is_empty():
        lines.append("No problems found.")
    for i in issues:
        lines.append("[%s] %s" % [i.get("severity", "info"), i.get("message", "")])
        if i.get("fix", "") != "":
            lines.append("  Fix: " + str(i["fix"]))
    var results_list: Array = result.get("results", [])
    for r in results_list:
        lines.append("%s - %s" % [r.get("path", ""), "; ".join(r.get("reasons", []))])
    _results.text = "\n".join(lines)


func _run_check() -> Dictionary:
    var op = Evaluator.new()
    return op.evaluate_project()
