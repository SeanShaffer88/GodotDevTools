extends SceneTree
const Core := preload("res://addons/sarif_export/core/srf_exporter.gd")
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
    var result: Dictionary = op.run("res://demo/suite/after")
    var sarif: Dictionary = JSON.parse_string(result["artifacts"]["gdt.sarif"])
    check("SARIF 2.1.0 with two runs", sarif["version"] == "2.1.0" and sarif["runs"].size() == 2)
    check("four results converted", result["summary"]["results"] == 4)
    check("malformed report skipped and noted", op._count(result, "skipped_report") == 1)
    var np: Dictionary = sarif["runs"].filter(func(r): return r["tool"]["driver"]["name"].ends_with("node_paths"))[0]
    check("location and line mapped", np["results"][0]["locations"][0]["physicalLocation"]["region"]["startLine"] == 17 and np["results"][0]["locations"][0]["physicalLocation"]["artifactLocation"]["uri"] == "player.gd")
    check("info maps to note", JSON.stringify(sarif).contains("\"note\""))
    check("rules listed per kind", np["tool"]["driver"]["rules"].size() == 2)
    check("missing input is reported", op.run("res://definitely_missing_reports")["issues"][0]["kind"] == "bad_input")
    var r: Dictionary = op.run("res://demo/suite/after")
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("SARIF Exporter TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
