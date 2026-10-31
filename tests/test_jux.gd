extends SceneTree
const Core := preload("res://addons/junit_export/core/jux_exporter.gd")
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

func _parses(p: XMLParser) -> bool:
    while true:
        var e := p.read()
        if e == ERR_FILE_EOF:
            return true
        if e != OK:
            return false
    return true

func _init() -> void:
    var result: Dictionary = op.run("res://demo/suite/after")
    var xml: String = result["artifacts"]["gdt-junit.xml"]
    check("two suites", result["summary"]["suites"] == 2)
    check("info finding below warning level is not a failure", result["summary"]["failures"] == 3)
    check("special characters escaped", xml.contains("&lt;b&gt;anywhere&lt;/b&gt; &amp; unused") == false and not xml.contains("<b>"))
    var parser := XMLParser.new()
    check("output is well-formed XML", parser.open_buffer(xml.to_utf8_buffer()) == OK and _parses(parser))
    check("info level includes everything", op.run("res://demo/suite/after", {"fail_level": "info"})["summary"]["failures"] == 4)
    check("clean tool gets a passing case", op.evaluate({"t": {"issues": []}})["artifacts"]["gdt-junit.xml"].contains("name=\"clean\""))
    check("missing input is reported", op.run("res://definitely_missing_reports")["issues"][0]["kind"] == "bad_input")
    var r: Dictionary = op.run("res://demo/suite/after")
    check("markdown renders", op.to_markdown(r).begins_with("# "))
    check("json parses", JSON.parse_string(op.to_json(r)) is Dictionary)
    print("JUnit Exporter TESTS: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
