## Shader Doctor tests.
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

const Analyzer := preload("res://addons/shader_doctor/core/shd_analyzer.gd")


func _init() -> void:
    var op = Analyzer.new()
    var text := FileAccess.get_file_as_string("res://demo/shaders/toon.gdshader")
    var found: Array = op.analyze_shader(text, "res://demo/shaders/toon.gdshader")
    var found_kinds := _kinds(found)
    _check("redundant fetch flagged (gate kind)", found_kinds.has("redundant_fetch"), str(found))
    _check("fetch inside loop flagged", found_kinds.has("fetch_in_loop"))
    _check("unused uniform flagged", found_kinds.has("unused_uniform"))
    var parsed: Dictionary = op.parse_functions(text)
    _check("fragment function parsed", (parsed["functions"] as Array).size() == 1, str(parsed["functions"]))
    _check("three uniforms parsed", (parsed["uniforms"] as Array).size() == 3, str(parsed["uniforms"]))
    var clean: Array = op.analyze_shader("shader_type canvas_item;\n\nvoid fragment() {\n\tCOLOR = vec4(UV, 0.0, 1.0);\n}\n", "clean.gdshader")
    _check("clean shader has no findings", clean.is_empty(), str(clean))
    var branchy := "shader_type canvas_item;\n\nvoid fragment() {\n"
    for i in 7:
        branchy += "\tif (COLOR.r > 0.%d) { COLOR.r += 0.1; }\n" % i
    branchy += "}\n"
    _check("branch-heavy shader reported", _kinds(op.analyze_shader(branchy, "b.gdshader")).has("branch_heavy"))
    var r: Dictionary = op.run()
    _check("project scan sees the fixture shader", int(r["summary"]["shaders"]) >= 1, str(r["summary"]))
    _check("to_markdown renders fixes", op.to_markdown(r).contains("Fix:"))
    _finish("Shader Doctor TESTS")
