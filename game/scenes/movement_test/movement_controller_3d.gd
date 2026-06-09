extends Control
class_name MovementController3D

var angle_slider: HSlider
var distance_slider: HSlider
var angle_label: Label
var distance_label: Label
var confirm_button: Button

var selected_ship: NavalShip3D
var preview_line: Line2D

signal movement_confirmed(angle: float, distance: float)

func _ready():
    # === SETUP THE UI CONTAINER ===
    size = get_viewport_rect().size
    anchor_left = 0.0
    anchor_top = 0.0
    anchor_right = 0.3
    anchor_bottom = 1.0
    
    # Add a background so you can see it
    var bg = ColorRect.new()
    bg.color = Color(0.1, 0.1, 0.1, 0.8)
    bg.anchor_left = 0.0
    bg.anchor_top = 0.0
    bg.anchor_right = 1.0
    bg.anchor_bottom = 1.0
    add_child(bg)
    move_child(bg, 0)
    
    # === FIND UI ELEMENTS ===
    angle_label = get_node_or_null("AngleLabel")
    angle_slider = get_node_or_null("AngleSlider")
    distance_label = get_node_or_null("DistanceLabel")
    distance_slider = get_node_or_null("DistanceSlider")
    confirm_button = get_node_or_null("ConfirmButton")
    
    # Debug output
    print("=== UI ELEMENTS FOUND ===")
    print("angle_label: ", angle_label)
    print("angle_slider: ", angle_slider)
    print("distance_label: ", distance_label)
    print("distance_slider: ", distance_slider)
    print("confirm_button: ", confirm_button)
    print("========================")
    
    # === POSITION THEM ===
    var y_pos = 20.0
    var spacing = 80.0
    
    if angle_label:
        angle_label.position = Vector2(10, y_pos)
        angle_label.size = Vector2(200, 30)
        print("Positioned angle_label at ", angle_label.position)
        y_pos += spacing
    
    if angle_slider:
        angle_slider.position = Vector2(10, y_pos)
        angle_slider.size = Vector2(200, 30)
        angle_slider.min_value = 0
        angle_slider.max_value = 360
        print("Positioned angle_slider at ", angle_slider.position)
        y_pos += spacing
    
    if distance_label:
        distance_label.position = Vector2(10, y_pos)
        distance_label.size = Vector2(200, 30)
        print("Positioned distance_label at ", distance_label.position)
        y_pos += spacing
    
    if distance_slider:
        distance_slider.position = Vector2(10, y_pos)
        distance_slider.size = Vector2(200, 30)
        distance_slider.min_value = 0
        distance_slider.max_value = 500
        print("Positioned distance_slider at ", distance_slider.position)
        y_pos += spacing
    
    if confirm_button:
        confirm_button.position = Vector2(10, y_pos)
        confirm_button.size = Vector2(200, 40)
        confirm_button.text = "Confirm Move"
        print("Positioned confirm_button at ", confirm_button.position)
    
    # === CONNECT SIGNALS ===
    if angle_slider:
        angle_slider.value_changed.connect(_on_angle_changed)
    if distance_slider:
        distance_slider.value_changed.connect(_on_distance_changed)
    if confirm_button:
        confirm_button.pressed.connect(_confirm_movement)
    
    #preview_line = Line2D.new()
    #preview_line.default_color = Color.CYAN
    #preview_line.width = 2.0
    #add_child(preview_line)

func set_selected_ship(ship: NavalShip3D) -> void:
    selected_ship = ship
    if angle_slider:
        angle_slider.value = 0
    if distance_slider:
        distance_slider.value = 0
    _update_preview()

func _on_angle_changed(value: float) -> void:
    if angle_label:
        angle_label.text = "Angle: %.0f°" % value
    _update_preview()

func _on_distance_changed(value: float) -> void:
    if distance_label:
        distance_label.text = "Distance: %.0f" % value
    _update_preview()

func _update_preview() -> void:
    if not selected_ship or not angle_slider or not distance_slider:
        return
    
    var angle = deg_to_rad(angle_slider.value)
    var distance = distance_slider.value
    
    # Convert angle to direction in 3D (XZ plane)
    var direction = Vector3(cos(angle), 0, sin(angle))
    var start = selected_ship.global_position
    var end = start + direction * distance
    
    #preview_line.clear_points()
    #preview_line.add_point(start)
    #preview_line.add_point(end)

func _confirm_movement() -> void:
    if selected_ship and angle_slider and distance_slider:
        var angle = angle_slider.value
        var distance = distance_slider.value
        selected_ship.set_movement_target(angle, distance)
        movement_confirmed.emit(angle, distance)
