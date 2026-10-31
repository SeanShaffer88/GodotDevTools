## Crafting and Inventory Graph Validator - reachability.
## Starting from base items (gathered, bought or dropped), repeatedly runs
## every recipe whose inputs are all obtainable until nothing changes. Items
## and recipes outside that fixpoint can never be reached in play. Quantities
## are reported but not balanced: reachability only.
extends RefCounted

const EXTS: Array[String] = ["json"]
func run(input: String = "", options: Dictionary = {}) -> Dictionary:
    var data: Variant = _read_json(input)
    if typeof(data) != TYPE_DICTIONARY:
        return _fail(input, "Input missing or not a JSON object.", "Pass --input=<json> in the format described in the addon README.", "bad_input")
    var result: Dictionary = evaluate(data, options)
    for issue in result["issues"]:
        if issue["path"] == "":
            issue["path"] = input
    return result

const DEFAULTS := {}


func evaluate(data: Dictionary, options: Dictionary = {}) -> Dictionary:
    var base: Variant = data.get("base_items")
    var recipes: Variant = data.get("recipes")
    if typeof(base) != TYPE_ARRAY or typeof(recipes) != TYPE_ARRAY:
        return _fail("", "Need base_items and recipes arrays.", "See the README for the format.", "bad_input")
    var goals: Array = data.get("goals", []) if typeof(data.get("goals", [])) == TYPE_ARRAY else []
    var issues: Array = []
    var ids := {}
    for r in recipes:
        if typeof(r) != TYPE_DICTIONARY or typeof(r.get("inputs")) != TYPE_DICTIONARY or typeof(r.get("outputs")) != TYPE_DICTIONARY:
            return _fail("", "Each recipe needs inputs and outputs objects: %s" % str(r), "Fix the recipe.", "bad_input")
        var id := str(r.get("id", ""))
        if ids.has(id):
            issues.append(_issue("warning", "duplicate_recipe", "", 0, "Recipe id %s appears twice." % id, "Give each recipe a unique id."))
        ids[id] = true
    var have := {}
    for b in base:
        have[str(b)] = true
    var fired := {}
    var changed := true
    while changed:
        changed = false
        for i in range(recipes.size()):
            if fired.has(i):
                continue
            var ok := true
            for item in recipes[i]["inputs"].keys():
                if not have.has(item):
                    ok = false
            if ok:
                fired[i] = true
                changed = true
                for out in recipes[i]["outputs"].keys():
                    have[out] = true
    var produced_by := {}
    var used := {}
    for i in range(recipes.size()):
        for out in recipes[i]["outputs"].keys():
            if not produced_by.has(out):
                produced_by[out] = []
            produced_by[out].append(i)
        for inp in recipes[i]["inputs"].keys():
            used[inp] = true
    var reported := {}
    for i in range(recipes.size()):
        if fired.has(i):
            continue
        var r: Dictionary = recipes[i]
        var self_only := true
        var any_missing := false
        for inp in r["inputs"].keys():
            if have.has(inp):
                continue
            any_missing = true
            var makers: Array = produced_by.get(inp, [])
            if makers.is_empty() and not base.has(inp):
                self_only = false
                if not reported.has(inp):
                    reported[inp] = true
                    issues.append(_issue("error", "missing_input", "", 0, "%s is an input (recipe %s) but no recipe produces it and it is not a base item." % [inp, r.get("id", i)], "Add a source (base item, drop, recipe) or change the recipe."))
            elif not (makers.size() == 1 and makers[0] == i):
                self_only = false
        if any_missing and self_only:
            issues.append(_issue("error", "self_bootstrapping", "", 0, "Recipe %s needs its own output before it can run." % r.get("id", i), "Give the player a first batch of the input from another source."))
    for g in goals:
        if not have.has(str(g)):
            issues.append(_issue("error", "unobtainable_goal", "", 0, "Goal %s can never be obtained." % g, "Trace its recipe chain; the missing_input findings show where it breaks."))
    for item in have.keys():
        if not used.has(item) and not goals.has(item) and not base.has(item):
            issues.append(_issue("info", "dead_end", "", 0, "%s can be made but is never used or a goal." % item, "Use it somewhere, sell it, or stop producing it."))
    var reachable: Array = have.keys()
    reachable.sort()
    return _finish({"recipes": recipes.size(), "recipes_reachable": fired.size(), "items_obtainable": reachable.size()}, issues, {"obtainable": reachable})


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
    var lines: Array = ["# Crafting and Inventory Graph Validator", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
