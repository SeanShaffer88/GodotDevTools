## Loot Table and Economy Simulator - weighted drop analysis.
## For each table: exact per-roll odds (weight / total), chance per open with
## several rolls, expected value per open, the 99th-percentile number of opens
## before an item drops, and a seeded simulation whose observed rates and
## longest droughts are reported beside the maths. Deterministic per seed.
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

const DEFAULTS := {"draws": 10000, "seed": 1, "max_drought": 200}


func evaluate(data: Dictionary, options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    var issues: Array = []
    var tables: Variant = data.get("tables")
    if typeof(tables) != TYPE_DICTIONARY:
        return _fail("", "Missing \"tables\" object.", "See the README for the format.", "bad_input")
    var out := {}
    var names: Array = tables.keys()
    names.sort()
    for name in names:
        var t: Variant = tables[name]
        var entries: Array = t.get("entries", []) if typeof(t) == TYPE_DICTIONARY else []
        var rolls := int(t.get("rolls", 1)) if typeof(t) == TYPE_DICTIONARY else 1
        var total := 0.0
        for e in entries:
            if float(e.get("weight", 0)) <= 0.0:
                issues.append(_issue("warning", "zero_weight", "", 0, "%s: %s has weight %s and can never drop." % [name, e.get("item", "?"), e.get("weight", 0)], "Give it a positive weight or remove the entry."))
            else:
                total += float(e["weight"])
        if total <= 0.0 or rolls < 1:
            issues.append(_issue("error", "empty_table", "", 0, "Table %s has no droppable entries or rolls < 1." % name, "Add weighted entries and at least one roll."))
            continue
        var rng := RandomNumberGenerator.new()
        rng.seed = int(opts["seed"])
        var counts := {}
        var last := {}
        var longest := {}
        var draws := int(opts["draws"])
        for i in range(draws):
            var got := {}
            for r in range(rolls):
                var pick := rng.randf() * total
                for e in entries:
                    var w := float(e.get("weight", 0))
                    if w <= 0.0:
                        continue
                    pick -= w
                    if pick < 0.0:
                        got[str(e["item"])] = true
                        counts[str(e["item"])] = int(counts.get(str(e["item"]), 0)) + 1
                        break
            for item in got.keys():
                longest[item] = max(int(longest.get(item, 0)), i - int(last.get(item, -1)) - 1)
                last[item] = i
        var ev := 0.0
        var items: Array = []
        for e in entries:
            var w := float(e.get("weight", 0))
            if w <= 0.0:
                continue
            var p := w / total
            var p_open := 1.0 - pow(1.0 - p, rolls)
            ev += p * float(e.get("value", 0)) * rolls
            var p99 := 1 if p_open >= 1.0 else int(ceil(log(0.01) / log(1.0 - p_open)))
            var item := str(e["item"])
            longest[item] = max(int(longest.get(item, 0)), draws - int(last.get(item, -1)) - 1)
            items.append({"item": item, "per_roll": snappedf(p, 0.00001), "per_open": snappedf(p_open, 0.00001), "p99_drought": p99,
                "observed_per_open": snappedf(float(counts.get(item, 0)) / draws / rolls * (p_open / p) if p > 0 else 0.0, 0.00001), "longest_drought_seen": longest[item]})
            if p99 > int(opts["max_drought"]):
                issues.append(_issue("warning", "drought_risk", "", 0, "%s: 1 player in 100 opens %s %d times without seeing %s (chance per open %.3f%%)." % [name, name, p99, item, p_open * 100.0], "Raise its weight, add a pity counter, or accept the drought as a design choice."))
        out[name] = {"rolls": rolls, "expected_value_per_open": snappedf(ev, 0.01), "items": items}
    return _finish({"tables": out.size(), "draws": int(opts["draws"]), "seed": int(opts["seed"])}, issues, {"tables": out})


func _markdown_extra(result: Dictionary) -> Array:
    var lines: Array = []
    for name in result.get("tables", {}).keys():
        var t: Dictionary = result["tables"][name]
        lines.append("### %s (EV per open %.2f)" % [name, t["expected_value_per_open"]])
        lines.append("| Item | Per open | p99 drought | Longest seen |")
        lines.append("|---|---|---|---|")
        for i in t["items"]:
            lines.append("| %s | %.4f | %d | %d |" % [i["item"], i["per_open"], i["p99_drought"], i["longest_drought_seen"]])
        lines.append("")
    return lines


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
    var lines: Array = ["# Loot Table and Economy Simulator", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
