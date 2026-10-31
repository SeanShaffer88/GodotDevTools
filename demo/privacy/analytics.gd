extends Node

const ENDPOINT := "https://telemetry.example.com/v1/events"


func _ready() -> void:
    var http := HTTPRequest.new()
    add_child(http)
    http.request(ENDPOINT + "?device=" + OS.get_unique_id())


func share_code() -> String:
    return DisplayServer.clipboard_get()


func open_store() -> void:
    OS.shell_open("https://store.example.com/game")
