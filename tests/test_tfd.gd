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
