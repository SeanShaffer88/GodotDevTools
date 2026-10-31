## Scene Lint Rule Engine - rule-driven scene checks.
## Parses every text scene into nodes (type, name, parent, properties) and
## applies JSON rules. Rule fields: id, match_type ("*" or a node type),
## and one check of require_child_type (string or list), forbid_property,
## require_property (+ optional equals), or name_pattern (regex).
## Instanced nodes have no type in scene text and only match "*". Read-only.
extends RefCounted

const EXTS: Array[String] = ["tscn"]
const DEFAULT_RULES := [
    {"id": "body2d-needs-shape", "match_type": ["CharacterBody2D", "RigidBody2D", "StaticBody2D", "AnimatableBody2D", "Area2D"], "require_child_type": ["CollisionShape2D", "CollisionPolygon2D"]},
    {"id": "body3d-needs-shape", "match_type": ["CharacterBody3D", "RigidBody3D", "StaticBody3D", "AnimatableBody3D", "Area3D"], "require_child_type": ["CollisionShape3D", "CollisionPolygon3D"]},
]
const DEFAULTS := {"rules": ""}


func run(input: String = "res://", options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    var rules: Variant = DEFAULT_RULES
    if str(opts["rules"]) != "":
        rules = _read_json(str(opts["rules"]))
        if typeof(rules) != TYPE_ARRAY:
            return _fail(str(opts["rules"]), "Rules file missing or not a JSON array.", "Pass --rules=<file> containing an array of rule objects.", "bad_rules")
    if DirAccess.open(input) == null:
        return _fail(input, "Cannot open scan directory.", "Provide an existing readable project directory.")
    var paths: Array = []
    _walk(input, paths)
    paths.sort()
    var texts := {}
    for path in paths:
        var file := FileAccess.open(path, FileAccess.READ)
        texts[path] = null if file == null else file.get_as_text()
    return analyze(texts, {"rule_list": rules})


func validate_rules(rules: Array) -> String:
    for r in rules:
        if typeof(r) != TYPE_DICTIONARY or str(r.get("id", "")) == "" or not r.has("match_type"):
            return "Every rule needs an id and match_type."
        var checks := 0
        for k in ["require_child_type", "forbid_property", "require_property", "name_pattern"]:
            if r.has(k):
                checks += 1
        if checks != 1:
            return "Rule %s needs exactly one check field." % r.get("id", "?")
        if r.has("name_pattern") and RegEx.create_from_string(str(r["name_pattern"])) == null:
            return "Rule %s has an invalid name_pattern." % r["id"]
    return ""


func parse_scene(text: String) -> Array:
    var nodes: Array = []
    var current: Dictionary = {}
    var lines := text.split("\n")
    for index in range(lines.size()):
        var s := lines[index].strip_edges()
        if s.begins_with("[node "):
            var name := _attr(s, "name")
            var parent := _attr(s, "parent")
            var path := "." if not s.contains(" parent=") else (name if parent == "." else parent + "/" + name)
            current = {"name": name, "type": _attr(s, "type"), "path": path, "parent": parent if s.contains(" parent=") else "", "props": {}, "line": index + 1}
            nodes.append(current)
        elif s.begins_with("["):
            current = {}
        elif not current.is_empty() and s.contains(" = "):
            current["props"][s.get_slice(" = ", 0)] = s.substr(s.get_slice(" = ", 0).length() + 3)
    return nodes


func analyze(texts: Dictionary, options: Dictionary = {}) -> Dictionary:
    var rules: Array = options.get("rule_list", DEFAULT_RULES)
    var problem := validate_rules(rules)
    if problem != "":
        return _fail("rules", problem, "Fix the rules file; see the addon README for the format.", "bad_rules")
    var issues: Array = []
    var count := 0
    for path in texts.keys():
        if texts[path] == null:
            issues.append(_issue("error", "scan_error", str(path), 0, "Cannot read file.", "Check file permissions and retry."))
            continue
        var nodes := parse_scene(str(texts[path]))
        count += nodes.size()
        for node in nodes:
            for rule in rules:
                var mt: Variant = rule["match_type"]
                var types: Array = mt if typeof(mt) == TYPE_ARRAY else [mt]
                if not ("*" in types or node["type"] in types):
                    continue
                var msg := ""
                if rule.has("require_child_type"):
                    var want: Variant = rule["require_child_type"]
                    var wanted: Array = want if typeof(want) == TYPE_ARRAY else [want]
                    var parent_key: String = node["path"]
                    var found := false
                    for other in nodes:
                        if other["parent"] == parent_key and other["type"] in wanted:
                            found = true
                    if not found:
                        msg = "%s (%s) has no %s child." % [node["path"], node["type"], " or ".join(wanted)]
                elif rule.has("forbid_property"):
                    if node["props"].has(rule["forbid_property"]):
                        msg = "%s sets forbidden property %s." % [node["path"], rule["forbid_property"]]
                elif rule.has("require_property"):
                    var key: String = rule["require_property"]
                    if not node["props"].has(key):
                        msg = "%s does not set %s." % [node["path"], key]
                    elif rule.has("equals") and str(node["props"][key]) != str(rule["equals"]):
                        msg = "%s sets %s = %s, expected %s." % [node["path"], key, node["props"][key], rule["equals"]]
                elif rule.has("name_pattern"):
                    if RegEx.create_from_string(str(rule["name_pattern"])).search(node["name"]) == null:
                        msg = "Node name '%s' does not match %s." % [node["name"], rule["name_pattern"]]
                if msg != "":
                    issues.append(_issue(str(rule.get("severity", "warning")), "rule_violation", str(path), node["line"], "[%s] %s" % [rule["id"], msg], str(rule.get("fix", "Change the scene to satisfy the rule, or adjust the rule if it no longer applies."))))
    return _finish({"scenes": texts.size(), "nodes": count, "rules": rules.size()}, issues)


func _attr(line: String, key: String) -> String:
    var marker := " " + key + "=\""
    var i := line.find(marker)
    if i < 0:
        return ""
    var start := i + marker.length()
    return line.substr(start, line.find("\"", start) - start)


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
            elif name.get_extension().to_lower() in EXTS:
                out.append(child)
        name = dir.get_next()
    dir.list_dir_end()


func _opts(options: Dictionary) -> Dictionary:
    var merged: Dictionary = DEFAULTS.duplicate(true)
    merged.merge(options, true)
    return merged


func _read_json(path: String) -> Variant:
    if not FileAccess.file_exists(path):
        return null
    return JSON.parse_string(FileAccess.get_file_as_string(path))


func _issue(severity: String, kind: String, path: String, line: int, message: String, fix: String) -> Dictionary:
    return {"severity": severity, "kind": kind, "path": path, "line": line, "message": message, "fix": fix}


func _fail(path: String, message: String, fix: String, kind: String = "scan_error") -> Dictionary:
    return {"summary": {"issues": 1}, "issues": [_issue("error", kind, path, 0, message, fix)]}


func _finish(summary: Dictionary, issues: Array, extra: Dictionary = {}) -> Dictionary:
    issues.sort_custom(func(a, b): return "%s|%08d|%s" % [a["path"], int(a["line"]), a["kind"]] < "%s|%08d|%s" % [b["path"], int(b["line"]), b["kind"]])
    summary["issues"] = issues.size()
    var result := {"summary": summary, "issues": issues}
    result.merge(extra)
    return result


func _count(result: Dictionary, kind: String) -> int:
    var n := 0
    for issue in result["issues"]:
        if issue["kind"] == kind:
            n += 1
    return n


func to_json(result: Dictionary) -> String:
    return JSON.stringify(result, "  ")


func to_markdown(result: Dictionary) -> String:
    var lines: Array = ["# Scene Lint Rule Engine", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
