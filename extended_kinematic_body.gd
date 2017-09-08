extends KinematicBody

export(Vector3) var up = Vector3(0.0, 1.0, 0.0)
export(float) var step_height = 0.2
export(float) var anti_bump_factor = 1.0
export(float) var slope_stop_min_velocity = 0.05
var is_grounded = false
onready var step_ray_exclusion_array = [self]

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

func slide_move(p_motion, p_slide_attempts):
	var motion = p_motion
	var motion_collision = move(motion)
	var attempts = p_slide_attempts
	while(is_colliding() and attempts > 0):
		var collider = get_collider()
		var n = get_collision_normal()
		motion = n.slide(motion_collision)
		move(motion)
		attempts -= 1
		
	return motion_collision

func extended_move(p_motion, p_slide_attempts):
	var dss = PhysicsServer.space_get_direct_state(get_world().get_space())
	if(dss):
		var exclude_array = [self]
		var shape_owners = get_shape_owners()
		if(shape_owners.size() == 1):
			var shape_count = shape_owner_get_shape_count(shape_owners[0])
			if shape_count == 1:
				var shape = shape_owner_get_shape(shape_owners[0], 0)
				if(shape is CapsuleShape):
					if(is_grounded):
						print(up * step_height)
						
						# Raise off the ground
						var step_up_kinematic_result = move_and_collide(up * step_height)
						
						# Do actual motion
						print(move_and_slide(p_motion, Vector3(0.0, 0.0, 0.0), slope_stop_min_velocity, p_slide_attempts))
						
						# Return to ground
						if step_up_kinematic_result == null:
							move_and_collide(up * -step_height)
						else:
							print(step_up_kinematic_result.travel)
							move_and_collide(step_up_kinematic_result.travel)
						
						# Process step down / fall
						var can_to = test_move(Transform(), -(up * step_height))
						if(!can_to):
							move_and_collide(-(up * anti_bump_factor))
						else:
							is_grounded = false
					else:
						var motion_collision = move_and_slide(p_motion, Vector3(0.0, 0.0, 0.0), slope_stop_min_velocity, p_slide_attempts)
						if(motion_collision.y == 0.0):
							is_grounded = true
				else:
					printerr("extended_kinematic_body collider must be a capsule")
		else:
			printerr("extended_kinematic_body can only have 1 collider")
			
func _enter_tree():
	var motion_collision = move_and_collide(up * -anti_bump_factor)
	if(motion_collision):
		is_grounded = true