@tool
extends MeshInstance3D


func _ready() -> void:
	add_to_group("terrain")

@export_range(64, 2048, 16) var size = 256.0:
	set(new_size):
		size = new_size
		update_mesh()

@export_range(4, 2048, 4) var resolution = 32:
	set(new_res):
		resolution = new_res
		update_mesh()

@export var noise: FastNoiseLite:
	set(new_noise):
		noise = new_noise;
		update_mesh()
		if noise:
			noise.changed.connect(update_mesh)

@export_range(4, 128, 4) var height = 64:
	set(new_height):
		height = new_height;
		update_mesh()

func get_height(x, y) -> float:
	return (noise.get_noise_2d(x, y) - 0.5) * height;

func get_normal(x, y) -> Vector3:
	var epsilon = size / resolution
	var normal = Vector3(
		(get_height(x - epsilon, y) - get_height(x + epsilon, y)) / (2 * epsilon),
		1.0,
		(get_height(x, y - epsilon) - get_height(x, y + epsilon)) / (2 * epsilon),
	)
	return normal.normalized()

func update_mesh():
	var plane = PlaneMesh.new()
	plane.subdivide_width = resolution
	plane.subdivide_depth = resolution
	plane.size = Vector2(size, size)
	
	var plane_arrays = plane.get_mesh_arrays()
	var vertex_array : PackedVector3Array = plane_arrays[ArrayMesh.ARRAY_VERTEX]
	var normal_array : PackedVector3Array = plane_arrays[ArrayMesh.ARRAY_NORMAL]
	var tangent_array : PackedFloat32Array = plane_arrays[ArrayMesh.ARRAY_TANGENT]

	for i in vertex_array.size():
		var vertex := vertex_array[i]
		var normal := Vector3.UP
		var tangent := Vector3.RIGHT
		if noise:
			vertex.y = get_height(vertex.x, vertex.z)
			normal = get_normal(vertex.x, vertex.z)
			tangent = normal.cross(Vector3.UP)
		vertex_array[i] = vertex
		normal_array[i] = normal
		tangent_array[4 * i + 0] = tangent.x
		tangent_array[4 * i + 1] = tangent.y
		tangent_array[4 * i + 2] = tangent.z

	var array_mesh = ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, plane_arrays)
	mesh = array_mesh
	
