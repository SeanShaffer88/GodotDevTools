## Interactive Dialogue and Quest Debugger - graph layout operation.
## Pure geometry for the drawn node-graph view: lays one dialogue out in
## layers (breadth-first depth from the start node), stacks each layer's
## nodes vertically in id order for determinism, and gives every edge its
## two connection points. Choices that point at missing nodes get a
## "ghost" placeholder box one layer past their source, so the drawing
## shows exactly what the report says. Problem flags come from the issues
## list analyse() produced - this file re-runs no checking of its own.
extends RefCounted

var node_size := Vector2(190, 58)
var layer_gap := 90.0
var node_gap := 26.0
var margin := Vector2(16, 16)


## Lay out one dialogue. `graph` is a loaded dqd_graph operation (its
## `dialogues` and `edges()` are read), `issues` is analyse()'s list.
## Returns {dialogue, nodes: [{id, rect, layer, flags, ghost, start,
## end}], edges: [{from, to, choice_text, has_condition, broken,
## points: [Vector2, Vector2]}], content_size}.
func layout_dialogue(graph: RefCounted, dialogue_id: String, issues: Array) -> Dictionary:
    var dialogue: Dictionary = graph.dialogues.get(dialogue_id, {})
    var nodes: Dictionary = dialogue.get("nodes", {})
    var start := str(dialogue.get("start", ""))
    var es: Array = graph.edges(dialogue_id)
    var flags: Dictionary = _flags_for(dialogue_id, issues)
    var layers: Dictionary = _bfs_layers(nodes, start, es)
    var max_layer := 0
    for l in layers.values():
        max_layer = maxi(max_layer, int(l))
    var ghosts: Dictionary = _ghost_layers(es, nodes, layers)
    var by_layer: Dictionary = {}
    for nid in layers:
        _push_layer(by_layer, int(layers[nid]), nid)
    for gid in ghosts:
        _push_layer(by_layer, int(ghosts[gid]), gid)
    var orphans: Array = []
    for nid in nodes:
        if not layers.has(nid) and not ghosts.has(nid):
            orphans.append(nid)
    if not orphans.is_empty():
        for nid in orphans:
            _push_layer(by_layer, max_layer + 1, nid)
    var out_nodes: Array = []
    var rect_by_id: Dictionary = {}
    var layer_keys: Array = by_layer.keys()
    layer_keys.sort()
    var widest := 0
    for l in layer_keys:
        var ids: Array = by_layer[l]
        ids.sort()
        widest = maxi(widest, ids.size())
        for idx in ids.size():
            var nid: String = ids[idx]
            var pos := margin + Vector2(int(l) * (node_size.x + layer_gap),
                idx * (node_size.y + node_gap))
            rect_by_id[nid] = Rect2(pos, node_size)
            out_nodes.append({"id": nid, "rect": Rect2(pos, node_size), "layer": int(l),
                "flags": flags.get(nid, []), "ghost": ghosts.has(nid),
                "start": nid == start, "end": bool(nodes.get(nid, {}).get("end", false)),
                "speaker": str(nodes.get(nid, {}).get("speaker", "")),
                "text": str(nodes.get(nid, {}).get("text", ""))})
    var last_layer := 0
    if not layer_keys.is_empty():
        last_layer = int(layer_keys[layer_keys.size() - 1])
    var content := Vector2(
        margin.x * 2.0 + float(last_layer + 1) * node_size.x + float(last_layer) * layer_gap,
        margin.y * 2.0 + float(widest) * node_size.y + float(maxi(widest - 1, 0)) * node_gap)
    var out_edges: Array = []
    for e in es:
        var from_id := str(e.get("from", ""))
        var to_id := str(e.get("to", ""))
        if not rect_by_id.has(from_id):
            continue
        var a: Rect2 = rect_by_id[from_id]
        var p0 := a.position + Vector2(a.size.x, a.size.y * 0.5)
        var p1: Vector2
        if rect_by_id.has(to_id):
            var b: Rect2 = rect_by_id[to_id]
            p1 = b.position + Vector2(0.0, b.size.y * 0.5)
        else:
            p1 = p0 + Vector2(layer_gap, 0.0)
        out_edges.append({"from": from_id, "to": to_id,
            "choice_text": str(e.get("choice_text", "")),
            "has_condition": not (e.get("condition", {}) as Dictionary).is_empty(),
            "broken": not nodes.has(to_id), "points": [p0, p1]})
    return {"dialogue": dialogue_id, "nodes": out_nodes, "edges": out_edges,
        "content_size": content}


func _push_layer(by_layer: Dictionary, layer: int, nid: String) -> void:
    if not by_layer.has(layer):
        by_layer[layer] = []
    (by_layer[layer] as Array).append(nid)


func _flags_for(dialogue_id: String, issues: Array) -> Dictionary:
    var flags: Dictionary = {}
    for i in issues:
        if str(i.get("path", "")) != dialogue_id:
            continue
        var nid := str(i.get("node", ""))
        var kind := str(i.get("kind", ""))
        if nid == "" or kind == "":
            continue
        if not flags.has(nid):
            flags[nid] = []
        if kind not in (flags[nid] as Array):
            (flags[nid] as Array).append(kind)
    return flags


func _bfs_layers(nodes: Dictionary, start: String, es: Array) -> Dictionary:
    var layers: Dictionary = {}
    if not nodes.has(start):
        return layers
    layers[start] = 0
    var queue: Array = [start]
    while not queue.is_empty():
        var cur: String = queue.pop_front()
        for e in es:
            var to := str(e.get("to", ""))
            if str(e.get("from", "")) == cur and nodes.has(to) and not layers.has(to):
                layers[to] = int(layers[cur]) + 1
                queue.append(to)
    return layers


## Missing edge targets: one ghost per id, one layer past its first source.
func _ghost_layers(es: Array, nodes: Dictionary, layers: Dictionary) -> Dictionary:
    var ghosts: Dictionary = {}
    for e in es:
        var to := str(e.get("to", ""))
        if to == "" or nodes.has(to) or ghosts.has(to):
            continue
        ghosts[to] = int(layers.get(str(e.get("from", "")), 0)) + 1
    return ghosts
