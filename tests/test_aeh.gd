extends SceneTree
const Core := preload("res://addons/art_handoff/core/aeh_validator.gd")
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
    var result: Dictionary = op.run("res://demo/workflow/handoff")
    check("unapplied 100x scale", op._count(result, "unapplied_scale") == 1)
    check("100 m crate is not suspicious, default names are", op._count(result, "size_suspect") == 0 and op._count(result, "default_name") == 2)
    check("oversized model flagged at a 50 m limit", op._count(op.run("res://demo/workflow/handoff", {"max_size": 50.0}), "size_suspect") == 1)
    var tex := {"res://t.gltf": {"nodes": [{"name": "Wall-colonl", "mesh": 0}], "meshes": [{"primitives": [{"attributes": {"POSITION": 0}, "material": 0}]}], "accessors": [{"min": [0, 0, 0], "max": [1, 1, 1]}], "materials": [{"name": "brick", "pbrMetallicRoughness": {"baseColorTexture": {"index": 0}}}]}}
    var t: Dictionary = op.evaluate(tex)
    check("textured mesh without UVs", op._count(t, "missing_uv") == 1)
    check("misspelt import suffix", op._count(t, "unknown_suffix") == 1)
    check("missing input is reported", op.run("res://definitely_missing_dir_aeh")["issues"][0]["kind"] in ["scan_error", "bad_input"])
    var r: Dictionary = op.run("res://demo/workflow/handoff")
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Art-to-Engine Handoff Validator TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
