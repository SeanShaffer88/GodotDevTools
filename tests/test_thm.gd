## Mobile Thermal and Battery Simulation tests.
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

const Model := preload("res://addons/thermal_sim/core/thm_model.gd")


func _init() -> void:
    var op = Model.new()
    var profile: Dictionary = Model.PROFILES["low_end_android_estimate"]
    var watts: float = op.power_w(profile, {"cpu": 1.0, "gpu": 1.0})
    _check("power adds base, cpu, gpu and screen", absf(watts - (0.9 + 1.5 + 1.5 + 0.8)) < 0.001, str(watts))
    var hotter: float = op.thermal_step(30.0, watts, profile, 1.0)
    _check("temperature rises under load", hotter > 30.0, str(hotter))
    var cooler: float = op.thermal_step(30.0, 0.0, profile, 1.0)
    _check("temperature falls with no load", cooler < 30.0, str(cooler))
    var workload = JSON.parse_string(FileAccess.get_file_as_string("res://demo/thermal/workload.json"))
    var r: Dictionary = op.run(workload["timeline"], str(workload["profile"]))
    var kinds := _kinds(r["issues"])
    _check("sustained combat throttles the low-end estimate (gate kind)", kinds.has("thermal_throttle"), str(r["issues"]))
    _check("battery estimate lands under budget", kinds.has("battery_drain_high"))
    _check("missed frame budget reported", kinds.has("frame_budget_exceeded"))
    _check("timeline covers every sample", (r["timeline"] as Array).size() == 90, str((r["timeline"] as Array).size()))
    _check("peak temperature crosses the throttle point", float(r["summary"]["peak_temp_c"]) > float(profile["throttle_temp"]), str(r["summary"]))
    var unknown: Dictionary = op.run([], "toaster_estimate")
    _check("unknown profile is a config error", _kinds(unknown["issues"]).has("config_error"))
    var again: Dictionary = op.run(workload["timeline"], str(workload["profile"]))
    _check("simulation is deterministic", op.to_json(r) == op.to_json(again))
    _check("to_markdown says ESTIMATE", op.to_markdown(r).contains("ESTIMATE"))
    _finish("Mobile Thermal and Battery Simulation TESTS")
