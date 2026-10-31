extends SceneTree
const Core := preload("res://addons/test_priority/core/priority_plan.gd")
const SceneMap := preload("res://addons/scene_dependency/core/sdm_graph.gd")
var passes := 0
var failures := 0

func check(label: String, ok: bool) -> void:
    if ok:
        passes += 1
        print("PASS  ", label)
    else:
        failures += 1
        print("FAIL  ", label)

func kinds(result: Dictionary) -> Array:
    var result_kinds: Array = []
    for issue in result["issues"]:
        result_kinds.append(issue["kind"])
    return result_kinds

func _init() -> void:
    var op = Core.new()
    var fixture: Dictionary = op.run("res://demo/test_priority/mapping.json", "res://demo/test_priority/changes.json")
    check("unmapped path detected", kinds(fixture).has("unmapped_path"))
    check("shared test ranked first", fixture["rows"][0]["test"] == "tests/test_gameplay.gd" and fixture["rows"][0]["score"] == 2)
    var mapping := {"paths": {"a": ["test_b", "test_a", "test_a"]}}
    var plan: Dictionary = op.analyze(mapping, {"changed": ["a", "a"]})
    check("duplicate changes and mappings counted once", plan["rows"].size() == 2 and plan["rows"][0]["score"] == 1)
    check("ties sorted by test name", plan["rows"][0]["test"] == "test_a")
    check("invalid mappings rejected", kinds(op.analyze({"paths": {"a": "test"}}, {"changed": ["a"]})).has("invalid_mapping"))
    check("invalid changed path rejected", kinds(op.analyze(mapping, {"changed": [null]})).has("invalid_path"))
    var graph: Dictionary = SceneMap.new().run("res://demo/dependencies", ["res://demo/dependencies/main.tscn"])
    var graph_mapping := {"paths": {"res://demo/dependencies/main.tscn": ["scene_test"]}}
    var graph_changes := {"changed": ["res://demo/dependencies/material.tres"]}
    var indirect: Dictionary = op.analyze(graph_mapping, graph_changes, graph)
    check("dependency map discovers transitive affected test", indirect["rows"].size() == 1 and indirect["rows"][0]["test"] == "scene_test")
    check("evidence traces chain to mapped scene", indirect["rows"][0]["evidence"][0]["dependency_chain"] == ["res://demo/dependencies/material.tres", "res://demo/dependencies/main.gd", "res://demo/dependencies/main.tscn"])
    var cycle := {"edges": [{"from": "a", "to": "b"}, {"from": "b", "to": "a"}, {"from": "a", "to": "b"}]}
    var cyclic: Dictionary = op.analyze({"paths": {"a": ["test"], "b": ["test"]}}, {"changed": ["a", "b"]}, cycle)
    check("cycles terminate and score unique changes", cyclic["rows"][0]["score"] == 2 and cyclic["rows"][0]["evidence"].size() == 4)
    check("invalid graph rejected", kinds(op.analyze(mapping, {"changed": ["a"]}, {"edges": [{"from": "x"}]})).has("invalid_graph"))
    check("empty mapped test set is not silently covered", kinds(op.analyze({"paths": {"a": []}}, {"changed": ["a"]})).has("unmapped_path"))
    check("missing graph file is an error", kinds(op.run("res://demo/test_priority/mapping.json", "res://demo/test_priority/changes.json", "res://missing_priority_graph.json")).has("input_error"))
    var graph_fixture: Dictionary = op.run("res://demo/test_priority/graph_mapping.json", "res://demo/test_priority/graph_changes.json", "res://demo/test_priority/graph.json")
    check("graph JSON files are supported", graph_fixture["rows"].size() == 1 and graph_fixture["rows"][0]["test"] == "res://tests/test_sdm.gd")
    check("invalid input shape reported", kinds(op.analyze({}, {})).has("input_error"))
    check("missing file reported", kinds(op.run("res://nonexistent_batch_fixture.json", "res://nonexistent_batch_fixture.json")).has("input_error"))
    check("markdown report renders", op.to_markdown(fixture).begins_with("# "))
    check("JSON report parses", JSON.parse_string(op.to_json(fixture)).has("issues"))
    print("test_priority TESTS: %d passed, %d failed" % [passes, failures])
    quit(1 if failures else 0)
