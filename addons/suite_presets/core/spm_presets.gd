## Suite Presets - plugin profiles for project.godot.
## Pure string transform over project.godot text (testable headless):
## apply_preset() rewrites the [editor_plugins] enabled list for a preset.
## The CLI previews by default; --apply writes the file (caller backs up).
extends RefCounted

const PRESETS := {
	"full": {"label": "Full suite (all plugins)", "include": ["*"]},
	"ci_only": {"label": "CI only (no docks needed in editor)", "include": ["report_schema", "sarif_export", "junit_export", "suite_dispatcher", "precommit"]},
	"mobile_perf": {"label": "Mobile performance pack", "include": ["frame_spikes", "overdraw", "batch_profiler", "thermal_sim", "texture_filter", "asset_health", "handheld_readiness", "load_profiler"]},
	"content": {"label": "Content and asset pack", "include": ["asset_health", "cleanup_workbench", "naming_conventions", "scene_lint", "duplicate_code", "unused_symbols", "art_handoff"]},
	"testing": {"label": "Testing pack", "include": ["test_runner", "flaky_tests", "mutation_tester", "property_tests", "scenario_tests", "visual_regression", "golden_snapshot"]},
}

func run(preset_name: String = "full", options: Dictionary = {}) -> Dictionary:
	if not PRESETS.has(preset_name):
		return _fail(preset_name, "Unknown preset '%s'." % preset_name, "Use one of: " + ", ".join(PRESETS.keys()) + ".", "unknown_preset")
	var preset: Dictionary = PRESETS[preset_name]
	var addons: Array = options.get("addons", [])
	if addons.is_empty():
		addons = _list_addons(str(options.get("addons_dir", "res://addons")))
	var include: Array = preset["include"]
	var enabled: Array = []
	var disabled: Array = []
	for a in addons:
		if include.has("*") or include.has(a):
			enabled.append(a)
		else:
			disabled.append(a)
	return _finish({"preset": preset_name, "enabled": enabled.size(), "disabled": disabled.size()}, [], {"enabled": enabled, "disabled": disabled, "label": preset["label"]})

func apply_preset(project_text: String, preset_name: String, addons: Array) -> String:
	var result: Dictionary = run(preset_name, {"addons": addons})
	if result["summary"].has("issues") and int(result["summary"]["issues"]) > 0 and result["issues"].size() > 0 and str(result["issues"][0]["kind"]) == "unknown_preset":
		return project_text
	var lines := project_text.split("\n")
	var out: Array = []
	var in_plugins := false
	var wrote := false
	for line in lines:
		if line.strip_edges() == "[editor_plugins]":
			in_plugins = true
			out.append(line)
			continue
		if in_plugins and line.begins_with("enabled="):
			out.append(_enabled_line(result["enabled"]))
			wrote = true
			in_plugins = false
			continue
		if in_plugins and line.strip_edges() != "" and not line.begins_with("enabled="):
			in_plugins = false
		out.append(line)
	if not wrote:
		out.append("[editor_plugins]")
		out.append(_enabled_line(result["enabled"]))
	return "\n".join(out)

func _enabled_line(enabled: Array) -> String:
	var parts: Array = []
	for a in enabled:
		parts.append("\"res://addons/%s/plugin.cfg\"" % a)
	return "enabled=PackedStringArray(" + ", ".join(parts) + ")"

func _list_addons(addons_dir: String) -> Array:
	var out: Array = []
	var dir := DirAccess.open(addons_dir)
	if dir == null:
		return out
	for name in dir.get_directories():
		if FileAccess.file_exists(addons_dir.path_join(name).path_join("plugin.cfg")):
			out.append(name)
	out.sort()
	return out

func _issue(severity: String, kind: String, path: String, line: int, message: String, fix: String) -> Dictionary:
	return {"severity": severity, "kind": kind, "path": path, "line": line, "message": message, "fix": fix}

func _fail(path: String, message: String, fix: String, kind: String = "scan_error") -> Dictionary:
	return {"summary": {"issues": 1}, "issues": [_issue("error", kind, path, 0, message, fix)]}

func _finish(summary: Dictionary, issues: Array, extra: Dictionary = {}) -> Dictionary:
	issues.sort_custom(func(a, b): return "%s|%08d|%s" % [a["path"], int(a["line"]), a["kind"]] < "%s|%08d|%s" % [b["path"], int(b["line"]), b["kind"]])
	summary["issues"] = issues.size()
	var result := {"summary": summary, "issues": issues}
	result.merge(extra)
	return result

func to_json(result: Dictionary) -> String:
	return JSON.stringify(result, "  ")

func to_markdown(result: Dictionary) -> String:
	var lines: Array = ["# Suite Presets", "", "Summary: " + str(result["summary"]), "", "## Enabled"]
	for a in result.get("enabled", []):
		lines.append("- " + a)
	lines.append("## Disabled")
	for a in result.get("disabled", []):
		lines.append("- " + a)
	return "\n".join(lines) + "\n"
