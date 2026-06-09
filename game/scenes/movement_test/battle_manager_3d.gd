extends Node3D
class_name BattleManager3D

@export var ships: Array[NavalShip3D]

signal turn_changed
signal ship_turn_started(ship: NavalShip3D)
signal ship_turn_ended(ship: NavalShip3D)

var current_turn: int = 0
var current_ship_index: int = 0
var _movement_controller: MovementController3D

@export var range_ring_scene: PackedScene

var _range_ring: RangeRing




func _ready() -> void:
    _movement_controller = find_child("MovementController3D", true, false)

    if not _movement_controller:
        push_error("BattleManager3D: MovementController3D not found!")
        return

    _movement_controller.movement_confirmed.connect(_on_movement_confirmed)
    _movement_controller.fire_confirmed.connect(_on_fire_confirmed)
    _movement_controller.turn_ended.connect(_on_turn_ended)

    if range_ring_scene:
        _range_ring = range_ring_scene.instantiate() as RangeRing
        add_child(_range_ring)


    start_next_ship_turn()



func start_next_ship_turn() -> void:
    if current_ship_index >= ships.size():
        current_ship_index = 0
        current_turn += 1
        turn_changed.emit()

    var ship = _current_ship()
    ship.reset_turn_actions()

    # Jump ring instantly to the new ship
    if _range_ring:
        _range_ring.attach_to_ship(ship)

    ship_turn_started.emit(ship)
    _movement_controller.set_selected_ship(ship)

func _on_movement_confirmed(angle: float, distance: float) -> void:
    _current_ship().set_movement_target(angle, distance)


func _on_fire_confirmed(angle: float, distance: float) -> void:
    _current_ship().fire_cannon(angle, distance)


func _on_turn_ended() -> void:
    # Wait for the ship to finish any movement in progress before advancing
    var ship = _current_ship()

    if ship.is_moving:
        await _wait_for_ship_done(ship)

    ship_turn_ended.emit(ship)
    current_ship_index += 1
    start_next_ship_turn()


func _wait_for_ship_done(ship: NavalShip3D) -> void:
    while ship.is_moving:
        await get_tree().process_frame


func _current_ship() -> NavalShip3D:
    return ships[current_ship_index]
