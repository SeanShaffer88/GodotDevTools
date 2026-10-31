## Memory Leak and Orphan Node Hunter - scan operation.
## Static half of the hunter, pure text analysis over the project's
## scripts: files that call remove_child() but never free or queue_free
## anything (orphans - out of the tree, still in RAM), pairs of
## RefCounted classes whose member variables reference each other in a
## circle (a cycle nothing can ever release), and RefCounted scripts
## that connect to signals (a connection can hold the object alive long
## after its owner is gone). These are suspects for a human or the
## runtime watcher to confirm, reported as such - the rule for this
## project is to flag, never to guess a verdict. The runtime node
## (runtime/mlh_watch.gd) counts actual orphans in a live session.
extends RefCounted

var skip_addons: bool = true


func find_scripts() -> Array:
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
        if name.begins_with("."):
            name = dir.get_next()
            continue
        var full := dir_path.path_join(name)
        if dir.current_is_dir():
            if name not in [".godot", "addons"]:
                _walk(full, out)
        elif name.get_extension() == "gd":
            out.append(full)
        name = dir.get_next()
    dir.list_dir_end()


## Parse one script's text into the facts the scan uses.
func parse_script(text: String, path: String) -> Dictionary:
    var info := {"path": path, "class_name": "", "extends_refcounted": false,
        "has_remove_child": false, "has_free": false, "has_connect": false,
        "typed_refs": []}
    var lines := text.split("\n")
    for raw in lines:
        var line := raw.strip_edges()
        if line.begins_with("class_name "):
            info["class_name"] = line.trim_prefix("class_name ").strip_edges()
        elif line.begins_with("extends RefCounted") or line.begins_with("extends Resource"):
            info["extends_refcounted"] = true
        if "remove_child(" in line:
            info["has_remove_child"] = true
        if ".queue_free(" in line or ".free(" in line:
            info["has_free"] = true
        if ".connect(" in line:
            info["has_connect"] = true
        if line.begins_with("var ") and bool(info["extends_refcounted"]):
            var typed := _typed_ref(line)
            if typed != "" and typed not in (info["typed_refs"] as Array):
                (info["typed_refs"] as Array).append(typed)
    return info


## "var partner: DemoChainB" or "var partner: DemoChainB = null" -> the
## type name; empty when the declaration is not a class-typed member.
func _typed_ref(line: String) -> String:
    var i := line.find(": ")
    if i < 0:
        return ""
    var rest := line.substr(i + 2)
    for sep in [" =", "=", "\n"]:
        var j := rest.find(sep)
        if j >= 0:
            rest = rest.substr(0, j)
    rest = rest.strip_edges()
    if rest == "" or rest.begins_with("(") or " " in rest:
        return ""
    if rest[0] < "A" or rest[0] > "Z":
        return ""
    return rest


## Pure: find reference circles among parsed RefCounted scripts.
func find_cycles(infos: Array) -> Array:
    var refs: Dictionary = {}
    var is_rc: Dictionary = {}
    for info in infos:
        var cname := str(info["class_name"])
        if cname == "" or not bool(info["extends_refcounted"]):
            continue
        is_rc[cname] = true
        refs[cname] = info["typed_refs"]
    var cycles: Array = []
    var state: Dictionary = {}
    var stack: Array = []
    for cname in refs:
        _dfs(str(cname), refs, is_rc, state, stack, cycles)
    return cycles


func _dfs(node: String, refs: Dictionary, is_rc: Dictionary, state: Dictionary,
        stack: Array, cycles: Array) -> void:
    if int(state.get(node, 0)) == 2:
        return
    if int(state.get(node, 0)) == 1:
        var idx: int = stack.find(node)
        if idx >= 0:
            cycles.append(stack.slice(idx) + [node])
        return
    state[node] = 1
    stack.append(node)
    for nxt in refs.get(node, []):
        if is_rc.has(str(nxt)):
            _dfs(str(nxt), refs, is_rc, state, stack, cycles)
    stack.pop_back()
    state[node] = 2


## The one operation: scan the project (or a given list of parsed
## scripts) and report leak suspects.
func run(infos: Array = []) -> Dictionary:
    var parsed: Array = infos
    if parsed.is_empty():
        for path in find_scripts():
            parsed.append(parse_script(FileAccess.get_file_as_string(str(path)), str(path)))
    var issues: Array = []
    for info in parsed:
        if bool(info["has_remove_child"]) and not bool(info["has_free"]):
            issues.append({"severity": "warning", "kind": "orphan_risk", "path": str(info["path"]),
                "message": "%s calls remove_child() but never free() or queue_free() anything - removed nodes stay in RAM until something frees them." % info["path"],
                "fix": "Free the removed node (queue_free), reparent it, or store it deliberately and free it later - and say which in a comment."})
        if bool(info["extends_refcounted"]) and bool(info["has_connect"]):
            issues.append({"severity": "info", "kind": "signal_hold", "path": str(info["path"]),
                "message": "%s is RefCounted and connects to signals; a connection from a longer-lived object can hold this one in RAM." % info["path"],
                "fix": "Disconnect in an explicit teardown call, or connect from the short-lived side so the reference dies with it."})
    for cycle in find_cycles(parsed):
        issues.append({"severity": "error", "kind": "refcount_cycle", "path": str(cycle[0]),
            "message": "RefCounted circle: %s. Each member holds the next, so none of them can ever reach zero references." % " -> ".join(cycle),
            "fix": "Break the circle: make one direction untyped/weak-style (store an id or use @warning_ignore-free lookup), or move the back-reference to the owner that frees both."})
    return {"summary": {"scripts": parsed.size(), "issues": issues.size()},
        "issues": issues}


func to_json(result: Dictionary) -> String:
    return JSON.stringify({"summary": result["summary"], "issues": result["issues"]}, "\t")


func to_markdown(result: Dictionary) -> String:
    var s: Dictionary = result["summary"]
    var lines: Array[String] = ["# Leak Hunter Report", "",
        "%d scripts scanned, %d suspects." % [s["scripts"], s["issues"]], "",
        "Suspects are prompts to check, not proof - confirm with the runtime watcher or a debugger.", ""]
    for i in result["issues"]:
        lines.append("- [%s] %s" % [i["severity"], i["message"]])
    return "\n".join(lines) + "\n"
