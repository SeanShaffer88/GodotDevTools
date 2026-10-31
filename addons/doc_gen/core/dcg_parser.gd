## Automated Documentation Generator for GDScript - parse operation.
## Parses GDScript source text into API facts - class name, extends,
## the ## doc comment attached to each declaration, signals, @export
## variables, constants, and functions with typed parameters, defaults
## and return types - then renders them as Markdown and as a minimal
## dependency-free HTML page. run() scans the project and reports
## public functions and exports that carry no doc comment
## (undocumented), because a generator that prints empty descriptions is
## just a prettier way of having no docs. Parsing is line-based on
## purpose: it never executes or imports the scripts it documents, so it
## stays safe on broken, half-written or circular code.
extends RefCounted

var documented := 0
var undocumented := 0


func find_scripts(include_addons: bool = true) -> Array:
    var out: Array = []
    _walk("res://", out, include_addons)
    out.sort()
    return out


func _walk(dir_path: String, out: Array, include_addons: bool) -> void:
    var dir := DirAccess.open(dir_path)
    if dir == null:
        return
    dir.list_dir_begin()
    var name := dir.get_next()
    while name != "":
        if name.begins_with("."):
            name = dir.get_next()
            continue
        var full := dir_path.path_join(name)
        if dir.current_is_dir():
            if name != ".godot" and (include_addons or name != "addons"):
                _walk(full, out, include_addons)
        elif name.get_extension() == "gd":
            out.append(full)
        name = dir.get_next()
    dir.list_dir_end()


## Parse one script's text into its API record.
func parse_script(text: String, path: String) -> Dictionary:
    var record := {"path": path, "class_name": "", "extends": "", "doc": [],
        "signals": [], "exports": [], "constants": [], "functions": []}
    var pending_doc: Array[String] = []
    var class_doc_done := false
    for raw in text.split("\n"):
        var line := raw.strip_edges()
        if line.begins_with("##"):
            pending_doc.append(line.trim_prefix("##").strip_edges())
            continue
        if line == "" or line.begins_with("#"):
            if line == "":
                pending_doc = []
            continue
        if line.begins_with("class_name "):
            record["class_name"] = line.trim_prefix("class_name ").strip_edges()
            if not class_doc_done:
                record["doc"] = pending_doc.duplicate()
                class_doc_done = true
            pending_doc = []
            continue
        if line.begins_with("extends "):
            record["extends"] = line.trim_prefix("extends ").strip_edges()
            if not class_doc_done:
                record["doc"] = pending_doc.duplicate()
                class_doc_done = true
            pending_doc = []
            continue
        if line.begins_with("signal "):
            var rest := line.trim_prefix("signal ")
            var sname := rest.substr(0, rest.find("(")) if "(" in rest else rest
            (record["signals"] as Array).append({"name": sname.strip_edges(),
                "args": _args(rest), "doc": pending_doc.duplicate()})
            pending_doc = []
            continue
        if line.begins_with("@export"):
            var decl := line
            if " var " in decl:
                decl = decl.substr(decl.find(" var ") + 5)
            (record["exports"] as Array).append(_parse_var(decl, pending_doc))
            pending_doc = []
            continue
        if line.begins_with("const "):
            var crest := line.trim_prefix("const ")
            var eq := crest.find(" = ")
            var cname := crest.substr(0, eq) if eq > 0 else crest.trim_suffix(":")
            (record["constants"] as Array).append({"name": cname.strip_edges(),
                "value": crest.substr(eq + 3) if eq > 0 else "", "doc": pending_doc.duplicate()})
            pending_doc = []
            continue
        if line.begins_with("func "):
            (record["functions"] as Array).append(_parse_func(line, pending_doc))
            pending_doc = []
            continue
        if line.begins_with("var ") and not class_doc_done:
            pass
        if not line.begins_with("var ") and not line.begins_with("@"):
            pending_doc = []
    return record


func _args(decl: String) -> Array:
    var open := decl.find("(")
    if open < 0:
        return []
    var close := _matching(decl, open)
    if close <= open:
        return []
    var inner := decl.substr(open + 1, close - open - 1).strip_edges()
    if inner == "":
        return []
    var out: Array = []
    for part in _split_top(inner):
        var piece := str(part).strip_edges()
        var colon := piece.find(":")
        var eq := piece.find("=")
        var pname := piece.substr(0, colon) if colon > 0 else (piece.substr(0, eq) if eq > 0 else piece)
        out.append({"name": pname.strip_edges(),
            "type": piece.substr(colon + 1, eq - colon - 1).strip_edges() if colon > 0 and eq > colon else (piece.substr(colon + 1).strip_edges() if colon > 0 else ""),
            "default": piece.substr(eq + 1).strip_edges() if eq > 0 else ""})
    return out


func _matching(s: String, open_idx: int) -> int:
    var depth := 0
    for i in range(open_idx, s.length()):
        if s[i] == "(":
            depth += 1
        elif s[i] == ")":
            depth -= 1
            if depth == 0:
                return i
    return -1


## Split on commas that are not inside (), [] or "".
func _split_top(s: String) -> Array:
    var out: Array = []
    var depth := 0
    var in_string := false
    var current := ""
    for i in s.length():
        var ch := s[i]
        if ch == "\"" and (i == 0 or s[i - 1] != "\\"):
            in_string = not in_string
        if not in_string:
            if ch in ["(", "["]:
                depth += 1
            elif ch in [")", "]"]:
                depth -= 1
            elif ch == "," and depth == 0:
                out.append(current)
                current = ""
                continue
        current += ch
    if current.strip_edges() != "":
        out.append(current)
    return out


func _parse_var(decl: String, doc: Array) -> Dictionary:
    var eq := _top_eq(decl)
    var head := decl.substr(0, eq) if eq > 0 else decl
    var colon := head.find(":")
    var vname := head.substr(0, colon) if colon > 0 else head
    var vtype := head.substr(colon + 1).strip_edges() if colon > 0 else ""
    return {"name": vname.strip_edges(), "type": vtype,
        "default": decl.substr(eq + 1).strip_edges() if eq > 0 else "", "doc": doc.duplicate()}


func _top_eq(decl: String) -> int:
    var depth := 0
    for i in decl.length():
        var ch := decl[i]
        if ch in ["(", "["]:
            depth += 1
        elif ch in [")", "]"]:
            depth -= 1
        elif ch == "=" and depth == 0:
            if i + 1 < decl.length() and decl[i + 1] == "=":
                return -1
            if i > 0 and decl[i - 1] in ["!", "<", ">"]:
                return -1
            return i
    return -1


func _parse_func(line: String, doc: Array) -> Dictionary:
    var decl := line.trim_prefix("func ").strip_edges()
    var open := decl.find("(")
    var fname := decl.substr(0, open) if open > 0 else decl.trim_suffix(":")
    var returns := ""
    var arrow := decl.find("->")
    if arrow > 0:
        returns = decl.substr(arrow + 2).trim_suffix(":").strip_edges()
    return {"name": fname.strip_edges(), "args": _args(decl), "returns": returns,
        "doc": doc.duplicate()}


## The one operation: parse scripts (given, or discovered) and report
## public API with no doc comment.
func run(scripts: Array = []) -> Dictionary:
    var records: Array = []
    var issues: Array = []
    var paths := scripts
    if paths.is_empty():
        paths = find_scripts()
    documented = 0
    undocumented = 0
    for path in paths:
        var text := ""
        if str(path).begins_with("res://") or str(path).begins_with("/"):
            text = FileAccess.get_file_as_string(str(path))
        else:
            var dict_path: Dictionary = path
            text = str(dict_path.get("text", ""))
        var record_path := str(path) if not (path is Dictionary) else str((path as Dictionary).get("path", "?"))
        var record := parse_script(text, record_path)
        records.append(record)
        for fn in record["functions"]:
            var f: Dictionary = fn
            if str(f["name"]).begins_with("_"):
                continue
            if (f["doc"] as Array).is_empty():
                undocumented += 1
                issues.append({"severity": "info", "kind": "undocumented", "path": record_path,
                    "message": "Public function %s() in %s has no ## doc comment." % [f["name"], record_path],
                    "fix": "Add ## lines above the declaration - this generator prints them verbatim."})
            else:
                documented += 1
        for ex in record["exports"]:
            var e: Dictionary = ex
            if (e["doc"] as Array).is_empty():
                undocumented += 1
                issues.append({"severity": "info", "kind": "undocumented", "path": record_path,
                    "message": "@export %s in %s has no ## doc comment." % [e["name"], record_path],
                    "fix": "Exports face designers in the Inspector; document what the number means."})
            else:
                documented += 1
    return {"summary": {"scripts": records.size(), "documented": documented,
            "undocumented": undocumented, "issues": issues.size()},
        "records": records, "issues": issues}


func render_markdown(result: Dictionary) -> String:
    var lines: Array[String] = ["# GDScript API Documentation", "",
        "Generated by doc_gen from ## comments in source. %d script(s)." % result["summary"]["scripts"], ""]
    for record in result["records"]:
        var r: Dictionary = record
        lines.append("## %s" % (str(r["class_name"]) if str(r["class_name"]) != "" else r["path"]))
        lines.append("")
        lines.append("`%s` extends `%s`" % [r["path"], r["extends"]])
        for d in r["doc"]:
            lines.append("")
            lines.append(str(d))
        lines.append("")
        if not (r["signals"] as Array).is_empty():
            lines.append("### Signals")
            for s in r["signals"]:
                var sig: Dictionary = s
                lines.append("- `%s(%s)` - %s" % [sig["name"], _arg_text(sig["args"]),
                    " ".join(sig["doc"])])
        if not (r["exports"] as Array).is_empty():
            lines.append("")
            lines.append("### Exports")
            for e in r["exports"]:
                var ex: Dictionary = e
                lines.append("- `%s: %s = %s` - %s" % [ex["name"], ex["type"], ex["default"],
                    " ".join(ex["doc"])])
        if not (r["functions"] as Array).is_empty():
            lines.append("")
            lines.append("### Functions")
            for f in r["functions"]:
                var fn: Dictionary = f
                lines.append("- `%s(%s) -> %s` - %s" % [fn["name"], _arg_text(fn["args"]),
                    fn["returns"], " ".join(fn["doc"])])
        lines.append("")
    return "\n".join(lines) + "\n"


func _arg_text(args: Array) -> String:
    var parts: Array = []
    for a in args:
        var arg: Dictionary = a
        var piece := str(arg["name"])
        if str(arg["type"]) != "":
            piece += ": " + str(arg["type"])
        if str(arg["default"]) != "":
            piece += " = " + str(arg["default"])
        parts.append(piece)
    return ", ".join(parts)


func render_html(result: Dictionary) -> String:
    var md := render_markdown(result)
    var escaped := md.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
    var body: Array[String] = []
    for line in escaped.split("\n"):
        var l := line.strip_edges()
        if l.begins_with("### "):
            body.append("<h3>%s</h3>" % l.trim_prefix("### "))
        elif l.begins_with("## "):
            body.append("<h2>%s</h2>" % l.trim_prefix("## "))
        elif l.begins_with("# "):
            body.append("<h1>%s</h1>" % l.trim_prefix("# "))
        elif l.begins_with("- "):
            body.append("<li>%s</li>" % l.trim_prefix("- "))
        elif l == "":
            continue
        else:
            body.append("<p>%s</p>" % l)
    return "<!DOCTYPE html>\n<html>\n<head><meta charset=\"utf-8\"><title>GDScript API</title></head>\n<body>\n%s\n</body>\n</html>\n" % "\n".join(body)


func to_json(result: Dictionary) -> String:
    return JSON.stringify({"summary": result["summary"], "issues": result["issues"]}, "\t")


func to_markdown(result: Dictionary) -> String:
    var s: Dictionary = result["summary"]
    var lines: Array[String] = ["# Documentation Coverage Report", "",
        "%d scripts: %d documented declarations, %d undocumented." % [
            s["scripts"], s["documented"], s["undocumented"]], ""]
    for i in result["issues"]:
        lines.append("- [%s] %s" % [i["severity"], i["message"]])
    return "\n".join(lines) + "\n"
