# ProgressionBarUI.gd
# Attach to a Control node (e.g. a CanvasLayer or Panel) in your fleet/lobby scene.
#
# Required child nodes — set them in the Inspector or via @onready paths:
#   ProgressBar  node  → xp_bar       (shows XP progress within the current fleet level)
#   Label        node  → level_label  (e.g. "Fleet Level 4")
#   Label        node  → xp_label     (e.g. "240 / 400 XP")
#   VBoxContainer node → ship_list    (dynamically populated with ship rows)
#
# FIX (vs Unity version):
#   - Unity Initialise() passed DatabaseManager as a constructor argument to repos
#     that already use the singleton — parameter was unused. Removed.
#   - Repos are now instantiated without arguments (they all rely on DatabaseManager autoload).
#
# How to use:
#   1. Place this script on a Control node.
#   2. Assign the four child nodes in the Inspector.
#   3. Call  initialise(player_id)  once after the player has logged in.
#   4. Call  refresh()  any time the fleet XP changes (after a battle, for example).

extends Control

# ── Inspector references ──────────────────────────────────────────────────────

@export var xp_bar: ProgressBar
@export var level_label: Label
@export var xp_label: Label
@export var ship_list: VBoxContainer

# Optional: assign a PackedScene with a Label (and optionally an icon TextureRect)
# to use as the template for each ship row. If left null, plain Labels are created.
@export var ship_row_scene: PackedScene

# ── Internal state ────────────────────────────────────────────────────────────

var _stats_repo: PlayerStatsRepository
var _unlock_repo: ShipUnlockRepository
var _player_id: int = -1


# ── Public API ────────────────────────────────────────────────────────────────

## Call this once after the player has been loaded.
func initialise(player_id: int) -> void:
	_stats_repo  = PlayerStatsRepository.new()
	_unlock_repo = ShipUnlockRepository.new()
	_player_id   = player_id
	refresh()


## Refreshes both the XP bar and the ship unlock list.
## Call this whenever fleet XP or fleet level might have changed.
func refresh() -> void:
	if _player_id < 0:
		push_warning("ProgressionBarUI: Call initialise(player_id) before refresh().")
		return
	_refresh_xp_bar()
	_refresh_ship_list()


# ── XP bar ────────────────────────────────────────────────────────────────────

func _refresh_xp_bar() -> void:
	var data: Dictionary = _stats_repo.get_progress_bar_data(_player_id)
	var total_xp: int = data.get("total_xp", 0)
	var xp_start: int = data.get("xp_start", 0)
	var xp_end: int   = data.get("xp_end",   100)

	var current_level: int  = PlayerStatsRepository.calculate_fleet_level(total_xp)
	var xp_into_level: int  = total_xp - xp_start
	var xp_for_level: int   = xp_end   - xp_start

	if level_label:
		level_label.text = "Fleet Level %d" % current_level

	if xp_label:
		xp_label.text = "%d / %d XP" % [xp_into_level, xp_for_level]

	if xp_bar:
		xp_bar.min_value = 0.0
		xp_bar.max_value = float(xp_for_level)
		xp_bar.value     = float(xp_into_level)


# ── Ship unlock list ──────────────────────────────────────────────────────────

func _refresh_ship_list() -> void:
	if not ship_list:
		return

	# Clear previous rows
	for child in ship_list.get_children():
		child.queue_free()

	var statuses: Array = _unlock_repo.get_all_ship_statuses_for_player(_player_id)

	for status in statuses:
		var row: Control = _make_ship_row(status)
		ship_list.add_child(row)


func _make_ship_row(status: BattleFleetModels.ShipUnlockStatus) -> Control:
	# Use the provided prefab scene, or fall back to a plain HBoxContainer + Label
	if ship_row_scene:
		var row: Control = ship_row_scene.instantiate()

		# Expects a Label named "ShipLabel" and optionally a TextureRect named "LockIcon"
		var label := row.find_child("ShipLabel", true, false) as Label
		if label:
			label.text        = "%s  —  %s" % [status.display_name, status.get_unlock_label()]
			label.modulate    = Color.WHITE if status.is_unlocked else Color(0.6, 0.6, 0.6)

		var lock_icon := row.find_child("LockIcon", true, false) as TextureRect
		if lock_icon:
			lock_icon.visible = not status.is_unlocked

		return row
	else:
		# Fallback: simple HBoxContainer with two Labels
		var hbox := HBoxContainer.new()

		var name_label := Label.new()
		name_label.text     = status.display_name
		name_label.modulate = Color.WHITE if status.is_unlocked else Color(0.6, 0.6, 0.6)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(name_label)

		var status_label := Label.new()
		status_label.text     = status.get_unlock_label()
		status_label.modulate = Color(0.2, 0.9, 0.2) if status.is_unlocked else Color(0.9, 0.6, 0.2)
		hbox.add_child(status_label)

		return hbox
