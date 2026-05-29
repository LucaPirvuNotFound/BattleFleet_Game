extends CharacterBody3D


const SPEED = 5.0
const JUMP_VELOCITY = 4.5


func _physics_process(delta: float) -> void:
	var overlaps = $VisArea.get_overlapping_bodies()
	
	if overlaps.size() > 0:
		for overlap in overlaps:
			if overlap.name == "Inamic2":
				#overlap.hide()
			 	
				var playerPosition = overlap.global_transform.origin
				$RayCast3D.look_at(playerPosition, Vector3.UP)
				$RayCast3D.force_raycast_update()
				
				if $RayCast3D.is_colliding():
					var collider = $RayCast3D.get_collider()
					
					if collider.name == "Inamic2":
						#overlap.show()
						
						$RayCast3D.debug_shape_custom_color = Color(0, 0, 250)
						print("merge")
					
					else:
						
						$RayCast3D.debug_shape_custom_color = Color(250, 0, 0)
						print("Nu este")
	
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
