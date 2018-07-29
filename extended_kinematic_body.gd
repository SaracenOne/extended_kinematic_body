extends KinematicBody

var virtual_step_offset = 0.0

export(Vector3) var up = Vector3(0.0, 1.0, 0.0)
export(float) var step_height = 0.2
export(float) var anti_bump_factor = 0.75
export(float) var slope_stop_min_velocity = 0.05
export(float) var slope_max_angle = deg2rad(45)

var is_grounded = false

onready var exclusion_array = [self]

static func get_sphere_query_parameters(p_transform, p_radius, p_mask, p_exclude):
	var query = PhysicsShapeQueryParameters.new()
	query.set_transform(p_transform)
	var shape = SphereShape.new()
	shape.set_radius(p_radius)
	shape.set_mask(p_mask)
	shape.set_exclude(p_exclude)
	
static func get_capsule_query_parameters(p_transform, p_height, p_radius, p_mask, p_exclude):
	var query = PhysicsShapeQueryParameters.new()
	query.set_transform(p_transform)
	var shape = CapsuleShape.new()
	shape.set_height(p_height)
	shape.set_radius(p_radius)
	shape.set_mask(p_mask)
	shape.set_exclude(p_exclude)
	
static func test_slope(p_normal, p_up, p_slope_max_angle):
	var dot_product = p_normal.dot(p_up)
	return (dot_product >= 0.0 and dot_product < p_slope_max_angle) == false
	
func get_virtual_step_offset():
	return virtual_step_offset
	
func extended_move(p_motion, p_slide_attempts):
	var dss = PhysicsServer.space_get_direct_state(get_world().get_space())
	var motion = Vector3(0.0, 0.0, 0.0)
	if(dss):
		var shape_owners = get_shape_owners()
		if(shape_owners.size() == 1):
			var shape_count = shape_owner_get_shape_count(shape_owners[0])
			if shape_count == 1:
				var shape = shape_owner_get_shape(shape_owners[0], 0)
				if(shape is CapsuleShape):
					var capsule_radius = shape.get_radius()
					if(is_grounded):
						# Initial transform
						var initial_transform = global_transform
						
						# Raise off the ground
						var step_up_kinematic_result = move_and_collide(up * step_height)
						var step_up_transform = global_transform
						
						# Do actual motion
						motion = move_and_slide(p_motion, up, slope_stop_min_velocity, p_slide_attempts, slope_max_angle, true)
						
						# Return to ground
						var step_down_kinematic_result = null
						
						if step_up_kinematic_result == null:
							virtual_step_offset = -step_height
							step_down_kinematic_result = move_and_collide(up * -step_height)
						else:
							virtual_step_offset = -step_up_kinematic_result.get_travel().length()
							step_down_kinematic_result = move_and_collide((up * -step_height) + step_up_kinematic_result.remainder)
							
						if step_down_kinematic_result:
							virtual_step_offset += step_down_kinematic_result.get_travel().length()
							motion = (up * -step_height)
							
							# Use raycast from just above the kinematic result to determine the world normal of the collided surface
							var ray_result = dss.intersect_ray(step_down_kinematic_result.position + (up * step_height), step_down_kinematic_result.position - (up * anti_bump_factor), exclusion_array)
							
							# Use it to verify whether it is a slope
							if(ray_result.empty() or !test_slope(ray_result.normal, up, slope_max_angle)):
								var slope_limit_fix = 2
								while(slope_limit_fix > 0):
									if step_down_kinematic_result:
										var step_down_normal = step_down_kinematic_result.normal
										
										# If you are now on a valid surface, break the loop
										if test_slope(step_down_normal, up, slope_max_angle):
											break
										else:
											#move_and_collide(motion) # Is this needed?
											
											# Use the step down normal to slide down to the ground
											motion = motion.slide(step_down_normal)
											var slide_down_result = move_and_collide(motion)
											
											# Accumulate this back into the visual step offset
											if slide_down_result:
												virtual_step_offset += slide_down_result.get_travel().length()
											else:
												virtual_step_offset = 0.0
									else:
										break
									slope_limit_fix -= 1
							else:
								move_and_collide(motion)
						else:
							# Process step down / fall
							virtual_step_offset = 0.0
							var collided = test_move(global_transform, -(up * step_height), true)
							if(collided):
								var kinematic_collision = move_and_collide(-(up * anti_bump_factor))
								if !kinematic_collision:
									kinematic_collision = move_and_collide(-(up * (step_height - anti_bump_factor)))
									if kinematic_collision:
										virtual_step_offset = kinematic_collision.get_travel().length() + anti_bump_factor
									else:
										virtual_step_offset = step_height
										
								if !kinematic_collision:
									is_grounded = false
								else: 
									if !test_slope(kinematic_collision.normal, up, slope_max_angle):
										var ray_result = dss.intersect_ray(kinematic_collision.position + (up * step_height), kinematic_collision.position - (up * step_height), exclusion_array)
										if(ray_result.empty() or !test_slope(ray_result.normal, up, slope_max_angle)):
											is_grounded = false
							else:
								is_grounded = false
					else:
						motion = move_and_slide(p_motion, up, slope_stop_min_velocity, p_slide_attempts, slope_max_angle, true)
						if is_on_floor():
							is_grounded = true
				else:
					printerr("extended_kinematic_body collider must be a capsule")
		else:
			printerr("extended_kinematic_body can only have 1 collider")
			
	return motion
			
func _enter_tree():
	var collided = test_move(global_transform, -(up * anti_bump_factor), true)
	if collided:
		var motion_collision = move_and_collide(up * -anti_bump_factor)
		is_grounded = true