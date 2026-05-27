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
	_apply_slots(data.get("slots", []))

func _apply_slots(slots: Array) -> void:
	# Populate each Lienzo node listed in the JSON slots array.
	# JSON uses 0-based indices; scene nodes are 1-based (Wall1, Slot1, …).
	for s in slots:
		var wall_idx: int = s.get("wall", -1)
		var slot_idx: int = s.get("slot", -1)
		var asset = s.get("asset", {})
		if not asset is Dictionary or asset.is_empty() or wall_idx < 0 or slot_idx < 0:
			continue
		var node_path := "Wall%d/Slot%d/Lienzo" % [wall_idx + 1, slot_idx + 1]
		var lienzo = get_node_or_null(node_path)
		if lienzo == null:
			push_warning("Hall '%s': nodo '%s' no encontrado" % [name, node_path])
			continue
		lienzo.load_asset(asset)


func _apply_door(door: Node3D, state) -> void:
	var is_hall_ref = state != null and state != "entrance" and state != "open" and state != "closed"
	var shows_arc  = state == "entrance" or is_hall_ref
	var shows_bush = state == "closed" or state == null

	var arc: Node3D = door.get_node("Arc")
	arc.visible = shows_arc
	# Deshabilitar colisión de los pilares cuando el arco está oculto.
	# Se desactivan los CollisionShape3D hijos del StaticBody3D directamente,
	# sin asumir ningún valor de collision_layer.
	var pillars = arc.get_node_or_null("StaticBody3D")
	if pillars:
		for shape in pillars.get_children():
			if shape is CollisionShape3D:
				shape.disabled = not shows_arc

	var back_bush: CSGBox3D = door.get_node("BackBush")
	back_bush.visible = shows_bush
	# Disable the auto-generated StaticBody3D when the bush is hidden so it
	# doesn't create an invisible wall.  set_deferred is required because CSG
	# nodes rebuild their collision body at the end of the physics frame.
	back_bush.set_deferred("use_collision", shows_bush)
	# "open": both hidden — physically connected, the other hall renders the arch
