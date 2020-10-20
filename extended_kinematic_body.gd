extends KinematicBody

var virtual_step_offset: float = 0.0

export (Vector3) var up: Vector3 = Vector3(0.0, 1.0, 0.0)
export (float) var step_height: float = 0.2
export (float) var anti_bump_factor: float = 0.75
export (float) var slope_stop_min_velocity: float = 0.05
export (float) var slope_max_angle: float = deg2rad(45)
export (bool) var infinite_interia: bool = false

var is_grounded: bool = false

onready var exclusion_array: Array = [self]

static func get_sphere_query_parameters(p_transform, p_radius, p_mask, p_exclude) -> PhysicsShapeQueryParameters:
	var query: PhysicsShapeQueryParameters = PhysicsShapeQueryParameters.new()
	query.set_transform(p_transform)
	var shape: SphereShape = SphereShape.new()
	shape.set_radius(p_radius)
	shape.set_mask(p_mask)
	shape.set_exclude(p_exclude)
	
	return query

static func get_capsule_query_parameters(p_transform, p_height, p_radius, p_mask, p_exclude) -> PhysicsShapeQueryParameters:
	var query: PhysicsShapeQueryParameters = PhysicsShapeQueryParameters.new()
	query.set_transform(p_transform)
	var shape: CapsuleShape = CapsuleShape.new()
	shape.set_height(p_height)
	shape.set_radius(p_radius)
	shape.set_mask(p_mask)
	shape.set_exclude(p_exclude)
	
	return query

static func test_slope(p_normal, p_up, p_slope_max_angle) -> float:
	var dot_product: float = p_normal.dot(p_up)
	return (dot_product >= 0.0 and dot_product < p_slope_max_angle) == false


func get_virtual_step_offset() -> float:
	return virtual_step_offset


func _is_valid_kinematic_collision(p_collision: KinematicCollision) -> bool:
	if p_collision == null:
		return false
	else:
		if ! p_collision.remainder.length() > 0.00001:
			return false

	return true


func _step_down(p_dss: PhysicsDirectSpaceState) -> void:
	# Process step down / fall
	virtual_step_offset = 0.0
	var collided: bool = test_move(global_transform, -(up * step_height), infinite_interia)
	if collided:
		var kinematic_collision = move_and_collide(
			-(up * anti_bump_factor), infinite_interia, false)
		if ! _is_valid_kinematic_collision(kinematic_collision):
			kinematic_collision = move_and_collide(
				-(up * (step_height - anti_bump_factor)), infinite_interia, false
			)
			if _is_valid_kinematic_collision(kinematic_collision):
				virtual_step_offset = kinematic_collision.get_travel().length() + anti_bump_factor
			else:
				virtual_step_offset = step_height

		if ! kinematic_collision:
			is_grounded = false
		else:
			if ! test_slope(kinematic_collision.normal, up, slope_max_angle):
				# Is the collision slope relative to world space?
				var ray_result = p_dss.intersect_ray(
					kinematic_collision.position + (up * step_height),
					kinematic_collision.position - (up * step_height),
					exclusion_array,
					collision_mask
				)
				if ray_result.empty() or ! test_slope(ray_result.normal, up, slope_max_angle):
					is_grounded = false
				# Is there valid floor beneath me?
				ray_result = p_dss.intersect_ray(
					global_transform.origin,
					global_transform.origin - (up * step_height * 2.0),
					exclusion_array,
					collision_mask
				)
				if ray_result.empty() or ! test_slope(ray_result.normal, up, slope_max_angle):
					is_grounded = false
	else:
		is_grounded = false


func extended_move(p_motion: Vector3, p_slide_attempts: int) -> Vector3:
	var global_transform: Transform = get_global_transform()
	
	var dss: PhysicsDirectSpaceState = PhysicsServer.space_get_direct_state(get_world().get_space())
	var motion: Vector3 = Vector3(0.0, 0.0, 0.0)
	if dss:
		var shape_owners = get_shape_owners()
		if shape_owners.size() == 1:
			var shape_count: int = shape_owner_get_shape_count(shape_owners[0])
			if shape_count == 1:
				var shape: Shape = shape_owner_get_shape(shape_owners[0], 0)
				if shape is CapsuleShape:
					if is_grounded:
						# Raise off the ground
						var step_up_kinematic_result: KinematicCollision = move_and_collide(
							up * step_height, infinite_interia, false
						)
						# Do actual motion
						motion = move_and_slide(
							p_motion,
							up,
							slope_stop_min_velocity,
							p_slide_attempts,
							slope_max_angle,
							infinite_interia
						)
						
						# Return to ground
						var step_down_kinematic_result: KinematicCollision = null
						
						if step_up_kinematic_result == null:
							virtual_step_offset = -step_height
							step_down_kinematic_result = move_and_collide(
								up * -step_height, infinite_interia, false
							)
						else:
							virtual_step_offset = -step_up_kinematic_result.get_travel().length()
							step_down_kinematic_result = move_and_collide(
								(up * -step_height) + step_up_kinematic_result.remainder,
								infinite_interia, false
							)
							
						if _is_valid_kinematic_collision(step_down_kinematic_result):
							virtual_step_offset += step_down_kinematic_result.get_travel().length()
							motion = (up * -step_height)
							
							# Use raycast from just above the kinematic result to determine the world normal of the collided surface
							var ray_result = dss.intersect_ray(
								step_down_kinematic_result.position + (up * step_height),
								step_down_kinematic_result.position - (up * anti_bump_factor),
								exclusion_array,
								collision_mask
							)
							
							# Use it to verify whether it is a slope
							if (
								ray_result.empty()
								or ! test_slope(ray_result.normal, up, slope_max_angle)
							):
								var slope_limit_fix: int = 2
								while slope_limit_fix > 0:
									if _is_valid_kinematic_collision(step_down_kinematic_result):
										var step_down_normal: Vector3 = step_down_kinematic_result.normal
										
										# If you are now on a valid surface, break the loop
										if test_slope(step_down_normal, up, slope_max_angle):
											break
										else:
											#move_and_collide(
											#motion, infinite_interia, false) # Is this needed?
											
											# Use the step down normal to slide down to the ground
											motion = motion.slide(step_down_normal)
											var slide_down_result: KinematicCollision = move_and_collide(
												motion, infinite_interia, false
											)
											
											# Accumulate this back into the visual step offset
											if _is_valid_kinematic_collision(slide_down_result):
												virtual_step_offset += slide_down_result.get_travel().length()
											else:
												virtual_step_offset = 0.0
									else:
										break
									slope_limit_fix -= 1
							else:
								if move_and_collide(
									motion, infinite_interia, false) == null:
									is_grounded = false
						else:
							_step_down(dss)
					else:
						motion = move_and_slide(
							p_motion, up, 0.0, p_slide_attempts, 1.0, infinite_interia
						)
						if is_on_floor():
							is_grounded = true
							_step_down(dss)
				else:
					printerr("extended_kinematic_body collider must be a capsule")
		else:
			printerr("extended_kinematic_body can only have 1 collider")

	return motion


func _enter_tree() -> void:
	var collided: bool = test_move(global_transform, -(up * anti_bump_factor), infinite_interia)
	if collided:
		var motion_collision: KinematicCollision = move_and_collide(up * -anti_bump_factor, infinite_interia, false)
		if motion_collision:
			is_grounded = true
