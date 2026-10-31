extends SceneTree
const Core := preload("res://addons/render_compat/core/rcm_matrix.gd")
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
    var compat: Dictionary = op.run("res://demo/perf_static", {"renderer": "gl_compatibility"})
    check("VoxelGI and FogVolume unsupported in Compatibility", op._count(compat, "unsupported_feature") == 2)
    check("reflection probe listed as used", compat["features"].has("ReflectionProbe"))
    check("forward+ supports them", op._count(op.run("res://demo/perf_static", {"renderer": "forward_plus"}), "unsupported_feature") == 0)
    check("custom matrix applies", op._count(op.analyze({"res://a.tscn": "[node name=\"P\" type=\"ReflectionProbe\"]\n"}, {"renderer": "mobile", "matrix_data": {"mobile": ["ReflectionProbe"]}}), "unsupported_feature") == 1)
    check("bad matrix rejected", op.run("res://demo/perf_static", {"matrix": "res://nope.json"})["issues"][0]["kind"] == "bad_matrix")
    check("missing input is reported", op.run("res://definitely_missing_dir_rcm")["issues"][0]["kind"] in ["scan_error", "bad_input"])
    var r: Dictionary = op.run("res://demo/perf_static", {"renderer": "gl_compatibility"})
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Rendering Settings Compatibility Matrix TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
