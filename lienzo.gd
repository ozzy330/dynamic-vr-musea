extends Node3D
@export var imagen: Texture2D
@export var video: VideoStream
@export var audio: AudioStream

func _ready():
	$Area3D.body_entered.connect(_on_area_3d_body_entered)
	$Area3D.body_exited.connect(_on_area_3d_body_exited)

	if video:
		$VideoStreamPlayer.stream = video
		$VideoStreamPlayer.play()
		$VideoStreamPlayer.paused = true
		var mat = StandardMaterial3D.new()
		mat.albedo_texture = $VideoStreamPlayer.get_video_texture()
		$MeshInstance3D.material_override = mat
	elif imagen:
		var mat = StandardMaterial3D.new()
		mat.albedo_texture = imagen
		$MeshInstance3D.material_override = mat

	if audio:
		$AudioStreamPlayer3D.stream = audio

func _on_area_3d_body_entered(body):
	if video:
		$VideoStreamPlayer.paused = false
	if audio:
		$AudioStreamPlayer3D.play()

func _on_area_3d_body_exited(body):
	if video:
		$VideoStreamPlayer.stop()
		$VideoStreamPlayer.play()
		$VideoStreamPlayer.paused = true
	$AudioStreamPlayer3D.stop()
