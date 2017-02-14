extends KinematicBody

export(Vector3) var up = Vector3(0.0, 1.0, 0.0)
export(float) var step_height = 0.2
export(float) var anti_bump_factor = 1.0
var is_grounded = true
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
		if(get_shape_count() == 1):
			var shape = get_shape(0)
			if(shape extends CapsuleShape):
				if(is_grounded):
					var step_movement = move(up * step_height)
					var motion_collision = slide_move(p_motion, p_slide_attempts)
						
					move(up * -(step_height) - step_movement)
					var can_to = can_teleport_to(get_global_transform().origin - (up * step_height))
					if(!can_to):
						move(up * -anti_bump_factor)
					else:
						is_grounded = false
				else:
					var motion_collision = slide_move(p_motion, p_slide_attempts)
					if((motion_collision * up).length() > 0.0):
						is_grounded = true
			else:
				printerr("extended_kinematic_body collider must be a capsule")
		else:
			printerr("extended_kinematic_body can only have 1 collider")