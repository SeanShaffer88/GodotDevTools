## Third-Party Notice Collector - license gathering.
## Each immediate subfolder of the input folder is a package. Its license file
## (LICENSE, LICENCE, COPYING, NOTICE, with any extension, searched to two
## levels) is read, identified by keywords (MIT, Apache-2.0, BSD, GPL, LGPL,
## AGPL, MPL, CC0, CC-BY, Zlib, Unlicense), and appended to a notices text in
## the report. Identification is a hint; read each license. Not legal advice.
extends RefCounted

const EXTS: Array[String] = ["txt", "md"]
const DEFAULTS := {}
const NAMES: Array[String] = ["license", "licence", "copying", "notice", "copyright"]
## [keyword, id, copyleft] checked in order.
const KNOWN := [["GNU AFFERO GENERAL PUBLIC LICENSE", "AGPL-3.0", true], ["GNU LESSER GENERAL PUBLIC LICENSE", "LGPL", true],
    ["GNU GENERAL PUBLIC LICENSE", "GPL", true], ["Mozilla Public License", "MPL-2.0", true], ["Apache License", "Apache-2.0", false],
    ["Permission is hereby granted, free of charge", "MIT", false], ["Redistribution and use in source and binary forms", "BSD", false],
    ["CC0", "CC0-1.0", false], ["Creative Commons Attribution", "CC-BY", false], ["This software is provided 'as-is'", "Zlib", false],
    ["This is free and unencumbered software", "Unlicense", false]]


func run(input: String = "res://addons", options: Dictionary = {}) -> Dictionary:
    var dir := DirAccess.open(input)
    if dir == null:
        return _fail(input, "Cannot open folder.", "Pass --dir=<folder of packages>.")
    var packages := {}
    for name in dir.get_directories():
        if name.begins_with("."):
            continue
        var pkg := input.path_join(name)
        packages[pkg] = _find_license(pkg, 0)
    return evaluate(packages)


func _find_license(path: String, depth: int) -> Dictionary:
    var dir := DirAccess.open(path)
    if dir == null:
        return {}
    for f in dir.get_files():
        if f.get_basename().to_lower() in NAMES or f.to_lower() in NAMES:
            return {"file": path.path_join(f), "text": FileAccess.get_file_as_string(path.path_join(f))}
    if depth < 1:
        for d in dir.get_directories():
            var found := _find_license(path.path_join(d), depth + 1)
            if not found.is_empty():
                return found
    return {}


func identify(text: String) -> Array:
    for k in KNOWN:
        if text.to_lower().contains(str(k[0]).to_lower()):
            return [k[1], k[2]]
    return ["unknown", false]


## packages: {package path: {} or {file, text}}
func evaluate(packages: Dictionary) -> Dictionary:
    var issues: Array = []
    var rows: Array = []
    var notice: Array = ["# Third-party notices", ""]
    var names: Array = packages.keys()
    names.sort()
    for pkg in names:
        var lic: Dictionary = packages[pkg]
        if lic.is_empty():
            issues.append(_issue("warning", "missing_license", pkg, 0, "No LICENSE/COPYING/NOTICE file found.", "Find the package's license at its source and add it before shipping; without one you may have no right to redistribute it."))
            rows.append({"package": pkg, "license": "missing"})
            continue
        var id := identify(str(lic["text"]))
        rows.append({"package": pkg, "license": id[0], "file": lic["file"]})
        if id[0] == "unknown":
            issues.append(_issue("info", "unknown_license", lic["file"], 0, "License text not recognized.", "Read it and record its terms."))
        elif id[1]:
            issues.append(_issue("warning", "copyleft_review", lic["file"], 0, "%s (copyleft) license." % id[0], "Review its obligations (source availability, same-license distribution) for how you ship."))
        notice.append("## %s (%s)" % [str(pkg).get_file(), id[0]])
        notice.append("")
        notice.append(str(lic["text"]).strip_edges())
        notice.append("")
    return _finish({"packages": names.size()}, issues, {"packages": rows, "notices_text": "\n".join(notice) + "\n"})


func _markdown_extra(result: Dictionary) -> Array:
    var out: Array = ["| Package | License |", "|---|---|"]
    for r in result.get("packages", []):
        out.append("| `%s` | %s |" % [r["package"], r["license"]])
    out.append("")
    out.append("Full notices text is in the JSON report (`notices_text`).")
    out.append("")
    return out


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
    var lines: Array = ["# Third-Party Notice Collector", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
