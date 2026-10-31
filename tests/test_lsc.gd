extends SceneTree
const Core := preload("res://addons/light_cost/core/lsc_estimator.gd")
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
    var result: Dictionary = op.run("res://demo/rendering", {"renderer": "forward_plus"})
    var street: Dictionary = result["scenes"].filter(func(s): return s["path"].ends_with("street.tscn"))[0]
    check("instanced lamps counted", street["omni"] == 5 and street["shadow_omni_spot"] == 5)
    check("spot without shadow counted", street["spot"] == 1)
    check("five shadowed lamps over budget", op._count(result, "shadow_budget") == 1)
    check("two shadowed suns flagged", op._count(result, "multiple_directional_shadows") == 1)
    check("forward+ has no per-object note", op._count(result, "renderer_light_limit") == 0)
    check("lamp scene alone within budget", not result["issues"].any(func(i): return i["path"].ends_with("lamp.tscn")))
    var cyc: Dictionary = op.analyze({"res://a.tscn": "[ext_resource type=\"PackedScene\" path=\"res://a.tscn\" id=\"1\"]\n[node name=\"A\" type=\"Node3D\"]\n[node name=\"L\" type=\"OmniLight3D\" parent=\".\"]\n[node name=\"Me\" parent=\".\" instance=ExtResource(\"1\")]\n"})
    check("self-instancing does not loop", cyc["scenes"][0]["omni"] == 1)
    var many := "[node name=\"R\" type=\"Node3D\"]\n"
    for i in range(9):
        many += "[node name=\"L%d\" type=\"OmniLight3D\" parent=\".\"]\n" % i
    check("mobile per-object limit noted", op._count(op.analyze({"res://m.tscn": many}, {"renderer": "mobile"}), "renderer_light_limit") == 1)
    check("missing input is reported", op.run("res://definitely_missing_dir_lsc")["issues"][0]["kind"] in ["scan_error", "bad_input"])
    var r: Dictionary = op.run("res://demo/rendering", {"renderer": "forward_plus"})
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("3D Light and Shadow Cost Estimator TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
