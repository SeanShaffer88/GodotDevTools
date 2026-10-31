extends SceneTree
const Core := preload("res://addons/suite_dispatcher/core/gdt_registry.gd")
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
    var result: Dictionary = op.run("res://addons")
    check("discovers the whole suite", result["summary"]["tools"] >= 100)
    check("titles read from plugin.cfg", result["tools"]["node_paths"]["title"] == "Node Path Breakage Detector")
    check("exact name resolves", op.resolve(result["tools"], "node_paths") == "node_paths")
    check("unique prefix resolves", op.resolve(result["tools"], "mutation") == "mutation_tester")
    check("ambiguous prefix refused", op.resolve(result["tools"], "audio") == "")
    var code: int = op.dispatch(result["tools"]["node_paths"]["cli"], ["--dir=res://demo/code_health", "--fail-on=broken_path"])
    check("dispatch passes options and returns exit 2", code == 2)
    check("missing input is reported", op.run("res://definitely_missing_addons")["issues"][0]["kind"] == "bad_input")
    var r: Dictionary = op.run("res://addons")
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Suite CLI Dispatcher TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
