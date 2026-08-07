extends Node

## Proves ExplorationCamera3D is a standalone, reusable component: it must
## work with a plain, non-Abyss-specific target and without any Abyss Forest
## node in the tree at all.

const CAMERA_SCENE := preload("res://scenes/world_3d/components/exploration_camera_3d.tscn")


func _ready() -> void:
	var camera := CAMERA_SCENE.instantiate() as Camera3D
	if camera == null:
		_fail("Exploration camera component failed to instantiate")
		return
	add_child(camera)

	var target := CharacterBody3D.new()
	target.name = "GenericExplorer"
	var shape := CollisionShape3D.new()
	shape.shape = CapsuleShape3D.new()
	target.add_child(shape)
	add_child(target)
	target.global_position = Vector3(100.0, 0.0, -40.0)

	camera.call("set_target", target)
	for frame_index in range(60):
		await get_tree().physics_frame

	var distance_from_target := camera.global_position.distance_to(target.global_position)
	if distance_from_target < 4.0 or distance_from_target > 25.0:
		_fail(
			"Camera did not settle at a sane distance from a generic target: %.3f"
			% distance_from_target
		)
		return
	if int(camera.call("get_active_preset_id")) != 2:
		_fail("Component must default to its production preset without any Abyss scene present")
		return

	# Move the target and confirm the camera actually follows it.
	target.global_position = Vector3(120.0, 0.0, -55.0)
	for frame_index in range(90):
		await get_tree().physics_frame
	var follow_gap := camera.global_position.distance_to(target.global_position)
	if follow_gap < 4.0 or follow_gap > 25.0:
		_fail("Camera did not follow the generic target after it moved: gap=%.3f" % follow_gap)
		return

	# Apply configured distance/pitch and confirm they take effect with no
	# Abyss-specific state involved.
	camera.set("_distance_target", 9.0)
	camera.set("_pitch_target_degrees", 25.0)
	for frame_index in range(240):
		await get_tree().physics_frame
	var configured_distance := float(camera.call("get_camera_distance"))
	if not is_equal_approx(configured_distance, 9.0):
		_fail("Configured distance did not apply on a standalone target: %.3f" % configured_distance)
		return
	var configured_pitch := float(camera.call("get_downward_pitch_degrees"))
	if not is_equal_approx(configured_pitch, 25.0):
		_fail("Configured pitch did not apply on a standalone target: %.3f" % configured_pitch)
		return

	if has_node("AbyssForest3D") or get_tree().root.find_child("SealArea", true, false) != null:
		_fail("Reusability test accidentally pulled in Abyss-specific nodes")
		return

	print("EXPLORATION_CAMERA_REUSABILITY_OK standalone instantiate, generic target, follow, and configuration verified")
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
