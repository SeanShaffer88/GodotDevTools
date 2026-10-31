extends SceneTree
const Core := preload("res://addons/rng_fairness/core/rft_tester.gd")
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
    var result: Dictionary = op.run("res://demo/balance/fairness.json")
    check("fair chest passes", result["tables"]["chest"]["p_value"] > 0.9)
    check("chest chi-square value", is_equal_approx(result["tables"]["chest"]["chi_square"], 0.0217))
    check("rigged gacha flagged", op._count(result, "unfair_distribution") == 1 and result["tables"]["gacha"]["p_value"] < 1e-6)
    check("four coin flips are too few", op._count(result, "low_sample") == 1)
    check("p-value matches known chi-square quantile", absf(op.gamma_q(0.5, 3.841459 / 2.0) - 0.05) < 1e-5)
    check("lgamma(5) = ln 24", absf(op.lgamma(5.0) - log(24.0)) < 1e-6)
    check("unknown outcome reported", op._count(op.evaluate({"tables": {"t": {"weights": {"a": 1, "b": 1}, "observed": {"a": 10, "c": 3}}}}), "unknown_outcome") == 1)
    check("missing input is reported", op.run("res://definitely_missing.json")["issues"][0]["kind"] == "bad_input")
    var r: Dictionary = op.run("res://demo/balance/fairness.json")
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Random Table Fairness Tester TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
