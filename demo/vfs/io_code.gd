## Fixture: path handling that only works on one platform - exactly the
## literals the virtual filesystem audit flags.
extends Node

const WINDOWS_SAVE := "user://saves\\slot1.dat"
const LEGACY_PATH := "C:\\games\\demo\\save.dat"
const CLIMB := "user://../outside.txt"


## Returns the save slot path (on Windows-shaped paths only).
func load_slot() -> String:
    return WINDOWS_SAVE


## A legacy desktop path that dies on every other platform.
func legacy() -> String:
    return LEGACY_PATH


## Climbs out of the sandbox with a hardcoded parent step.
func climb() -> String:
    return CLIMB
