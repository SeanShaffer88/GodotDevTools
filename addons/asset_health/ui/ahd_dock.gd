## Asset Health Dashboard - editor dock.
@tool
extends VBoxContainer

const Scanner := preload("res://addons/asset_health/core/ahd_scanner.gd")

var _results: RichTextLabel


func _init() -> void:
    name = "Asset Health Dashboard"
    custom_minimum_size = Vector2(320, 200)
    var title := Label.new()
    title.text = "Asset Health Dashboard"
    title.tooltip_text = "Find oversized textures, duplicate files, unused resources, import-setting inconsistencies and assets that may hurt loading times."
    add_child(title)
    var run_btn := Button.new()
    run_btn.text = "Run check"
    run_btn.tooltip_text = "Run the Asset Health Dashboard check on this project and list the results below."
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


const HELP_TEXT := "Run scans every file in the project: textures over 2048x2048 (with estimated video memory), byte-identical duplicates, files nothing references, import settings that differ between files of the same kind, and very large files that stall loading. Files under addons/ are tooling and are skipped."


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
    var op = Scanner.new()
    return op.scan()
