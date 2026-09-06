class_name BattleCameraCoordinator
extends RefCounted

## Coordinates 2D battle camera shake, target hit shakes, and viewport resets.

var camera_shake_tween: Tween = null


func shake_camera(manager: Node) -> void:
	shake_camera_with_strength(manager, manager.CAMERA_SHAKE_OFFSET)


func shake_camera_with_strength(manager: Node, strength: float) -> void:
	if manager.battle_presentation_3d != null and is_instance_valid(manager.battle_presentation_3d):
		manager.battle_presentation_3d.camera_shake(strength)
		return

	if manager.battle_camera == null:
		return

	if camera_shake_tween != null and camera_shake_tween.is_valid():
		camera_shake_tween.kill()
	camera_shake_tween = manager.create_tween()
	camera_shake_tween.tween_property(manager.battle_camera, "offset", Vector2(strength, randf_range(-1.5, 1.5)), 0.025)
	camera_shake_tween.tween_property(manager.battle_camera, "offset", Vector2(-strength, randf_range(-1.5, 1.5)), 0.035)
	camera_shake_tween.tween_property(manager.battle_camera, "offset", Vector2.ZERO, 0.035)


func shake_target_once(manager: Node, target: Node2D, strength: float, duration: float) -> Signal:
	if target == null:
		return manager.get_tree().process_frame

	var original_position: Vector2 = target.position
	var half_duration: float = duration * 0.5
	var tween: Tween = manager.create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(
		target,
		"position",
		original_position + Vector2(
			randf_range(-strength, strength),
			randf_range(-strength * 0.35, strength * 0.35)
		),
		half_duration
	)
	tween.tween_property(target, "position", original_position, half_duration)
	return tween.finished


func reset_camera(manager: Node) -> void:
	if manager.battle_camera != null:
		if camera_shake_tween != null and camera_shake_tween.is_valid():
			camera_shake_tween.kill()
		var viewport_size: Vector2 = manager.get_viewport().get_visible_rect().size
		if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
			viewport_size = manager.BASE_VIEWPORT_SIZE
		manager.battle_camera.position = viewport_size * 0.5
		manager.battle_camera.offset = Vector2.ZERO
		manager.battle_camera.zoom = Vector2.ONE
