extends Control
class_name CompassAnglePicker

signal angle_changed(angle: float)

@export var min_angle: float = -180.0
@export var max_angle: float = 180.0

var angle: float = 0.0:
	set(value):
		angle = clampf(value, min_angle, max_angle)
		angle_changed.emit(angle)
		queue_redraw()

var _dragging := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(200, 118)


func set_angle(value: float) -> void:
	angle = value


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and _is_on_arc(mb.position):
				_dragging = true
				_set_angle_from_local(mb.position)
			else:
				_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		_set_angle_from_local((event as InputEventMouseMotion).position)


func _is_on_arc(local_pos: Vector2) -> bool:
	var center := _arc_center()
	var radius := _arc_radius()
	var to_point: Vector2 = local_pos - center
	if to_point.y > 6.0:
		return false
	var dist := to_point.length()
	if dist > radius + 18.0 or dist < radius - 18.0:
		return false
	var arc_deg := rad_to_deg(atan2(to_point.x, -to_point.y))
	return arc_deg >= -92.0 and arc_deg <= 92.0


func _set_angle_from_local(local_pos: Vector2) -> void:
	var center := _arc_center()
	var to_point: Vector2 = local_pos - center
	if to_point.y > 6.0:
		return
	var arc_deg := rad_to_deg(atan2(to_point.x, -to_point.y))
	angle = clampf(arc_deg * 2.0, min_angle, max_angle)


func _arc_center() -> Vector2:
	var pad := 14.0
	return Vector2(size.x * 0.5, size.y - pad)


func _arc_radius() -> float:
	var pad := 14.0
	return minf((size.x - pad * 2.0) * 0.5, size.y - pad - 8.0)


func _arc_dir_for_ship_angle(ship_deg: float) -> Vector2:
	var arc_rad := deg_to_rad(ship_deg * 0.5)
	return Vector2(sin(arc_rad), -cos(arc_rad))


func _draw() -> void:
	var center := _arc_center()
	var radius := _arc_radius()

	_draw_arc_polyline(center, radius, -90.0, 90.0, Color(0.55, 0.72, 0.9, 0.9), 2.5)
	_draw_tick(center, radius, 0.0, "0°", Color(0.9, 0.95, 1.0))
	_draw_tick(center, radius, -90.0, "-90°", Color(0.75, 0.8, 0.9))
	_draw_tick(center, radius, 90.0, "90°", Color(0.75, 0.8, 0.9))
	_draw_tick(center, radius, -180.0, "-180°", Color(0.75, 0.8, 0.9))
	_draw_tick(center, radius, 180.0, "180°", Color(0.75, 0.8, 0.9))

	var pointer_dir := _arc_dir_for_ship_angle(angle)
	var pointer_tip: Vector2 = center + pointer_dir * radius
	draw_line(center, pointer_tip, Color(1.0, 0.85, 0.25, 1.0), 3.0)
	draw_circle(pointer_tip, 7.0, Color(1.0, 0.85, 0.25, 1.0))
	draw_circle(pointer_tip, 3.0, Color(0.15, 0.12, 0.05, 1.0))
	draw_circle(center, 5.0, Color(0.85, 0.9, 1.0, 1.0))


func _draw_arc_polyline(
	center: Vector2,
	radius: float,
	from_deg: float,
	to_deg: float,
	color: Color,
	width: float
) -> void:
	var steps := 32
	var points: PackedVector2Array = []
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var deg := lerpf(from_deg, to_deg, t)
		var rad := deg_to_rad(deg)
		points.append(center + Vector2(sin(rad), -cos(rad)) * radius)
	for i in range(points.size() - 1):
		draw_line(points[i], points[i + 1], color, width)


func _draw_tick(center: Vector2, radius: float, ship_deg: float, label: String, color: Color) -> void:
	var dir := _arc_dir_for_ship_angle(ship_deg)
	draw_line(center + dir * (radius - 8.0), center + dir * (radius + 8.0), color, 1.5)
	var font := ThemeDB.fallback_font
	var font_size := 11
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var label_pos: Vector2 = center + dir * (radius + 14.0) - text_size * 0.5
	draw_string(font, label_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
