extends Camera3D
## Map camera: far = top-down (orthographic), close = tilted 3D (perspective). Drag to pan.

signal zoom_changed(zoom_out_ratio: float)
signal view_changed

@export var zoom_min: float = -0.45
@export var zoom_max: float = 1.0
@export var zoom_step: float = 0.08

@export var far_height: float = 420.0
@export var close_height: float = 55.0
@export var close_back_offset: float = 90.0
@export var far_ortho_size: float = 380.0
@export var max_zoom_out_multiplier: float = 1.75
@export var close_fov: float = 52.0
@export var ortho_zoom_threshold: float = 0.35
## Show km grid when zoomed out at least this much (0.8 = 80% zoomed out).
@export var grid_zoom_out_threshold: float = 0.8
## Pan margin when fully zoomed out (world units).
@export var bounds_margin_far: float = 160.0
## Pan margin when fully zoomed in — tighter boundaries.
@export var bounds_margin_near: float = 6.0
## Extra north/south pan slack when zoomed out (multiplier on vertical limit).
@export var vertical_pan_boost: float = 1.6

var map_half_size: float = 128.0
var focus: Vector3 = Vector3.ZERO

var _zoom: float = 0.0
var _last_zoom_out_ratio: float = -1.0
var _dragging: bool = false
var _last_mouse: Vector2 = Vector2.ZERO
var _glide_tween: Tween


func setup_for_terrain(terrain: MeshInstance3D) -> void:
	if terrain:
		map_half_size = float(terrain.size) * 0.5
	_zoom = 0.0
	focus = Vector3.ZERO
	current = true
	_apply_transform()


func handle_input_event(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = mb.pressed
			_last_mouse = mb.position
		elif mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				_zoom = clampf(_zoom + zoom_step, zoom_min, zoom_max)
				_apply_transform()
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_zoom = clampf(_zoom - zoom_step, zoom_min, zoom_max)
				_apply_transform()
	elif event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		var delta := motion.position - _last_mouse
		_last_mouse = motion.position
		var viewport_size := get_viewport().get_visible_rect().size
		if viewport_size.y <= 0.0:
			return
		var pan_scale := _get_pan_scale(viewport_size)
		focus.x -= delta.x * pan_scale
		focus.z -= delta.y * pan_scale
		_clamp_focus()
		_apply_transform()


func _get_pan_scale(viewport_size: Vector2) -> float:
	if projection == PROJECTION_ORTHOGONAL:
		return size / viewport_size.y
	var visible_half := tan(deg_to_rad(fov * 0.5)) * position.y
	return (visible_half * 2.0) / viewport_size.y


func get_zoom_out_ratio() -> float:
	return inverse_lerp(zoom_max, zoom_min, _zoom)


func should_show_km_grid() -> bool:
	return get_zoom_out_ratio() >= grid_zoom_out_threshold


func _apply_transform() -> void:
	if _zoom <= ortho_zoom_threshold:
		projection = PROJECTION_ORTHOGONAL
		var t := inverse_lerp(zoom_min, ortho_zoom_threshold, _zoom)
		var max_size := far_ortho_size * max_zoom_out_multiplier
		size = lerpf(max_size, far_ortho_size * 0.55, t)
		position = Vector3(focus.x, far_height, focus.z)
		rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	else:
		projection = PROJECTION_PERSPECTIVE
		fov = close_fov
		var t := (_zoom - ortho_zoom_threshold) / (1.0 - ortho_zoom_threshold)
		var height := lerpf(far_height * 0.7, close_height, t)
		var back := lerpf(10.0, close_back_offset, t)
		position = Vector3(focus.x, height, focus.z + back)
		look_at(Vector3(focus.x, 0.0, focus.z), Vector3.UP)

	_clamp_focus()
	var zoom_out_ratio := get_zoom_out_ratio()
	if not is_equal_approx(zoom_out_ratio, _last_zoom_out_ratio):
		_last_zoom_out_ratio = zoom_out_ratio
		zoom_changed.emit(zoom_out_ratio)
	view_changed.emit()


func _clamp_focus() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var half_w := _get_visible_half_width(viewport_size)
	var half_h := _get_visible_half_height(viewport_size)
	var zoom_out := get_zoom_out_ratio()
	var limit_x := _pan_limit(map_half_size, half_w, zoom_out)
	var limit_z := _pan_limit(map_half_size, half_h, zoom_out, true)
	focus.x = clampf(focus.x, -limit_x, limit_x)
	focus.z = clampf(focus.z, -limit_z, limit_z)


func _pan_limit(half_map: float, half_view: float, zoom_out: float, vertical: bool = false) -> float:
	var margin := _current_bounds_margin()
	var limit: float
	if half_view >= half_map:
		# Zoomed out: allow panning so top/bottom (or sides) of the map can be reached.
		limit = half_view + margin
	else:
		limit = half_map - half_view + margin
	if vertical:
		limit *= lerpf(1.0, vertical_pan_boost, zoom_out)
	return maxf(limit, margin)


func _current_bounds_margin() -> float:
	# Zoomed in → smaller pan limits. Zoomed out → wider limits.
	return lerpf(bounds_margin_near, bounds_margin_far, get_zoom_out_ratio())


func focus_on_world_point(point: Vector3) -> void:
	_stop_glide()
	focus = Vector3(point.x, 0.0, point.z)
	_clamp_focus()
	_apply_transform()


func glide_to_world_point(point: Vector3, duration: float = 1.15) -> void:
	_stop_glide()
	var target := Vector3(point.x, 0.0, point.z)
	var start := focus
	_glide_tween = create_tween()
	_glide_tween.set_trans(Tween.TRANS_SINE)
	_glide_tween.set_ease(Tween.EASE_IN_OUT)
	_glide_tween.tween_method(_set_focus_during_glide, start, target, duration)


func _set_focus_during_glide(value: Vector3) -> void:
	focus = value
	_clamp_focus()
	_apply_transform()


func _stop_glide() -> void:
	if _glide_tween:
		_glide_tween.kill()
		_glide_tween = null


func _get_visible_half_width(viewport_size: Vector2) -> float:
	var aspect := viewport_size.x / maxf(viewport_size.y, 1.0)
	if projection == PROJECTION_ORTHOGONAL:
		return size * aspect
	return tan(deg_to_rad(fov * 0.5)) * position.y * aspect


func _get_visible_half_height(viewport_size: Vector2) -> float:
	if projection == PROJECTION_ORTHOGONAL:
		return size
	return tan(deg_to_rad(fov * 0.5)) * position.y
