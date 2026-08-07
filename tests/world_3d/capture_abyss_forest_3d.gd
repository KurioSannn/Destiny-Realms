extends Node

const ABYSS_SCENE := preload("res://scenes/world_3d/abyss_forest_3d.tscn")
const CAPTURE_PATH := "res://docs/images/abyss_forest_3d_1280x720.png"
const SEAL_CAPTURE_PATH := "res://docs/images/abyss_forest_3d_seal_1280x720.png"


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	var world := ABYSS_SCENE.instantiate()
	add_child(world)
	for frame_index in range(12):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(CAPTURE_PATH)
	if error != OK:
		push_error("Failed to capture Abyss Forest 3D: %s" % error_string(error))
		get_tree().quit(1)
		return
	print("ABYSS_FOREST_CAPTURE_OK %s" % CAPTURE_PATH)
	var player := world.get_node_or_null("Player") as CharacterBody3D
	if player != null:
		player.global_position = Vector3(0.0, 0.63, -12.3)
		for frame_index in range(36):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var seal_image := get_viewport().get_texture().get_image()
		var seal_error := seal_image.save_png(SEAL_CAPTURE_PATH)
		if seal_error != OK:
			push_error("Failed to capture Abyss Forest seal: %s" % error_string(seal_error))
			get_tree().quit(1)
			return
		print("ABYSS_FOREST_SEAL_CAPTURE_OK %s" % SEAL_CAPTURE_PATH)
	get_tree().quit(0)
