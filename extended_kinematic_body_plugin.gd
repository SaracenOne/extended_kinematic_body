tool
extends EditorPlugin


func get_name() -> String:
	return "ExtendedKinematicBody"


func _enter_tree() -> void:
	add_custom_type(
		"ExtendedKinematicBody",
		"KinematicBody",
		preload("extended_kinematic_body.gd"),
		preload("icon_extended_kinematic_body.svg")
	)


func _exit_tree() -> void:
	remove_custom_type("ExtendedKinematicBody")
