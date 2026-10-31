## Mobile Thermal and Battery Drain Emulation Dock - editor dock.
## Hand-built (not the uniform template) because it carries a device
## profile picker: the whole point of the dock is comparing one workload
## across estimated devices, so the profile is a visible choice, not a
## buried default.
@tool
extends VBoxContainer

const Core := preload("res://addons/thermal_sim/core/thm_model.gd")

var _results: RichTextLabel
var _profiles: OptionButton
var _workload_path := LineEdit.new()


func _init() -> void:
    name = "Mobile Thermal and Battery Drain Emulation Dock"
    custom_minimum_size = Vector2(320, 200)
    var title := Label.new()
    title.text = "Mobile Thermal and Battery Drain Emulation Dock"
    title.tooltip_text = "Documented-estimate RC thermal model, frame-budget and battery-hours comparisons across workload changes."
    add_child(title)
    var estimate := Label.new()
    estimate.text = "ESTIMATES for comparing changes - not device measurements."
    estimate.tooltip_text = "Every device number in this dock is a documented guess. Use it to rank optimizations on the same guessed hardware, never as an absolute prediction."
    add_child(estimate)
    _profiles = OptionButton.new()
    _profiles.tooltip_text = "Estimated device profile to simulate against."
    for profile in Core.PROFILES:
        _profiles.add_item(str(profile))
    add_child(_profiles)
    _workload_path.text = "res://demo/thermal/workload.json"
    _workload_path.tooltip_text = "Workload JSON: {profile, timeline: [{dt_s, cpu, gpu, fps}]} sampled per second."
    add_child(_workload_path)
    var run_btn := Button.new()
    run_btn.text = "Simulate"
    run_btn.tooltip_text = "Run the thermal simulation for the selected profile and show the estimate below."
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
    _results.tooltip_text = "Results of the last simulation. Pick a profile and press Simulate."
    add_child(_results)
    _results.text = "Pick a device profile and press Simulate."


const HELP_TEXT := "A documented estimate, not a measurement - no device farm here, and this dock says so. An RC thermal circuit per estimated device profile integrates power over your workload timeline; the report gives time-to-throttle, frame-budget misses and battery-hours. The value is comparative: run it before and after an optimization on the same guessed hardware and the ranking of changes is meaningful even when absolute numbers are not. Edit the workload JSON to describe a scene: one sample per second with cpu and gpu load from 0 to 1 and the achieved fps."


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
    var timeline: Array = result.get("timeline", [])
    var shown := 0
    for row in timeline:
        if shown >= 40:
            lines.append("... %d more timeline row(s)" % (timeline.size() - 40))
            break
        lines.append("timeline: " + str(row))
        shown += 1
    _results.text = "\n".join(lines)


func _run_check() -> Dictionary:
    var op = Core.new()
    var path := _workload_path.text.strip_edges()
    if not FileAccess.file_exists(path):
        return {"summary": {"profile": "", "samples": 0, "peak_temp_c": 0.0,
                "throttle_at_s": -1, "avg_watts": 0.0, "battery_hours": 0.0,
                "budget_broken": 0, "issues": 1}, "timeline": [],
            "issues": [{"severity": "error", "kind": "missing_file", "path": path,
                "message": "Workload not found: %s" % path,
                "fix": "Point the field at a workload JSON; demo/thermal/workload.json ships with the repo."}]}
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
    var cfg: Dictionary = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
    var profile := str(cfg.get("profile", "mid_android_estimate"))
    if _profiles.selected >= 0:
        profile = _profiles.get_item_text(_profiles.selected)
    return op.run(cfg.get("timeline", []), profile)
