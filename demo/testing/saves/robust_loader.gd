extends RefCounted
## Save loader fixture: validates and falls back to defaults.

const DEFAULTS := {"version": 2, "player": {"name": "", "level": 1, "hp": 10}, "inventory": [], "gold": 0}


static func load_save(text: String) -> Variant:
    var data = JSON.parse_string(text)
    if typeof(data) != TYPE_DICTIONARY:
        return DEFAULTS.duplicate(true)
    var out: Dictionary = DEFAULTS.duplicate(true)
    if typeof(data.get("gold")) in [TYPE_INT, TYPE_FLOAT]:
        out["gold"] = max(0, int(data["gold"]))
    if typeof(data.get("player")) == TYPE_DICTIONARY:
        out["player"] = data["player"]
    if typeof(data.get("inventory")) == TYPE_ARRAY:
        out["inventory"] = data["inventory"]
    return out


static func is_valid(save: Dictionary) -> bool:
    return typeof(save.get("gold")) in [TYPE_INT, TYPE_FLOAT] and typeof(save.get("player")) == TYPE_DICTIONARY and typeof(save.get("inventory")) == TYPE_ARRAY
