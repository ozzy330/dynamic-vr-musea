extends Node

@export var speed: float = 3.0
@export var mouse_sensitivity: float = 0.15

var _active := false
var _origin: XROrigin3D
var _camera: XRCamera3D


func _ready() -> void:
	_origin = get_parent() as XROrigin3D
	_camera = _origin.get_node_or_null("XRCamera3D")
	await get_tree().process_frame
	_active = not get_viewport().use_xr
	if _active:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		# Ocultar controllers en desktop
		var left := _origin.get_node_or_null("LeftHand")
		var right := _origin.get_node_or_null("RightHand")
		if left: left.visible = false
		if right: right.visible = false


func _input(event: InputEvent) -> void:
	if not _active:
		return
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if \
			Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_origin.rotate_y(deg_to_rad(-event.relative.x * mouse_sensitivity))
		if _camera:
			_camera.rotate_x(deg_to_rad(-event.relative.y * mouse_sensitivity))
			_camera.rotation.x = clamp(_camera.rotation.x, deg_to_rad(-89), deg_to_rad(89))


func _process(delta: float) -> void:
	if not _active or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var dir := Vector3.ZERO
	var b := _origin.global_transform.basis
	if Input.is_action_pressed("ui_up"):  dir -= b.z
	if Input.is_action_pressed("ui_down"): dir += b.z
	if Input.is_action_pressed("ui_left"):     dir -= b.x
	if Input.is_action_pressed("ui_right"):    dir += b.x
	if dir.length() > 0:
		_origin.global_position += dir.normalized() * speed * delta
