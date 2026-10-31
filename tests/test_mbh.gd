extends SceneTree
const Core := preload("res://addons/bench_harness/core/mbh_harness.gd")
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
    var result: Dictionary = op.run("res://demo/ci/bench/bench_math.gd", {"iterations": 10, "warmup": 2})
    check("two bench methods timed, helper skipped", result["summary"]["benchmarks"] == 2 and not result["stats"].has("helper_not_a_benchmark"))
    check("median and p95 recorded", result["stats"]["bench_sum_array"]["median_us"] >= 0 and result["stats"]["bench_sum_array"]["p95_us"] >= result["stats"]["bench_sum_array"]["min_us"])
    check("gate-compatible metric emitted", result["metrics"]["bench_math.bench_sum_array"]["unit"] == "us" and result["metrics"]["bench_math.bench_sum_array"]["direction"] == "higher_is_worse")
    var fixed: Dictionary = op.evaluate({"bench_x": [10, 12, 11, 100]}, "s")
    check("median of even count", is_equal_approx(float(fixed["stats"]["bench_x"]["median_us"]), 11.5))
    check("outlier makes it noisy", op._count(fixed, "noisy_benchmark") == 1)
    check("no benchmarks is an error", op.evaluate({})["issues"][0]["kind"] == "no_benchmarks")
    check("missing input is reported", op.run("res://definitely_missing.gd")["issues"][0]["kind"] == "bad_bench_script")
    var r: Dictionary = op.run("res://demo/ci/bench/bench_math.gd", {"iterations": 5, "warmup": 1})
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Micro-Benchmark Harness TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
