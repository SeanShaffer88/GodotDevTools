## Read-only, literal marker scanner. Findings are review candidates, not proof of export inclusion.
extends RefCounted

const DEFAULT_RULES := [
    {"marker": "DEBUG_MENU", "kind": "debug_marker", "severity": "warning"},
    {"marker": "PLACEHOLDER", "kind": "placeholder", "severity": "warning"},
    {"marker": "TEST_ONLY", "kind": "test_content", "severity": "warning"},
]
const EXTENSIONS := ["gd", "cs", "tscn", "tres", "txt", "json", "cfg", "ini", "csv", "po"]

func _walk(path: String, out: Array) -> void:
    var dir := DirAccess.open(path)
    if dir == null:
        return
    dir.list_dir_begin()
    var name := dir.get_next()
    while name != "":
        if not name.begins_with(".") and name not in ["addons", "reports", "visual_reports"]:
            var child := path.path_join(name)
            if dir.current_is_dir():
                _walk(child, out)
            elif name.get_extension().to_lower() in EXTENSIONS:
                out.append(child)
        name = dir.get_next()
    dir.list_dir_end()

func run(scan_dir: String = "res://", rules: Array = DEFAULT_RULES) -> Dictionary:
    if DirAccess.open(scan_dir) == null:
        var problem := {"severity": "error", "kind": "scan_error", "path": scan_dir, "message": "Cannot open scan directory.", "fix": "Provide an existing readable project directory."}
        return {"summary": {"files": 0, "issues": 1}, "issues": [problem]}
    var paths: Array = []
    _walk(scan_dir, paths)
    paths.sort()
    var files := {}
    for path in paths:
        var file := FileAccess.open(path, FileAccess.READ)
        if file == null:
            files[path] = null
        else:
            files[path] = file.get_as_text()
    return analyze(files, rules)

## Input is a path-to-text dictionary. A null value represents a read error.
func analyze(files: Dictionary, rules: Array = DEFAULT_RULES) -> Dictionary:
    var issues: Array = []
    var paths: Array = files.keys()
    paths.sort()
    for path in paths:
        if files[path] == null:
            issues.append({"severity": "error", "kind": "scan_error", "path": str(path), "message": "Cannot read file.", "fix": "Check file permissions and retry."})
            continue
        var lines := str(files[path]).split("\n")
        for index in range(lines.size()):
            for rule in rules:
                var marker := str(rule.get("marker", ""))
                if marker != "" and lines[index].contains(marker):
                    issues.append({"severity": str(rule.get("severity", "warning")), "kind": str(rule.get("kind", "marker")), "path": str(path), "line": index + 1, "message": "Review marker '%s' on line %d." % [marker, index + 1], "fix": "Review whether this content belongs in the release; remove or replace it if needed."})
    return {"summary": {"files": paths.size(), "issues": issues.size()}, "issues": issues}

func to_json(result: Dictionary) -> String:
    return JSON.stringify(result, "  ")

func to_markdown(result: Dictionary) -> String:
    var lines: Array[String] = ["# Demo-to-Release Content Guard", "", "Summary: " + str(result["summary"]), "", "## Findings"]
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue.get("line", "-"), issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
