extends Node

@onready var http: HTTPRequest = $HTTPRequest


func fetch_scores() -> void:
    http.request_completed.connect(_on_scores)
    http.request("https://api.example.com/scores")


func _on_scores(_result: int, _code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    var scores = JSON.parse_string(body.get_string_from_utf8())
    print(scores[0])


func fetch_news() -> void:
    var r := HTTPRequest.new()
    add_child(r)
    r.timeout = 5.0
    r.request_completed.connect(_on_news)
    r.request("https://api.example.com/news")


func _on_news(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    if result != HTTPRequest.RESULT_SUCCESS or code != 200:
        return
    print(body.size())
