## Pre-commit Hook Installer - opt-in local gate.
## Builds a POSIX sh pre-commit hook that runs each configured tool CLI with
## its options through $GODOT (default "godot") and blocks the commit when any
## exits non-zero. The hook carries a marker line; --install writes it only
## when no hook exists or the existing one carries the marker, and
## --uninstall removes only a marked hook. The hook text is always in the
## report artifacts for manual installation.
extends RefCounted

const EXTS: Array[String] = ["json"]
const DEFAULTS := {"install": false, "uninstall": false, "git_dir": "res://.git"}
const MARKER := "# Installed by GodotDevTools pre-commit hook installer"


func run(input: String = "", options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    var cfg: Variant = _read_json(input)
    if typeof(cfg) != TYPE_ARRAY:
        return _fail(input, "Hook config missing or not a JSON array.", "Write [{\"tool\": \"node_paths\", \"args\": \"--fail-on=broken_path\"}].", "bad_config")
    var issues: Array = []
    var steps: Array = []
    for entry in cfg:
        var tool := str(entry.get("tool", "")) if typeof(entry) == TYPE_DICTIONARY else ""
        var cli := _cli_for(tool)
        if cli == "":
            issues.append(_issue("error", "unknown_tool", input, 0, "No CLI found for tool '%s'." % tool, "Use an addon folder name from res://addons."))
            continue
        steps.append({"cli": cli, "args": str(entry.get("args", ""))})
    var hook := hook_text(steps)
    var result := {"steps": steps.size(), "installed": false, "removed": false}
    if opts["install"] or opts["uninstall"]:
        var git := ProjectSettings.globalize_path(str(opts["git_dir"]))
        if DirAccess.open(git) == null:
            issues.append(_issue("error", "no_git_dir", str(opts["git_dir"]), 0, "No git folder here.", "Pass --git-dir=<path to .git>."))
            return _finish(result, issues, {"artifacts": {"pre-commit": hook}})
        DirAccess.make_dir_recursive_absolute(git.path_join("hooks"))
        var path := git.path_join("hooks").path_join("pre-commit")
        var existing := FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
        if existing != "" and not existing.contains(MARKER):
            issues.append(_issue("error", "foreign_hook", path, 0, "A pre-commit hook not written by this tool exists; left untouched.", "Merge the generated hook (report artifact) into it by hand."))
        elif opts["uninstall"]:
            if existing != "":
                DirAccess.remove_absolute(path)
                result["removed"] = true
        else:
            var f := FileAccess.open(path, FileAccess.WRITE)
            f.store_string(hook)
            f.close()
            if OS.get_name() != "Windows":
                OS.execute("chmod", ["+x", path])
            result["installed"] = true
    return _finish(result, issues, {"artifacts": {"pre-commit": hook}})


func _cli_for(tool: String) -> String:
    if tool == "" or tool.contains("/") or tool.contains(".."):
        return ""
    var dir := DirAccess.open("res://addons/%s/cli" % tool)
    if dir == null:
        return ""
    for f in dir.get_files():
        if f.ends_with("_cli.gd"):
            return "res://addons/%s/cli/%s" % [tool, f]
    return ""


func hook_text(steps: Array) -> String:
    var lines: Array = ["#!/bin/sh", MARKER, "# Runs GodotDevTools checks before each commit. Skip once with: git commit --no-verify",
        "GODOT=\"${GODOT:-godot}\"", "ROOT=\"$(git rev-parse --show-toplevel)\"", "status=0"]
    for s in steps:
        lines.append("\"$GODOT\" --headless --path \"$ROOT\" --script %s -- %s || status=1" % [s["cli"], s["args"]])
    lines.append("if [ \"$status\" -ne 0 ]; then echo \"GodotDevTools pre-commit checks failed (see output above).\"; fi")
    lines.append("exit $status")
    return "\n".join(lines) + "\n"


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
    var lines: Array = ["# Pre-commit Hook Installer", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
