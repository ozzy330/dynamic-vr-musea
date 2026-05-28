extends Node3D

# Path to the world JSON — used as fallback when the server is unreachable.
@export_file("*.json") var world_json_path: String = "res://world.json"

## Server base URL, e.g. "http://192.168.1.x:8080".
## When set:
##   - world JSON is fetched via HTTP (fallback to local on failure)
##   - asset paths (res://media/…) are remapped to HTTP URLs so lienzo.gd
##     downloads them at runtime instead of reading from res://.
## Leave empty for local-only development (res:// paths, no network).
@export var server_url: String = ""

const HALL_SCENE   = preload("res://hall_basic.tscn")
const HALL_SPACING = 25.0   # units between hall centers

var xr_interface: XRInterface


func _ready() -> void:
	_init_xr()
	_fetch_world()


# ── XR ────────────────────────────────────────────────────────────────────────

func _init_xr() -> void:
	xr_interface = XRServer.find_interface("OpenXR")
	if xr_interface and xr_interface.is_initialized():
		print("OpenXR initialized successfully")
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		get_viewport().use_xr = true
	else:
		print("OpenXR not initialized, please check if your headset is connected")


# ── World fetching ─────────────────────────────────────────────────────────────

func _fetch_world() -> void:
	if server_url.is_empty():
		_build_world_from_data(_load_json(world_json_path))
		return

	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_world_received.bind(http))
	var err := http.request(server_url + "/world")
	if err != OK:
		push_warning("HTTPRequest failed to start — falling back to local JSON")
		http.queue_free()
		_build_world_from_data(_load_json(world_json_path))


func _on_world_received(result: int, response_code: int, _headers: PackedStringArray,
		body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		push_warning("Server unreachable (result=%d code=%d) — fallback local" % [result, response_code])
		_build_world_from_data(_load_json(world_json_path))
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if data == null or not data is Dictionary:
		push_warning("Invalid JSON from server — fallback local")
		_build_world_from_data(_load_json(world_json_path))
		return
	print("World loaded from server (%d halls)" % data.get("halls", []).size())
	_build_world_from_data(data)


# ── World building ─────────────────────────────────────────────────────────────

## Remaps a single asset dict: res://media/… → server_url/media/…
func _remap_asset(asset) -> Dictionary:
	if not asset is Dictionary or server_url.is_empty():
		return asset if asset is Dictionary else {}
	var out: Dictionary = asset.duplicate()
	for key in ["imagen", "video", "audio"]:
		if out.has(key) and (out[key] as String).begins_with("res://media/"):
			out[key] = (out[key] as String).replace("res://media/", server_url + "/media/")
	return out


func _remap_slots(slots: Array) -> Array:
	var out: Array = []
	for s in slots:
		var r: Dictionary = s.duplicate()
		if r.has("asset"):
			r["asset"] = _remap_asset(r["asset"])
		out.append(r)
	return out


func _build_world_from_data(world: Dictionary) -> void:
	if world.is_empty():
		return

	var halls_list: Array = world.get("halls", [])
	if halls_list.is_empty():
		push_error("RoomManager: 'halls' array is empty or missing")
		return

	var count := halls_list.size()

	for i in range(count):
		var data: Dictionary = halls_list[i].duplicate(true)

		# Remap asset paths to HTTP URLs when server_url is configured.
		if not server_url.is_empty() and data.has("slots"):
			data["slots"] = _remap_slots(data["slots"])

		var hall_id: String = data.get("hallId", "hall_%d" % i)
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
