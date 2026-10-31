## Dynamic Tilemap Rule and Autotile Generator - rule operation.
## Godot 4 terrain autotiling hangs on peering bits: the eight
## neighbours of a cell, clockwise from the top-left corner. This core
## takes a rule table - terrains plus tiles with their peering
## assignments - and does the two jobs around it. Generation: for every
## ordered pair of terrains it emits the transition tile specs the set
## needs (straight edges in all four directions, then corners), as data
## an artist or a script can apply. Validation: transition pairs that
## exist in one direction only (asymmetric_rule - the classic cause of
## seams that appear from one side but not the other), terrain pairs
## with no transition at all (missing_transition), and tiles whose
## corner bit disagrees with both flanking sides (corner_conflict, which
## paints a lone diagonal pixel). Applying specs to a TileSet stays a
## deliberate human step - documented in the tool README.
extends RefCounted

## Bit index -> neighbour, clockwise from top-left, matching Godot 4's
## TileSet.CellNeighbor ordering (corner, side, corner, side, ...).
const PEERING: Array = [
    {"name": "top_left", "dx": -1, "dy": -1}, {"name": "top", "dx": 0, "dy": -1},
    {"name": "top_right", "dx": 1, "dy": -1}, {"name": "right", "dx": 1, "dy": 0},
    {"name": "bottom_right", "dx": 1, "dy": 1}, {"name": "bottom", "dx": 0, "dy": 1},
    {"name": "bottom_left", "dx": -1, "dy": 1}, {"name": "left", "dx": -1, "dy": 0},
]
const SIDE_BITS: Array = [1, 3, 5, 7]
const CORNER_BITS: Array = [0, 2, 4, 6]


func opposite_bit(bit: int) -> int:
    return (bit + 4) % 8


func neighbour_bits(bit: int) -> Array:
    return [(bit + 1) % 8, (bit + 7) % 8]


## Load a tile's peering map: {bit_index: terrain_or_empty}.
func tile_peering(tile: Dictionary) -> Dictionary:
    var out: Dictionary = {}
    var raw: Dictionary = tile.get("peering", {})
    for bit in 8:
        out[bit] = str(raw.get(str(bit), raw.get(str(PEERING[bit]["name"]), "")))
    return out


## The generation half: transition specs the rule set needs for each
## ordered terrain pair.
func generate(rules: Dictionary) -> Array:
    var terrains: Array = rules.get("terrains", [])
    var specs: Array = []
    for a in terrains:
        for b in terrains:
            if str(a) == str(b):
                continue
            for bit in SIDE_BITS:
                var peering: Dictionary = {}
                for i in 8:
                    peering[i] = str(a)
                peering[bit] = str(b)
                specs.append({"terrain_from": str(a), "terrain_to": str(b),
                    "direction": str(PEERING[bit]["name"]),
                    "name": "%s_to_%s_%s" % [a, b, PEERING[bit]["name"]],
                    "peering": peering})
    return specs


## The validation half: check the authored tile set against the specs.
func validate(rules: Dictionary) -> Array:
    var issues: Array = []
    var tiles: Array = rules.get("tiles", [])
    var authored: Array = []
    for t in tiles:
        authored.append({"tile": t, "peering": tile_peering(t)})
    var terrains: Array = rules.get("terrains", [])
    for a in terrains:
        for b in terrains:
            if str(a) == str(b):
                continue
            for bit in SIDE_BITS:
                var forward := _has_edge(authored, str(a), str(b), bit)
                var backward := _has_edge(authored, str(a), str(b), opposite_bit(bit))
                if forward and not backward:
                    issues.append({"severity": "error", "kind": "asymmetric_rule", "path": "%s|%s" % [a, b],
                        "message": "%s meets %s on the %s edge, but no tile carries %s on its %s edge - the boundary paints from one side only and seams from the other." % [
                            a, b, str(PEERING[bit]["name"]), b, str(PEERING[opposite_bit(bit)]["name"])],
                        "fix": "Add the mirror transition tile (generated spec '%s_to_%s_%s')." % [a, b, str(PEERING[opposite_bit(bit)]["name"])]})
                if not forward and not backward:
                    issues.append({"severity": "warning", "kind": "missing_transition", "path": "%s|%s" % [a, b],
                        "message": "No transition tiles exist between %s and %s at all - painting them adjacently shows a hard cut." % [a, b],
                        "fix": "Author the four edge tiles (and four corners) from the generated specs, or keep the terrains separated by design."})
    for entry in authored:
        var peering: Dictionary = entry["peering"]
        for bit in CORNER_BITS:
            var corner := str(peering[bit])
            if corner == "":
                continue
            var n := neighbour_bits(bit)
            var side_a := str(peering[int(n[0])])
            var side_b := str(peering[int(n[1])])
            if side_a != corner and side_b != corner and side_a == side_b:
                issues.append({"severity": "warning", "kind": "corner_conflict", "path": str((entry["tile"] as Dictionary).get("name", "tile")),
                    "message": "Tile '%s' peers %s at its %s corner while both flanking sides peer %s - the corner paints as a lone diagonal pixel." % [
                        (entry["tile"] as Dictionary).get("name", "tile"), corner,
                        str(PEERING[bit]["name"]), side_a],
                    "fix": "Corner terrain should only show where both flanking sides agree with it; clear the corner bit or use a dedicated corner tile."})
    return issues


func _has_edge(authored: Array, a: String, b: String, bit: int) -> bool:
    for entry in authored:
        var peering: Dictionary = entry["peering"]
        var base := str(peering[opposite_bit(bit)])
        if base != a:
            continue
        if str(peering[bit]) != b:
            continue
        var clean := true
        for i in 8:
            var v := str(peering[i])
            if i != bit and v != a and v != "":
                clean = false
                break
        if clean:
            return true
    return false


func run(rules: Dictionary) -> Dictionary:
    var specs := generate(rules)
    var issues := validate(rules)
    var tiles: Array = rules.get("tiles", [])
    return {"summary": {"terrains": rules.get("terrains", []).size(), "tiles": tiles.size(),
            "specs_generated": specs.size(), "issues": issues.size()},
        "specs": specs, "issues": issues}


func to_json(result: Dictionary) -> String:
    return JSON.stringify({"summary": result["summary"], "issues": result["issues"],
        "specs": result.get("specs", [])}, "\t")


func to_markdown(result: Dictionary) -> String:
    var s: Dictionary = result["summary"]
    var lines: Array[String] = ["# Tilemap Rules Report", "",
        "%d terrains, %d authored tiles, %d transition specs generated, %d problems." % [
            s["terrains"], s["tiles"], s["specs_generated"], s["issues"]], ""]
    for i in result["issues"]:
        lines.append("- [%s] %s" % [i["severity"], i["message"]])
    return "\n".join(lines) + "\n"
