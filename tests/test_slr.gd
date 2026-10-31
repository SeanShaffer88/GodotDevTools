extends SceneTree
const Core := preload("res://addons/scene_lint/core/slr_engine.gd")
var op = Core.new()
var passed := 0
var failed := 0

func check(label: String, ok: bool) -> void:
    if ok:
        passed += 1
        print("PASS  ", label)
    else:
        failed += 1
        print("FAIL  ", label)

func _has(result: Dictionary, kind: String, line: int) -> bool:
    for issue in result["issues"]:
        if issue["kind"] == kind and int(issue["line"]) == line:
            return true
    return false

func _init() -> void:
    var result: Dictionary = op.run("res://demo/scene_lint")
    check("body without shape fails built-in rule", _has(result, "rule_violation", 3))
    check("area with shape passes", not _has(result, "rule_violation", 7))
    var custom: Dictionary = op.run("res://demo/scene_lint", {"rules": "res://demo/scene_lint/rules.json"})
    check("custom name pattern catches 'pickup zone'", _has(custom, "rule_violation", 7))
    check("custom rules replace built-ins", op._count(custom, "rule_violation") == 2)
    var bad: Dictionary = op.analyze({}, {"rule_list": [{"id": "x", "match_type": "*"}]})
    check("rule without a check is rejected", bad["issues"][0]["kind"] == "bad_rules")
    check("missing rules file rejected", op.run("res://demo/scene_lint", {"rules": "res://nope.json"})["issues"][0]["kind"] == "bad_rules")
    var eq: Dictionary = op.analyze({"res://a.tscn": "[node name=\"L\" type=\"Label\"]\nhorizontal_alignment = 0\n"}, {"rule_list": [{"id": "centered", "match_type": "Label", "require_property": "horizontal_alignment", "equals": "1"}]})
    check("require_property with equals", op._count(eq, "rule_violation") == 1)
    check("missing input is reported", op.run("res://definitely_missing_dir_slr")["issues"][0]["kind"] in ["scan_error", "bad_input"])
    var r: Dictionary = op.run("res://demo/scene_lint")
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Scene Lint Rule Engine TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
