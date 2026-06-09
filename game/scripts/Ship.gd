@tool
extends Node3D

func _ready() -> void:
    var map = get_tree().get_first_node_in_group("map")
    if map and map.has_method("register_ship"):
        map.register_ship(self)
