extends SceneTree
const Core := preload("res://addons/mesh_stats/core/msr_report.gd")
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
    var result: Dictionary = op.run("res://demo/rendering")
    var f: Dictionary = result["files"][0]
    check("one glTF read", result["summary"]["files"] == 1)
    check("two primitives of 3200 triangles", f["triangles"] == 6400 and f["primitives"] == 2)
    check("vertices counted per primitive", f["vertices"] == 3362)
    check("two materials", f["materials"] == 2)
    check("default budgets pass", result["issues"].is_empty())
    check("triangle budget enforced", op._count(op.run("res://demo/rendering", {"max_triangles": 5000}), "triangle_budget") == 1)
    var glb := PackedByteArray()
    var js := JSON.stringify({"asset": {"version": "2.0"}, "meshes": [{"primitives": [{"attributes": {"POSITION": 0}}]}], "accessors": [{"count": 9}]}).to_utf8_buffer()
    while js.size() % 4 != 0:
        js.append(32)
    glb.resize(20)
    glb[0] = 103; glb[1] = 108; glb[2] = 84; glb[3] = 70
    glb.encode_u32(4, 2)
    glb.encode_u32(8, 20 + js.size())
    glb.encode_u32(12, js.size())
    glb[16] = 74; glb[17] = 83; glb[18] = 79; glb[19] = 78
    glb.append_array(js)
    check("GLB container parsed; non-indexed triangles", op.analyze({"res://a.glb": op.gltf_json(glb, true)})["files"][0]["triangles"] == 3)
    check("unreadable glTF reported", op.analyze({"res://b.gltf": null})["issues"][0]["kind"] == "bad_gltf")
    check("missing input is reported", op.run("res://definitely_missing_dir_msr")["issues"][0]["kind"] in ["scan_error", "bad_input"])
    var r: Dictionary = op.run("res://demo/rendering")
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Mesh Statistics Report TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
