tool
extends EditorPlugin

func get_name(): 
	return "ExtendedKinematicBody"

func _enter_tree():
	add_custom_type("ExtendedKinematicBody","KinematicBody",preload("extended_kinematic_body.gd"),preload("extended_kinematic_body.png"))
func _exit_tree():
	remove_custom_type("ExtendedKinematicBody")
