extends SceneTree
const Simulator := preload("res://addons/flag_simulator/core/flag_simulator.gd")
var passes := 0
var failures := 0

func check(label: String, ok: bool) -> void:
    if ok:
        passes += 1
        print("PASS  ", label)
    else:
        failures += 1
        print("FAIL  ", label)

func kinds(result: Dictionary) -> Array:
    var out: Array = []
    for issue in result["issues"]:
        out.append(issue["kind"])
    return out

func _init() -> void:
    var op = Simulator.new()
    var broken: Dictionary = op.run("res://demo/flags/flags.json", "example")
    check("unknown prerequisite detected", kinds(broken).has("unknown_prerequisite"))
    check("invalid config yields no decisions", broken["decisions"].is_empty())
    var clean: Dictionary = op.run("res://demo/flags/clean.json", "example")
    check("valid fixture simulates two flags", clean["summary"]["flags"] == 2 and clean["issues"].is_empty())
    check("100 percent enabled", clean["decisions"]["core"]["enabled"])
    check("bucket matches reference vector", op.bucket("shop", "example") == 2986)
    check("bucket stays in range", op.bucket("shop", "example") >= 0 and op.bucket("shop", "example") < 10000)
    var fallback: Dictionary = op.run("res://demo/flags/clean.json", "example", false)
    check("offline defaults used", fallback["decisions"]["core"]["enabled"] and not fallback["decisions"]["shop"]["enabled"] and fallback["decisions"]["shop"]["source"] == "default")
    var deps := {"flags": {"base": {"default": false, "rollout": 0}, "child": {"default": true, "rollout": 100, "requires": ["base"]}}}
    var blocked: Dictionary = op.simulate(deps, "example")
    check("disabled prerequisite blocks candidate", blocked["decisions"]["child"]["candidate"] and not blocked["decisions"]["child"]["enabled"])
    check("offline prerequisites still enforced", not op.simulate(deps, "example", false)["decisions"]["child"]["enabled"])
    var cycle := {"flags": {"a": {"default": true, "rollout": 100, "requires": ["b"]}, "b": {"default": true, "rollout": 100, "requires": ["a"]}}}
    var cyclic: Dictionary = op.simulate(cycle, "example")
    check("cycle flagged without decisions", kinds(cyclic).has("prerequisite_cycle") and cyclic["decisions"].is_empty())
    check("invalid percent flagged", kinds(op.simulate({"flags": {"a": {"default": false, "rollout": 101}}}, "x")).has("invalid_flag"))
    check("invalid default flagged", kinds(op.simulate({"flags": {"a": {"default": "true"}}}, "x")).has("invalid_flag"))
    check("missing file flagged", kinds(op.run("res://missing_flags_fixture.json", "x")).has("input_error"))
    check("markdown lists decision", op.to_markdown(clean).contains("core"))
    check("json parses", JSON.parse_string(op.to_json(clean)).has("decisions"))
    print("Flag Simulator TESTS: %d passed, %d failed" % [passes, failures])
    quit(1 if failures else 0)
