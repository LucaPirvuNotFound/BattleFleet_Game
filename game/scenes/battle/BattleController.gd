extends Control

@onready var _phase_label: Label = %PhaseLabel
@onready var _info_label: Label = %InfoLabel
@onready var _action_button: Button = %ActionButton
@onready var _back_button: Button = %BackButton

var _poll_timer: Timer


func _ready() -> void:
	if not MatchContext.is_active:
		_set_info("No active match. Use Back to return to the menu.")
		_action_button.visible = false
		_back_button.pressed.connect(_on_back_pressed)
		return

	_poll_timer = Timer.new()
	_poll_timer.wait_time = 1.5
	_poll_timer.timeout.connect(_on_poll_timeout)
	add_child(_poll_timer)
	_poll_timer.start()

	_refresh_from_context()
	_action_button.pressed.connect(_on_action_pressed)
	_back_button.pressed.connect(_on_back_pressed)


func _set_info(message: String) -> void:
	_info_label.text = message


func _refresh_from_context() -> void:
	_phase_label.text = "Phase: %s" % MatchContext.phase.to_upper()
	_info_label.text = (
		"Match: %s\nMode: %s | Map seed: %d (map %d)\nFirst: %s | You go first: %s\nOpponent: %s"
		% [
			MatchContext.match_id,
			MatchContext.mode,
			MatchContext.map_seed,
			MatchContext.map_index,
			MatchContext.first_player_username,
			str(MatchContext.you_go_first),
			MatchContext.opponent_username if MatchContext.opponent_username != "" else "(none)",
		]
	)

	match MatchContext.phase:
		"placement":
			_action_button.text = "Submit placement & ready"
			_action_button.disabled = false
		"combat":
			_action_button.text = "Combat (stub)"
			_action_button.disabled = true
			_info_label.text += "\n\nBoth players ready — combat phase starts here."
		_:
			_action_button.text = "Waiting"
			_action_button.disabled = true


func _on_action_pressed() -> void:
	_action_button.disabled = true
	var match_id := MatchContext.match_id
	var result: Dictionary

	match MatchContext.phase:
		"placement":
			var placements := NetworkManager.match_service.build_default_placements(
				MatchContext.your_fleet
			)
			result = await NetworkManager.match_service.submit_placement(match_id, placements)
			if result.success:
				result = await NetworkManager.match_service.mark_ready(match_id)
		_:
			result = {"success": false, "error": "Nothing to do in this phase"}

	if not result.success:
		_info_label.text = "Error: %s" % str(result.get("error", "unknown"))
	else:
		_refresh_from_context()

	_action_button.disabled = false


func _on_poll_timeout() -> void:
	if not MatchContext.is_active:
		return
	var result := await NetworkManager.match_service.fetch_match(MatchContext.match_id)
	if result.success:
		var previous_phase := MatchContext.phase
		_refresh_from_context()
func _on_back_pressed() -> void:
	MatchContext.clear()
	get_tree().change_scene_to_packed(preload("res://scenes/menus/MainMenu.tscn"))
