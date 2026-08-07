extends Node

const WORLD_SCENE := preload("res://scenes/world/world_scene.tscn")


func _ready() -> void:
	_capture.call_deferred()


func _capture() -> void:
	_apply_requested_window_size()
	var scene := WORLD_SCENE.instantiate()
	get_tree().root.add_child(scene)
	await get_tree().create_timer(1.2).timeout
	await RenderingServer.frame_post_draw

	var viewport_size := get_window().size
	var output_path := (
		"res://docs/images/world_hud_runtime_%dx%d.png"
		% [viewport_size.x, viewport_size.y]
	)
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(output_path)
	if error != OK:
		push_error("Could not save World HUD capture: %s" % error_string(error))
		get_tree().quit(1)
		return

	print("PASS: captured World HUD runtime at %dx%d" % [viewport_size.x, viewport_size.y])
	get_tree().quit(0)


func _apply_requested_window_size() -> void:
	for argument in OS.get_cmdline_user_args():
		if not argument.begins_with("--capture-size="):
			continue
		var dimensions := argument.trim_prefix("--capture-size=").split("x")
		if dimensions.size() == 2:
			get_window().size = Vector2i(int(dimensions[0]), int(dimensions[1]))

