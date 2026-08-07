extends Node

const ABYSS_SCENE := preload("res://scenes/world_3d/abyss_forest_3d.tscn")
const CAPTURE_PATHS: Dictionary = {
	1: "res://docs/images/camera_pov/f1_current_comparison_1280x720.png",
	2: "res://docs/images/camera_pov/f2_ethra_target_comparison_1280x720.png",
}
const F2_AREA_CAPTURES: Array[Dictionary] = [
	{
		"name": "spawn",
		"position": Vector3(0.0, 0.63, 13.5),
		"path": "res://docs/images/camera_pov/f2_ethra_target_spawn_1280x720.png",
	},
	{
		"name": "dense_forest",
		"position": Vector3(0.0, 0.63, 6.0),
		"path": "res://docs/images/camera_pov/f2_ethra_target_dense_forest_1280x720.png",
	},
	{
		"name": "open_path",
		"position": Vector3(-1.6, 0.63, -5.0),
		"path": "res://docs/images/camera_pov/f2_ethra_target_open_path_1280x720.png",
	},
	{
		"name": "ruins",
		"position": Vector3(0.4, 0.63, 1.0),
		"path": "res://docs/images/camera_pov/f2_ethra_target_ruins_1280x720.png",
	},
	{
		"name": "seal",
		"position": Vector3(0.0, 0.63, -12.3),
		"path": "res://docs/images/camera_pov/f2_ethra_target_seal_1280x720.png",
	},
]
const RESPONSIVE_CAPTURE_PATH := "res://docs/images/camera_pov/f2_ethra_target_comparison_1920x1080.png"
const COMPARISON_POSITION := Vector3(0.0, 0.63, 6.0)


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	var world := ABYSS_SCENE.instantiate() as Node3D
	add_child(world)
	for frame_index in range(12):
		await get_tree().process_frame

	var player := world.get_node_or_null("Player") as CharacterBody3D
	var camera := world.get_node_or_null("ExplorationCamera") as Camera3D
	var visual := world.get_node_or_null("Player/CharacterVisual") as AnimatedSprite3D
	if player == null or camera == null or visual == null:
		push_error("Camera comparison capture is missing required nodes")
		get_tree().quit(1)
		return

	player.set_physics_process(false)
	player.velocity = Vector3.ZERO
	player.global_position = COMPARISON_POSITION
	visual.pause()
	visual.frame = 0
	visual.flip_h = false

	for preset_id in [1, 2]:
		player.global_position = COMPARISON_POSITION
		visual.frame = 0
		visual.flip_h = false
		camera.call("apply_camera_preset", preset_id, true)
		for frame_index in range(72):
			await get_tree().physics_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var capture_path: String = CAPTURE_PATHS[preset_id]
		var error := image.save_png(capture_path)
		if error != OK:
			push_error("Failed to capture F%d: %s" % [preset_id, error_string(error)])
			get_tree().quit(1)
			return
		print("CAMERA_CAPTURE_F%d_OK %s" % [preset_id, capture_path])

	for area_capture in F2_AREA_CAPTURES:
		player.global_position = area_capture["position"]
		visual.frame = 0
		visual.flip_h = false
		camera.call("apply_camera_preset", 2, false)
		for frame_index in range(48):
			await get_tree().physics_frame
		await RenderingServer.frame_post_draw
		var area_image := get_viewport().get_texture().get_image()
		var area_path: String = area_capture["path"]
		var area_error := area_image.save_png(area_path)
		if area_error != OK:
			push_error("Failed to capture F2 %s: %s" % [area_capture["name"], error_string(area_error)])
			get_tree().quit(1)
			return
		print("CAMERA_CAPTURE_F2_%s_OK %s" % [str(area_capture["name"]).to_upper(), area_path])

	get_window().size = Vector2i(1920, 1080)
	player.global_position = COMPARISON_POSITION
	visual.frame = 0
	visual.flip_h = false
	camera.call("apply_camera_preset", 2, false)
	for frame_index in range(24):
		await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	var responsive_image := get_viewport().get_texture().get_image()
	if responsive_image.get_size() != Vector2i(1920, 1080):
		push_error("1920x1080 camera capture rendered at %s" % str(responsive_image.get_size()))
		get_tree().quit(1)
		return
	var responsive_error := responsive_image.save_png(RESPONSIVE_CAPTURE_PATH)
	if responsive_error != OK:
		push_error("Failed to capture F2 at 1920x1080: %s" % error_string(responsive_error))
		get_tree().quit(1)
		return
	print("CAMERA_CAPTURE_1920_OK %s" % RESPONSIVE_CAPTURE_PATH)

	get_tree().quit(0)
