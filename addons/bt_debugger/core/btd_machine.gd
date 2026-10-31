## Behavior Tree and State Machine Debugger - definition operation.
## Loads a JSON behaviour definition (states with selector/sequence
## trees, guarded transitions, blackboard conditions and actions),
## validates the graph - states that transitions reference but nobody
## defines, states nothing can ever reach, states with no behaviour on
## them - and runs it: tick() evaluates the current state's tree against
## the blackboard, applies actions, fires transitions, and records every
## decision as a trace entry. The dock draws the graph from this data
## and highlights the live path; the CLI replays a recorded session's
## blackboard snapshots. The interpreter is pure (JSON in, decisions
## out), so a behaviour can be tested headless, and the runtime node
## (runtime/btd_agent.gd) drives a real scene from the same definition.
extends RefCounted

## Safety valve: no definition gets more ticks than this per run.
var tick_budget: int = 64


func load_definition(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {"errors": [{"severity": "error", "kind": "missing_file", "path": path,
            "message": "Behaviour definition not found: %s" % path,
            "fix": "Check the path; demo/ai/guard_bt.json shows the expected shape."}],
            "definition": {}}
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
    if typeof(parsed) != TYPE_DICTIONARY:
        return {"errors": [{"severity": "error", "kind": "bad_json", "path": path,
            "message": "%s is not a JSON object." % path,
            "fix": "Fix the file's JSON syntax."}], "definition": {}}
    return {"errors": [], "definition": parsed}


## Pure: check the graph itself, before any ticking.
func validate(definition: Dictionary) -> Array:
    var issues: Array = []
    var states: Array = definition.get("states", [])
    var by_name: Dictionary = {}
    for s in states:
        var st: Dictionary = s
        by_name[str(st.get("name", ""))] = st
        var tree: Dictionary = st.get("tree", {})
        if tree.is_empty() and str(st.get("on_enter", "")) == "":
            issues.append({"severity": "warning", "kind": "no_entry", "path": str(st.get("name", "")),
                "message": "State '%s' has no tree and no on_enter action - entering it does nothing and it can only leave via a transition guard." % st.get("name"),
                "fix": "Give the state a behaviour tree or an on_enter action, even an idle one, so its time on stage is visible in the trace."})
    for tr in definition.get("transitions", []):
        var t: Dictionary = tr
        for end in ["from", "to"]:
            if not by_name.has(str(t.get(end, ""))):
                issues.append({"severity": "error", "kind": "missing_state", "path": str(t.get(end, "")),
                    "message": "Transition '%s -> %s' names '%s', which no state defines." % [t.get("from"), t.get("to"), t.get(end)],
                    "fix": "Add the missing state or fix the name in the transition."})
    var initial := str(definition.get("initial", ""))
    if initial != "" and not by_name.has(initial):
        issues.append({"severity": "error", "kind": "missing_state", "path": initial,
            "message": "Initial state '%s' is not defined." % initial,
            "fix": "Define it, or point 'initial' at a state that exists."})
    var reachable: Dictionary = {}
    if initial != "":
        reachable[initial] = true
        var frontier: Array = [initial]
        while not frontier.is_empty():
            var current := str(frontier.pop_back())
            for tr in definition.get("transitions", []):
                var t: Dictionary = tr
                if str(t.get("from", "")) == current and not reachable.has(str(t.get("to", ""))):
                    reachable[str(t.get("to", ""))] = true
                    frontier.append(str(t.get("to", "")))
    for name in by_name:
        if not reachable.has(str(name)):
            issues.append({"severity": "warning", "kind": "unreachable_state", "path": str(name),
                "message": "State '%s' can never be entered from '%s' - no chain of transitions reaches it." % [name, initial],
                "fix": "Add a transition into it, or delete it if it is a leftover."})
    return issues


func check_condition(cond: Dictionary, blackboard: Dictionary) -> bool:
    if cond.is_empty():
        return true
    var key := str(cond.get("key", ""))
    var op := str(cond.get("op", "has"))
    if not blackboard.has(key) and op != "has":
        return false
    match op:
        "has":
            return blackboard.has(key)
        "eq":
            return str(blackboard.get(key)) == str(cond.get("value"))
        "gt":
            return float(blackboard.get(key, 0.0)) > float(cond.get("value", 0.0))
        "lt":
            return float(blackboard.get(key, 0.0)) < float(cond.get("value", 0.0))
        "gte":
            return float(blackboard.get(key, 0.0)) >= float(cond.get("value", 0.0))
    return false


func apply_action(action: Dictionary, blackboard: Dictionary, trace: Array) -> void:
    if action.is_empty():
        return
    for key in action.get("set", {}):
        blackboard[str(key)] = action["set"][key]
        trace.append({"op": "set", "key": str(key), "value": action["set"][key]})
    for key in action.get("add", {}):
        blackboard[str(key)] = float(blackboard.get(key, 0.0)) + float(action["add"][key])
        trace.append({"op": "add", "key": str(key), "value": blackboard[str(key)]})
    for name in action.get("do", []):
        trace.append({"op": "do", "key": str(name), "value": ""})


## Evaluate a behaviour tree node against the blackboard. Returns
## "success" | "failure"; every decision lands in the trace.
func tick_tree(node: Dictionary, blackboard: Dictionary, trace: Array) -> String:
    var kind := str(node.get("type", "action"))
    var label := str(node.get("name", kind))
    var result := "failure"
    match kind:
        "selector":
            result = "failure"
            for child in node.get("children", []):
                var r := tick_tree(child, blackboard, trace)
                if r == "success":
                    result = "success"
                    break
        "sequence":
            result = "success"
            for child in node.get("children", []):
                var r2 := tick_tree(child, blackboard, trace)
                if r2 == "failure":
                    result = "failure"
                    break
        "condition":
            result = "success" if check_condition(node.get("cond", {}), blackboard) else "failure"
        _:
            apply_action(node.get("action", {}), blackboard, trace)
            result = "success"
    trace.append({"op": "node", "key": label, "value": result})
    return result


## One tick of the machine, shared by run() below and the runtime agent
## node: enter `current`, run its on_enter action and tree, then take
## the first transition whose guard passes. Returns the next state name
## ("" when none fires); trace and blackboard are appended/mutated.
func step(current: String, definition: Dictionary, blackboard: Dictionary, trace: Array) -> String:
    var states: Dictionary = {}
    for s in definition.get("states", []):
        var st_def: Dictionary = s
        states[str(st_def.get("name", ""))] = st_def
    var st: Dictionary = states.get(current, {})
    trace.append({"op": "enter", "key": current, "value": ""})
    apply_action(st.get("on_enter", {}), blackboard, trace)
    tick_tree(st.get("tree", {}), blackboard, trace)
    for tr in definition.get("transitions", []):
        var t: Dictionary = tr
        if str(t.get("from", "")) == current and check_condition(t.get("when", {}), blackboard):
            var next := str(t.get("to", ""))
            trace.append({"op": "transition", "key": current + " -> " + next, "value": ""})
            return next
    return ""


## The one operation: validate, then run the machine from its initial
## state against a starting blackboard, following transitions whose
## guards pass, recording a trace until a stop condition or the tick
## budget.
func run(definition: Dictionary, blackboard: Dictionary = {}, stop_when: Dictionary = {}) -> Dictionary:
    var issues := validate(definition)
    var errors := 0
    for i in issues:
        if str(i["severity"]) == "error":
            errors += 1
    var trace: Array = []
    var states: Dictionary = {}
    for s in definition.get("states", []):
        var st: Dictionary = s
        states[str(st.get("name", ""))] = st
    var current := str(definition.get("initial", ""))
    var ticks := 0
    var visited: Dictionary = {}
    while states.has(current) and ticks < tick_budget and errors == 0:
        ticks += 1
        var st: Dictionary = states[current]
        trace.append({"op": "enter", "key": current, "value": ticks})
        visited[current] = int(visited.get(current, 0)) + 1
        if not stop_when.is_empty() and check_condition(stop_when, blackboard):
            trace.append({"op": "stop", "key": "stop_when", "value": "met"})
            break
        apply_action(st.get("on_enter", {}), blackboard, trace)
        tick_tree(st.get("tree", {}), blackboard, trace)
        var next := ""
        for tr in definition.get("transitions", []):
            var t: Dictionary = tr
            if str(t.get("from", "")) == current and check_condition(t.get("when", {}), blackboard):
                next = str(t.get("to", ""))
                trace.append({"op": "transition", "key": current + " -> " + next, "value": ""})
                break
        if next == "" or next == current:
            if next == current and ticks >= tick_budget:
                break
            if next == "":
                break
        current = next
    if ticks >= tick_budget:
        issues.append({"severity": "warning", "kind": "runaway_machine", "path": current,
            "message": "The machine was still transitioning after %d ticks (ended in '%s') - a guard combination may loop forever." % [tick_budget, current],
            "fix": "Add a guard that eventually fails, or a tick-cooldown per transition; watch the trace for the repeating cycle."})
    return {"summary": {"states": states.size(), "ticks": ticks, "errors": errors,
            "issues": issues.size()},
        "trace": trace, "blackboard": blackboard, "issues": issues}


func to_json(result: Dictionary) -> String:
    return JSON.stringify({"summary": result["summary"], "issues": result["issues"],
        "trace": result.get("trace", [])}, "\t")


func to_markdown(result: Dictionary) -> String:
    var s: Dictionary = result["summary"]
    var lines: Array[String] = ["# Behaviour Debugger Report", "",
        "%d states, %d ticks, %d problems." % [s["states"], s["ticks"], s["issues"]], ""]
    for i in result["issues"]:
        lines.append("- [%s] %s" % [i["severity"], i["message"]])
    lines.append("")
    lines.append("## Trace")
    for t in result.get("trace", []):
        lines.append("- %s %s %s" % [t["op"], t["key"], t["value"]])
    return "\n".join(lines) + "\n"
