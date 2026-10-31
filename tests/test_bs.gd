extends SceneTree
const Analyzer := preload("res://addons/build_size/core/bs_analyzer.gd")
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
    var out: Array = []
    for issue in result["issues"]:
        out.append(issue["kind"])
    return out

func _init() -> void:
    var op = Analyzer.new()
    var fixture: Dictionary = op.run("res://demo/build_size", 1)
    check("fixture scans two files", fixture["summary"]["files"] == 2)
    check("file budget catches fixture", kinds(fixture).count("file_budget") == 2)
    check("root and folder accounted", fixture["groups"].has("(root)") and fixture["groups"].has("assets"))
    var rows := [{"path": "assets/a.PNG", "bytes": 30}, {"path": "main.pck", "bytes": 10}, {"path": "assets/b.png", "bytes": 20}]
    var result: Dictionary = op.analyze(rows, 20, 59)
    check("totals sum actual bytes", result["summary"]["bytes"] == 60)
    check("folder grouping sums", result["groups"]["assets"] == 50 and result["groups"]["(root)"] == 10)
    check("extension grouping ignores case", result["extensions"]["png"] == 50)
    check("file sorting largest first", result["files"][0]["path"] == "assets/a.PNG")
    check("budgets are strict", kinds(result).count("file_budget") == 1 and kinds(result).has("total_budget"))
    check("budget boundary passes", op.analyze(rows, 30, 60)["issues"].is_empty())
    check("zero disables budgets", op.analyze(rows)["issues"].is_empty())
    check("invalid budget reported", kinds(op.analyze(rows, -1)).has("invalid_budget"))
    check("invalid row reported", kinds(op.analyze([{"path": "x", "bytes": -2}])).has("invalid_entry"))
    check("missing directory reported", kinds(op.run("res://missing_build_size_fixture")).has("scan_error"))
    check("markdown reports file", op.to_markdown(result).contains("assets/a.PNG"))
    check("json parses", JSON.parse_string(op.to_json(result)).has("groups"))
    print("Build Size Explorer TESTS: %d passed, %d failed" % [passes, failures])
    quit(1 if failures else 0)
