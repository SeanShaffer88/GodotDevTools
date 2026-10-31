## Fixture: the orphan pattern the leak hunter flags. This script
## detaches spent pickups from the tree and never frees them - exactly
## the remove_child-without-free bug the static scan looks for.
extends Node


## Drop a spent pickup. The node leaves the tree here and nothing ever
## frees it, so it stays in RAM for the rest of the session.
func drop_pickup(pickup: Node) -> void:
    remove_child(pickup)
    print("pickup dropped: ", pickup.name)
