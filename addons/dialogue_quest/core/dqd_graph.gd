## Interactive Dialogue and Quest Debugger - graph operation.
## Loads dialogue and quest data from JSON files in one shared shape:
##   {"dialogues": {"<id>": {"start": "<node>", "nodes": {
##       "<node>": {"speaker": "...", "text": "...",
##                  "choices": [{"text": "...", "next": "<node>",
##                               "condition": {"var": "met_guard",
##                                              "op": "==", "value": true},
##                               "effects": {"gold": -5}}],
##                  "next": "<node>", "quest": "<quest_id>"}}},
##    "quests": {"<id>": {"title": "...", "requires": ["<quest_id>"],
##                        "starts_at": "<dialogue>:<node>"}}}
## Builds the branch graph, then reports: choices pointing at nodes
## that do not exist, nodes no path can reach, dead ends that are not
## marked as endings, dependency cycles between quests, and quests whose
## requirements can never be met. The simulator walks the graph with a
## state Dictionary, evaluating conditions exactly as written, so a
## developer can play a conversation and see which branches open.
extends RefCounted

var data: Dictionary = {}
var dialogues: Dictionary = {}
var quests: Dictionary = {}


func load_files(paths: Array) -> Dictionary:
    data = {"dialogues": {}, "quests": {}}
    var errors: Array = []
    for path in paths:
        if not FileAccess.file_exists(path):
            errors.append({"severity": "error", "kind": "missing_file", "path": path,
                "message": "Dialogue/quest file not found: %s" % path,
                "fix": "Pass an existing JSON file, or check the path for a typo."})
            continue
        var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
        if typeof(parsed) != TYPE_DICTIONARY:
            errors.append({"severity": "error", "kind": "bad_json", "path": path,
                "message": "%s is not valid dialogue JSON." % path,
                "fix": "Fix the JSON syntax; the whole file is skipped until it parses."})
            continue
        for did in parsed.get("dialogues", {}):
            dialogues[did] = parsed["dialogues"][did]
        for qid in parsed.get("quests", {}):
            quests[qid] = parsed["quests"][qid]
    data = {"dialogues": dialogues, "quests": quests}
    return {"errors": errors}


func find_files() -> Array:
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
        elif name.get_extension() == "json":
            var text := FileAccess.get_file_as_string(full)
            if text.contains("\"dialogues\"") or text.contains("\"quests\""):
                out.append(full)
        name = dir.get_next()
    dir.list_dir_end()


## All edges of one dialogue: [{from, to, choice_text, condition}]
func edges(dialogue_id: String) -> Array:
    var out: Array = []
    var d: Dictionary = dialogues.get(dialogue_id, {})
    var nodes: Dictionary = d.get("nodes", {})
    for nid in nodes:
        var node: Dictionary = nodes[nid]
        if node.has("next") and str(node["next"]) != "":
            out.append({"from": nid, "to": node["next"], "choice_text": "(continue)", "condition": {}})
        for c in node.get("choices", []):
            out.append({"from": nid, "to": str(c.get("next", "")), "choice_text": str(c.get("text", "")),
                "condition": c.get("condition", {})})
    return out


func eval_condition(condition: Dictionary, state: Dictionary) -> bool:
    if condition.is_empty():
        return true
    var var_name := str(condition.get("var", ""))
    var op := str(condition.get("op", "=="))
    var expected = condition.get("value", true)
    var actual = state.get(var_name, null)
    match op:
        "==": return str(actual) == str(expected)
        "!=": return str(actual) != str(expected)
        ">": return typeof(actual) in [TYPE_INT, TYPE_FLOAT] and float(actual) > float(expected)
        ">=": return typeof(actual) in [TYPE_INT, TYPE_FLOAT] and float(actual) >= float(expected)
        "<": return typeof(actual) in [TYPE_INT, TYPE_FLOAT] and float(actual) < float(expected)
        "<=": return typeof(actual) in [TYPE_INT, TYPE_FLOAT] and float(actual) <= float(expected)
        "has": return actual != null and actual != false
        "not": return actual == null or actual == false
    return false


func analyse() -> Dictionary:
    var issues: Array = []
    var node_total := 0
    var edge_total := 0
    for did in dialogues:
        var d: Dictionary = dialogues[did]
        var nodes: Dictionary = d.get("nodes", {})
        node_total += nodes.size()
        var es := edges(did)
        edge_total += es.size()
        var start := str(d.get("start", ""))
        if start == "" or not nodes.has(start):
            issues.append({"severity": "error", "kind": "bad_start", "path": did,
                "message": "Dialogue '%s' starts at '%s', which is not one of its nodes." % [did, start],
                "fix": "Set start to an existing node id."})
            continue
        for e in es:
            if not nodes.has(e["to"]):
                issues.append({"severity": "error", "kind": "missing_target", "path": did,
                    "message": "Dialogue '%s': node '%s' choice '%s' points at missing node '%s'." % [did, e["from"], e["choice_text"], e["to"]],
                    "fix": "Create the node, or point the choice at the node you meant."})
        var reachable: Dictionary = {start: true}
        var queue: Array = [start]
        while not queue.is_empty():
            var cur: String = queue.pop_front()
            for e in es:
                if e["from"] == cur and nodes.has(e["to"]) and not reachable.has(e["to"]):
                    reachable[e["to"]] = true
                    queue.append(e["to"])
        for nid in nodes:
            if not reachable.has(nid):
                issues.append({"severity": "warning", "kind": "unreachable_node", "path": did,
                    "message": "Dialogue '%s': node '%s' can never be reached from the start." % [did, nid],
                    "fix": "Point a choice at it, or delete it if it is leftover writing."})
            var node: Dictionary = nodes[nid]
            var has_out := false
            for e in es:
                if e["from"] == nid:
                    has_out = true
            if not has_out and not bool(node.get("end", false)):
                issues.append({"severity": "warning", "kind": "dead_end", "path": did,
                    "message": "Dialogue '%s': node '%s' stops the conversation but is not marked as an ending." % [did, nid],
                    "fix": "Add \"end\": true if the stop is intended, or add the missing choice."})
    for qid in quests:
        var q: Dictionary = quests[qid]
        for req in q.get("requires", []):
            if not quests.has(str(req)):
                issues.append({"severity": "error", "kind": "missing_quest_requirement", "path": qid,
                    "message": "Quest '%s' requires quest '%s', which does not exist." % [qid, req],
                    "fix": "Create the required quest, or remove it from requires."})
    for cycle in _quest_cycles():
        issues.append({"severity": "warning", "kind": "quest_cycle", "path": str(cycle[0]),
            "message": "Quests depend on each other in a circle: %s. None of them can ever start." % " -> ".join(cycle),
            "fix": "Break the circle: one of these quests must not require another in the loop."})
    return {"summary": {"dialogues": dialogues.size(), "quests": quests.size(),
            "nodes": node_total, "edges": edge_total, "issues": issues.size()},
        "issues": issues}


func _quest_cycles() -> Array:
    var cycles: Array = []
    var state: Dictionary = {} ## qid -> 1 in stack, 2 done
    var stack: Array = []
    for qid in quests:
        _dfs_quest(qid, state, stack, cycles)
    return cycles


func _dfs_quest(qid: String, state: Dictionary, stack: Array, cycles: Array) -> void:
    if int(state.get(qid, 0)) == 2:
        return
    if int(state.get(qid, 0)) == 1:
        var idx := stack.find(qid)
        if idx >= 0:
            cycles.append(stack.slice(idx))
        return
    state[qid] = 1
    stack.append(qid)
    for req in quests.get(qid, {}).get("requires", []):
        if quests.has(str(req)):
            _dfs_quest(str(req), state, stack, cycles)
    stack.pop_back()
    state[qid] = 2


## Play a dialogue: starts at the start node, then takes the choice
## indexes in `picks`, evaluating conditions against `state` and
## applying choice effects. Returns the visited node list and where /
## why the walk stopped.
func simulate(dialogue_id: String, picks: Array, state: Dictionary) -> Dictionary:
    var sim_state: Dictionary = state.duplicate(true)
    var d: Dictionary = dialogues.get(dialogue_id, {})
    if d.is_empty():
        return {"visited": [], "state": sim_state, "stopped": "no_such_dialogue", "available": []}
    var nodes: Dictionary = d.get("nodes", {})
    var current := str(d.get("start", ""))
    var visited: Array = []
    var pick_i := 0
    while current != "" and nodes.has(current):
        visited.append(current)
        var node: Dictionary = nodes[current]
        var open_choices: Array = []
        for c in node.get("choices", []):
            if eval_condition(c.get("condition", {}), sim_state):
                open_choices.append(c)
        if bool(node.get("end", false)):
            return {"visited": visited, "state": sim_state, "stopped": "ended", "available": []}
        if node.has("next") and str(node["next"]) != "":
            current = str(node["next"])
            continue
        if open_choices.is_empty():
            return {"visited": visited, "state": sim_state, "stopped": "no_open_choices", "available": []}
        if pick_i >= picks.size():
            return {"visited": visited, "state": sim_state, "stopped": "awaiting_pick",
                "available": open_choices.map(func(c): return str(c.get("text", "")))}
        var pick: Dictionary = open_choices[mini(int(picks[pick_i]), open_choices.size() - 1)]
        pick_i += 1
        for k in pick.get("effects", {}):
            sim_state[k] = pick["effects"][k]
        current = str(pick.get("next", ""))
    return {"visited": visited, "state": sim_state, "stopped": "missing_node", "available": []}


func to_json(result: Dictionary) -> String:
    return JSON.stringify({"summary": result["summary"], "issues": result["issues"],
        "dialogues": dialogues.keys(), "quests": quests.keys()}, "\t")


func to_markdown(result: Dictionary) -> String:
    var s: Dictionary = result["summary"]
    var lines: Array[String] = ["# Dialogue and Quest Report", "",
        "%d dialogues (%d nodes, %d branches), %d quests. %d problems." % [
            s["dialogues"], s["nodes"], s["edges"], s["quests"], s["issues"]], ""]
    for i in result["issues"]:
        lines.append("- [%s] %s" % [i["severity"], i["message"]])
    return "\n".join(lines) + "\n"
