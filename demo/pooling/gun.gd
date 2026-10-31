extends Node2D

const BULLET := preload("res://demo/pooling/bullet.tscn")
var crate_scene: PackedScene = preload("res://demo/pooling/crate.tscn")
var mystery: PackedScene


func _ready() -> void:
    for i in 4:
        add_child(crate_scene.instantiate())
    $Cooldown.timeout.connect(_reload)


func _physics_process(_delta: float) -> void:
    if Input.is_action_pressed("ui_accept"):
        add_child(BULLET.instantiate())


func _reload() -> void:
    if mystery:
        add_child(mystery.instantiate())
