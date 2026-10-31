extends CharacterBody2D

signal died
signal never_fired(amount: int)

const SPEED := 200.0
var health = 100
var armor: int = 5
var label_text


func _ready() -> void:
    died.connect(_on_died)
    $Sprite.visible = true
    %HealthBar.value = health
    $Weapon/Muzzle.visible = false
    get_node("Sprite").modulate = Color.WHITE


func take_damage(amount, source) -> void:
    health -= amount
    if health <= 0:
        died.emit()


func _on_died():
    queue_free()


func helper_never_called(x: int) -> int:
    return x * 2


func choose_action(state: Dictionary) -> String:
    if state.get("stunned", false):
        return "wait"
    elif state.get("low_health", false) and state.get("has_potion", false):
        return "heal"
    elif state.get("enemy_near", false):
        for enemy in state.get("enemies", []):
            if enemy.get("boss", false):
                if state.get("brave", false) or state.get("cornered", false):
                    while state.get("charging", false):
                        if enemy.get("shield", false):
                            return "dodge"
                        state["charging"] = false
                    return "fight"
                return "flee"
        return "attack"
    elif state.get("loot", false) or state.get("chest", false):
        return "loot"
    return "idle"


func tally_score(entries: Array) -> int:
    var total := 0
    for entry in entries:
        if entry.has("points"):
            total += int(entry["points"])
        if entry.has("bonus"):
            total += int(entry["bonus"]) * 2
        if entry.has("penalty"):
            total -= int(entry["penalty"])
    return total
