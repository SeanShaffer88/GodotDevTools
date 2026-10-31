extends SceneTree
const Core := preload("res://addons/shader_variants/core/svb_budget.gd")
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
    var result: Dictionary = op.run("res://demo/perf_static")
    check("four distinct feature combinations", result["summary"]["material_variants"] == 4)
    check("colour-only differences share a variant", result["variants"][0]["materials"] == 2)
    check("default budget not exceeded", op._count(result, "variant_budget") == 0)
    check("tight budget flagged", op._count(op.run("res://demo/perf_static", {"max_variants": 3}), "variant_budget") == 1)
    check("three #ifdef keywords flagged", op._count(result, "preprocessor_variants") == 1 and result["issues"].any(func(i): return i["message"].contains("up to 8")))
    check("standalone material resource counted", op.analyze({"res://m.tres": "[gd_resource type=\"StandardMaterial3D\" format=3]\n[resource]\nemission_enabled = true\n"})["summary"]["material_variants"] == 1)
    check("missing input is reported", op.run("res://definitely_missing_dir_svb")["issues"][0]["kind"] in ["scan_error", "bad_input"])
    var r: Dictionary = op.run("res://demo/perf_static")
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Shader Variant Budget Manager TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
