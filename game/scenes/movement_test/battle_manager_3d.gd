extends Node3D
class_name BattleManager3D

@export var ships: Array[NavalShip3D]
var current_turn: int = 0
var current_ship_index: int = 0

#@onready var movement_controller: MovementController3D = $UI/MovementController3D

var movement_controller: MovementController3D


signal turn_changed
signal ship_turn_started(ship: NavalShip3D)
signal ship_turn_ended(ship: NavalShip3D)

func _ready():
    # Use find_child to search the whole tree
    movement_controller = find_child("MovementController3D", true, false)
    
    if not movement_controller:
        push_error("MovementController3D not found!")
        return
    
    print("=== BATTLEMANAGER3D READY ===")
    print("Movement controller found: ", movement_controller.name)
    print("Ships: ", ships.size())
    print("============================")
    
    movement_controller.movement_confirmed.connect(_on_movement_confirmed)
    start_next_turn()
    
#func _ready():
    ## Try different possible paths
    #movement_controller = get_node_or_null("UI/MovementController")
    #
    ## If that doesn't work, search the whole scene
    #if not movement_controller:
        #movement_controller = find_child("MovementController", true, false)
    #
    ## If still not found, error out with helpful message
    #if not movement_controller:
        #push_error("MovementController not found! Check your scene structure.")
        #return
    #
    #movement_controller.movement_confirmed.connect(_on_movement_confirmed)
    #print("Ships found: ", ships.size())
    #start_next_turn()
    

func start_next_turn() -> void:
    if current_ship_index >= ships.size():
        current_ship_index = 0
        current_turn += 1
        turn_changed.emit()
    
    var current_ship = ships[current_ship_index]
    print("Current ship: ", current_ship.name)  # Debug
    ship_turn_started.emit(current_ship)
    movement_controller.set_selected_ship(current_ship)

func _on_movement_confirmed(angle: float, distance: float) -> void:
    var current_ship = ships[current_ship_index]
    
    while current_ship.is_moving:
        await get_tree().process_frame
    
    ship_turn_ended.emit(current_ship)
    current_ship_index += 1
    start_next_turn()
