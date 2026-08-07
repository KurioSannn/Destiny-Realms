extends Node

const ABYSS_SCENE := preload("res://scenes/world_3d/abyss_forest_3d.tscn")
const IMG_ROOT := "res://docs/images/camera_pov/"

var world: Node3D
var camera: Camera3D
var player: CharacterBody3D
var visual: AnimatedSprite3D


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	world = ABYSS_SCENE.instantiate() as Node3D
	add_child(world)
	for frame_index in range(12):
		await get_tree().process_frame

	player = world.get_node_or_null("Player") as CharacterBody3D
	camera = world.get_node_or_null("ExplorationCamera") as Camera3D
	visual = world.get_node_or_null("Player/CharacterVisual") as AnimatedSprite3D
	if player == null or camera == null or visual == null:
		push_error("Camera control capture is missing required nodes")
		get_tree().quit(1)
		return

	player.set_physics_process(false)
	player.velocity = Vector3.ZERO
	visual.pause()
	visual.frame = 0
	visual.flip_h = false
	camera.call("apply_camera_preset", 2, false)

	await _capture_at(Vector3(0.0, 0.63, 6.0), 0.0, 14.5, 13.0, "camera_control_default_1280x720.png")
	await _capture_at(Vector3(0.0, 0.63, 6.0), 0.0, 14.5, 7.0, "camera_control_zoom_close_1280x720.png")
	await _capture_at(Vector3(0.0, 0.63, 6.0), 0.0, 14.5, 11.0, "camera_control_zoom_medium_1280x720.png")
	await _capture_at(Vector3(0.0, 0.63, 6.0), 0.0, 14.5, 19.0, "camera_control_zoom_wide_1280x720.png")
	await _capture_at(Vector3(0.0, 0.63, 6.0), 90.0, 14.5, 13.0, "camera_control_yaw_side_1280x720.png")
	await _capture_at(Vector3(0.0, 0.63, 6.0), 180.0, 14.5, 13.0, "camera_control_yaw_behind_1280x720.png")
	await _capture_at(Vector3(0.0, 0.63, 6.0), -90.0, 14.5, 13.0, "camera_control_yaw_other_side_1280x720.png")
	await _capture_at(Vector3(0.0, 0.63, 6.0), 45.0, 14.5, 13.0, "camera_control_yaw_diagonal_1280x720.png")
	await _capture_at(Vector3(0.0, 0.63, 6.0), 0.0, 10.0, 13.0, "camera_control_pitch_min_1280x720.png")
	await _capture_at(Vector3(0.0, 0.63, 6.0), 0.0, 32.0, 13.0, "camera_control_pitch_max_1280x720.png")

	# Combined offset immediately followed by a reset, to verify smooth return to default.
	await _capture_at(Vector3(0.0, 0.63, 6.0), 40.0, 24.0, 8.0, "camera_control_combined_before_reset_1280x720.png")
	camera.call("_reset_camera_control")
	for frame_index in range(240):
		await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	_save(get_viewport().get_texture().get_image(), "camera_control_after_reset_1280x720.png")

	# Walking while a combined offset is active.
	camera.set("_yaw_target_degrees", 25.0)
	camera.set("_pitch_target_degrees", 20.0)
	camera.set("_distance_target", 9.0)
	for frame_index in range(240):
		await get_tree().physics_frame
	player.set_physics_process(false)
	player.global_position = Vector3(0.0, 0.63, 8.5)
	Input.action_press("move_up")
	for frame_index in range(30):
		await get_tree().physics_frame
	Input.action_release("move_up")
	await RenderingServer.frame_post_draw
	_save(get_viewport().get_texture().get_image(), "camera_control_walking_offset_1280x720.png")

	await _capture_at(Vector3(0.0, 0.63, 6.0), 25.0, 18.0, 8.0, "camera_control_dense_forest_close_1280x720.png")
	await _capture_at(Vector3(0.4, 0.63, 1.0), 25.0, 18.0, 8.0, "camera_control_ruins_close_1280x720.png")
	await _capture_at(Vector3(0.0, 0.63, -12.3), 0.0, 14.5, 11.0, "camera_control_seal_medium_1280x720.png")

	# Obstruction: orbit toward a ruin wall close enough that the raycast should pull the camera in.
	await _capture_at(Vector3(-10.5, 0.63, 7.0), 200.0, 14.5, 13.0, "camera_control_obstruction_near_ruin_1280x720.png")

	get_window().size = Vector2i(1920, 1080)
	await _capture_at(Vector3(0.0, 0.63, 6.0), 0.0, 14.5, 13.0, "camera_control_default_1920x1080.png")
	await _capture_at(Vector3(0.0, 0.63, 6.0), 0.0, 14.5, 7.0, "camera_control_zoom_close_1920x1080.png")
	await _capture_at(Vector3(0.0, 0.63, 6.0), 180.0, 32.0, 8.0, "camera_control_orbit_extreme_1920x1080.png")

	print("CAMERA_PLAYER_CONTROL_CAPTURE_OK")
	get_tree().quit(0)


func _capture_at(
	position: Vector3,
	yaw_degrees: float,
	pitch_degrees: float,
	distance: float,
	file_name: String
) -> void:
	player.global_position = position
	visual.frame = 0
	visual.flip_h = false
	camera.set("_yaw_target_degrees", yaw_degrees)
	camera.set("_pitch_target_degrees", pitch_degrees)
	camera.set("_distance_target", distance)
	for frame_index in range(240):
		await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	_save(get_viewport().get_texture().get_image(), file_name)


func _save(image: Image, file_name: String) -> void:
	var path := IMG_ROOT + file_name
	var error := image.save_png(path)
	if error != OK:
		push_error("Failed to capture %s: %s" % [file_name, error_string(error)])
		get_tree().quit(1)
		return
	print("CAMERA_CONTROL_CAPTURE_OK %s" % path)
