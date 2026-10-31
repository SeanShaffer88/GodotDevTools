extends RefCounted
## Property-test fixture: wrap_degrees forgets negative inputs.


static func wrap_degrees(deg: int) -> int:
    return deg % 360


static func clamp_hp(hp: int, max_hp: int) -> int:
    return clampi(hp, 0, max_hp)
