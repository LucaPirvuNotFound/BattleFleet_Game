extends PanelContainer
class_name BattleHudPanel

## HUD panels on CanvasLayer: sync offset rect to child minimum size + style margins.

@export var fit_on_ready := false


func _ready() -> void:
	if fit_on_ready:
		fit_to_content()


func fit_to_content(fixed_width: float = -1.0) -> void:
	call_deferred("_deferred_fit", fixed_width)


func _deferred_fit(fixed_width: float) -> void:
	await get_tree().process_frame
	reset_size()
	var min_sz := get_minimum_size()
	if fixed_width > 0.0:
		min_sz.x = fixed_width
	_apply_content_size(min_sz)


func _apply_content_size(min_sz: Vector2) -> void:
	custom_minimum_size = min_sz

	var pinned_right := is_equal_approx(anchor_left, 1.0) and is_equal_approx(anchor_right, 1.0)
	var pinned_left := is_equal_approx(anchor_left, 0.0) and is_equal_approx(anchor_right, 0.0)

	if pinned_right and not pinned_left:
		offset_left = offset_right - min_sz.x
	elif pinned_left or offset_right > offset_left:
		offset_right = offset_left + min_sz.x
	else:
		size.x = min_sz.x

	offset_bottom = offset_top + min_sz.y
