## Visual Regression Testing - editor dock.
@tool
extends VBoxContainer

const Baselines := preload("res://addons/visual_regression/core/vrt_baselines.gd")

var _results: RichTextLabel


func _init() -> void:
    name = "Visual Regression Testing"
    custom_minimum_size = Vector2(320, 200)
    var title := Label.new()
    title.text = "Visual Regression Testing"
    title.tooltip_text = "Capture scene screenshots across resolutions and compare them with approved baselines, highlighting pixel-level differences."
    add_child(title)
    var run_btn := Button.new()
    run_btn.text = "Run check"
    run_btn.tooltip_text = "Run the Visual Regression Testing check on this project and list the results below."
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


const HELP_TEXT := "Put approved screenshots in res://visual_baselines named <scene>__<width>x<height>.png and fresh captures in res://visual_current with the same names, then Run. Failing pairs differ from the approved picture; the CLI writes a highlight image per failure (changed pixels in magenta). Approve a change by copying the capture over the baseline."


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
    var op = Baselines.new()
    return op.run_suite("res://visual_baselines", "res://visual_current")
