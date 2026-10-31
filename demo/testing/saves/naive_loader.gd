extends RefCounted
## Save loader fixture: trusts its input (the save corruption tester should catch this).


static func load_save(text: String) -> Variant:
    var data = JSON.parse_string(text)
    if data == null:
        return null
    return data


static func is_valid(save: Dictionary) -> bool:
    return typeof(save.get("gold")) in [TYPE_INT, TYPE_FLOAT] and typeof(save.get("player")) == TYPE_DICTIONARY and typeof(save.get("inventory")) == TYPE_ARRAY
