@tool
extends SubViewportContainer

const MINIMAP_PX := 200

var _viewport: SubViewport
var _ships_layer: Node2D
var _background: TextureRect

var _map_size: float = 1024.0
var _ship_sprites: Dictionary = {}
var _terrain_setup_done: bool = false
var _terrain: MeshInstance3D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(MINIMAP_PX, MINIMAP_PX)
	_viewport.transparent_bg = true
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)

	_background = TextureRect.new()
	_background.stretch_mode = TextureRect.STRETCH_KEEP
	_background.size = Vector2(MINIMAP_PX, MINIMAP_PX)
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport.add_child(_background)

	_ships_layer = Node2D.new()
	_viewport.add_child(_ships_layer)


func setup(terrain_node: MeshInstance3D, map_size: float) -> void:
	_map_size = map_size
	_terrain = terrain_node
	if terrain_node and terrain_node.noise:
		_generate_terrain_texture()
		_terrain_setup_done = true


func _find_terrain() -> MeshInstance3D:
	var map = get_tree().get_first_node_in_group("map")
	if map:
		for child in map.get_children():
			if child is MeshInstance3D and child.name == "Terrain":
				return child
	return null


func _generate_terrain_texture() -> void:
	var noise: FastNoiseLite = _terrain.noise
	var height_amp: float = _terrain.height if "height" in _terrain else 64.0
	var image := Image.create(MINIMAP_PX, MINIMAP_PX, false, Image.FORMAT_RGB8)

	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.704, 0.816, 1.0])
	grad.colors = PackedColorArray([
		Color(0.15, 0.25, 0.55),
		Color(0.25, 0.4, 0.6),
		Color(0.73, 0.71, 0.33),
		Color(0.28, 0.18, 0.06),
		Color(0.35, 0.16, 0.06),
		Color(0.40, 0.12, 0.04),
	])

	var half := _map_size * 0.5
	for y in MINIMAP_PX:
		for x in MINIMAP_PX:
			var wx := (float(x) / MINIMAP_PX) * _map_size - half
			var wz := (float(y) / MINIMAP_PX) * _map_size - half
			var h := (noise.get_noise_2d(wx, wz) - 0.5) * height_amp
			var uv := (h / height_amp) + 0.5
			image.set_pixel(x, y, grad.sample(uv))

	_background.texture = ImageTexture.create_from_image(image)


func _make_dot_tex() -> ImageTexture:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)


func _ensure_ship_sprite(ship: Node3D) -> Sprite2D:
	if _ship_sprites.has(ship):
		return _ship_sprites[ship]
	var sprite := Sprite2D.new()
	sprite.texture = _make_dot_tex()
	sprite.modulate = Color(0.8, 0.85, 0.95)
	sprite.centered = true
	_ship_sprites[ship] = sprite
	_ships_layer.add_child(sprite)
	return sprite


func _process(_delta: float) -> void:
	if not _terrain_setup_done:
		var t = _find_terrain()
		if t and t.noise:
			_terrain = t
			if "size" in t:
				_map_size = t.size
			_generate_terrain_texture()
			_terrain_setup_done = true

	var seen := {}
	for ship in get_tree().get_nodes_in_group("ships"):
		if is_instance_valid(ship):
			seen[ship] = true
			var sprite := _ensure_ship_sprite(ship)
			var nx = (ship.global_position.x / _map_size) + 0.5
			var nz = (ship.global_position.z / _map_size) + 0.5
			sprite.position = Vector2(nx * MINIMAP_PX, nz * MINIMAP_PX)

	for ship in _ship_sprites.keys():
		if not seen.has(ship):
			_ship_sprites[ship].queue_free()
			_ship_sprites.erase(ship)
