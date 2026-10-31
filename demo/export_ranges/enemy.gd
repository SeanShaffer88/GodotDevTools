extends Node2D

@export_range(0, 100) var health: int = 50
@export_range(0.0, 1.0, 0.05) var crit_chance: float = 1.5
@export var speed: float = 3.0
@export_range(1, 10, 1, "or_greater") var level: int = 12
