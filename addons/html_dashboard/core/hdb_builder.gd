## Static HTML Dashboard - offline summary page.
## Builds one HTML file with inline CSS and a few lines of inline script (no
## network, no external files): a table of tools with error / warning / info
## counts, then each tool's findings in a collapsible section, with a
## severity filter. Follows the system light/dark preference.
extends RefCounted

const EXTS: Array[String] = ["json"]
## Reports folder -> {"reports": {tool: report}, "skipped": [path]}. A report is
## <dir>/<tool>/<tool>.json holding a dictionary with an "issues" array.
func load_reports(dir_path: String, skip: Array = []) -> Dictionary:
    var out := {"reports": {}, "skipped": []}
    var dir := DirAccess.open(dir_path)
    if dir == null:
        return out
    var names: Array = Array(dir.get_directories())
    names.sort()
    for tool in names:
        if tool in skip or tool.begins_with("."):
            continue
        var p := dir_path.path_join(tool).path_join(tool + ".json")
        if not FileAccess.file_exists(p):
            continue
        var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
        if typeof(data) == TYPE_DICTIONARY and typeof(data.get("issues")) == TYPE_ARRAY and data["issues"].all(func(i): return _valid_issue(i)):
            out["reports"][tool] = data
        else:
            out["skipped"].append(p)
    return out


func _valid_issue(i: Variant) -> bool:
    return typeof(i) == TYPE_DICTIONARY and str(i.get("severity", "")) in ["error", "warning", "info"] and i.has("kind") and i.has("message")

func run(input: String = "res://reports", options: Dictionary = {}) -> Dictionary:
    if DirAccess.open(input) == null:
        return _fail(input, "Reports folder not found.", "Run some tool CLIs first, then pass --reports=<folder>.", "bad_input")
    var loaded := load_reports(input, [SELF])
    return evaluate(loaded["reports"], loaded["skipped"], _opts(options))

const DEFAULTS := {"title": "GodotDevTools report"}
const SELF := "html_dashboard"


func _h(s: Variant) -> String:
    return str(s).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;")


func evaluate(reports: Dictionary, skipped: Array = [], options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    var issues: Array = []
    for p in skipped:
        issues.append(_issue("info", "skipped_report", p, 0, "Not a valid report; left off the dashboard.", "Validate it with the Report Schema tool."))
    var tools: Array = reports.keys()
    tools.sort()
    var rows: Array = []
    var sections: Array = []
    var totals := {"error": 0, "warning": 0, "info": 0}
    for tool in tools:
        var c := {"error": 0, "warning": 0, "info": 0}
        var items: Array = []
        for i in reports[tool]["issues"]:
            if not _valid_issue(i):
                continue
            c[i["severity"]] += 1
            totals[i["severity"]] += 1
            var loc := _h(i.get("path", ""))
            if int(i.get("line", 0)) > 0:
                loc += ":%d" % int(i["line"])
            items.append("<li class=\"%s\"><span class=\"sev\">%s</span> <code>%s</code> <b>%s</b> %s <i>%s</i></li>" % [i["severity"], i["severity"], loc, _h(i["kind"]), _h(i["message"]), _h(i.get("fix", ""))])
        rows.append("<tr><td><a href=\"#%s\">%s</a></td><td class=\"n error\">%d</td><td class=\"n warning\">%d</td><td class=\"n info\">%d</td></tr>" % [_h(tool), _h(tool), c["error"], c["warning"], c["info"]])
        sections.append("<details id=\"%s\"%s><summary>%s (%d)</summary><ul>%s</ul></details>" % [_h(tool), " open" if c["error"] + c["warning"] > 0 else "", _h(tool), items.size(), "".join(items) if not items.is_empty() else "<li>No findings.</li>"])
    var page := """<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>%s</title>
<style>
:root{--bg:#fff;--fg:#1b1b1f;--muted:#5b5b66;--line:#ddd;--err:#b3261e;--warn:#8a5a00;--info:#1f5fa8}
@media (prefers-color-scheme: dark){:root{--bg:#141418;--fg:#ececf1;--muted:#a3a3b0;--line:#33333b;--err:#ff8a80;--warn:#ffcc66;--info:#8ab4ff}}
body{background:var(--bg);color:var(--fg);font:15px/1.5 system-ui,sans-serif;margin:0 auto;max-width:1100px;padding:16px}
h1{font-size:1.4rem}table{border-collapse:collapse;width:100%%}td,th{border-bottom:1px solid var(--line);padding:6px 8px;text-align:left}
.n{text-align:right;font-variant-numeric:tabular-nums}.error{color:var(--err)}.warning{color:var(--warn)}.info{color:var(--info)}
details{border:1px solid var(--line);border-radius:6px;margin:8px 0;padding:6px 10px}summary{cursor:pointer;font-weight:600}
li{margin:4px 0;color:var(--fg)}li .sev{font-weight:600;text-transform:uppercase;font-size:.75rem}li.error .sev{color:var(--err)}li.warning .sev{color:var(--warn)}li.info .sev{color:var(--info)}
i{color:var(--muted)}code{overflow-wrap:anywhere}label{margin-right:12px}
</style></head><body>
<h1>%s</h1>
<p>%d tools &middot; <span class="error">%d errors</span> &middot; <span class="warning">%d warnings</span> &middot; <span class="info">%d info</span></p>
<p><label><input type="checkbox" checked data-sev="error"> errors</label><label><input type="checkbox" checked data-sev="warning"> warnings</label><label><input type="checkbox" checked data-sev="info"> info</label></p>
<table><thead><tr><th>Tool</th><th class="n">Errors</th><th class="n">Warnings</th><th class="n">Info</th></tr></thead><tbody>%s</tbody></table>
%s
<script>
document.querySelectorAll('input[data-sev]').forEach(function(box){box.addEventListener('change',function(){
document.querySelectorAll('li.'+box.dataset.sev).forEach(function(li){li.style.display=box.checked?'':'none';});});});
</script>
</body></html>
""" % [_h(opts["title"]), _h(opts["title"]), tools.size(), totals["error"], totals["warning"], totals["info"], "".join(rows), "\n".join(sections)]
    return _finish({"tools": tools.size(), "errors": totals["error"], "warnings": totals["warning"], "infos": totals["info"]}, issues, {"artifacts": {"dashboard.html": page}})


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
    var lines: Array = ["# Static HTML Dashboard", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
