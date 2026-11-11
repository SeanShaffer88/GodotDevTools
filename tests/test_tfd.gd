extends SceneTree
const Finder := preload("res://addons/tool_finder/core/tfd_finder.gd")
var passes := 0
var failures := 0

func check(label: String, ok: bool) -> void:
	if ok:
		passes += 1
		print("PASS  ", label)
	else:
		failures += 1
		print("FAIL  ", label)

func result_ids(result: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for match_result in result.get("results", []):
		ids.append(str(match_result["id"]))
	return ids

func result_for(result: Dictionary, id: String) -> Dictionary:
	for match_result in result.get("results", []):
		if str(match_result["id"]) == id:
			return match_result
	return {}

func _init() -> void:
	var finder = Finder.new()
	var catalog := [
		{"id": "frame_spikes", "title": "Frame-Time Spike Investigator", "description": "Correlate frame spikes with scene changes.", "folder": "addons/frame_spikes"},
		{"id": "thermal_sim", "title": "Mobile Thermal Simulator", "description": "Estimate thermal throttling on mobile.", "folder": "addons/thermal_sim"},
		{"id": "test_runner", "title": "CI Test Runner", "description": "Discover and run tests headless.", "folder": "addons/test_runner"},
	]
	var lag: Dictionary = finder.search(catalog, "my game lags on mobile")
	check("lag query matches frame spikes", str(lag["results"]).contains("frame_spikes"))
	check("lag query matches thermal sim", str(lag["results"]).contains("thermal_sim"))
	check("results are ranked with reasons", lag["results"].size() > 0 and not str(lag["results"][0]["why"]).is_empty())
	var test_q: Dictionary = finder.search(catalog, "how do I test my game")
	check("test query matches test runner", str(test_q["results"]).contains("test_runner"))
	var none: Dictionary = finder.search(catalog, "zzzzqqqq")
	check("unknown query reports no_match", str(none["issues"]).contains("no_match"))
	check("empty query is bad_input", str(finder.run("", {"catalog": catalog})["issues"]).contains("bad_input"))
	check("catalog builds from real addons dir", finder.build_catalog("res://addons").size() > 100)
	var android: Dictionary = finder.run("android")
	check("Android query recommends the three new tools", str(android["results"]).contains("android_export_audit") and str(android["results"]).contains("android_touch_audit") and str(android["results"]).contains("android_logcat_triage"))
	var logcat: Dictionary = finder.run("logcat")
	var explained := false
	for match_result in logcat["results"]:
		if match_result["id"] == "android_logcat_triage" and "recommended for 'logcat'" in match_result["why"]:
			explained = true
	check("logcat query explains its recommendation", explained)

	var boundary_catalog := [
		{"id": "frame_spikes", "title": "Frame Spike Investigator", "description": "Inspect frame timing", "folder": "addons/frame_spikes"},
		{"id": "thermal_sim", "title": "Mobile Thermal Simulator", "description": "Estimate thermal load", "folder": "addons/thermal_sim"},
		{"id": "responsive_ui", "title": "Responsive UI Previewer", "description": "Preview layouts", "folder": "addons/responsive_ui"},
		{"id": "build_size", "title": "Build Size Explorer", "description": "Measure package size", "folder": "addons/build_size"},
		{"id": "flag_inspector", "title": "Flag Inspector", "description": "Review flags", "folder": "addons/flag_inspector"},
		{"id": "test_runner", "title": "CI Test Runner", "description": "Discover tests", "folder": "addons/test_runner"},
		{"id": "crash_packager", "title": "Crash Packager", "description": "Package crash reports", "folder": "addons/crash_packager"},
		{"id": "texture_health", "title": "Texture Health", "description": "Review assets and textures", "folder": "addons/texture_health"},
		{"id": "physics_jitter", "title": "Physics Jitter Detector", "description": "Review physics", "folder": "addons/physics_jitter"},
		{"id": "catalog_helper", "title": "Catalog Helper", "description": "Manage catalog entries", "folder": "addons/catalog_helper"},
		{"id": "unicode_helper", "title": "Café Helper", "description": "Review menus", "folder": "addons/unicode_helper"},
	]
	var build: Dictionary = finder.search(boundary_catalog, "build")
	check("build finds build tool without triggering UI", result_ids(build).has("build_size") and not result_ids(build).has("responsive_ui"))
	var flag: Dictionary = finder.search(boundary_catalog, "flag")
	check("flag does not trigger lag recommendations", result_ids(flag).has("flag_inspector") and not result_ids(flag).has("frame_spikes"))
	var log_query: Dictionary = finder.search(boundary_catalog, "log")
	check("log does not match catalog as a substring", not result_ids(log_query).has("catalog_helper"))
	var ui: Dictionary = finder.search(boundary_catalog, "UI?!")
	check("punctuation and case preserve UI recommendations without matching build", "recommended for 'ui'" in result_for(ui, "responsive_ui").get("why", []) and not result_ids(ui).has("build_size"))
	var lagging: Dictionary = finder.search(boundary_catalog, "LAGGING,\tmobile!")
	check("lagging alias and punctuation preserve recommendations", "recommended for 'lag'" in result_for(lagging, "frame_spikes").get("why", []) and result_ids(lagging).has("thermal_sim"))
	check("a problem recommendation contributes five points", result_for(lagging, "frame_spikes").get("score", 0) == 5)
	var crash: Dictionary = finder.search(boundary_catalog, "crash")
	var crashes: Dictionary = finder.search(boundary_catalog, "CRASHES?!")
	check("crashes normalizes to crash with the same ranking", crash.get("results", []) == crashes.get("results", []) and result_ids(crashes).has("crash_packager"))
	var single_test: Dictionary = finder.search(boundary_catalog, "test")
	var repeated_test: Dictionary = finder.search(boundary_catalog, "test tests TESTING")
	check("repeated terms and aliases do not inflate scores", single_test.get("results", []) == repeated_test.get("results", []))
	var textures: Dictionary = finder.search(boundary_catalog, "textures and assets")
	var texture: Dictionary = finder.search(boundary_catalog, "texture asset")
	check("simple plurals match singular catalog words", textures.get("results", []) == texture.get("results", []) and result_ids(textures).has("texture_health"))
	var physics: Dictionary = finder.search(boundary_catalog, "physics")
	check("physics remains a problem keyword", "recommended for 'physics'" in result_for(physics, "physics_jitter").get("why", []))
	check("Unicode letters are tokenized", result_ids(finder.search(boundary_catalog, "CAFÉ!")).has("unicode_helper"))
	var filler: Dictionary = finder.search(boundary_catalog, "how do I")
	check("stop-word-only query is a no_match, not bad_input", str(filler["issues"]).contains("no_match"))
	var weighting_catalog := [
		{"id": "aaa_description", "title": "Unrelated", "description": "Review build data", "folder": "addons/aaa_description"},
		{"id": "zzz_title", "title": "Build Inspector", "description": "Review build data", "folder": "addons/zzz_title"},
	]
	var weighted: Dictionary = finder.search(weighting_catalog, "build")
	var weighted_ids := result_ids(weighted)
	check("title matches rank above description matches", weighted_ids.size() == 2 and weighted_ids[0] == "zzz_title" and weighted_ids[1] == "aaa_description")
	check("matching a title and description scores only the stronger field", result_for(weighted, "zzz_title").get("score", 0) == 3 and result_for(weighted, "aaa_description").get("score", 0) == 1)
	check("match reasons identify the matching field", "matches 'build' in title or id" in result_for(weighted, "zzz_title").get("why", []) and "matches 'build' in description" in result_for(weighted, "aaa_description").get("why", []))
	var id_only_catalog := [{"id": "needle_marker", "title": "Unrelated", "description": "", "folder": "addons/needle_marker"}]
	var id_only: Dictionary = finder.search(id_only_catalog, "MARKER!")
	check("underscores delimit ID words", result_for(id_only, "needle_marker").get("score", 0) == 3 and "matches 'marker' in title or id" in result_for(id_only, "needle_marker").get("why", []))

	var ties: Array = []
	for n in range(12):
		var id := "tool_%02d" % (11 - n)
		ties.append({"id": id, "title": "Audit", "description": "", "folder": "addons/" + id})
	var forward: Dictionary = finder.search(ties, "audit")
	ties.reverse()
	var backward: Dictionary = finder.search(ties, "audit")
	var ordered_ids := result_ids(forward)
	check("tied scores are ordered by ID independent of input order", ordered_ids.size() == 10 and ordered_ids == result_ids(backward) and ordered_ids[0] == "tool_00")
	check("results are capped at ten in deterministic order", ordered_ids.size() == 10 and ordered_ids[9] == "tool_09")
	var all_explained := true
	for match_result in forward.get("results", []):
		if match_result["why"].is_empty() or int(match_result["score"]) <= 0:
			all_explained = false
	check("every result has a positive score and reasons", all_explained)

	var scratch := "user://finder_crlf_%s" % str(OS.get_process_id())
	var addon := scratch.path_join("sample_tool")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(addon))
	var cfg_path := addon.path_join("plugin.cfg")
	var cfg_file := FileAccess.open(cfg_path, FileAccess.WRITE)
	cfg_file.store_string("[plugin]\r\nname = \"Windows Title\"\r\ndescription = \"Portable description\"\r\n")
	cfg_file.close()
	var windows_catalog: Array = finder.build_catalog(scratch)
	check("catalog parses CRLF and spaced plugin.cfg values", windows_catalog.size() == 1 and windows_catalog[0]["title"] == "Windows Title" and windows_catalog[0]["description"] == "Portable description")
	for path in [cfg_path, addon, scratch]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	check("markdown lists matches", finder.to_markdown(lag).contains("Frame-Time"))
	check("json round-trips", JSON.parse_string(finder.to_json(lag)).has("results"))
	print("Tool Finder TESTS: %d passed, %d failed" % [passes, failures])
	quit(1 if failures else 0)
