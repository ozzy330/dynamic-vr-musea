@tool
extends Node3D

@export var imagen: Texture2D
@export var video:  VideoStream
@export var audio:  AudioStream

@export_group("Tamaño")
## Ancho del cuadro en metros.
@export_range(0.1, 10.0, 0.01, "suffix:m") var ancho: float = 1.865:
	set(v):
		ancho = v
		_apply_size()
## Alto del cuadro en metros.
@export_range(0.1, 10.0, 0.01, "suffix:m") var alto: float = 1.582:
	set(v):
		alto = v
		_apply_size()

var _area: Area3D            = null
var _video_with_audio: bool = true   # false → VideoStreamPlayer muteado, AudioStreamPlayer3D activo


# ── Editor warnings ────────────────────────────────────────────────────────────
# Shows a yellow ⚠ on the node in the editor if required children are missing.
# @tool makes _ready() run in the editor so we can connect child signals and
# call update_configuration_warnings() for live (dynamic) warning refresh.

func _get_configuration_warnings() -> PackedStringArray:
	var w := PackedStringArray()
	var area := get_node_or_null("Area3D")
	if area == null:
		w.append("Needs an Area3D child to detect proximity (add one and adjust its CollisionShape3D here).")
	elif area.get_node_or_null("CollisionShape3D") == null:
		w.append("The Area3D child needs a CollisionShape3D child to define the trigger zone.")
	return w


# ── Size ───────────────────────────────────────────────────────────────────────

func _apply_size() -> void:
	var mi: MeshInstance3D = get_node_or_null("MeshInstance3D")
	if mi == null or not mi.mesh is QuadMesh:
		return
	# Duplicate so each instance owns its own QuadMesh resource.
	var q: QuadMesh = mi.mesh.duplicate()
	q.size = Vector2(ancho, alto)
	mi.mesh = q
	# Remove any scale baked in the .tscn — QuadMesh.size is the single source
	# of truth for dimensions from now on.
	mi.scale = Vector3.ONE


# ── Runtime ────────────────────────────────────────────────────────────────────

func _ready() -> void:
	# Connect in both editor and game so warnings refresh whenever a child is
	# added or removed (e.g. dropping an Area3D onto the node in the editor).
	child_entered_tree.connect(func(_n): update_configuration_warnings())
	child_exiting_tree.connect(func(_n): update_configuration_warnings())

	# Setters fire before the node is ready (property restore from .tscn),
	# so get_node_or_null returns null at that point.  Apply here to be safe.
	_apply_size()

	if Engine.is_editor_hint():
		return  # don't execute game logic while in the editor

	$VideoStreamPlayer.visible = false

	_area = get_node_or_null("Area3D")
	if _area == null:
		push_warning("Lienzo '%s': no Area3D child found — proximity trigger disabled." % name)
	else:
		_area.body_entered.connect(_on_body_entered)
		_area.body_exited.connect(_on_body_exited)

	# Apply exports set from the editor (no-op if called again via load_asset).
	_setup_content()


# ── Content loading ────────────────────────────────────────────────────────────

## Carga imagen, video y/o audio desde un dict {imagen, video, audio, video_with_audio}.
## video_with_audio (bool, default true):
##   true  → VideoStreamPlayer suena normal, campo "audio" ignorado.
##   false → VideoStreamPlayer muteado, AudioStreamPlayer3D carga "audio" si existe.
func load_asset(asset: Dictionary) -> void:
	if asset.is_empty():
		return
	var video_path:  String = asset.get("video",            "")
	var imagen_path: String = asset.get("imagen",           "")
	var audio_path:  String = asset.get("audio",            "")
	_video_with_audio        = asset.get("video_with_audio", true)

	if not video_path.is_empty():
		video  = load(video_path)
		imagen = null
	elif not imagen_path.is_empty():
		imagen = load(imagen_path)
		video  = null

	# Load separate audio when:
	#   - there is no video (image slot → never a conflict), OR
	#   - there is video but video_with_audio = false (video is muted).
	if not audio_path.is_empty() and (video == null or not _video_with_audio):
		audio = load(audio_path)
	else:
		audio = null

	_setup_content()


func _setup_content() -> void:
	if Engine.is_editor_hint():
		return
	if video:
		$VideoStreamPlayer.stream = video
		$VideoStreamPlayer.play()
		$VideoStreamPlayer.paused = true
		# Mute when video_with_audio = false so the AudioStreamPlayer3D takes over.
		$VideoStreamPlayer.volume = 1.0 if _video_with_audio else 0.0
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = $VideoStreamPlayer.get_video_texture()
		$MeshInstance3D.material_override = mat
	elif imagen:
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = imagen
		$MeshInstance3D.material_override = mat
	if audio:
		$AudioStreamPlayer3D.stream = audio


func _on_body_entered(body) -> void:
	# Only react to bodies on collision layer 2 (the XR player).
	if not (body.collision_layer & 2):
		return
	if video:
		$VideoStreamPlayer.paused = false
	if audio:
		$AudioStreamPlayer3D.play()


func _on_body_exited(body) -> void:
	if not (body.collision_layer & 2):
		return
	if video:
		$VideoStreamPlayer.stop()
		$VideoStreamPlayer.play()
		$VideoStreamPlayer.paused = true
	$AudioStreamPlayer3D.stop()
