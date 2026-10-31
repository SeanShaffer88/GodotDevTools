extends Node


func sum_round(entries: Array) -> int:
    var total := 0
    for entry in entries:
        if entry.has("points"):
            total += int(entry["points"])
        if entry.has("bonus"):
            total += int(entry["bonus"]) * 2
        if entry.has("penalty"):
            total -= int(entry["penalty"])
    return total
