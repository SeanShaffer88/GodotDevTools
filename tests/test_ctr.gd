## CI and Headless Test Runner tests.
extends SceneTree

var _failures: Array[String] = []
var _passes: int = 0


func _check(label: String, ok: bool, evidence: String = "") -> void:
    if ok:
        _passes += 1
        print("PASS  ", label)
    else:
        _failures.append(label)
        print("FAIL  ", label, "  ", evidence)


func _finish(name: String) -> void:
    print("----")
    print(name, ": %d passed, %d failed" % [_passes, _failures.size()])
    quit(1 if not _failures.is_empty() else 0)


func _kinds(issues: Array) -> Array:
    var out: Array = []
    for i in issues:
        out.append(i["kind"])
    return out

const Runner := preload("res://addons/test_runner/core/ctr_runner.gd")


func _init() -> void:
    var op = Runner.new()
    var harness := op.classify("extends SceneTree\n\nfunc _init() -> void:\n\t_check(\"x\", true)\n\t_finish()\n")
    _check("harness classified", str(harness["kind"]) == "harness" and int(harness["checks"]) == 1 and bool(harness["has_finish"]), str(harness))
    var gut := op.classify("extends GutTest\n\nfunc test_x() -> void:\n\tassert_true(true)\n")
    _check("GUT suite classified without GUT installed", str(gut["kind"]) == "gut", str(gut))
    var other := op.classify("extends Node\n")
    _check("anything else is unknown", str(other["kind"]) == "unknown")
    op.test_dirs.assign(["res://demo/tests"])
    var demo: Dictionary = op.run()
    _check("demo discovery finds the three samples", int(demo["summary"]["tests"]) == 3, str(demo["summary"]))
    _check("finish-less harness flagged (gate kind)", _kinds(demo["issues"]).has("no_finish"), str(demo["issues"]))
    var plan_ok := false
    for row in demo["plan"]:
        if str(row["path"]) == "res://demo/tests/sample_pass.gd" and (row["command"] as Array).has("--script"):
            plan_ok = true
    _check("plan builds a headless command per harness file", plan_ok, str(demo["plan"]))
    var verdict: Dictionary = op.classify_check_output("WARNING: something\n", 0)
    _check("warnings do not fail a check", bool(verdict["ok"]) and (verdict["warnings"] as Array).size() == 1, str(verdict))
    var bad_verdict: Dictionary = op.classify_check_output("ERROR: parse failed\n", 1)
    _check("errors fail a check", not bool(bad_verdict["ok"]))
    var xml := op.to_junit([{"suite": "demo", "passed": 2, "failed": 1, "seconds": 0.5, "failures": ["broken: detail <x> & more"]}])
    _check("junit xml counts and escapes", xml.contains("tests=\"3\"") and xml.contains("failures=\"1\"") and xml.contains("&lt;x&gt; &amp;"), xml)
    op.test_dirs.assign(["res://tests"])
    var real: Dictionary = op.run()
    _check("real suite discovery includes every test file", (real["plan"] as Array).size() >= 29, str(real["summary"]))
    _check("to_markdown renders a title", op.to_markdown(real).begins_with("# "))
    _finish("CI and Headless Test Runner TESTS")
