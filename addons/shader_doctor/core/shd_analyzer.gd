## Shader Doctor - shader analysis operation.
## Static analysis of Godot shading-language files (.gdshader), pure
## text work with no renderer: it counts texture fetches and finds the
## redundant ones (the same sampler sampled with the same UV expression
## twice in one function), flags fetches inside loops (the classic
## mobile frame-time trap), measures branch density (if/else/discard,
## which break GPU coherency), lists uniforms declared but never used,
## and suggests mobile-friendly rewrites per finding. Godot compiles
## visual shaders to this same language, so the analyzer covers both
## hand-written and graph-generated code; applying suggestions stays a
## human step - this tool diagnoses, it never rewrites your shader.
extends RefCounted

## More texture fetches than this in one function is worth a look.
var fetch_budget: int = 8
## More branch points than this in one shader is worth a look.
var branch_budget: int = 6


func find_shaders() -> Array:
    var out: Array = []
    _walk("res://", out)
    return out


func _walk(dir_path: String, out: Array) -> void:
    var dir := DirAccess.open(dir_path)
    if dir == null:
        return
    dir.list_dir_begin()
    var name := dir.get_next()
    while name != "":
        if name.begins_with(".") or name == "addons":
            name = dir.get_next()
            continue
        var full := dir_path.path_join(name)
        if dir.current_is_dir():
            if name != ".godot":
                _walk(full, out)
        elif name.get_extension() == "gdshader":
            out.append(full)
        name = dir.get_next()
    dir.list_dir_end()


## Split shader text into {name, body} function blocks plus the global
## section (uniforms live there).
func parse_functions(text: String) -> Dictionary:
    var functions: Array = []
    var uniforms: Array = []
    var current := ""
    var body: Array[String] = []
    var depth := 0
    for raw in text.split("\n"):
        var line := raw.strip_edges()
        if line.begins_with("uniform "):
            var parts := line.split(" ")
            if parts.size() >= 3:
                uniforms.append({"type": parts[1], "name": parts[2].trim_suffix(";")})
        if depth == 0 and (line.begins_with("void ") or line.begins_with("vec") or line.begins_with("float ")) and line.ends_with("{"):
            current = line.substr(0, line.length() - 1).strip_edges()
            body = []
            depth = 1
            continue
        if depth > 0:
            body.append(line)
            depth += line.count("{") - line.count("}")
            if depth <= 0:
                functions.append({"name": current, "body": body})
                depth = 0
    return {"functions": functions, "uniforms": uniforms}


func _fetches(line: String) -> Array:
    var out: Array = []
    var search_from := 0
    while true:
        var i := line.find("texture(", search_from)
        if i < 0:
            break
        var close := _matching_paren(line, i + 7)
        if close > i:
            out.append(line.substr(i + 8, close - i - 8).replace(" ", ""))
        search_from = i + 8
    return out


func _matching_paren(line: String, open_idx: int) -> int:
    var depth := 0
    for i in range(open_idx, line.length()):
        if line[i] == "(":
            depth += 1
        elif line[i] == ")":
            depth -= 1
            if depth == 0:
                return i
    return -1


## The one operation: analyze one shader's text (or scan the project).
func analyze_shader(text: String, path: String) -> Array:
    var issues: Array = []
    var parsed := parse_functions(text)
    var branches := 0
    var uniform_uses: Dictionary = {}
    for fn in parsed["functions"]:
        var seen_fetches: Dictionary = {}
        var fetch_count := 0
        var loop_depth := 0
        var body: Array = fn["body"]
        for line in body:
            var stripped := str(line).strip_edges()
            if stripped.begins_with("for ") or stripped.begins_with("while "):
                loop_depth += 1
            loop_depth += stripped.count("{") - stripped.count("}")
            if loop_depth < 0:
                loop_depth = 0
            if stripped.begins_with("if ") or stripped.begins_with("} else") or stripped == "else {" or "discard" in stripped:
                branches += 1
            for f in _fetches(str(line)):
                fetch_count += 1
                if loop_depth > 0:
                    issues.append({"severity": "warning", "kind": "fetch_in_loop", "path": path,
                        "message": "%s: %s samples texture(%s) inside a loop - on mobile GPUs every iteration is a real fetch." % [fn["name"], path, f],
                        "fix": "Hoist the sample above the loop if the UV does not change per iteration, or unroll small loops into straight-line code."})
                if seen_fetches.has(f):
                    issues.append({"severity": "warning", "kind": "redundant_fetch", "path": path,
                        "message": "%s: %s samples texture(%s) more than once with identical arguments." % [fn["name"], path, f],
                        "fix": "Store the first sample in a local variable and reuse it - the compiler may not remove the second fetch."})
                seen_fetches[f] = true
        if fetch_count > fetch_budget:
            issues.append({"severity": "info", "kind": "fetch_heavy", "path": path,
                "message": "%s: %s performs %d texture fetches (budget %d)." % [path, fn["name"], fetch_count, fetch_budget],
                "fix": "Combine channels into one texture (mask packs), or move detail work to a cheaper pass."})
    for u in parsed["uniforms"]:
        var uname := str(u["name"])
        if text.count(uname) <= 1:
            issues.append({"severity": "info", "kind": "unused_uniform", "path": path,
                "message": "%s: uniform '%s %s' is declared but never used." % [path, u["type"], uname],
                "fix": "Delete it - unused uniforms still occupy constant-buffer space on some mobile drivers."})
    if branches > branch_budget:
        issues.append({"severity": "info", "kind": "branch_heavy", "path": path,
            "message": "%s has %d branch points (budget %d); divergent branches stall GPU warps." % [path, branches, branch_budget],
            "fix": "Replace branching with mix()/step()/clamp() where the maths allows, or split variants into separate shaders."})
    return issues


func run(shader_text: String = "", shader_path: String = "") -> Dictionary:
    var issues: Array = []
    var shaders_checked := 0
    if shader_text != "":
        shaders_checked = 1
        issues = analyze_shader(shader_text, shader_path)
    else:
        for path in find_shaders():
            var text := FileAccess.get_file_as_string(str(path))
            if text == "":
                continue
            shaders_checked += 1
            issues.append_array(analyze_shader(text, str(path)))
    return {"summary": {"shaders": shaders_checked, "issues": issues.size()},
        "issues": issues}


func to_json(result: Dictionary) -> String:
    return JSON.stringify({"summary": result["summary"], "issues": result["issues"]}, "\t")


func to_markdown(result: Dictionary) -> String:
    var s: Dictionary = result["summary"]
    var lines: Array[String] = ["# Shader Doctor Report", "",
        "%d shader(s) analyzed, %d findings." % [s["shaders"], s["issues"]], ""]
    for i in result["issues"]:
        lines.append("- [%s] %s" % [i["severity"], i["message"]])
        lines.append("  Fix: %s" % str(i["fix"]))
    return "\n".join(lines) + "\n"
