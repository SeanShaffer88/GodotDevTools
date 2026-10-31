extends SceneTree
const Core := preload("res://addons/html_dashboard/core/hdb_builder.gd")
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
    var html: String = result["artifacts"]["dashboard.html"]
    check("two tools summarized", result["summary"]["tools"] == 2)
    check("severity totals", result["summary"]["errors"] == 1 and result["summary"]["warnings"] == 2 and result["summary"]["infos"] == 1)
    check("HTML escaped", html.contains("&lt;b&gt;anywhere&lt;/b&gt; &amp; unused") and not html.contains("<b>anywhere"))
    check("no external resources", not html.contains("http://") and not html.contains("src=") and not html.contains("<link"))
    check("dark mode supported", html.contains("prefers-color-scheme: dark"))
    check("custom title", op.run("res://demo/suite/after", {"title": "Nightly"})["artifacts"]["dashboard.html"].contains("<title>Nightly</title>"))
    check("missing input is reported", op.run("res://definitely_missing_reports")["issues"][0]["kind"] == "bad_input")
    var r: Dictionary = op.run("res://demo/suite/after")
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("Static HTML Dashboard TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
