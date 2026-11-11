extends SceneTree
const Coverage := preload("res://addons/coverage_gate/core/cvg_coverage.gd")
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
	var cov = Coverage.new()
	var files := {"res://demo/coverage_gate/sample.gd": "extends RefCounted\nfunc covered_helper() -> int:\n\treturn 42\nfunc uncovered_helper() -> int:\n\treturn 0\n"}
	var tests := {"res://tests/test_cvg.gd": "covered_helper sample"}
	var result: Dictionary = cov.analyze(files, tests, {"min_percent": 0.0})
	check("counts functions", result["summary"]["functions"] == 2)
	check("counts covered functions", result["summary"]["covered"] == 1)
	check("percent is 50", result["summary"]["percent"] == 50.0)
	check("estimate flag set", result["estimate"] == true)
	var gated: Dictionary = cov.analyze(files, tests, {"min_percent": 90.0})
	check("below threshold flagged", str(gated["issues"]).contains("below_threshold"))
	check("missing dir is bad_input", str(cov.run("res://missing_cov_dir", {})["issues"]).contains("bad_input"))
	check("fixture estimates without error", cov.run("res://demo/coverage_gate", {})["summary"]["files"] == 1)
	check("markdown warns estimate", cov.to_markdown(result).contains("estimate"))
	check("json round-trips", JSON.parse_string(cov.to_json(result)).has("per_file"))
	print("Coverage Gate TESTS: %d passed, %d failed" % [passes, failures])
	quit(1 if failures else 0)
