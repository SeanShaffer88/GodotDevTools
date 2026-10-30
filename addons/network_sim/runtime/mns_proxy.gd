## Multiplayer Network Simulator - in-game proxy node.
## Put this node between your game and its multiplayer calls during
## local testing: send through the proxy instead of the peer directly,
## and every packet experiences the simulated latency / loss /
## disconnects. Delivery arrives via the `message_delivered` signal.
## Remove or bypass the node for release builds - it is a test tool.
extends Node

signal message_delivered(payload: Dictionary)

const Channel := preload("res://addons/network_sim/core/mns_channel.gd")

var channel = Channel.new()

@export var latency_ticks: int = 6:
    set(v): latency_ticks = v; channel.latency_ticks = v
@export var jitter_ticks: int = 3:
    set(v): jitter_ticks = v; channel.jitter_ticks = v
@export_range(0.0, 1.0) var loss_fraction: float = 0.05:
    set(v): loss_fraction = v; channel.loss_fraction = v


func _ready() -> void:
    channel.latency_ticks = latency_ticks
    channel.jitter_ticks = jitter_ticks
    channel.loss_fraction = loss_fraction


func send(payload: Dictionary) -> void:
    channel.send(payload)


func _physics_process(_delta: float) -> void:
    for msg in channel.advance():
        message_delivered.emit(msg)
