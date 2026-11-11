## Tool Finder - problem-first search over the suite catalog.
## The catalog is built by reading addons/*/plugin.cfg as data (the same
## discovery suite_dispatcher uses); no tool imports another tool.
## Search is keyword + problem-phrase matching, ranked and explained.
extends RefCounted

const PROBLEM_TOOLS := {
	"lag": ["frame_spikes", "overdraw", "batch_profiler", "load_profiler", "thermal_sim"],
	"slow": ["frame_spikes", "overdraw", "batch_profiler", "load_profiler"],
	"mobile": ["thermal_sim", "handheld_readiness", "texture_filter", "asset_health", "overdraw", "android_touch_audit", "android_export_audit", "android_logcat_triage"],
	"android": ["android_export_audit", "android_touch_audit", "android_logcat_triage", "android_permissions", "lifecycle"],
	"touch": ["android_touch_audit", "responsive_ui", "handheld_readiness"],
	"logcat": ["android_logcat_triage", "crash_packager"],
	"crash": ["crash_packager", "load_failure", "save_corruption", "leak_hunter", "android_logcat_triage"],
	"leak": ["leak_hunter", "pool_advisor", "save_bloat"],
	"test": ["test_runner", "flaky_tests", "mutation_tester", "property_tests", "scenario_tests"],
	"accessibility": ["accessibility", "a11y_options", "colorvision", "subtitle_audit"],
	"localization": ["l10n_matrix", "font_glyphs", "subtitle_audit"],
	"export": ["export_doctor", "export_ranges", "build_size", "release_guard", "android_export_audit"],
	"shader": ["shader_doctor", "shader_variants", "overdraw"],
	"audio": ["audio_sandbox", "audio_levels", "audio_import"],
	"physics": ["physics_jitter", "collision_matrix", "controller_course"],
	"save": ["schema_migrator", "save_corruption", "save_bloat"],
	"ui": ["responsive_ui", "theme_audit", "accessibility", "palette_check", "android_touch_audit"],
}

func run(query: String = "", options: Dictionary = {}) -> Dictionary:
	var catalog: Array = options.get("catalog", [])
	if catalog.is_empty():
		catalog = build_catalog(str(options.get("addons_dir", "res://addons")))
	return search(catalog, query)

func build_catalog(addons_dir: String = "res://addons") -> Array:
	var out: Array = []
	var dir := DirAccess.open(addons_dir)
	if dir == null:
		return out
	var names: Array = Array(dir.get_directories())
	names.sort()
	for name in names:
		var cfg := addons_dir.path_join(name).path_join("plugin.cfg")
		if not FileAccess.file_exists(cfg):
			continue
		var title: String = str(name)
		var desc := ""
		var config := ConfigFile.new()
		if config.load(cfg) == OK:
			title = str(config.get_value("plugin", "name", name))
			desc = str(config.get_value("plugin", "description", ""))
		out.append({"id": name, "title": title, "description": desc, "folder": "addons/" + name})
	return out

func search(catalog: Array, query: String) -> Dictionary:
	var issues: Array = []
	var q := query.strip_edges().to_lower()
	if q == "":
		return _fail("res://addons", "Search query is empty.", "Type a problem, e.g. 'my game lags on mobile'.", "bad_input")
	var scored: Array = []
	for entry in catalog:
		var score := 0
		var why: Array = []
		var hay := (str(entry.get("title", "")) + " " + str(entry.get("description", "")) + " " + str(entry.get("id", ""))).to_lower()
		for word in q.split(" ", false):
			if word.length() >= 3 and hay.contains(word):
				score += 2
				why.append("matches '" + word + "'")
		for phrase in PROBLEM_TOOLS.keys():
			if q.contains(phrase):
				if Array(PROBLEM_TOOLS[phrase]).has(str(entry.get("id", ""))):
					score += 5
					why.append("recommended for '" + phrase + "'")
		if score > 0:
			scored.append({"entry": entry, "score": score, "why": why})
	scored.sort_custom(func(a, b): return int(a["score"]) > int(b["score"]))
	var results: Array = []
	for s in scored.slice(0, 10):
		var e: Dictionary = s["entry"]
		results.append({"id": e["id"], "title": e["title"], "folder": e["folder"], "score": s["score"], "why": s["why"]})
	if results.is_empty():
		issues.append(_issue("warning", "no_match", "res://addons", 0, "No tool matches '" + query + "'.", "Try a problem phrase such as 'lag', 'crash', 'test' or 'export'."))
	return _finish({"query": query, "catalog": catalog.size(), "matches": results.size()}, issues, {"results": results})

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
	var lines: Array = ["# Tool Finder", "", "Summary: " + str(result["summary"]), ""]
	for r in result.get("results", []):
		lines.append("- **%s** (`%s`) score %s - %s" % [r["title"], r["folder"], r["score"], ", ".join(r["why"])])
	lines.append("## Findings")
	for issue in result["issues"]:
		lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
	return "\n".join(lines) + "\n"
