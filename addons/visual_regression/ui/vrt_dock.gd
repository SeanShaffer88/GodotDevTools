## Visual Regression Testing - editor dock.
@tool
extends VBoxContainer

const Baselines := preload("res://addons/visual_regression/core/vrt_baselines.gd")
const Review := preload("res://addons/visual_regression/core/vrt_review.gd")
const Capture := preload("res://addons/visual_regression/core/vrt_capture.gd")

var _results: RichTextLabel
var _scenes_edit: LineEdit
var _out_edit: LineEdit
var _capture_btn: Button


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
    var cap_title := Label.new()
    cap_title.text = "Capture"
    cap_title.tooltip_text = "One-click shutter: save fresh screenshots of scenes at the standard resolutions, named for the compare run."
    add_child(cap_title)
    _scenes_edit = LineEdit.new()
    _scenes_edit.placeholder_text = "res://path/scene.tscn, res://other.tscn"
    _scenes_edit.tooltip_text = "Comma-separated scene paths to capture. Leave empty to capture the project's main scene."
    add_child(_scenes_edit)
    _out_edit = LineEdit.new()
    _out_edit.text = "res://visual_current"
    _out_edit.tooltip_text = "Folder the captures are written to. The compare run reads this folder as 'current'."
    add_child(_out_edit)
    _capture_btn = Button.new()
    _capture_btn.text = "Capture now"
    _capture_btn.tooltip_text = "Instantiate each scene offscreen at every standard resolution, let it settle, and save the PNGs. Needs the editor's renderer - it never runs headless."
    _capture_btn.pressed.connect(_on_capture)
    add_child(_capture_btn)
    _results = RichTextLabel.new()
    _results.fit_content = true
    _results.custom_minimum_size = Vector2(320, 300)
    _results.tooltip_text = "Results of the last run. Run the check to fill this in."
    add_child(_results)
    _results.text = "Press Run check."


const HELP_TEXT := "Capture: list scene paths (comma-separated; empty = the main scene), set the output folder, press Capture now - each scene is instantiated offscreen at the standard resolutions and saved as <scene>__<width>x<height>.png. Compare: put approved screenshots in res://visual_baselines with the same names and press Run check. Failing pairs differ from the approved picture; the CLI writes a highlight image per failure (changed pixels in magenta). Approve a change by copying the capture over the baseline."


func _on_run() -> void:
    var result: Dictionary = _run_check()
    _show(result)
    var queue: Dictionary = Review.new().build(result, "res://visual_baselines", "res://visual_current")
    _results.text += "\nReview queue: %d item(s); use the CLI to save and record decisions." % queue["items"].size()


func _on_capture() -> void:
    var scenes: Array = []
    for part in _scenes_edit.text.split(","):
        var p := part.strip_edges()
        if p != "":
            scenes.append(p)
    if scenes.is_empty():
        var main := str(ProjectSettings.get_setting("application/run/main_scene", ""))
        if main == "":
            _results.text = "List at least one scene path, or set a main scene in Project Settings."
            return
        scenes.append(main)
    _capture_btn.disabled = true
    _results.text = "Capturing %d scene(s)..." % scenes.size()
    var cap = Capture.new()
    var report: Dictionary = await cap.run_captures(self, scenes, _out_edit.text.strip_edges())
    _capture_btn.disabled = false
    _show(report)


func _show(result: Dictionary) -> void:
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
    for w in result.get("written", []):
        lines.append("Wrote " + str(w))
    _results.text = "\n".join(lines)


func _run_check() -> Dictionary:
    var op = Baselines.new()
    return op.run_suite("res://visual_baselines", "res://visual_current")
