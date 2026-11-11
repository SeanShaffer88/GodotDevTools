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
	check("explicit empty addon list stays empty", presets.run("full", {"addons": []})["enabled"].is_empty() and presets.apply_preset("", "full", []).contains("enabled=PackedStringArray()"))
	check("unknown preset reported", str(presets.run("nope", {"addons": addons})["issues"]).contains("unknown_preset"))
	var text := "[editor_plugins]\nenabled=PackedStringArray(\"res://addons/test_runner/plugin.cfg\")\n"
	var applied := presets.apply_preset(text, "mobile_perf", addons)
	check("apply rewrites enabled line", applied.contains("frame_spikes") and not applied.contains("test_runner/plugin.cfg"))
	check("apply keeps other lines", applied.contains("[editor_plugins]"))
	check("unknown preset does not rewrite", presets.apply_preset(text, "missing", addons) == text)
	var windows := "[editor_plugins]\r\n; keep comment\r\nother=42\r\n enabled = PackedStringArray(\"old\")\r\n[rendering]\r\nfoo=1\r\n"
	var windows_applied: String = presets.apply_preset(windows, "content", ["asset_health"])
	check("CRLF, comments and other settings preserved", windows_applied.contains("; keep comment\r\nother=42\r\nenabled=PackedStringArray(") and windows_applied.contains("\r\n[rendering]\r\n") and windows_applied.count("[editor_plugins]") == 1)
	var no_enabled := "[editor_plugins]\nother=42\n[rendering]\nfoo=1\n"
	var added: String = presets.apply_preset(no_enabled, "content", ["asset_health"])
	check("missing enabled inserted in existing section", added.count("[editor_plugins]") == 1 and added.find("enabled=") < added.find("[rendering]"))
	var multiline := "[editor_plugins]\nenabled=PackedStringArray(\n\"old\"\n)\n"
	check("multiline setting refused", presets.apply_preset(multiline, "content", ["asset_health"]) == multiline)
	var duplicate := "[editor_plugins]\nenabled=PackedStringArray()\n[editor_plugins]\nenabled=PackedStringArray()\n"
	check("duplicate section refused", presets.apply_preset(duplicate, "content", ["asset_health"]) == duplicate and not presets.rewrite_preset(duplicate, "content", ["asset_health"])["ok"])
	var mixed := "[editor_plugins]\r\nenabled=PackedStringArray()\n"
	check("mixed line endings refused", not presets.rewrite_preset(mixed, "content", ["asset_health"])["ok"])
	var stable: Dictionary = presets.rewrite_preset(applied, "mobile_perf", addons)
	check("already-applied preset is a valid no-op", stable["ok"] and stable["text"] == applied)
	check("addon paths are escaped", presets._enabled_line(["odd\"folder"]).contains("odd\\\"folder"))
	check("real addons dir lists many tools", presets.run("full", {})["summary"]["enabled"] > 100)
	check("markdown lists enabled", presets.to_markdown(mobile).contains("frame_spikes"))
	check("json round-trips", JSON.parse_string(presets.to_json(mobile)).has("enabled"))
	print("Suite Presets TESTS: %d passed, %d failed" % [passes, failures])
	quit(1 if failures else 0)
