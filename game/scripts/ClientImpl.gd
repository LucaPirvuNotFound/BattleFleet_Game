extends Node

const MAIN_MENU = preload("res://scenes/menus/MainMenu.tscn")

func _ready() -> void:
	var menu_instance = MAIN_MENU.instantiate()
	
	get_tree().root.add_child.call_deferred(menu_instance)
