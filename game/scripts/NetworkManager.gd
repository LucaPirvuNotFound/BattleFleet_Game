extends Node

# This will hold either our Server or Client logic script
var impl: Node = null

func _ready() -> void:
	if OS.has_feature("server"):
		impl = preload("res://scripts/ServerImpl.gd").new()
	else:
		impl = preload("res://scripts/ClientImpl.gd").new()
	
	add_child(impl)
