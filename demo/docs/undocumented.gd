## Fixture: a half-documented script for the documentation generator.
extends Node

signal documented_signal(value: int)

signal mystery_signal

## Documented export: how loudly the fixture greets.
@export var shout_level: int = 3

@export var quiet_flag := false


## Documented: greets whoever is listening, loudly per shout_level.
func greet(who: String) -> String:
    return "hello ".repeat(shout_level) + who


func mystery(a: int, b := 2) -> int:
    return a + b
