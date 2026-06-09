extends RefCounted
class_name BattleProjectileLauncher

const CANNONBALL_SCENE: PackedScene = preload("res://scenes/movement_test/projectile.tscn")
const BATTLE_BALL_SCRIPT: Script = preload("res://scripts/battle/BattleCannonBall.gd")
const IMPACT_SCENE := preload("res://scenes/movement_test/impact_marker.tscn")

const GRAVITY := 9.8
const MUZZLE_HEIGHT := 12.0
const SPAWN_FORWARD_OFFSET := 22.0
const MIN_LAUNCH_ANGLE_DEG := 8.0
const MAX_LAUNCH_ANGLE_DEG := 42.0
const WATER_SURFACE_Y := 1.55


static func fire(
	firer: Node3D,
	weapon_name: String,
	angle_deg: float,
	distance: float,
	on_impact: Callable
) -> BattleCannonBall:
	var stats := BattleTurnManager.get_weapon_stats(weapon_name)
	var max_range: float = float(stats.get("max_range", 200.0))
	var min_range: float = float(stats.get("min_range", 0.0))
	var aoe_radius: float = float(stats.get("aoe_radius", 15.0))
	var clamped_distance := clampf(distance, min_range, max_range)

	var battle_angle := -angle_deg
	var distance_ratio := clamped_distance / maxf(max_range, 1.0)
	var launch_angle_deg := lerpf(MIN_LAUNCH_ANGLE_DEG, MAX_LAUNCH_ANGLE_DEG, distance_ratio)
	var launch_angle_rad := deg_to_rad(launch_angle_deg)

	var ship_forward := -firer.global_transform.basis.z
	var direction := ship_forward.rotated(Vector3.UP, deg_to_rad(battle_angle)).normalized()
	var spawn_pos := (
		firer.global_position
		+ Vector3(0.0, MUZZLE_HEIGHT, 0.0)
		+ direction * SPAWN_FORWARD_OFFSET
	)

	var ship_flat := Vector3(firer.global_position.x, WATER_SURFACE_Y, firer.global_position.z)
	var landing_pos := ship_flat + direction * clamped_distance
	var flight_distance := maxf(clamped_distance - SPAWN_FORWARD_OFFSET, 12.0)

	var launch_speed := sqrt(flight_distance * GRAVITY / sin(2.0 * launch_angle_rad))
	var launch_velocity := (
		direction * launch_speed * cos(launch_angle_rad)
		+ Vector3.UP * launch_speed * sin(launch_angle_rad)
	)

	var world_parent := firer.get_parent() as Node3D
	var firer_ship_index := int(firer.get_meta("ship_index", -1))

	var ball := CANNONBALL_SCENE.instantiate() as RigidBody3D
	ball.set_script(BATTLE_BALL_SCRIPT)
	ball.collision_layer = 8
	ball.collision_mask = 7
	if world_parent:
		world_parent.add_child(ball)
	else:
		firer.get_tree().root.add_child(ball)

	ball.global_position = spawn_pos
	var battle_ball := ball as BattleCannonBall
	battle_ball.set_meta("firer", firer)
	battle_ball.firer_ship_index = firer_ship_index
	battle_ball.world_parent = world_parent
	battle_ball.target_distance = flight_distance
	battle_ball.origin = Vector3(spawn_pos.x, WATER_SURFACE_Y, spawn_pos.z)
	battle_ball.planned_landing = landing_pos
	battle_ball.impact_marker_scene = IMPACT_SCENE
	battle_ball.impact_radius = maxf(aoe_radius / 1.8, 4.0)
	battle_ball.linear_velocity = launch_velocity

	for node in battle_ball.get_tree().get_nodes_in_group("battle_ships"):
		if not node is CollisionObject3D:
			continue
		if int(node.get_meta("ship_index", -1)) == firer_ship_index:
			battle_ball.add_collision_exception_with(node as CollisionObject3D)

	battle_ball.landed.connect(
		func(impact_pos: Vector3) -> void:
			if on_impact.is_valid():
				on_impact.call(impact_pos, weapon_name, null)
	)
	battle_ball.hit_something.connect(
		func(body: Object, impact_pos: Vector3) -> void:
			if on_impact.is_valid():
				on_impact.call(impact_pos, weapon_name, body)
	)

	return battle_ball
