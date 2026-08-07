extends Node

const ABYSS_SCENE := preload("res://scenes/world_3d/abyss_forest_3d.tscn")
const CAMERA_OBSTRUCTION_LAYER_BIT := 2


func _ready() -> void:
	var world := ABYSS_SCENE.instantiate() as Node3D
	if world == null:
		_fail("Abyss Forest could not be instantiated for camera obstruction test")
		return
	add_child(world)
	await get_tree().process_frame
	await get_tree().physics_frame

	var camera := world.get_node_or_null("ExplorationCamera") as Camera3D
	var player := world.get_node_or_null("Player") as CharacterBody3D
	if camera == null or player == null:
		_fail("Camera obstruction test is missing camera or player")
		return

	player.set_physics_process(false)
	player.velocity = Vector3.ZERO
	player.global_position = Vector3(0.0, 0.63, 13.5)
	camera.call("apply_camera_preset", 2, false)
	camera.set("_yaw_target_degrees", 0.0)
	camera.set("_pitch_target_degrees", 14.5)
	camera.set("_distance_target", 13.0)
	for frame_index in range(240):
		await get_tree().physics_frame

	var clear_distance := float(camera.call("get_camera_distance"))
	if not is_equal_approx(clear_distance, 13.0):
		_fail("Baseline (unobstructed) camera distance should be 13.0, got %.3f" % clear_distance)
		return

	# Drop a solid obstacle across the pivot -> camera line, close enough to
	# the camera end that the raycast must pull the distance in noticeably.
	var pivot_position: Vector3 = player.global_position + Vector3(0.0, 1.05, -2.0)
	var camera_side_point := pivot_position.lerp(camera.global_position, 0.7)
	var obstacle := StaticBody3D.new()
	obstacle.collision_layer = CAMERA_OBSTRUCTION_LAYER_BIT
	obstacle.collision_mask = 0
	obstacle.position = camera_side_point
	world.add_child(obstacle)
	var obstacle_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8.0, 8.0, 8.0)
	obstacle_shape.shape = box
	obstacle.add_child(obstacle_shape)

	# Obstruction pull-in is intentionally fast (move_toward, not exponential),
	# so a handful of frames is enough for it to take effect.
	var pulled_in_distance := clear_distance
	for frame_index in range(30):
		await get_tree().physics_frame
		pulled_in_distance = float(camera.call("get_camera_distance"))
	if pulled_in_distance >= clear_distance - 0.5:
		_fail(
			"Camera did not pull in when obstructed: clear=%.3f obstructed=%.3f"
			% [clear_distance, pulled_in_distance]
		)
		return
	if pulled_in_distance < 1.9:
		_fail("Camera pulled in past its minimum obstruction distance: %.3f" % pulled_in_distance)
		return

	# The camera must never end up farther from the pivot than the obstacle
	# hit point once obstructed (no clipping through the obstacle).
	var pivot_now: Vector3 = player.global_position + Vector3(0.0, 1.05, -2.0)
	if camera.global_position.distance_to(pivot_now) > pivot_now.distance_to(camera_side_point) + 0.5:
		_fail("Camera position clipped past the obstacle instead of stopping short of it")
		return

	obstacle.queue_free()
	await get_tree().physics_frame

	# Restoration is intentionally slower (exponential ease), so give it a
	# generous settle window and require it to have recovered by the end.
	for frame_index in range(240):
		await get_tree().physics_frame
	var restored_distance := float(camera.call("get_camera_distance"))
	if not is_equal_approx(restored_distance, 13.0):
		_fail("Camera distance did not smoothly restore after obstruction cleared, got %.3f" % restored_distance)
		return

	print("CAMERA_OBSTRUCTION_OK pull-in, no clip-through, and smooth restore verified")
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
