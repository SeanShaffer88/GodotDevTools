## Offline and Poor-Connection Test Harness - fault-injecting HTTP node.
## Use instead of HTTPRequest in builds you test: same request() call and
## request_completed signal. With a fault profile set, each request may be
## failed as offline (RESULT_CANT_CONNECT), timeout (RESULT_TIMEOUT after
## `timeout` seconds), slow (real request after delay_ms), or http_error
## (RESULT_SUCCESS with the profile's status code). Without a profile it
## behaves like a plain HTTPRequest.
extends Node

const Core := preload("res://addons/offline_harness/core/ocn_harness.gd")

signal request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray)

@export var timeout: float = 10.0
var profile: Dictionary = {}
var request_count: int = 0
var _core = Core.new()


## The fault the next request to `url` would get (does not count as a request).
func peek(url: String) -> Dictionary:
    return _core.decide(profile, url, request_count)


func request(url: String, custom_headers: PackedStringArray = PackedStringArray(), method: int = HTTPClient.METHOD_GET, request_data: String = "") -> Error:
    var f: Dictionary = _core.decide(profile, url, request_count) if not profile.is_empty() else {"fault": "none", "delay_ms": 0, "status": 0}
    request_count += 1
    match f["fault"]:
        "offline":
            call_deferred("emit_signal", "request_completed", HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray())
            return OK
        "timeout":
            get_tree().create_timer(timeout).timeout.connect(func(): request_completed.emit(HTTPRequest.RESULT_TIMEOUT, 0, PackedStringArray(), PackedByteArray()))
            return OK
        "http_error":
            call_deferred("emit_signal", "request_completed", HTTPRequest.RESULT_SUCCESS, int(f["status"]), PackedStringArray(), PackedByteArray())
            return OK
        "slow":
            get_tree().create_timer(float(f["delay_ms"]) / 1000.0).timeout.connect(func(): _real(url, custom_headers, method, request_data))
            return OK
    return _real(url, custom_headers, method, request_data)


func _real(url: String, headers: PackedStringArray, method: int, data: String) -> Error:
    var http := HTTPRequest.new()
    http.timeout = timeout
    add_child(http)
    http.request_completed.connect(func(r, c, h, b):
        request_completed.emit(r, c, h, b)
        http.queue_free())
    return http.request(url, headers, method, data)
