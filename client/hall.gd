extends Node3D

# Door state values:
#   "<hallId>" -> shows Arc (connects to another hall)
#   "open"     -> no Arc, no BackBush (faces the previous hall; its arc is already visible)
#   "closed"   -> no Arc, shows BackBush (dead end wall)
#
# Door states are computed entirely by xr_main.gd from the hall order in the JSON —
# no need to specify them manually in the JSON.

func setup(data: Dictionary, state_a: String = "closed", state_b: String = "closed") -> void:
	_apply_door($DoorA, state_a)
	_apply_door($DoorB, state_b)

func _apply_door(door: Node3D, state) -> void:
	var is_hall_ref = state != null and state != "entrance" and state != "open" and state != "closed"
	var shows_arc  = state == "entrance" or is_hall_ref
	var shows_bush = state == "closed" or state == null

	door.get_node("Arc").visible = shows_arc

	var back_bush: CSGBox3D = door.get_node("BackBush")
	back_bush.visible = shows_bush
	# Disable the auto-generated StaticBody3D when the bush is hidden so it
	# doesn't create an invisible wall.  set_deferred is required because CSG
	# nodes rebuild their collision body at the end of the physics frame.
	back_bush.set_deferred("use_collision", shows_bush)
	# "open": both hidden — physically connected, the other hall renders the arch
