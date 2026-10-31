extends RefCounted
## Mutation fixture: clamps health into [0, max_hp].


static func clamp_health(value: int, max_hp: int) -> int:
    if value < 0:
        return 0
    if value > max_hp:
        return max_hp
    return value


static func is_dead(hp: int) -> bool:
    return hp <= 0
