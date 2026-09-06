extends Node

const ABYSS_SCENE := preload("res://scenes/world_3d/abyss_forest_3d.tscn")


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	var world := ABYSS_SCENE.instantiate() as Node3D
	if world == null:
		_fail("Abyss Forest could not be instantiated for camera control test")
		return
	add_child(world)
	await get_tree().process_frame
	await get_tree().physics_frame

	var camera := world.get_node_or_null("ExplorationCamera") as Camera3D
	var player := world.get_node_or_null("Player") as CharacterBody3D
	if camera == null or player == null:
		_fail("Camera control test is missing camera or player")
		return

	player.set_physics_process(false)
	player.velocity = Vector3.ZERO
	player.global_position = Vector3(0.0, 0.63, 6.0)
	camera.call("apply_camera_preset", 2, false)
	for frame_index in range(6):
		await get_tree().process_frame

	if not is_equal_approx(camera.fov, 35.5):
		_fail("F2 default FOV must stay fixed at 35.5, got %.3f" % camera.fov)
		return
	if not is_equal_approx(float(camera.call("get_camera_distance")), 13.0):
		_fail("F2 default distance must start at 13.0, got %.3f" % float(camera.call("get_camera_distance")))
		return

	# --- Mouse wheel must physically dolly the camera, not touch FOV ---
	for wheel_index in range(10):
		_send_wheel(true)
	await _settle(world, 240)
	if not is_equal_approx(camera.fov, 35.5):
		_fail("Zoom must never change FOV, got %.3f" % camera.fov)
		return
	if not is_equal_approx(float(camera.get("_distance_current")), 7.0):
		_fail("Zoom-in did not settle at the 7m clamp, got %.3f" % float(camera.get("_distance_current")))
		return

	for wheel_index in range(20):
		_send_wheel(false)
	await _settle(world, 240)
	if not is_equal_approx(float(camera.get("_distance_current")), 19.0):
		_fail("Zoom-out did not settle at the 19m clamp, got %.3f" % float(camera.get("_distance_current")))
		return

	# --- F5/F6/F7 debug shortcuts retarget distance only ---
	_send_key(KEY_F5)
	await _settle(world, 240)
	if not is_equal_approx(float(camera.get("_distance_current")), 7.0):
		_fail("F5 close shortcut did not reach 7m, got %.3f" % float(camera.get("_distance_current")))
		return
	_send_key(KEY_F6)
	await _settle(world, 240)
	if not is_equal_approx(float(camera.get("_distance_current")), 11.0):
		_fail("F6 medium shortcut did not reach 11m, got %.3f" % float(camera.get("_distance_current")))
		return
	_send_key(KEY_F7)
	await _settle(world, 240)
	if not is_equal_approx(float(camera.get("_distance_current")), 19.0):
		_fail("F7 wide shortcut did not reach 19m, got %.3f" % float(camera.get("_distance_current")))
		return

	# --- Reset (R) must smoothly return FOV/distance to their defaults ---
	_send_key(KEY_R)
	await _settle(world, 240)
	if not is_equal_approx(camera.fov, 35.5):
		_fail("Reset did not restore default FOV, got %.3f" % camera.fov)
		return
	if not is_equal_approx(float(camera.get("_distance_current")), 13.0):
		_fail("Reset did not restore default distance, got %.3f" % float(camera.get("_distance_current")))
		return

	# --- Yaw orbit must reach a full 360 degrees ---
	_send_mouse_button(MOUSE_BUTTON_RIGHT, true)
	_send_mouse_motion(Vector2(600.0, 0.0))  # 600px * 0.15 deg/px = 90 degrees
	_send_mouse_button(MOUSE_BUTTON_RIGHT, false)
	await _settle(world, 240)
	var yaw_side := float(camera.get("_yaw_current_degrees"))
	if not is_equal_approx(yaw_side, 90.0):
		_fail("Yaw did not reach 90 degrees (side view), got %.3f" % yaw_side)
		return
	if camera.is_position_behind(player.global_position):
		_fail("Player must remain in front of the camera at 90 degree yaw")
		return

	# Drag further to 170 degrees, then continue past the +/-180 seam and verify the
	# camera takes the short way around (monotonic convergence, no long-way jump).
	_send_mouse_button(MOUSE_BUTTON_RIGHT, true)
	_send_mouse_motion(Vector2(533.34, 0.0))  # +80 degrees -> target 170 degrees
	_send_mouse_button(MOUSE_BUTTON_RIGHT, false)
	await _settle(world, 240)
	var yaw_near_seam := float(camera.get("_yaw_current_degrees"))
	if not is_equal_approx(yaw_near_seam, 170.0):
		_fail("Yaw did not reach 170 degrees ahead of the wrap seam, got %.3f" % yaw_near_seam)
		return

	_send_mouse_button(MOUSE_BUTTON_RIGHT, true)
	_send_mouse_motion(Vector2(200.0, 0.0))  # +30 degrees -> wraps target to -160 degrees
	_send_mouse_button(MOUSE_BUTTON_RIGHT, false)
	await world.get_tree().physics_frame
	var yaw_target_after_wrap := float(camera.get("_yaw_target_degrees"))
	if not is_equal_approx(yaw_target_after_wrap, -160.0):
		_fail("Yaw target did not wrap safely past 180 degrees, got %.3f" % yaw_target_after_wrap)
		return

	var previous_gap := INF
	for frame_index in range(240):
		await world.get_tree().physics_frame
		var current_yaw := float(camera.get("_yaw_current_degrees"))
		var target_yaw := float(camera.get("_yaw_target_degrees"))
		var gap := absf(wrapf(target_yaw - current_yaw, -180.0, 180.0))
		if gap > previous_gap + 0.01:
			_fail("Yaw must converge monotonically across the wrap seam (short way around)")
			return
		previous_gap = gap
	var yaw_after_wrap := float(camera.get("_yaw_current_degrees"))
	if not is_equal_approx(yaw_after_wrap, -160.0):
		_fail("Yaw did not settle at -160 degrees after wrapping, got %.3f" % yaw_after_wrap)
		return

	# Full 180 degree orbit (directly behind Takashi) must also be reachable.
	camera.set("_yaw_target_degrees", 180.0)
	await _settle(world, 240)
	var yaw_behind := float(camera.get("_yaw_current_degrees"))
	if not (is_equal_approx(yaw_behind, 180.0) or is_equal_approx(yaw_behind, -180.0)):
		_fail("Yaw did not reach 180 degrees (directly behind), got %.3f" % yaw_behind)
		return

	# --- Reset (R) must smoothly return yaw to zero via the shortest path ---
	_send_key(KEY_R)
	var reset_previous_gap := INF
	for frame_index in range(240):
		await world.get_tree().physics_frame
		var current_yaw := float(camera.get("_yaw_current_degrees"))
		var gap := absf(wrapf(0.0 - current_yaw, -180.0, 180.0))
		if gap > reset_previous_gap + 0.01:
			_fail("Yaw reset must converge monotonically, not oscillate")
			return
		reset_previous_gap = gap
	var yaw_after_reset := float(camera.get("_yaw_current_degrees"))
	if not is_equal_approx(yaw_after_reset, 0.0):
		_fail("Reset did not restore yaw to zero, got %.3f" % yaw_after_reset)
		return

	# --- Pitch orbit must clamp the absolute downward angle to [10, 32] ---
	_send_mouse_button(MOUSE_BUTTON_MIDDLE, true)
	_send_mouse_motion(Vector2(0.0, -4000.0))
	_send_mouse_button(MOUSE_BUTTON_MIDDLE, false)
	await _settle(world, 240)
	var pitch_up := float(camera.get("_pitch_current_degrees"))
	if not is_equal_approx(pitch_up, 32.0):
		_fail("Drag-up pitch did not settle at the 32 degree clamp, got %.3f" % pitch_up)
		return

	_send_mouse_button(MOUSE_BUTTON_MIDDLE, true)
	_send_mouse_motion(Vector2(0.0, 8000.0))
	_send_mouse_button(MOUSE_BUTTON_MIDDLE, false)
	await _settle(world, 240)
	var pitch_down := float(camera.get("_pitch_current_degrees"))
	if not is_equal_approx(pitch_down, 10.0):
		_fail("Drag-down pitch did not settle at the 10 degree clamp, got %.3f" % pitch_down)
		return

	_send_key(KEY_R)
	await _settle(world, 240)
	var pitch_after_reset := float(camera.get("_pitch_current_degrees"))
	if not is_equal_approx(pitch_after_reset, 14.5):
		_fail("Reset did not restore pitch to the 14.5 degree default, got %.3f" % pitch_after_reset)
		return

	# --- Tree occluder fading must keep working from every orbit angle ---
	# Reuses the exact geometric test abyss_forest_3d.gd applies in _update_camera_occluders
	# so this stays correct even though that script is out of scope to modify here.
	var occluder_meshes: Dictionary = world.get("_tree_occluder_meshes")
	var test_yaw_degrees: Array[float] = [0.0, 90.0, 180.0, -90.0, 45.0]
	var found_blocker_at_any_angle := false
	for test_yaw in test_yaw_degrees:
		camera.set("_yaw_target_degrees", test_yaw)
		camera.set("_pitch_target_degrees", 14.5)
		camera.set("_distance_target", 13.0)
		await _settle(world, 180)
		for frame_index in range(12):
			await world.get_tree().process_frame

		var camera_flat := Vector2(camera.global_position.x, camera.global_position.z)
		var player_flat := Vector2(player.global_position.x, player.global_position.z)
		var segment := player_flat - camera_flat
		var segment_length_squared := segment.length_squared()
		if segment_length_squared < 0.001:
			continue
		for tree_variant in occluder_meshes.keys():
			var tree := tree_variant as Node3D
			if not is_instance_valid(tree):
				continue
			var tree_flat := Vector2(tree.global_position.x, tree.global_position.z)
			var segment_t := clampf((tree_flat - camera_flat).dot(segment) / segment_length_squared, 0.0, 1.0)
			var closest_point := camera_flat + segment * segment_t
			if segment_t > 0.06 and segment_t < 0.96 and tree_flat.distance_to(closest_point) < 3.1:
				var meshes: Array = occluder_meshes[tree]
				for mesh_variant in meshes:
					var mesh := mesh_variant as GeometryInstance3D
					if mesh != null and mesh.transparency > 0.1:
						found_blocker_at_any_angle = true
				break
		if found_blocker_at_any_angle:
			break
	if not found_blocker_at_any_angle:
		_fail("Occluder fading did not activate at any tested orbit angle")
		return
	camera.call("apply_camera_preset", 2, false)
	await _settle(world, 240)

	# The occluder-fade sweep above orbits yaw to whatever angle first finds
	# a blocking tree, then leaves it there -- it never claimed to restore
	# yaw to 0. That was harmless while it happened to land near 0, but the
	# exact angle depends on where trees are, and the Abyss remake pass
	# (landmark exclusion zones + minimum tree spacing) moved them, so the
	# sweep now stops at 180 degrees. Reset explicitly so the F1 isolation
	# check below depends only on F1 behavior, not on incidental leftover
	# yaw from an unrelated, tree-layout-sensitive test above it.
	_send_key(KEY_R)
	await _settle(world, 240)

	# --- F1 must remain completely unaffected by mouse camera control ---
	_send_key(KEY_F1)
	await _settle(world, 45)
	var f1_offset := camera.global_position - player.global_position
	if f1_offset.distance_to(Vector3(10.5, 12.5, 10.5)) > 0.1:
		_fail("F1 offset changed unexpectedly: %s" % str(f1_offset))
		return
	_send_wheel(true)
	_send_mouse_button(MOUSE_BUTTON_RIGHT, true)
	_send_mouse_motion(Vector2(4000.0, 4000.0))
	_send_mouse_button(MOUSE_BUTTON_RIGHT, false)
	await _settle(world, 45)
	if not is_equal_approx(float(camera.get("_distance_current")), 13.0):
		_fail("Mouse wheel must be ignored entirely while F1 is active")
		return
	if not is_equal_approx(float(camera.get("_yaw_current_degrees")), 0.0):
		_fail("Mouse drag must be ignored entirely while F1 is active")
		return
	if camera.projection != Camera3D.PROJECTION_ORTHOGONAL or not is_equal_approx(camera.size, 15.2):
		_fail("F1 projection/size must stay exactly at baseline")
		return

	# --- Switching back to F2 must restore F2 cleanly with no lingering orbit ---
	_send_key(KEY_F2)
	await _settle(world, 240)
	if not is_equal_approx(camera.fov, 35.5):
		_fail("F2 did not restore cleanly to default FOV after an F1 detour, got %.3f" % camera.fov)
		return
	if not is_equal_approx(float(camera.call("get_camera_distance")), 13.0):
		_fail("F2 did not restore cleanly to default distance after an F1 detour")
		return

	# --- mouse_control_enabled gate must block all mouse camera input ---
	camera.call("set_mouse_control_enabled", false)
	_send_wheel(true)
	_send_mouse_button(MOUSE_BUTTON_RIGHT, true)
	_send_mouse_motion(Vector2(4000.0, 0.0))
	_send_mouse_button(MOUSE_BUTTON_RIGHT, false)
	await _settle(world, 45)
	if not is_equal_approx(float(camera.get("_distance_target")), 13.0):
		_fail("mouse_control_enabled=false must block wheel zoom input")
		return
	if not is_equal_approx(float(camera.get("_yaw_target_degrees")), 0.0):
		_fail("mouse_control_enabled=false must block orbit drag input")
		return
	camera.call("set_mouse_control_enabled", true)

	print("CAMERA_PLAYER_CONTROL_OK distance zoom, F5-F7, yaw wrap, pitch clamps, reset, F1 isolation, F2 restore, occluders, and gating verified")
	get_tree().quit(0)


func _settle(world: Node, frames: int) -> void:
	for frame_index in range(frames):
		await world.get_tree().physics_frame


func _send_key(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	Input.parse_input_event(event)


func _send_wheel(zoom_in: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_UP if zoom_in else MOUSE_BUTTON_WHEEL_DOWN
	event.pressed = true
	event.position = Vector2(640.0, 360.0)
	Input.parse_input_event(event)


func _send_mouse_button(button_index: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	event.pressed = pressed
	event.position = Vector2(640.0, 360.0)
	Input.parse_input_event(event)


func _send_mouse_motion(relative: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = relative
	event.position = Vector2(640.0, 360.0) + relative
	Input.parse_input_event(event)


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
