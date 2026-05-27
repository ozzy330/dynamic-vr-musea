extends Node3D

# Path to the world JSON. Change in Inspector to swap test configurations.
@export_file("*.json") var world_json_path: String = "res://world.json"

const HALL_SCENE   = preload("res://hall_basic.tscn")
const HALL_SPACING = 25.0   # units between hall centers

var xr_interface: XRInterface


func _ready() -> void:
	_init_xr()
	_build_world()


# ── XR ────────────────────────────────────────────────────────────────────────

func _init_xr() -> void:
	xr_interface = XRServer.find_interface("OpenXR")
	if xr_interface and xr_interface.is_initialized():
		print("OpenXR initialized successfully")
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		get_viewport().use_xr = true
	else:
		print("OpenXR not initialized, please check if your headset is connected")


# ── World building ─────────────────────────────────────────────────────────────

func _build_world() -> void:
	var world := _load_json(world_json_path)
	if world.is_empty():
		return

	var halls_list: Array = world.get("halls", [])
	if halls_list.is_empty():
		push_error("RoomManager: 'halls' array is empty or missing")
		return

	var count := halls_list.size()

	for i in range(count):
		var data: Dictionary = halls_list[i]
		var hall_id: String  = data.get("hallId", "hall_%d" % i)

		# Halls are laid out in a line going LEFT (−X) through doorB.
		# Hall 0 starts at the world origin.
		var hall: Node3D = HALL_SCENE.instantiate()
		add_child(hall)
		hall.position = Vector3(-HALL_SPACING * i, 0, 0)
		hall.name     = hall_id

		# doorA (right side):
		#   first hall → closed (nothing behind it)
		#   every other → open (the previous hall's arch is already there)
		var state_a: String = "closed" if i == 0 else "open"

		# doorB (left side):
		#   last hall  → closed (dead end)
		#   every other → hallId of the next hall (shows arch, connects forward)
		var state_b: String
		if i < count - 1:
			state_b = halls_list[i + 1].get("hallId", "hall_%d" % (i + 1))
		else:
			state_b = "closed"

		hall.setup(data, state_a, state_b)


# ── JSON loader ────────────────────────────────────────────────────────────────

func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("RoomManager: cannot open '%s'" % path)
		return {}
	var result = JSON.parse_string(file.get_as_text())
	if result == null or not result is Dictionary:
		push_error("RoomManager: invalid JSON in '%s'" % path)
		return {}
	return result
