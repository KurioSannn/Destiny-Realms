extends Node

const ABYSS_SCENE := preload("res://scenes/world_3d/abyss_forest_3d.tscn")
const TEST_AREAS: Array[Dictionary] = [
	{"name": "spawn", "position": Vector3(0.0, 0.63, 13.5)},
	{"name": "dense forest", "position": Vector3(0.0, 0.63, 6.0)},
	{"name": "open path", "position": Vector3(-1.6, 0.63, -5.0)},
	{"name": "ruins", "position": Vector3(0.4, 0.63, 1.0)},
	{"name": "seal", "position": Vector3(0.0, 0.63, -12.3)},
]

# The old F2 default (pre camera/world-scale rework) intentionally kept
# Takashi small on screen (7-22% of viewport height). The new production
# camera must read as meaningfully closer than that old ceiling.
const OLD_F2_MAX_SCREEN_HEIGHT_FRACTION := 0.22

const EXPECTED_PRESETS: Dictionary = {
	1: {
		"keycode": KEY_F1,
		"projection": Camera3D.PROJECTION_ORTHOGONAL,
		"offset": Vector3(10.5, 12.5, 10.5),
		"size": 15.2,
		"pitch": 38.1,
		"label": "Camera: F1 — Legacy",
	},
	2: {
		"keycode": KEY_F2,
		"projection": Camera3D.PROJECTION_PERSPECTIVE,
		"fov": 35.5,
		"distance": 13.0,
		"pitch": 14.5,
		"label": "Camera: F2 — Exploration",
	},
}


func _ready() -> void:
	var world := ABYSS_SCENE.instantiate() as Node3D
	if world == null:
		_fail("Abyss Forest could not be instantiated for camera preset test")
		return
	add_child(world)
	await get_tree().process_frame
	await get_tree().physics_frame

	var camera := world.get_node_or_null("ExplorationCamera") as Camera3D
	var debug_label := world.get_node_or_null("CameraPresetDebug/Panel/Label") as Label
	var player := world.get_node_or_null("Player") as CharacterBody3D
	var visual := world.get_node_or_null("Player/CharacterVisual") as AnimatedSprite3D
	var shadow := world.get_node_or_null("Player/Shadow") as MeshInstance3D
	if camera == null or debug_label == null or player == null or visual == null or shadow == null:
		_fail("Camera comparison is missing camera, label, player, sprite, or shadow")
		return

	if int(camera.call("get_active_preset_id")) != 2:
		_fail("F2 must be the default production candidate")
		return

	for preset_id in [1, 2]:
		var expected: Dictionary = EXPECTED_PRESETS[preset_id]
		var previous_camera_position := camera.global_position
		var maximum_frame_step := 0.0
		_send_function_key(int(expected["keycode"]))
		for frame_index in range(60):
			await get_tree().physics_frame
			maximum_frame_step = maxf(
				maximum_frame_step,
				camera.global_position.distance_to(previous_camera_position)
			)
			previous_camera_position = camera.global_position
		if maximum_frame_step > 2.5:
			_fail("F%d transition jumped %.3f units in one frame" % [preset_id, maximum_frame_step])
			return

		if int(camera.call("get_active_preset_id")) != preset_id:
			_fail("F%d did not activate through runtime input" % preset_id)
			return
		if camera.projection != int(expected["projection"]):
			_fail("F%d projection mismatch" % preset_id)
			return
		if preset_id == 1:
			# Position is an ongoing exponential follow-lerp, not a tween with
			# a completion signal, so it only ever asymptotically approaches
			# the legacy offset -- a small residual after 60 frames is expected.
			var offset := camera.global_position - player.global_position
			if offset.distance_to(expected["offset"]) > 0.05:
				_fail("F1 legacy offset mismatch: %s" % str(offset))
				return
		if expected.has("size") and not is_equal_approx(camera.size, float(expected["size"])):
			_fail("F%d orthographic size mismatch" % preset_id)
			return
		if expected.has("fov") and not is_equal_approx(camera.fov, float(expected["fov"])):
			_fail("F%d perspective FOV mismatch" % preset_id)
			return
		if expected.has("distance"):
			var distance := float(camera.call("get_camera_distance"))
			if not is_equal_approx(distance, float(expected["distance"])):
				_fail("F%d camera distance mismatch: %.3f" % [preset_id, distance])
				return
		var pitch := float(camera.call("get_downward_pitch_degrees"))
		if absf(pitch - float(expected["pitch"])) > 0.15:
			_fail("F%d pitch mismatch: %.3f" % [preset_id, pitch])
			return
		if debug_label.text != str(expected["label"]):
			_fail("F%d debug label mismatch: %s" % [preset_id, debug_label.text])
			return

	_send_function_key(KEY_F3)
	_send_function_key(KEY_F4)
	for frame_index in range(4):
		await get_tree().physics_frame
	if int(camera.call("get_active_preset_id")) != 2:
		_fail("Retired F3/F4 keys must not change the active preset")
		return

	if not is_equal_approx(visual.pixel_size, 0.00162):
		_fail("Camera tuning must not alter Takashi's sprite scale")
		return
	if visual.billboard != BaseMaterial3D.BILLBOARD_ENABLED:
		_fail("Takashi must keep billboard facing enabled")
		return

	player.set_physics_process(false)
	player.velocity = Vector3.ZERO
	visual.pause()
	visual.frame = 0
	visual.flip_h = false
	var viewport_size := get_viewport().get_visible_rect().size
	var minimum_sprite_height := INF
	var maximum_sprite_height := 0.0
	for area in TEST_AREAS:
		player.global_position = area["position"]
		camera.call("apply_camera_preset", 2, false)
		for frame_index in range(8):
			await get_tree().process_frame

		if camera.is_position_behind(visual.global_position):
			_fail("Takashi is behind the F2 camera in %s" % area["name"])
			return

		var screen_center := camera.unproject_position(visual.global_position)
		var center_fraction := Vector2(
			screen_center.x / viewport_size.x,
			screen_center.y / viewport_size.y
		)
		if center_fraction.x < 0.1 or center_fraction.x > 0.9:
			_fail("Takashi leaves the safe horizontal frame in %s" % area["name"])
			return
		if center_fraction.y < 0.5:
			_fail("Takashi should sit in the lower half of frame (more world ahead) in %s" % area["name"])
			return

		var frame_texture := visual.sprite_frames.get_frame_texture(visual.animation, visual.frame)
		if frame_texture == null:
			_fail("Takashi frame texture is unavailable in %s" % area["name"])
			return
		var half_sprite_height := frame_texture.get_height() * visual.pixel_size * visual.scale.y * 0.5
		var top_screen := camera.unproject_position(visual.global_position + Vector3.UP * half_sprite_height)
		var bottom_screen := camera.unproject_position(visual.global_position - Vector3.UP * half_sprite_height)
		var sprite_screen_height := absf(bottom_screen.y - top_screen.y)
		minimum_sprite_height = minf(minimum_sprite_height, sprite_screen_height)
		maximum_sprite_height = maxf(maximum_sprite_height, sprite_screen_height)
		if top_screen.y < 12.0 or bottom_screen.y > viewport_size.y - 12.0:
			_fail("Takashi is not fully visible in %s" % area["name"])
			return
		var screen_height_fraction := sprite_screen_height / viewport_size.y
		if screen_height_fraction <= OLD_F2_MAX_SCREEN_HEIGHT_FRACTION:
			_fail(
				(
					"Takashi must read meaningfully larger than the old F2 ceiling (%.3f) in %s, got %.3f"
					% [OLD_F2_MAX_SCREEN_HEIGHT_FRACTION, area["name"], screen_height_fraction]
				)
			)
			return
		if screen_height_fraction > 0.75:
			_fail("Takashi screen size is unreasonably large (camera too close) in %s" % area["name"])
			return

		var shadow_offset := Vector2(
			shadow.global_position.x - player.global_position.x,
			shadow.global_position.z - player.global_position.z
		)
		if shadow_offset.length() > 0.02:
			_fail("Takashi's shadow is detached in %s" % area["name"])
			return

	if maximum_sprite_height - minimum_sprite_height > 1.0:
		_fail("Perspective sprite scale varies across normal exploration positions")
		return

	var occluder_meshes: Dictionary = world.get("_tree_occluder_meshes")
	var blocker_tree: Node3D
	for tree_variant in occluder_meshes.keys():
		var tree := tree_variant as Node3D
		if tree == null:
			continue
		var blocker_test_position := tree.global_position - Vector3(2.25, 0.0, 8.5)
		if (
			absf(blocker_test_position.x) < 20.0
			and blocker_test_position.z > -14.0
			and blocker_test_position.z < 14.0
		):
			blocker_tree = tree
			player.global_position = Vector3(
				blocker_test_position.x,
				0.63,
				blocker_test_position.z
			)
			break
	if blocker_tree == null:
		_fail("No registered tree was available for the F2 occluder test")
		return
	camera.call("apply_camera_preset", 2, false)
	for frame_index in range(36):
		await get_tree().process_frame
	var faded_occluder_found := false
	var blocker_meshes: Array = occluder_meshes[blocker_tree]
	for mesh_variant in blocker_meshes:
		var mesh := mesh_variant as GeometryInstance3D
		if mesh != null and mesh.transparency > 0.1:
			faded_occluder_found = true
			break
	if not faded_occluder_found:
		_fail("Tree transparency did not remain active with a controlled F2 blocker")
		return

	print("CAMERA_PRESETS_OK F1 rollback, F2 closer framing, five areas, sprite, shadow, and occluders verified")
	get_tree().quit(0)


func _send_function_key(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	Input.parse_input_event(event)


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
