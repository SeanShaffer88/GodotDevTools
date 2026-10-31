## Unused Signal and Method Finder - reference counting.
## Collects signal and function declarations from GDScript, then counts word
## references to each name across every scanned script and scene (scene
## [connection] entries count). Engine callbacks are skipped. A name used
## only at its declaration is a candidate for removal. Read-only.
extends RefCounted

const EXTS: Array[String] = ["gd", "tscn", "tres"]
const DEFAULTS := {"include_private": true}
## Engine virtuals called by Godot itself, never by user code.
const ENGINE_CALLBACKS: Array[String] = ["_ready", "_process", "_physics_process", "_input", "_unhandled_input",
    "_unhandled_key_input", "_enter_tree", "_exit_tree", "_notification", "_init", "_draw", "_gui_input",
    "_get_configuration_warnings", "_integrate_forces", "_to_string", "_get", "_set", "_get_property_list",
    "_validate_property", "_can_drop_data", "_drop_data", "_get_drag_data", "_has_point", "_make_custom_tooltip",
    "_shortcut_input", "_run", "_enter", "_exit", "_static_init", "_property_can_revert", "_property_get_revert",
    "_structured_text_parser", "_get_minimum_size", "_clips_input", "_iter_init", "_iter_next", "_iter_get"]

var _signal_re := RegEx.create_from_string("^\\s*signal\\s+([A-Za-z_][A-Za-z0-9_]*)")
var _func_re := RegEx.create_from_string("^\\s*(?:static\\s+)?func\\s+([A-Za-z_][A-Za-z0-9_]*)")
var _word_re := RegEx.create_from_string("[A-Za-z_][A-Za-z0-9_]*")


func analyze(texts: Dictionary, options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    var issues: Array = []
    var counts := {}
    var emits := {}
    var connects := {}
    var decls: Array = []
    var emit_re := RegEx.create_from_string("([A-Za-z_][A-Za-z0-9_]*)\\.emit\\(|emit_signal\\(\\s*[&]?\"([A-Za-z_][A-Za-z0-9_]*)\"")
    var connect_re := RegEx.create_from_string("([A-Za-z_][A-Za-z0-9_]*)\\.connect\\(|connect\\(\\s*[&]?\"([A-Za-z_][A-Za-z0-9_]*)\"|\\[connection signal=\"([A-Za-z_][A-Za-z0-9_]*)\"")
    for path in texts.keys():
        if texts[path] == null:
            issues.append(_issue("error", "scan_error", str(path), 0, "Cannot read file.", "Check file permissions and retry."))
            continue
        var lines := str(texts[path]).split("\n")
        var is_gd := str(path).get_extension() == "gd"
        for index in range(lines.size()):
            var line: String = lines[index]
            var code := line.get_slice("#", 0) if is_gd and not line.contains("\"") else line
            if is_gd:
                var sm := _signal_re.search(code)
                if sm != null:
                    decls.append({"kind": "signal", "name": sm.get_string(1), "path": str(path), "line": index + 1})
                var fm := _func_re.search(code)
                if fm != null:
                    decls.append({"kind": "func", "name": fm.get_string(1), "path": str(path), "line": index + 1})
            for w in _word_re.search_all(code):
                var word := w.get_string()
                counts[word] = int(counts.get(word, 0)) + 1
            for m in emit_re.search_all(code):
                emits[m.get_string(1) if m.get_string(1) != "" else m.get_string(2)] = true
            for m in connect_re.search_all(code):
                for g in [1, 2, 3]:
                    if m.get_string(g) != "":
                        connects[m.get_string(g)] = true
    var decl_counts := {}
    for d in decls:
        decl_counts[d["name"]] = int(decl_counts.get(d["name"], 0)) + 1
    var signals := 0
    var funcs := 0
    for d in decls:
        var name: String = d["name"]
        var others: int = int(counts.get(name, 0)) - int(decl_counts[name])
        if d["kind"] == "signal":
            signals += 1
            if not emits.has(name):
                issues.append(_issue("warning", "never_emitted", d["path"], d["line"], "Signal `%s` is never emitted." % name, "Emit it where the event happens, or delete the declaration and its connections."))
            elif not connects.has(name) and others <= 1:
                issues.append(_issue("info", "never_connected", d["path"], d["line"], "Signal `%s` is emitted but nothing connects to it." % name, "Connect a listener or remove the signal if it is no longer part of the API."))
        else:
            funcs += 1
            if name in ENGINE_CALLBACKS or (name.begins_with("_") and not opts["include_private"]):
                continue
            if others <= 0:
                issues.append(_issue("info", "unused_function", d["path"], d["line"], "Function `%s` is not referenced anywhere scanned." % name, "Delete it if nothing calls it by a runtime-built name; public API used by other projects is an exception."))
    return _finish({"files": texts.size(), "signals": signals, "functions": funcs}, issues)

func run(input: String = "res://", options: Dictionary = {}) -> Dictionary:
    if DirAccess.open(input) == null:
        return _fail(input, "Cannot open scan directory.", "Provide an existing readable project directory.")
    var paths: Array = []
    _walk(input, paths)
    paths.sort()
    var texts := {}
    for path in paths:
        var file := FileAccess.open(path, FileAccess.READ)
        texts[path] = null if file == null else file.get_as_text()
    return analyze(texts, options)


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
    var lines: Array = ["# Unused Signal and Method Finder", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
