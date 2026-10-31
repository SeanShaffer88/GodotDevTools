extends SceneTree
const Scanner := preload("res://addons/particle_budget/core/pbi_scanner.gd")
var passed := 0
var failed := 0

func check(label: String, ok: bool) -> void:
    if ok:
        passed += 1
        print("PASS  ", label)
    else:
        failed += 1
        print("FAIL  ", label)

func _kinds(result: Dictionary, node: String) -> Array:
    var out: Array = []
    for issue in result["issues"]:
        if issue["node"] == node:
            out.append(issue["kind"])
    return out

func _scene(result: Dictionary, path: String) -> Dictionary:
    for scene in result["scenes"]:
        if scene["path"] == path:
            return scene
    return {}

func _init() -> void:
    var op = Scanner.new()
    var result: Dictionary = op.run("res://demo/particles")
    var fire := _scene(result, "res://demo/particles/campfire.tscn")
    check("both fixture scenes have emitters", result["summary"]["scenes"] == 2 and result["summary"]["emitters"] == 4)
    check("amount_ratio halves GPU capacity", fire["emitters"][0]["capacity"] == 1500)
    check("omitted amount uses the Godot default of 8", fire["emitters"][2]["capacity"] == 8)
    check("instanced child emitters are counted with their chain", fire["emitters"].size() == 4 and fire["emitters"][3]["node"] == "SparkFx/Burst")
    check("worst case sums every emitter", fire["worst_case"] == 3308)
    check("always-on excludes idle one-shot effects", fire["always_on"] == 2708)
    check("large emitter over budget", "emitter_budget" in _kinds(result, "Smoke"))
    check("CPU emitter flagged as main-thread heavy", "cpu_heavy" in _kinds(result, "Embers"))
    check("long preprocess flagged", "preprocess_cost" in _kinds(result, "Smoke"))
    check("default scene budget not exceeded", not ("scene_budget" in _kinds(result, "")))
    var tight: Dictionary = op.run("res://demo/particles", {"max_scene": 3000})
    check("custom scene budget enforced", "scene_budget" in _kinds(tight, ""))
    var cyc: Dictionary = op.analyze({
        "res://a.tscn": "[ext_resource type=\"PackedScene\" path=\"res://b.tscn\" id=\"1\"]\n[node name=\"A\" type=\"Node2D\"]\n[node name=\"B\" parent=\".\" instance=ExtResource(\"1\")]\n",
        "res://b.tscn": "[ext_resource type=\"PackedScene\" path=\"res://a.tscn\" id=\"1\"]\n[node name=\"B\" type=\"Node2D\"]\n[node name=\"P\" type=\"GPUParticles3D\" parent=\".\"]\namount = 10\n[node name=\"A\" parent=\".\" instance=ExtResource(\"1\")]\n"})
    var cycle_found := false
    for issue in cyc["issues"]:
        cycle_found = cycle_found or issue["kind"] == "instance_cycle"
    check("instance cycles reported, not followed forever", cycle_found)
    var missing: Dictionary = op.analyze({"res://m.tscn": "[ext_resource type=\"PackedScene\" path=\"res://gone.tscn\" id=\"9\"]\n[node name=\"M\" type=\"Node3D\"]\n[node name=\"G\" parent=\".\" instance=ExtResource(\"9\")]\n"})
    check("missing instanced scene reported", missing["issues"].size() == 1 and missing["issues"][0]["kind"] == "missing_scene")
    check("unreadable scene is an error", op.analyze({"res://x.tscn": null})["issues"][0]["kind"] == "scan_error")
    check("missing directory is an error", op.run("res://definitely_missing_particles")["issues"][0]["kind"] == "scan_error")
    check("markdown lists the campfire", op.to_markdown(result).contains("campfire.tscn"))
    check("json parses", JSON.parse_string(op.to_json(result)).has("scenes"))
    print("Particle Budget TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
