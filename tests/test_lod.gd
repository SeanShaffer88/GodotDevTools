extends SceneTree
const Core := preload("res://addons/lod_planner/core/lod_planner.gd")
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
    check("inverted range on the tower", op._count(result, "invalid_range") == 1 and _has(result, "invalid_range", 7))
    check("heavy terrain instance without range", op._count(result, "no_visibility_range") == 1)
    check("terrain measured", result["summary"]["models_measured"] == 1)
    check("triangle count from glTF metadata", op.triangles(FileAccess.get_file_as_bytes("res://demo/rendering/terrain.gltf"), false) == 6400)
    check("disabled LOD import noted", op._count(op.analyze({"res://a.glb.import": "[params]\nmeshes/generate_lods=false\n"}), "lods_disabled") == 1)
    check("threshold configurable", op._count(op.run("res://demo/perf_static", {"heavy_triangles": 100000}), "no_visibility_range") == 0)
    check("missing input is reported", op.run("res://definitely_missing_dir_lod")["issues"][0]["kind"] in ["scan_error", "bad_input"])
    var r: Dictionary = op.run("res://demo/perf_static")
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("LOD and Visibility Range Planner TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
