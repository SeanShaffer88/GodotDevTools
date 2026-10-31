extends SceneTree
const Core := preload("res://addons/navmesh_lab/core/nml_lab.gd")
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
    var result: Dictionary = op.run("res://demo/gameplay/nav.tres", {"targets": "res://demo/gameplay/targets.json"})
    check("three polygons, two regions", result["summary"]["polygons"] == 3 and result["summary"]["regions"] == 2)
    check("treasure room region disconnected", op._count(result, "disconnected_region") == 1)
    check("10-unit corridor too narrow for radius 8", op._count(result, "narrow_passage") == 1)
    check("treasure unreachable", op._count(result, "unreachable_target") == 1)
    check("floating coin off mesh", op._count(result, "off_mesh_point") == 1)
    check("corridor end reachable", result["targets"][0]["reachable"])
    check("empty navmesh reported", op.evaluate({"vertices": [], "polygons": []})["issues"][0]["kind"] == "no_navmesh")
    check("missing input is reported", op.run("res://definitely_missing.tres")["issues"][0]["kind"] == "bad_input")
    var r: Dictionary = op.run("res://demo/gameplay/nav.tres", {"targets": "res://demo/gameplay/targets.json"})
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Navigation Mesh Diagnostic Lab TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
