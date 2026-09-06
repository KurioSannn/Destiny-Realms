extends Node

const WERDONIA_SCENE := preload("res://scenes/world_3d/werdonia_outskirts_3d.tscn")
const CAPTURE_PATH := "res://docs/images/werdonia_outskirts_3d_1280x720.png"

func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	var world := WERDONIA_SCENE.instantiate()
	add_child(world)
	for frame_index in range(15):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(CAPTURE_PATH)
	if error != OK:
		push_error("Failed to capture Werdonia Outskirts 3D: %s" % error_string(error))
		get_tree().quit(1)
		return
	print("WERDONIA_OUTSKIRTS_CAPTURE_OK %s" % CAPTURE_PATH)
	get_tree().quit(0)
