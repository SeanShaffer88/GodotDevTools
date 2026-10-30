## Automated Accessibility Checker - editor dock.
@tool
extends VBoxContainer

const Checker := preload("res://addons/accessibility/core/a11y_checker.gd")

var _results: RichTextLabel


func _init() -> void:
    name = "Automated Accessibility Checker"
    custom_minimum_size = Vector2(320, 200)
    var title := Label.new()
    title.text = "Automated Accessibility Checker"
    title.tooltip_text = "Detect tiny text, low contrast, missing keyboard navigation and controls that rely only on colour."
    add_child(title)
    var run_btn := Button.new()
    run_btn.text = "Run check"
    run_btn.tooltip_text = "Run the Automated Accessibility Checker check on this project and list the results below."
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


const HELP_TEXT := "Run checks every scene: text under 14 px, text/background contrast under 4.5:1 (the WCAG formula), interactive controls that cannot take keyboard focus, and status indicators that may communicate by colour alone. Contrast is measured against a dark theme background; if your game is light-themed, set assumed_background in the checker."


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
    var op = Checker.new()
    return op.scan()
