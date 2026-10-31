extends SceneTree
const Core := preload("res://addons/scene_dependency/core/sdm_graph.gd")
var failures := 0
var passes := 0

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
    var op = Core.new()
    var result: Dictionary = op.run("res://demo/dependencies", ["res://demo/dependencies/main.tscn"])
    check("fixture finds four files", result["summary"]["nodes"] == 4)
    check("scene and script edges found", result["summary"]["edges"] == 2)
    check("three reachable files", result["summary"]["reachable"] == 3)
    check("unused fixture is a candidate", kinds(result).has("unused_candidate"))
    check("references deduplicate", op.references('load("res://a.tres") + load("res://a.tres")').size() == 1)
    var files := {"res://a.gd": 'load("res://b.gd")', "res://b.gd": 'load("res://a.gd") + load("res://missing_resource_xyz.tres")'}
    var graph: Dictionary = op.analyze(files, ["res://a.gd"], 2)
    check("cycle detected", kinds(graph).has("cycle"))
    check("missing dependency detected", kinds(graph).has("missing_dependency"))
    check("long chain detected", kinds(graph).has("long_chain"))
    var no_roots: Dictionary = op.analyze(files, [])
    check("no roots suppress unused candidates", kinds(no_roots).has("no_roots") and not kinds(no_roots).has("unused_candidate"))
    var uid: Dictionary = op.analyze({"res://a.gd": 'load("uid://notrealinvalid")'}, ["res://a.gd"])
    check("unresolved uid reported", kinds(uid).has("unresolved_uid"))
    check("markdown has graph", op.to_markdown(result).contains("main.gd"))
    check("json includes edges", JSON.parse_string(op.to_json(result)).has("edges"))
    print("Scene Dependency Map TESTS: %d passed, %d failed" % [passes, failures])
    quit(1 if failures else 0)
