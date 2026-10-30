## Build and Export Doctor - editor dock.
@tool
extends VBoxContainer

const Doctor := preload("res://addons/export_doctor/core/bed_doctor.gd")

var _results: RichTextLabel


func _init() -> void:
    name = "Build and Export Doctor"
    custom_minimum_size = Vector2(320, 200)
    var title := Label.new()
    title.text = "Build and Export Doctor"
    title.tooltip_text = "Diagnose export failures and configuration mistakes, explain likely causes, and suggest targeted fixes before a release build."
    add_child(title)
    var run_btn := Button.new()
    run_btn.text = "Run check"
    run_btn.tooltip_text = "Run the Build and Export Doctor check on this project and list the results below."
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


const HELP_TEXT := "Run before every release build. It checks the main scene, icon and autoload paths, that every script loads, the export presets (paths, icons), whether export templates for this engine version are installed, and project feature tags. Every problem comes with its likely cause and a targeted fix in plain words."


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
    var op = Doctor.new()
    return op.diagnose()
