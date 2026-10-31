extends Node

const HUD := preload("res://demo/testing/scenario/counter.tscn")


func open_level(name: String) -> void:
    var scene = load("res://levels/%s.tscn" % name)
    add_child(scene.instantiate())


func open_menu() -> void:
    add_child(load("res://demo/testing/menus/main_menu.tscn").instantiate())


func open_options() -> void:
    var res := load("res://demo/testing/scenario/counter.tscn")
    if res == null:
        push_error("options missing")
        return
    add_child(res.instantiate())


func stream_level() -> void:
    ResourceLoader.load_threaded_request("res://demo/testing/scenario/counter.tscn")
    var packed = ResourceLoader.load_threaded_get("res://demo/testing/scenario/counter.tscn")
    add_child(packed.instantiate())
