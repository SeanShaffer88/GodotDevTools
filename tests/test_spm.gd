extends SceneTree
const Presets := preload("res://addons/suite_presets/core/spm_presets.gd")
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
	var presets = Presets.new()
	var addons := ["frame_spikes", "thermal_sim", "test_runner", "asset_health", "naming_conventions"]
	var mobile: Dictionary = presets.run("mobile_perf", {"addons": addons})
	check("mobile pack enables perf tools", mobile["enabled"].has("frame_spikes") and mobile["enabled"].has("thermal_sim"))
	check("mobile pack disables test runner", mobile["disabled"].has("test_runner"))
	var full: Dictionary = presets.run("full", {"addons": addons})
	check("full enables everything", full["enabled"].size() == addons.size() and full["disabled"].is_empty())
	check("unknown preset reported", str(presets.run("nope", {"addons": addons})["issues"]).contains("unknown_preset"))
	var text := "[editor_plugins]\nenabled=PackedStringArray(\"res://addons/test_runner/plugin.cfg\")\n"
	var applied := presets.apply_preset(text, "mobile_perf", addons)
	check("apply rewrites enabled line", applied.contains("frame_spikes") and not applied.contains("test_runner/plugin.cfg"))
	check("apply keeps other lines", applied.contains("[editor_plugins]"))
	check("real addons dir lists many tools", presets.run("full", {})["summary"]["enabled"] > 100)
	check("markdown lists enabled", presets.to_markdown(mobile).contains("frame_spikes"))
	check("json round-trips", JSON.parse_string(presets.to_json(mobile)).has("enabled"))
	print("Suite Presets TESTS: %d passed, %d failed" % [passes, failures])
	quit(1 if failures else 0)
